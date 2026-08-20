// 中央編集領域のキャンバス表示を担当する。
// 論理サイズと画面上の拡大率を分離し、描画にはDirect2Dを優先して使用する。
unit VectArtDesignerCanvas;

interface

uses
  System.Classes, System.Types, Vcl.Controls, VectArtDesignerCanvasInteraction,
  VectArtDesignerDocument, VectArtDesignerEditHistory,
  VectArtDesignerEditorState, VectArtDesignerSelectionGeometry,
  VectArtDesignerShapeCreation;

type
  TVectArtCanvasControl = class(TCustomControl)
  private
    FCanvasBounds: TRect;
    FDirect2DEnabled: Boolean;
    FDocument: TVectArtDocument;
    FEditorState: TVectArtEditorState;
    FInteraction: TVectArtCanvasInteraction;
    FShapeCreation: TVectArtShapeCreation;
    FPanning: Boolean;
    FPanOffset: TPointF;
    FPanStartMouse: TPoint;
    FPanStartOffset: TPointF;
    FViewZoom: Single;
    FZoom: Single;
    procedure CalculateCanvasBounds;
    procedure EndPan;
    procedure PaintDirect2D;
    procedure PaintGDI;
    procedure SetDocument(const Value: TVectArtDocument);
    procedure SetEditorState(const Value: TVectArtEditorState);
    function GetEditHistory: TVectArtEditHistory;
    procedure SetEditHistory(const Value: TVectArtEditHistory);
  protected
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property CanvasBounds: TRect read FCanvasBounds;
    property Document: TVectArtDocument read FDocument write SetDocument;
    property EditHistory: TVectArtEditHistory read GetEditHistory
      write SetEditHistory;
    property EditorState: TVectArtEditorState read FEditorState
      write SetEditorState;
    property Zoom: Single read FZoom;
  end;

const
  DESIGN_CANVAS_WIDTH  = DEFAULT_CANVAS_WIDTH;
  DESIGN_CANVAS_HEIGHT = DEFAULT_CANVAS_HEIGHT;

implementation

uses
  System.Math, Winapi.Windows, Vcl.Direct2D, Vcl.Graphics;

const
  CANVAS_MARGIN         = 32;
  CANVAS_SHADOW_OFFSET  = 6;
  COLOR_EDITOR_SURROUND = TColor($00121212);
  COLOR_CANVAS_SHADOW   = TColor($00070707);
  COLOR_SELECTION       = clBlack;
  COLOR_TRANSPARENT_A   = TColor($00D8D8D8);
  COLOR_TRANSPARENT_B   = TColor($00FFFFFF);
  TRANSPARENCY_CELL     = 16;
  MAX_VIEW_ZOOM         = 8.0;
  MIN_VIEW_ZOOM         = 0.25;
  VIEW_ZOOM_STEP        = 1.2;

function BlendColor(Foreground, Background: TColor;
  Opacity: Single): TColor;
var
  BackColor: TColor;
  ForeColor: TColor;
begin
  ForeColor := ColorToRGB(Foreground);
  BackColor := ColorToRGB(Background);
  Opacity := EnsureRange(Opacity, 0.0, 1.0);
  Result := RGB(
    Round(GetRValue(ForeColor) * Opacity +
      GetRValue(BackColor) * (1 - Opacity)),
    Round(GetGValue(ForeColor) * Opacity +
      GetGValue(BackColor) * (1 - Opacity)),
    Round(GetBValue(ForeColor) * Opacity +
      GetBValue(BackColor) * (1 - Opacity)));
end;

constructor TVectArtCanvasControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Color := COLOR_EDITOR_SURROUND;
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  FDirect2DEnabled := TDirect2DCanvas.Supported;
  FInteraction := TVectArtCanvasInteraction.Create;
  FShapeCreation := TVectArtShapeCreation.Create;
  FPanOffset := TPointF.Zero;
  FViewZoom := 1.0;
  CalculateCanvasBounds;
end;

destructor TVectArtCanvasControl.Destroy;
begin
  FShapeCreation.Free;
  FInteraction.Free;
  inherited Destroy;
end;

procedure TVectArtCanvasControl.CalculateCanvasBounds;
var
  AvailableHeight: Integer;
  AvailableWidth: Integer;
  ControlHeight: Integer;
  ControlWidth: Integer;
  DisplayHeight: Integer;
  DisplayWidth: Integer;
  LogicalHeight: Integer;
  LogicalWidth: Integer;
begin
  // Create/Parent/Alignの途中ではまだWinControlのハンドルを作成できない。
  // ClientWidth/ClientHeightは暗黙にHandleNeededを呼ぶため、その期間は
  // ハンドルを必要としないWidth/Heightを使って初期値を計算する。
  if HandleAllocated then
  begin
    ControlWidth := ClientWidth;
    ControlHeight := ClientHeight;
  end
  else
  begin
    ControlWidth := Width;
    ControlHeight := Height;
  end;
  AvailableWidth := Max(ControlWidth - (CANVAS_MARGIN * 2), 1);
  AvailableHeight := Max(ControlHeight - (CANVAS_MARGIN * 2), 1);
  LogicalWidth := DESIGN_CANVAS_WIDTH;
  LogicalHeight := DESIGN_CANVAS_HEIGHT;
  if (FDocument <> nil) and (FDocument.CanvasLayer <> nil) then
  begin
    LogicalWidth := Max(FDocument.CanvasLayer.Width, 1);
    LogicalHeight := Max(FDocument.CanvasLayer.Height, 1);
  end;
  FZoom := Min(AvailableWidth / LogicalWidth,
    AvailableHeight / LogicalHeight);
  FZoom := Min(FZoom, 1.0);
  FZoom := FZoom * FViewZoom;
  DisplayWidth := Max(Round(LogicalWidth * FZoom), 1);
  DisplayHeight := Max(Round(LogicalHeight * FZoom), 1);
  FCanvasBounds := Rect(
    (ControlWidth - DisplayWidth) div 2 + Round(FPanOffset.X),
    (ControlHeight - DisplayHeight) div 2 + Round(FPanOffset.Y),
    (ControlWidth + DisplayWidth) div 2 + Round(FPanOffset.X),
    (ControlHeight + DisplayHeight) div 2 + Round(FPanOffset.Y));
end;

function TVectArtCanvasControl.DoMouseWheel(Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  CanvasX: Single;
  CanvasY: Single;
  ClientPoint: TPoint;
  NewViewZoom: Single;
begin
  ClientPoint := ScreenToClient(MousePos);
  if not PtInRect(ClientRect, ClientPoint) then
    Exit(inherited DoMouseWheel(Shift, WheelDelta, MousePos));

  Result := True;
  if WheelDelta = 0 then
    Exit;
  CalculateCanvasBounds;
  if FZoom <= 0 then
    Exit;

  // カーソル直下の論理キャンバス座標を、新しい倍率でも同じ位置に保つ。
  CanvasX := (ClientPoint.X - FCanvasBounds.Left) / FZoom;
  CanvasY := (ClientPoint.Y - FCanvasBounds.Top) / FZoom;
  if WheelDelta > 0 then
    NewViewZoom := FViewZoom * VIEW_ZOOM_STEP
  else
    NewViewZoom := FViewZoom / VIEW_ZOOM_STEP;
  NewViewZoom := EnsureRange(NewViewZoom, MIN_VIEW_ZOOM, MAX_VIEW_ZOOM);
  if SameValue(NewViewZoom, FViewZoom) then
    Exit;

  FViewZoom := NewViewZoom;
  FPanOffset := TPointF.Zero;
  CalculateCanvasBounds;
  FPanOffset.X := ClientPoint.X - CanvasX * FZoom - FCanvasBounds.Left;
  FPanOffset.Y := ClientPoint.Y - CanvasY * FZoom - FCanvasBounds.Top;
  CalculateCanvasBounds;
  Invalidate;
end;

procedure TVectArtCanvasControl.EndPan;
begin
  if not FPanning then
    Exit;
  FPanning := False;
  MouseCapture := False;
  Cursor := crDefault;
end;

function TVectArtCanvasControl.GetEditHistory: TVectArtEditHistory;
begin
  Result := FInteraction.EditHistory;
end;

procedure TVectArtCanvasControl.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbRight then
  begin
    FPanning := True;
    FPanStartMouse := Point(X, Y);
    FPanStartOffset := FPanOffset;
    MouseCapture := True;
    Cursor := crSizeAll;
    Exit;
  end;
  if (Button = mbLeft) and (FDocument <> nil) then
  begin
    if CanFocus then
      SetFocus;
    CalculateCanvasBounds;
    FShapeCreation.Configure(FDocument, EditHistory, FEditorState,
      FCanvasBounds, FZoom);
    if FShapeCreation.MouseDown(Button, Shift, X, Y) then
    begin
      MouseCapture := True;
      Cursor := crCross;
      Exit;
    end;
    if (FEditorState <> nil) and
      (FEditorState.CurrentTool = vetRectangle) then
    begin
      Cursor := crCross;
      Exit;
    end;
    FInteraction.Configure(FDocument, FCanvasBounds, FZoom);
    if FInteraction.MouseDown(Button, X, Y) then
    begin
      MouseCapture := True;
      Cursor := FInteraction.CursorAt(X, Y);
    end;
    Exit;
  end;
  // 左ドラッグは将来の範囲選択用として、この段階では開始しない。
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TVectArtCanvasControl.MouseMove(Shift: TShiftState;
  X, Y: Integer);
begin
  if FPanning then
  begin
    if not (ssRight in Shift) then
    begin
      EndPan;
      Exit;
    end;
    FPanOffset.X := FPanStartOffset.X + X - FPanStartMouse.X;
    FPanOffset.Y := FPanStartOffset.Y + Y - FPanStartMouse.Y;
    CalculateCanvasBounds;
    Invalidate;
    Exit;
  end;
  CalculateCanvasBounds;
  FShapeCreation.Configure(FDocument, EditHistory, FEditorState,
    FCanvasBounds, FZoom);
  if FShapeCreation.MouseMove(Shift, X, Y) then
  begin
    if not FShapeCreation.Active then
      MouseCapture := False;
    Cursor := crCross;
    Invalidate;
    Exit;
  end;
  if (FEditorState <> nil) and
    (FEditorState.CurrentTool = vetRectangle) then
  begin
    Cursor := crCross;
    Exit;
  end;
  FInteraction.Configure(FDocument, FCanvasBounds, FZoom);
  if FInteraction.MouseMove(Shift, X, Y) then
  begin
    if not FInteraction.Dragging then
      MouseCapture := False;
    Cursor := FInteraction.CursorAt(X, Y);
    Invalidate;
    Exit;
  end;
  Cursor := FInteraction.CursorAt(X, Y);
  inherited MouseMove(Shift, X, Y);
end;

procedure TVectArtCanvasControl.MouseUp(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if (Button = mbRight) and FPanning then
  begin
    EndPan;
    Exit;
  end;
  FShapeCreation.Configure(FDocument, EditHistory, FEditorState,
    FCanvasBounds, FZoom);
  if FShapeCreation.MouseUp(Button, Shift, X, Y) then
  begin
    MouseCapture := False;
    Cursor := crCross;
    Invalidate;
    Exit;
  end;
  if FInteraction.MouseUp(Button) then
  begin
    MouseCapture := False;
    FInteraction.Configure(FDocument, FCanvasBounds, FZoom);
    Cursor := FInteraction.CursorAt(X, Y);
    Exit;
  end;
  inherited MouseUp(Button, Shift, X, Y);
end;

procedure TVectArtCanvasControl.Paint;
begin
  CalculateCanvasBounds;
  if FDirect2DEnabled then
    try
      PaintDirect2D;
      Exit;
    except
      FDirect2DEnabled := False;
    end;
  PaintGDI;
end;

procedure TVectArtCanvasControl.PaintDirect2D;
var
  CanvasLayer: TVectArtCanvasLayer;
  CellRect: TRect;
  CreationRect: TRect;
  Column: Integer;
  ColumnEnd: Integer;
  ColumnStart: Integer;
  Direct2DCanvas: TDirect2DCanvas;
  Handle: TVectArtSelectionHandle;
  I: Integer;
  Layer: TVectArtLayer;
  LayerRect: TRect;
  RectangleLayer: TVectArtRectangleLayer;
  RangeRect: TRect;
  Row: Integer;
  RowEnd: Integer;
  RowStart: Integer;
  SelectionGeometry: TVectArtSelectionGeometry;
  SelectionLayerRect: TRect;
  SelectionLocked: Boolean;
  ShadowBounds: TRect;
  VisibleCanvasBounds: TRect;
begin
  Direct2DCanvas := TDirect2DCanvas.Create(Canvas, ClientRect);
  try
    Direct2DCanvas.BeginDraw;
    try
      SelectionLayerRect := TRect.Empty;
      SelectionLocked := False;
      Direct2DCanvas.Brush.Color := COLOR_EDITOR_SURROUND;
      Direct2DCanvas.FillRect(ClientRect);
      ShadowBounds := FCanvasBounds;
      OffsetRect(ShadowBounds, CANVAS_SHADOW_OFFSET, CANVAS_SHADOW_OFFSET);
      Direct2DCanvas.Brush.Color := COLOR_CANVAS_SHADOW;
      Direct2DCanvas.FillRect(ShadowBounds);

      CanvasLayer := nil;
      if FDocument <> nil then
        CanvasLayer := FDocument.CanvasLayer;
      if (CanvasLayer <> nil) and CanvasLayer.Visible and
        not CanvasLayer.Transparent then
      begin
        Direct2DCanvas.Brush.Color := CanvasLayer.BackgroundColor;
        Direct2DCanvas.FillRect(FCanvasBounds);
      end
      else
      begin
        if IntersectRect(VisibleCanvasBounds, FCanvasBounds, ClientRect) then
        begin
          ColumnStart := (VisibleCanvasBounds.Left - FCanvasBounds.Left) div
            TRANSPARENCY_CELL;
          ColumnEnd := (VisibleCanvasBounds.Right - 1 - FCanvasBounds.Left) div
            TRANSPARENCY_CELL;
          RowStart := (VisibleCanvasBounds.Top - FCanvasBounds.Top) div
            TRANSPARENCY_CELL;
          RowEnd := (VisibleCanvasBounds.Bottom - 1 - FCanvasBounds.Top) div
            TRANSPARENCY_CELL;
          for Row := RowStart to RowEnd do
            for Column := ColumnStart to ColumnEnd do
            begin
              CellRect := Rect(
                FCanvasBounds.Left + Column * TRANSPARENCY_CELL,
                FCanvasBounds.Top + Row * TRANSPARENCY_CELL,
                Min(FCanvasBounds.Left + (Column + 1) * TRANSPARENCY_CELL,
                  FCanvasBounds.Right),
                Min(FCanvasBounds.Top + (Row + 1) * TRANSPARENCY_CELL,
                  FCanvasBounds.Bottom));
              if Odd(Row + Column) then
                Direct2DCanvas.Brush.Color := COLOR_TRANSPARENT_A
              else
                Direct2DCanvas.Brush.Color := COLOR_TRANSPARENT_B;
              Direct2DCanvas.FillRect(CellRect);
            end;
        end;
      end;

      if FDocument <> nil then
        for I := 1 to FDocument.LayerCount - 1 do
        begin
          Layer := FDocument[I];
          if not Layer.Visible or not (Layer is TVectArtRectangleLayer) then
            Continue;
          RectangleLayer := TVectArtRectangleLayer(Layer);
          LayerRect := Rect(
            FCanvasBounds.Left + Round(RectangleLayer.Bounds.Left * FZoom),
            FCanvasBounds.Top + Round(RectangleLayer.Bounds.Top * FZoom),
            FCanvasBounds.Left + Round(RectangleLayer.Bounds.Right * FZoom),
            FCanvasBounds.Top + Round(RectangleLayer.Bounds.Bottom * FZoom));
          Direct2DCanvas.Brush.Color := RectangleLayer.FillColor;
          Direct2DCanvas.Brush.Handle.SetOpacity(
            EnsureRange(RectangleLayer.Opacity, 0.0, 1.0));
          Direct2DCanvas.FillRect(LayerRect);
          Direct2DCanvas.Brush.Handle.SetOpacity(1.0);
          if FDocument.IsLayerSelected(I) then
          begin
            SelectionLocked := SelectionLocked or Layer.Locked;
            if SelectionLayerRect.IsEmpty then
              SelectionLayerRect := LayerRect
            else
              SelectionLayerRect := Rect(
                Min(SelectionLayerRect.Left, LayerRect.Left),
                Min(SelectionLayerRect.Top, LayerRect.Top),
                Max(SelectionLayerRect.Right, LayerRect.Right),
                Max(SelectionLayerRect.Bottom, LayerRect.Bottom));
          end;
        end;
      if (SelectionLayerRect.Width > 0) and
        (SelectionLayerRect.Height > 0) then
      begin
        SelectionGeometry := BuildSelectionGeometry(SelectionLayerRect);
        // Direct2DのFrameRectはPenではなくBrushを使う。
        Direct2DCanvas.Brush.Style := bsSolid;
        Direct2DCanvas.Brush.Color := COLOR_SELECTION;
        Direct2DCanvas.FrameRect(SelectionGeometry.FrameRect);
        if not SelectionLocked then
          for Handle := vshTopLeft to vshLeft do
          begin
            Direct2DCanvas.Brush.Color := clWhite;
            Direct2DCanvas.FillRect(SelectionGeometry.Handles[Handle]);
            Direct2DCanvas.Brush.Color := COLOR_SELECTION;
            Direct2DCanvas.FrameRect(SelectionGeometry.Handles[Handle]);
          end;
      end;
      if FInteraction.RangeSelecting then
      begin
        RangeRect := FInteraction.RangeSelectionRect;
        Direct2DCanvas.Brush.Style := bsSolid;
        Direct2DCanvas.Brush.Color := COLOR_SELECTION;
        Direct2DCanvas.FrameRect(RangeRect);
      end;
      CreationRect := FShapeCreation.PreviewRect;
      if not CreationRect.IsEmpty then
      begin
        Direct2DCanvas.Brush.Style := bsSolid;
        Direct2DCanvas.Brush.Color := COLOR_SELECTION;
        Direct2DCanvas.FrameRect(CreationRect);
      end;
    finally
      Direct2DCanvas.EndDraw;
    end;
  finally
    Direct2DCanvas.Free;
  end;
end;

procedure TVectArtCanvasControl.PaintGDI;
var
  CanvasBackground: TColor;
  CanvasLayer: TVectArtCanvasLayer;
  CreationRect: TRect;
  CellRect: TRect;
  Column: Integer;
  ColumnEnd: Integer;
  ColumnStart: Integer;
  Handle: TVectArtSelectionHandle;
  I: Integer;
  Layer: TVectArtLayer;
  LayerRect: TRect;
  RectangleLayer: TVectArtRectangleLayer;
  RangeRect: TRect;
  Row: Integer;
  RowEnd: Integer;
  RowStart: Integer;
  SelectionGeometry: TVectArtSelectionGeometry;
  SelectionLayerRect: TRect;
  SelectionLocked: Boolean;
  ShadowBounds: TRect;
  VisibleCanvasBounds: TRect;
begin
  SelectionLayerRect := TRect.Empty;
  SelectionLocked := False;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := COLOR_EDITOR_SURROUND;
  Canvas.FillRect(ClientRect);
  ShadowBounds := FCanvasBounds;
  OffsetRect(ShadowBounds, CANVAS_SHADOW_OFFSET, CANVAS_SHADOW_OFFSET);
  Canvas.Brush.Color := COLOR_CANVAS_SHADOW;
  Canvas.FillRect(ShadowBounds);

  CanvasLayer := nil;
  CanvasBackground := clWhite;
  if FDocument <> nil then
    CanvasLayer := FDocument.CanvasLayer;
  if (CanvasLayer <> nil) and CanvasLayer.Visible and
    not CanvasLayer.Transparent then
  begin
    CanvasBackground := CanvasLayer.BackgroundColor;
    Canvas.Brush.Color := CanvasLayer.BackgroundColor;
    Canvas.FillRect(FCanvasBounds);
  end
  else
  begin
    if IntersectRect(VisibleCanvasBounds, FCanvasBounds, ClientRect) then
    begin
      ColumnStart := (VisibleCanvasBounds.Left - FCanvasBounds.Left) div
        TRANSPARENCY_CELL;
      ColumnEnd := (VisibleCanvasBounds.Right - 1 - FCanvasBounds.Left) div
        TRANSPARENCY_CELL;
      RowStart := (VisibleCanvasBounds.Top - FCanvasBounds.Top) div
        TRANSPARENCY_CELL;
      RowEnd := (VisibleCanvasBounds.Bottom - 1 - FCanvasBounds.Top) div
        TRANSPARENCY_CELL;
      for Row := RowStart to RowEnd do
        for Column := ColumnStart to ColumnEnd do
        begin
          CellRect := Rect(
            FCanvasBounds.Left + Column * TRANSPARENCY_CELL,
            FCanvasBounds.Top + Row * TRANSPARENCY_CELL,
            Min(FCanvasBounds.Left + (Column + 1) * TRANSPARENCY_CELL,
              FCanvasBounds.Right),
            Min(FCanvasBounds.Top + (Row + 1) * TRANSPARENCY_CELL,
              FCanvasBounds.Bottom));
          if Odd(Row + Column) then
            Canvas.Brush.Color := COLOR_TRANSPARENT_A
          else
            Canvas.Brush.Color := COLOR_TRANSPARENT_B;
          Canvas.FillRect(CellRect);
        end;
    end;
  end;

  if FDocument <> nil then
    for I := 1 to FDocument.LayerCount - 1 do
    begin
      Layer := FDocument[I];
      if not Layer.Visible or not (Layer is TVectArtRectangleLayer) then
        Continue;
      RectangleLayer := TVectArtRectangleLayer(Layer);
      LayerRect := Rect(
        FCanvasBounds.Left + Round(RectangleLayer.Bounds.Left * FZoom),
        FCanvasBounds.Top + Round(RectangleLayer.Bounds.Top * FZoom),
        FCanvasBounds.Left + Round(RectangleLayer.Bounds.Right * FZoom),
        FCanvasBounds.Top + Round(RectangleLayer.Bounds.Bottom * FZoom));
      Canvas.Brush.Color := BlendColor(RectangleLayer.FillColor,
        CanvasBackground, RectangleLayer.Opacity);
      Canvas.FillRect(LayerRect);
      if FDocument.IsLayerSelected(I) then
      begin
        SelectionLocked := SelectionLocked or Layer.Locked;
        if SelectionLayerRect.IsEmpty then
          SelectionLayerRect := LayerRect
        else
          SelectionLayerRect := Rect(
            Min(SelectionLayerRect.Left, LayerRect.Left),
            Min(SelectionLayerRect.Top, LayerRect.Top),
            Max(SelectionLayerRect.Right, LayerRect.Right),
            Max(SelectionLayerRect.Bottom, LayerRect.Bottom));
      end;
    end;
  if (SelectionLayerRect.Width > 0) and (SelectionLayerRect.Height > 0) then
  begin
    SelectionGeometry := BuildSelectionGeometry(SelectionLayerRect);
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := COLOR_SELECTION;
    Canvas.FrameRect(SelectionGeometry.FrameRect);
    if not SelectionLocked then
      for Handle := vshTopLeft to vshLeft do
      begin
        Canvas.Brush.Color := clWhite;
        Canvas.FillRect(SelectionGeometry.Handles[Handle]);
        Canvas.Brush.Color := COLOR_SELECTION;
        Canvas.FrameRect(SelectionGeometry.Handles[Handle]);
      end;
  end;
  if FInteraction.RangeSelecting then
  begin
    RangeRect := FInteraction.RangeSelectionRect;
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := COLOR_SELECTION;
    Canvas.FrameRect(RangeRect);
  end;
  CreationRect := FShapeCreation.PreviewRect;
  if not CreationRect.IsEmpty then
  begin
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := COLOR_SELECTION;
    Canvas.FrameRect(CreationRect);
  end;
end;

procedure TVectArtCanvasControl.Resize;
begin
  inherited Resize;
  CalculateCanvasBounds;
  Invalidate;
end;

procedure TVectArtCanvasControl.SetDocument(const Value: TVectArtDocument);
begin
  if FDocument = Value then
    Exit;
  FDocument := Value;
  FPanOffset := TPointF.Zero;
  FViewZoom := 1.0;
  CalculateCanvasBounds;
  Invalidate;
end;

procedure TVectArtCanvasControl.SetEditHistory(
  const Value: TVectArtEditHistory);
begin
  FInteraction.EditHistory := Value;
end;

procedure TVectArtCanvasControl.SetEditorState(
  const Value: TVectArtEditorState);
begin
  FEditorState := Value;
  Invalidate;
end;

end.
