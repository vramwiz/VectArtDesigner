// 編集キャンバス上の選択、移動、8方向リサイズの入力状態を管理する。
unit VectArtDesignerCanvasInteraction;

interface

uses
  System.Classes, System.Generics.Collections, System.Types, Vcl.Controls,
  VectArtDesignerDocument, VectArtDesignerEditHistory,
  VectArtDesignerEditCommands,
  VectArtDesignerSelectionGeometry;

type
  TVectArtCanvasDragMode = (vcdmNone, vcdmMove, vcdmResize,
    vcdmRangeSelect);

  TVectArtCanvasInteraction = class
  private
    FCanvasBounds: TRect;
    FDocument: TVectArtDocument;
    FEditHistory: TVectArtEditHistory;
    FDragHandle: TVectArtSelectionHandle;
    FDragLayerIndex: Integer;
    FDragMode: TVectArtCanvasDragMode;
    FMoveLayerIndices: TArray<Integer>;
    FMoveStartBounds: TArray<TRectF>;
    FDragStartBounds: TRectF;
    FDragStartMouse: TPoint;
    FRangeCurrent: TPoint;
    FRangeStart: TPoint;
    FZoom: Single;
    procedure EndDrag;
    procedure ApplyRangeSelection;
    procedure ApplyResizeSelection(X, Y: Integer);
    procedure CaptureMoveSelection;
    procedure CommitBoundsCommand;
    function GetDragging: Boolean;
    function GetRangeSelecting: Boolean;
    function GetRangeSelectionRect: TRect;
    function HitTestLayer(X, Y: Integer): Integer;
    function LayerScreenRect(Index: Integer): TRect;
    function ResizedBounds(X, Y: Integer): TRectF;
    function SelectionContainsLockedLayer: Boolean;
    function SelectedLayersLogicalRect: TRectF;
    function SelectedLayersScreenRect: TRect;
  public
    procedure Configure(ADocument: TVectArtDocument;
      const ACanvasBounds: TRect; AZoom: Single);
    function CursorAt(X, Y: Integer): TCursor;
    function MouseDown(Button: TMouseButton; X, Y: Integer): Boolean;
    function MouseMove(Shift: TShiftState; X, Y: Integer): Boolean;
    function MouseUp(Button: TMouseButton): Boolean;
    property Dragging: Boolean read GetDragging;
    property EditHistory: TVectArtEditHistory read FEditHistory
      write FEditHistory;
    property RangeSelecting: Boolean read GetRangeSelecting;
    property RangeSelectionRect: TRect read GetRangeSelectionRect;
  end;

implementation

uses
  System.Math;

const
  MIN_RECTANGLE_SIZE = 16.0;

procedure TVectArtCanvasInteraction.Configure(ADocument: TVectArtDocument;
  const ACanvasBounds: TRect; AZoom: Single);
begin
  FDocument := ADocument;
  FCanvasBounds := ACanvasBounds;
  FZoom := AZoom;
end;

function TVectArtCanvasInteraction.CursorAt(X, Y: Integer): TCursor;
var
  Geometry: TVectArtSelectionGeometry;
  Handle: TVectArtSelectionHandle;
  LayerIndex: Integer;
  SelectionRect: TRect;
begin
  Result := crDefault;
  if FDragMode = vcdmMove then
    Exit(crSizeAll);
  if FDragMode = vcdmResize then
    Exit(SelectionHandleCursor(FDragHandle));
  if FDragMode = vcdmRangeSelect then
    Exit(crCross);
  if FDocument = nil then
    Exit;
  SelectionRect := SelectedLayersScreenRect;
  if not SelectionRect.IsEmpty and not SelectionContainsLockedLayer then
  begin
    Geometry := BuildSelectionGeometry(SelectionRect);
    Handle := HitTestSelectionHandle(Point(X, Y), Geometry);
    if Handle <> vshNone then
      Exit(SelectionHandleCursor(Handle));
  end;
  LayerIndex := HitTestLayer(X, Y);
  if (LayerIndex >= 0) and not FDocument[LayerIndex].Locked and
    not SelectionContainsLockedLayer then
    Result := crSizeAll;
end;

procedure TVectArtCanvasInteraction.ApplyResizeSelection(X, Y: Integer);
var
  I: Integer;
  NewBounds: TRectF;
  NewSelectionBounds: TRectF;
  ScaleX: Single;
  ScaleY: Single;
  StartBounds: TRectF;
begin
  NewSelectionBounds := ResizedBounds(X, Y);
  ScaleX := NewSelectionBounds.Width / FDragStartBounds.Width;
  ScaleY := NewSelectionBounds.Height / FDragStartBounds.Height;
  for I := 0 to High(FMoveLayerIndices) do
  begin
    StartBounds := FMoveStartBounds[I];
    NewBounds.Left := NewSelectionBounds.Left +
      (StartBounds.Left - FDragStartBounds.Left) * ScaleX;
    NewBounds.Right := NewSelectionBounds.Left +
      (StartBounds.Right - FDragStartBounds.Left) * ScaleX;
    NewBounds.Top := NewSelectionBounds.Top +
      (StartBounds.Top - FDragStartBounds.Top) * ScaleY;
    NewBounds.Bottom := NewSelectionBounds.Top +
      (StartBounds.Bottom - FDragStartBounds.Top) * ScaleY;
    FDocument.SetRectangleBounds(FMoveLayerIndices[I], NewBounds);
  end;
end;

procedure TVectArtCanvasInteraction.ApplyRangeSelection;
var
  I: Integer;
  Intersection: TRect;
  LayerRect: TRect;
  RangeRect: TRect;
  SelectedLayers: TList<Integer>;
begin
  if FDocument = nil then
    Exit;
  RangeRect := GetRangeSelectionRect;
  if (RangeRect.Width < 3) or (RangeRect.Height < 3) then
  begin
    FDocument.SetSelectedLayers([]);
    Exit;
  end;
  SelectedLayers := TList<Integer>.Create;
  try
    for I := 1 to FDocument.LayerCount - 1 do
      if FDocument[I].Visible and
        (FDocument[I] is TVectArtRectangleLayer) then
      begin
        LayerRect := LayerScreenRect(I);
        if IntersectRect(Intersection, RangeRect, LayerRect) then
          SelectedLayers.Add(I);
      end;
    FDocument.SetSelectedLayers(SelectedLayers.ToArray);
  finally
    SelectedLayers.Free;
  end;
end;

procedure TVectArtCanvasInteraction.CaptureMoveSelection;
var
  I: Integer;
  MoveIndex: Integer;
begin
  SetLength(FMoveLayerIndices, FDocument.SelectionCount);
  SetLength(FMoveStartBounds, FDocument.SelectionCount);
  MoveIndex := 0;
  for I := 1 to FDocument.LayerCount - 1 do
    if FDocument.IsLayerSelected(I) and
      (FDocument[I] is TVectArtRectangleLayer) then
    begin
      FMoveLayerIndices[MoveIndex] := I;
      FMoveStartBounds[MoveIndex] :=
        TVectArtRectangleLayer(FDocument[I]).Bounds;
      Inc(MoveIndex);
    end;
  SetLength(FMoveLayerIndices, MoveIndex);
  SetLength(FMoveStartBounds, MoveIndex);
end;

procedure TVectArtCanvasInteraction.CommitBoundsCommand;
var
  BoundsChanged: Boolean;
  I: Integer;
  NewBounds: TArray<TRectF>;
begin
  if (FEditHistory = nil) or (FDocument = nil) or
    (Length(FMoveLayerIndices) = 0) then
    Exit;
  SetLength(NewBounds, Length(FMoveLayerIndices));
  BoundsChanged := False;
  for I := 0 to High(FMoveLayerIndices) do
  begin
    NewBounds[I] := TVectArtRectangleLayer(
      FDocument[FMoveLayerIndices[I]]).Bounds;
    BoundsChanged := BoundsChanged or
      not SameValue(NewBounds[I].Left, FMoveStartBounds[I].Left) or
      not SameValue(NewBounds[I].Top, FMoveStartBounds[I].Top) or
      not SameValue(NewBounds[I].Right, FMoveStartBounds[I].Right) or
      not SameValue(NewBounds[I].Bottom, FMoveStartBounds[I].Bottom);
  end;
  if BoundsChanged then
    FEditHistory.AddApplied(TVectArtBoundsCommand.Create(FDocument,
      FMoveLayerIndices, FMoveStartBounds, NewBounds));
end;

procedure TVectArtCanvasInteraction.EndDrag;
begin
  FDragMode := vcdmNone;
  FDragHandle := vshNone;
  FDragLayerIndex := -1;
  SetLength(FMoveLayerIndices, 0);
  SetLength(FMoveStartBounds, 0);
end;

function TVectArtCanvasInteraction.GetDragging: Boolean;
begin
  Result := FDragMode <> vcdmNone;
end;

function TVectArtCanvasInteraction.GetRangeSelectionRect: TRect;
begin
  Result := Rect(Min(FRangeStart.X, FRangeCurrent.X),
    Min(FRangeStart.Y, FRangeCurrent.Y),
    Max(FRangeStart.X, FRangeCurrent.X),
    Max(FRangeStart.Y, FRangeCurrent.Y));
end;

function TVectArtCanvasInteraction.GetRangeSelecting: Boolean;
begin
  Result := FDragMode = vcdmRangeSelect;
end;

function TVectArtCanvasInteraction.HitTestLayer(X, Y: Integer): Integer;
var
  I: Integer;
  Layer: TVectArtLayer;
  LogicalX: Single;
  LogicalY: Single;
  RectangleLayer: TVectArtRectangleLayer;
begin
  Result := -1;
  if (FDocument = nil) or (FZoom <= 0) or
    not PtInRect(FCanvasBounds, Point(X, Y)) then
    Exit;
  LogicalX := (X - FCanvasBounds.Left) / FZoom;
  LogicalY := (Y - FCanvasBounds.Top) / FZoom;
  for I := FDocument.LayerCount - 1 downto 1 do
  begin
    Layer := FDocument[I];
    if not Layer.Visible or not (Layer is TVectArtRectangleLayer) then
      Continue;
    RectangleLayer := TVectArtRectangleLayer(Layer);
    if (LogicalX >= RectangleLayer.Bounds.Left) and
      (LogicalX <= RectangleLayer.Bounds.Right) and
      (LogicalY >= RectangleLayer.Bounds.Top) and
      (LogicalY <= RectangleLayer.Bounds.Bottom) then
      Exit(I);
  end;
end;

function TVectArtCanvasInteraction.LayerScreenRect(Index: Integer): TRect;
var
  RectangleLayer: TVectArtRectangleLayer;
begin
  Result := TRect.Empty;
  if (FDocument = nil) or (Index <= 0) or
    (Index >= FDocument.LayerCount) or
    not (FDocument[Index] is TVectArtRectangleLayer) then
    Exit;
  RectangleLayer := TVectArtRectangleLayer(FDocument[Index]);
  Result := Rect(
    FCanvasBounds.Left + Round(RectangleLayer.Bounds.Left * FZoom),
    FCanvasBounds.Top + Round(RectangleLayer.Bounds.Top * FZoom),
    FCanvasBounds.Left + Round(RectangleLayer.Bounds.Right * FZoom),
    FCanvasBounds.Top + Round(RectangleLayer.Bounds.Bottom * FZoom));
end;

function TVectArtCanvasInteraction.SelectedLayersLogicalRect: TRectF;
var
  Bounds: TRectF;
  Found: Boolean;
  I: Integer;
begin
  Result := TRectF.Empty;
  Found := False;
  if FDocument = nil then
    Exit;
  for I := 1 to FDocument.LayerCount - 1 do
    if FDocument.IsLayerSelected(I) and FDocument[I].Visible and
      (FDocument[I] is TVectArtRectangleLayer) then
    begin
      Bounds := TVectArtRectangleLayer(FDocument[I]).Bounds;
      if not Found then
      begin
        Result := Bounds;
        Found := True;
      end
      else
      begin
        Result.Left := Min(Result.Left, Bounds.Left);
        Result.Top := Min(Result.Top, Bounds.Top);
        Result.Right := Max(Result.Right, Bounds.Right);
        Result.Bottom := Max(Result.Bottom, Bounds.Bottom);
      end;
    end;
end;

function TVectArtCanvasInteraction.SelectionContainsLockedLayer: Boolean;
var
  I: Integer;
begin
  Result := False;
  if FDocument = nil then
    Exit;
  for I := 1 to FDocument.LayerCount - 1 do
    if FDocument.IsLayerSelected(I) and FDocument[I].Locked then
      Exit(True);
end;

function TVectArtCanvasInteraction.SelectedLayersScreenRect: TRect;
var
  LogicalRect: TRectF;
begin
  Result := TRect.Empty;
  LogicalRect := SelectedLayersLogicalRect;
  if LogicalRect.IsEmpty then
    Exit;
  Result := Rect(
    FCanvasBounds.Left + Round(LogicalRect.Left * FZoom),
    FCanvasBounds.Top + Round(LogicalRect.Top * FZoom),
    FCanvasBounds.Left + Round(LogicalRect.Right * FZoom),
    FCanvasBounds.Top + Round(LogicalRect.Bottom * FZoom));
end;

function TVectArtCanvasInteraction.MouseDown(Button: TMouseButton;
  X, Y: Integer): Boolean;
var
  Geometry: TVectArtSelectionGeometry;
  SelectionRect: TRect;
begin
  Result := False;
  if (Button <> mbLeft) or (FDocument = nil) or (FZoom <= 0) then
    Exit;
  SelectionRect := SelectedLayersScreenRect;
  if not SelectionRect.IsEmpty and not SelectionContainsLockedLayer then
  begin
    Geometry := BuildSelectionGeometry(SelectionRect);
    FDragHandle := HitTestSelectionHandle(Point(X, Y), Geometry);
    if FDragHandle <> vshNone then
    begin
      FDragMode := vcdmResize;
      FDragLayerIndex := FDocument.SelectedIndex;
      CaptureMoveSelection;
      FDragStartBounds := SelectedLayersLogicalRect;
    end;
  end;
  if FDragMode = vcdmNone then
  begin
    FDragLayerIndex := HitTestLayer(X, Y);
    if FDragLayerIndex < 0 then
    begin
      FDocument.SelectedIndex := -1;
      if not PtInRect(FCanvasBounds, Point(X, Y)) then
        Exit;
      FDragMode := vcdmRangeSelect;
      FRangeStart := Point(X, Y);
      FRangeCurrent := FRangeStart;
      Exit(True);
    end
    else
    begin
      // 選択済みの図形をつかんだ場合は複数選択を維持する。
      if not FDocument.IsLayerSelected(FDragLayerIndex) then
        FDocument.SelectedIndex := FDragLayerIndex;
      if FDocument[FDragLayerIndex].Locked or
        SelectionContainsLockedLayer then
      begin
        FDragLayerIndex := -1;
        Exit(False);
      end;
      FDragMode := vcdmMove;
      CaptureMoveSelection;
    end;
  end;
  FDragStartMouse := Point(X, Y);
  Result := True;
end;

function TVectArtCanvasInteraction.MouseMove(Shift: TShiftState;
  X, Y: Integer): Boolean;
var
  DX: Single;
  DY: Single;
  I: Integer;
  NewBounds: TRectF;
begin
  Result := False;
  if FDragMode = vcdmNone then
    Exit;
  if not (ssLeft in Shift) then
  begin
    EndDrag;
    Exit(True);
  end;
  if FDragMode = vcdmRangeSelect then
  begin
    FRangeCurrent := Point(X, Y);
    Exit(True);
  end;
  if FDragMode = vcdmMove then
  begin
    DX := (X - FDragStartMouse.X) / FZoom;
    DY := (Y - FDragStartMouse.Y) / FZoom;
    for I := 0 to High(FMoveLayerIndices) do
    begin
      NewBounds := FMoveStartBounds[I];
      NewBounds.Offset(DX, DY);
      FDocument.SetRectangleBounds(FMoveLayerIndices[I], NewBounds);
    end;
    Exit(True);
  end
  else
    ApplyResizeSelection(X, Y);
  Result := True;
end;

function TVectArtCanvasInteraction.MouseUp(Button: TMouseButton): Boolean;
begin
  Result := (Button = mbLeft) and (FDragMode <> vcdmNone);
  if Result then
  begin
    if FDragMode = vcdmRangeSelect then
      ApplyRangeSelection;
    if FDragMode in [vcdmMove, vcdmResize] then
      CommitBoundsCommand;
    EndDrag;
  end;
end;

function TVectArtCanvasInteraction.ResizedBounds(X, Y: Integer): TRectF;
var
  DX: Single;
  DY: Single;
begin
  Result := FDragStartBounds;
  DX := (X - FDragStartMouse.X) / FZoom;
  DY := (Y - FDragStartMouse.Y) / FZoom;
  if FDragHandle in [vshTopLeft, vshLeft, vshBottomLeft] then
    Result.Left := Min(FDragStartBounds.Left + DX,
      FDragStartBounds.Right - MIN_RECTANGLE_SIZE);
  if FDragHandle in [vshTopRight, vshRight, vshBottomRight] then
    Result.Right := Max(FDragStartBounds.Right + DX,
      FDragStartBounds.Left + MIN_RECTANGLE_SIZE);
  if FDragHandle in [vshTopLeft, vshTop, vshTopRight] then
    Result.Top := Min(FDragStartBounds.Top + DY,
      FDragStartBounds.Bottom - MIN_RECTANGLE_SIZE);
  if FDragHandle in [vshBottomLeft, vshBottom, vshBottomRight] then
    Result.Bottom := Max(FDragStartBounds.Bottom + DY,
      FDragStartBounds.Top + MIN_RECTANGLE_SIZE);
end;

end.
