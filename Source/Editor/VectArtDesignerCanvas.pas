// 中央編集領域のキャンバス表示を担当する。
// 図形本体は表示寸法のSkia画像へキャッシュし、最終合成と選択表示にはDirect2Dを優先する。
unit VectArtDesignerCanvas;

interface

uses
  System.Classes, System.SysUtils, System.Types, Vcl.Controls, Vcl.Graphics,
  Vcl.StdCtrls, Vcl.Direct2D, Winapi.Messages,
  VectArtDesignerCanvasInteraction,
  VectArtDesignerDocument, VectArtDesignerEditHistory,
  VectArtDesignerEditorState, VectArtDesignerSelectionGeometry,
  VectArtDesignerObjectContextMenu,
  VectArtDesignerShapeCreation, VectArtDesignerRenderer,
  VectArtDesignerTextEditing, WindowsImeController;

type
  TVectArtCanvasControl = class(TCustomControl)
  private
    FCanvasBounds: TRect;
    FDirect2DEnabled: Boolean;
    FDocument: TVectArtDocument;
    FEditorState: TVectArtEditorState;
    FInteraction: TVectArtCanvasInteraction;
    FReferenceBackground: TBitmap;
    FRenderedDocument: TBitmap;
    FRenderBuffer: TVectArtRenderBuffer;
    FRenderedPreviewStrokeWidth: Single;
    FRenderedRevision: Int64;
    FShapeCreation: TVectArtShapeCreation;
    FPanning: Boolean;
    FPanOffset: TPointF;
    FPanMoved: Boolean;
    FPanStartMouse: TPoint;
    FPanStartOffset: TPointF;
    FViewZoom: Single;
    FZoom: Single;
    FImeState: TWindowsImeState;
    FTextBeforeSelection: TArray<Integer>;
    FTextBuffer: string;
    FTextCaretIndex: Integer;
    FTextCompositionActive: Boolean;
    FTextCompositionText: string;
    FTextEditing: Boolean;
    FTextEditor: TVectArtImeEdit;
    FTextEnding: Boolean;
    FTextLayerIndex: Integer;
    FTextNewLayer: Boolean;
    FTextOriginalData: TVectArtTextData;
    FObjectPopup: TVectArtObjectContextMenu;
    procedure ObjectMenuExecuted(Sender: TObject);
    procedure ShowObjectContextMenu(X, Y: Integer);
    procedure BeginExistingTextEdit(Index, X, Y: Integer);
    procedure BeginNewTextEdit(X, Y: Integer);
    procedure FinishTextEdit(Cancel: Boolean;
      RestoreCanvasFocus: Boolean = True);
    function TextLayerAt(X, Y: Integer): Integer;
    procedure TextEditorCommittedText(Sender: TObject; const Text: string);
    procedure TextEditorComposition(Sender: TObject; const Text: string;
      CursorPosition: Integer; Active: Boolean);
    procedure TextEditorExit(Sender: TObject);
    procedure TextEditorKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure UpdateTextEditorBounds;
    procedure UpdateTextLayerFromBuffer;
    procedure WMDropFiles(var Message: TWMDropFiles); message WM_DROPFILES;
    procedure CalculateCanvasBounds;
    procedure EndPan;
    procedure DrawSnapGuides(ACanvas: TCanvas); overload;
    procedure DrawSnapGuides(ACanvas: TDirect2DCanvas); overload;
    procedure PaintDirect2D;
    procedure PaintGDI;
    procedure SetDocument(const Value: TVectArtDocument);
    procedure SetEditorState(const Value: TVectArtEditorState);
    function GetEditHistory: TVectArtEditHistory;
    function HasReferenceBackground: Boolean;
    procedure UpdateRenderedDocument;
    procedure SetEditHistory(const Value: TVectArtEditHistory);
  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    function PrepareObjectContextSelection(X, Y: Integer): Boolean;
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
    function ImportImageFiles(const FileNames: TArray<string>;
      const DropClientPoint: TPoint; out ErrorMessage: string): Integer;
    // 外部ホストのRGBA8画像をDocumentに含めない参照背景として設定する。
    procedure SetReferenceBackgroundRgba(const Pixels: TBytes;
      Width, Height: Integer);
    property CanvasBounds: TRect read FCanvasBounds;
    property Document: TVectArtDocument read FDocument write SetDocument;
    property EditHistory: TVectArtEditHistory read GetEditHistory
      write SetEditHistory;
    property EditorState: TVectArtEditorState read FEditorState
      write SetEditorState;
    property TextEditing: Boolean read FTextEditing;
    property Zoom: Single read FZoom;
  end;

const
  DESIGN_CANVAS_WIDTH  = DEFAULT_CANVAS_WIDTH;
  DESIGN_CANVAS_HEIGHT = DEFAULT_CANVAS_HEIGHT;

implementation

uses
  VectArtDesignerObjectAttributes,
  System.Generics.Collections, System.Math, System.Skia, System.UITypes,
  Winapi.D2D1,
  Winapi.ShellAPI, Winapi.Windows, Vcl.Dialogs, Vcl.Forms,
  VectArtDesignerBezierGeometry, VectArtDesignerGeometry,
  VectArtDesignerEditCommands, VectArtDesignerImageFileImport,
  VectArtDesignerLayerBatchCommands,
  VectArtDesignerLayerStructureCommands, VectArtDesignerSelectionOverlay,
  VectArtDesignerTextGeometry, VectArtDesignerSnapGeometry;

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
  // Falseにすると編集ビューの細線補正を一括で無効化する。
  ENABLE_THIN_STROKE_PREVIEW = True;
  MIN_PREVIEW_STROKE_WIDTH_PIXELS = 1.0;
  DEFAULT_TEXT_FONT_FAMILY = 'Yu Gothic UI';
  DEFAULT_TEXT_FONT_SIZE = 32.0;
  TEXT_INPUT_EDIT_WIDTH = 4;
  RIGHT_PAN_THRESHOLD = 4;

procedure DrawPremultipliedBitmap(Target: TCanvas; const Bounds: TRect;
  Bitmap: Vcl.Graphics.TBitmap);
var
  Blend: BLENDFUNCTION;
begin
  if (Bitmap = nil) or (Bitmap.Width <= 0) or (Bitmap.Height <= 0) then
    Exit;
  Blend.BlendOp := AC_SRC_OVER;
  Blend.BlendFlags := 0;
  Blend.SourceConstantAlpha := 255;
  Blend.AlphaFormat := AC_SRC_ALPHA;
  AlphaBlend(Target.Handle, Bounds.Left, Bounds.Top,
    Bounds.Width, Bounds.Height, Bitmap.Canvas.Handle,
    0, 0, Bitmap.Width, Bitmap.Height, Blend);
end;

type
  TPreviewLineSegment = record
    StartPoint: TPoint;
    EndPoint: TPoint;
  end;

function BuildStyledPreviewSegments(const StartPoint, EndPoint: TPoint;
  Width: Single; Style: TVectArtStrokeStyle): TArray<TPreviewLineSegment>;
var
  CurrentDistance: Single;
  DashIndex: Integer;
  DrawSegment: Boolean;
  DX: Single;
  DY: Single;
  EndDistance: Single;
  Intervals: TArray<Single>;
  LineLength: Single;
  SegmentLength: Single;
  UnitX: Single;
  UnitY: Single;
begin
  Result := nil;
  DX := EndPoint.X - StartPoint.X;
  DY := EndPoint.Y - StartPoint.Y;
  LineLength := Hypot(DX, DY);
  if LineLength <= 0 then
    Exit;
  Intervals := VectArtStrokeDashIntervals(Style, Max(Width, 1.0));
  if Length(Intervals) = 0 then
  begin
    SetLength(Result, 1);
    Result[0].StartPoint := StartPoint;
    Result[0].EndPoint := EndPoint;
    Exit;
  end;
  UnitX := DX / LineLength;
  UnitY := DY / LineLength;
  CurrentDistance := 0;
  DashIndex := 0;
  DrawSegment := True;
  while CurrentDistance < LineLength do
  begin
    SegmentLength := Max(Intervals[DashIndex], 1.0);
    EndDistance := Min(CurrentDistance + SegmentLength, LineLength);
    if DrawSegment then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)].StartPoint := Point(
        StartPoint.X + Round(UnitX * CurrentDistance),
        StartPoint.Y + Round(UnitY * CurrentDistance));
      Result[High(Result)].EndPoint := Point(
        StartPoint.X + Round(UnitX * EndDistance),
        StartPoint.Y + Round(UnitY * EndDistance));
    end;
    CurrentDistance := EndDistance;
    DashIndex := (DashIndex + 1) mod Length(Intervals);
    DrawSegment := not DrawSegment;
  end;
end;

procedure DrawStyledPreviewLine(Target: TCanvas; const StartPoint,
  EndPoint: TPoint; Color: TColor; Width: Single;
  Style: TVectArtStrokeStyle; LineCap: TVectArtLineCap;
  AntiAlias: Boolean; StartMarker, EndMarker: TVectArtLineMarker;
  StartMarkerSize, EndMarkerSize: Single); overload;
var
  DX: Single;
  DY: Single;
  EffectiveCap: TVectArtLineCap;
  I: Integer;
  LengthValue: Single;
  P1: TPoint;
  P2: TPoint;
  Radius: Integer;
  Geometry: TVectArtMarkerGeometry;
  MarkerPoints: TArray<TPoint>;
  Segments: TArray<TPreviewLineSegment>;
begin
  Segments := BuildStyledPreviewSegments(StartPoint, EndPoint, Width, Style);
  EffectiveCap := LineCap;
  if VectArtStrokeUsesRoundCaps(Style) then
    EffectiveCap := vlcRound;
  Target.Pen.Color := Color;
  Target.Pen.Width := Max(Round(Width), 1);
  Target.Pen.Style := psSolid;
  for I := 0 to High(Segments) do
  begin
    P1 := Segments[I].StartPoint;
    P2 := Segments[I].EndPoint;
    if EffectiveCap = vlcSquare then
    begin
      DX := P2.X - P1.X;
      DY := P2.Y - P1.Y;
      LengthValue := Hypot(DX, DY);
      if LengthValue > 0 then
      begin
        P1.Offset(-Round(DX / LengthValue * Width * 0.5),
          -Round(DY / LengthValue * Width * 0.5));
        P2.Offset(Round(DX / LengthValue * Width * 0.5),
          Round(DY / LengthValue * Width * 0.5));
      end;
    end;
    Target.MoveTo(P1.X, P1.Y);
    Target.LineTo(P2.X, P2.Y);
    if EffectiveCap = vlcRound then
    begin
      Radius := Max(Round(Width * 0.5), 1);
      Target.Brush.Style := bsSolid;
      Target.Brush.Color := Color;
      Target.Ellipse(P1.X - Radius, P1.Y - Radius, P1.X + Radius + 1,
        P1.Y + Radius + 1);
      Target.Ellipse(P2.X - Radius, P2.Y - Radius, P2.X + Radius + 1,
        P2.Y + Radius + 1);
      Target.Brush.Style := bsClear;
    end;
  end;
  for I := 0 to 1 do
  begin
    if I = 0 then
      Geometry := BuildLineMarkerGeometry(Ord(StartMarker), StartPoint,
        EndPoint, Width, StartMarkerSize)
    else
      Geometry := BuildLineMarkerGeometry(Ord(EndMarker), EndPoint,
        StartPoint, Width, EndMarkerSize);
    SetLength(MarkerPoints, Length(Geometry.PrimaryPoints));
    for Radius := 0 to High(MarkerPoints) do
      MarkerPoints[Radius] := Point(Round(Geometry.PrimaryPoints[Radius].X),
        Round(Geometry.PrimaryPoints[Radius].Y));
    if Length(MarkerPoints) < 2 then Continue;
    Target.Pen.Color := Color;
    Target.Pen.Width := Max(Round(Width), 1);
    if Geometry.Filled then
    begin
      Target.Brush.Style := bsSolid;
      Target.Brush.Color := Color;
      Target.Polygon(MarkerPoints);
      Target.Brush.Style := bsClear;
    end
    else
      Target.Polyline(MarkerPoints);
  end;
  Target.Pen.Width := 1;
end;

procedure DrawStyledPreviewLine(Target: TDirect2DCanvas;
  const StartPoint, EndPoint: TPoint; Color: TColor; Width: Single;
  Style: TVectArtStrokeStyle; LineCap: TVectArtLineCap;
  AntiAlias: Boolean; StartMarker, EndMarker: TVectArtLineMarker;
  StartMarkerSize, EndMarkerSize: Single); overload;
var
  DX: Single;
  DY: Single;
  EffectiveCap: TVectArtLineCap;
  I: Integer;
  LengthValue: Single;
  P1: TPoint;
  P2: TPoint;
  Radius: Integer;
  Geometry: TVectArtMarkerGeometry;
  MarkerPoints: TArray<TPoint>;
  Segments: TArray<TPreviewLineSegment>;
begin
  if AntiAlias then
    Target.RenderTarget.SetAntialiasMode(D2D1_ANTIALIAS_MODE_PER_PRIMITIVE)
  else
    Target.RenderTarget.SetAntialiasMode(D2D1_ANTIALIAS_MODE_ALIASED);
  Segments := BuildStyledPreviewSegments(StartPoint, EndPoint, Width, Style);
  EffectiveCap := LineCap;
  if VectArtStrokeUsesRoundCaps(Style) then
    EffectiveCap := vlcRound;
  Target.Pen.Color := Color;
  Target.Pen.Width := Max(Round(Width), 1);
  Target.Pen.Style := psSolid;
  for I := 0 to High(Segments) do
  begin
    P1 := Segments[I].StartPoint;
    P2 := Segments[I].EndPoint;
    if EffectiveCap = vlcSquare then
    begin
      DX := P2.X - P1.X;
      DY := P2.Y - P1.Y;
      LengthValue := Hypot(DX, DY);
      if LengthValue > 0 then
      begin
        P1.Offset(-Round(DX / LengthValue * Width * 0.5),
          -Round(DY / LengthValue * Width * 0.5));
        P2.Offset(Round(DX / LengthValue * Width * 0.5),
          Round(DY / LengthValue * Width * 0.5));
      end;
    end;
    Target.MoveTo(P1.X, P1.Y);
    Target.LineTo(P2.X, P2.Y);
    if EffectiveCap = vlcRound then
    begin
      Radius := Max(Round(Width * 0.5), 1);
      Target.Brush.Style := bsSolid;
      Target.Brush.Color := Color;
      Target.Ellipse(P1.X - Radius, P1.Y - Radius, P1.X + Radius + 1,
        P1.Y + Radius + 1);
      Target.Ellipse(P2.X - Radius, P2.Y - Radius, P2.X + Radius + 1,
        P2.Y + Radius + 1);
      Target.Brush.Style := bsClear;
    end;
  end;
  for I := 0 to 1 do
  begin
    if I = 0 then
      Geometry := BuildLineMarkerGeometry(Ord(StartMarker), StartPoint,
        EndPoint, Width, StartMarkerSize)
    else
      Geometry := BuildLineMarkerGeometry(Ord(EndMarker), EndPoint,
        StartPoint, Width, EndMarkerSize);
    SetLength(MarkerPoints, Length(Geometry.PrimaryPoints));
    for Radius := 0 to High(MarkerPoints) do
      MarkerPoints[Radius] := Point(Round(Geometry.PrimaryPoints[Radius].X),
        Round(Geometry.PrimaryPoints[Radius].Y));
    if Length(MarkerPoints) < 2 then Continue;
    Target.Pen.Color := Color;
    Target.Pen.Width := Max(Round(Width), 1);
    if Geometry.Filled then
    begin
      Target.Brush.Style := bsSolid;
      Target.Brush.Color := Color;
      Target.Polygon(MarkerPoints);
      Target.Brush.Style := bsClear;
    end
    else
      Target.Polyline(MarkerPoints);
  end;
  Target.Pen.Width := 1;
  Target.RenderTarget.SetAntialiasMode(D2D1_ANTIALIAS_MODE_PER_PRIMITIVE);
end;

constructor TVectArtCanvasControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Color := COLOR_EDITOR_SURROUND;
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  FDirect2DEnabled := TDirect2DCanvas.Supported;
  FInteraction := TVectArtCanvasInteraction.Create;
  FReferenceBackground := Vcl.Graphics.TBitmap.Create;
  FReferenceBackground.PixelFormat := pf32bit;
  FRenderedDocument := Vcl.Graphics.TBitmap.Create;
  FRenderedDocument.PixelFormat := pf32bit;
  FRenderBuffer := TVectArtRenderBuffer.Create;
  FRenderedPreviewStrokeWidth := -1.0;
  FRenderedRevision := -1;
  FShapeCreation := TVectArtShapeCreation.Create;
  FTextLayerIndex := -1;
  FTextEditor := TVectArtImeEdit.Create(Self);
  FTextEditor.Parent := Self;
  FTextEditor.BorderStyle := bsNone;
  FTextEditor.Ctl3D := False;
  FTextEditor.TabStop := True;
  FTextEditor.Visible := False;
  FTextEditor.SetBounds(0, 0, 1, 1);
  FTextEditor.OnCommittedText := TextEditorCommittedText;
  FTextEditor.OnComposition := TextEditorComposition;
  FTextEditor.OnExit := TextEditorExit;
  FTextEditor.OnKeyDown := TextEditorKeyDown;
  FObjectPopup := TVectArtObjectContextMenu.Create(Self);
  FObjectPopup.OnExecuted := ObjectMenuExecuted;
  FPanOffset := TPointF.Zero;
  FViewZoom := 1.0;
  CalculateCanvasBounds;
end;

destructor TVectArtCanvasControl.Destroy;
begin
  FTextEditor.Free;
  FRenderBuffer.Free;
  FRenderedDocument.Free;
  FReferenceBackground.Free;
  FShapeCreation.Free;
  FInteraction.Free;
  inherited Destroy;
end;

procedure TVectArtCanvasControl.CreateWnd;
begin
  inherited CreateWnd;
  DragAcceptFiles(Handle, True);
end;

procedure TVectArtCanvasControl.DestroyWnd;
begin
  DragAcceptFiles(Handle, False);
  inherited DestroyWnd;
end;

function TVectArtCanvasControl.ImportImageFiles(
  const FileNames: TArray<string>; const DropClientPoint: TPoint;
  out ErrorMessage: string): Integer;
const
  MULTIPLE_IMAGE_OFFSET = 16.0;
var
  AfterSelection: TArray<Integer>;
  BeforeSelection: TArray<Integer>;
  Data: TVectArtImageData;
  DataList: TList<TVectArtImageData>;
  DropPoint: TPointF;
  ErrorList: TStringList;
  FileName: string;
  ImportError: string;
  Index: Integer;
  NewIndices: TList<Integer>;
  StartIndex: Integer;
begin
  Result := 0;
  ErrorMessage := '';
  if (FDocument = nil) or (FDocument.CanvasLayer = nil) or
    (Length(FileNames) = 0) then
    Exit;
  if FTextEditing then
    FinishTextEdit(False);
  CalculateCanvasBounds;
  if FZoom <= 0 then
    Exit;
  BeforeSelection := FDocument.GetSelectedLayerIndices;
  DataList := TList<TVectArtImageData>.Create;
  ErrorList := TStringList.Create;
  NewIndices := TList<Integer>.Create;
  try
    for FileName in FileNames do
    begin
      DropPoint := PointF(
        (DropClientPoint.X - FCanvasBounds.Left) / FZoom +
          DataList.Count * MULTIPLE_IMAGE_OFFSET,
        (DropClientPoint.Y - FCanvasBounds.Top) / FZoom +
          DataList.Count * MULTIPLE_IMAGE_OFFSET);
      if TryCreateVectArtImageFromFile(FileName, DropPoint,
        FDocument.CanvasLayer.Width, FDocument.CanvasLayer.Height,
        Data, ImportError) then
        DataList.Add(Data)
      else
        ErrorList.Add(ExtractFileName(FileName) + ': ' + ImportError);
    end;
    if DataList.Count = 0 then
    begin
      ErrorMessage := ErrorList.Text.Trim;
      Exit;
    end;
    StartIndex := FDocument.LayerCount;
    for Data in DataList do
    begin
      Index := FDocument.InsertImage(FDocument.LayerCount, Data);
      NewIndices.Add(Index);
    end;
    AfterSelection := NewIndices.ToArray;
    FDocument.SetSelectedLayers(AfterSelection);
    if EditHistory <> nil then
      EditHistory.AddApplied(TVectArtInsertImagesCommand.Create(FDocument,
        StartIndex, DataList.ToArray, BeforeSelection, AfterSelection));
    Result := DataList.Count;
    ErrorMessage := ErrorList.Text.Trim;
    Invalidate;
  finally
    NewIndices.Free;
    ErrorList.Free;
    DataList.Free;
  end;
end;

procedure TVectArtCanvasControl.WMDropFiles(var Message: TWMDropFiles);
var
  Buffer: TArray<Char>;
  DropPoint: TPoint;
  ErrorMessage: string;
  FileCount: Cardinal;
  FileIndex: Cardinal;
  FileNameLength: Cardinal;
  FileNames: TArray<string>;
begin
  try
    FileCount := DragQueryFile(Message.Drop, Cardinal(-1), nil, 0);
    SetLength(FileNames, FileCount);
    if FileCount > 0 then
      for FileIndex := 0 to FileCount - 1 do
      begin
        FileNameLength := DragQueryFile(Message.Drop, FileIndex, nil, 0);
        SetLength(Buffer, FileNameLength + 1);
        DragQueryFile(Message.Drop, FileIndex, @Buffer[0], Length(Buffer));
        FileNames[FileIndex] := PChar(@Buffer[0]);
      end;
    DragQueryPoint(Message.Drop, DropPoint);
  finally
    DragFinish(Message.Drop);
  end;
  ImportImageFiles(FileNames, DropPoint, ErrorMessage);
  if ErrorMessage <> '' then
    MessageDlg('読み込めなかった画像があります。' + sLineBreak +
      ErrorMessage, mtWarning, [mbOK], 0);
  Message.Result := 0;
end;

procedure TVectArtCanvasControl.BeginNewTextEdit(X, Y: Integer);
var
  Data: TVectArtTextData;
  LogicalX: Single;
  LogicalY: Single;
begin
  if (FDocument = nil) or (FDocument.CanvasLayer = nil) or (FZoom <= 0) then
    Exit;
  LogicalX := EnsureRange((X - FCanvasBounds.Left) / FZoom, 0.0,
    FDocument.CanvasLayer.Width * 1.0);
  LogicalY := EnsureRange((Y - FCanvasBounds.Top) / FZoom, 0.0,
    FDocument.CanvasLayer.Height * 1.0);
  FTextBeforeSelection := FDocument.GetSelectedLayerIndices;
  Data := Default(TVectArtTextData);
  Data.Bounds := TRectF.Create(LogicalX, LogicalY,
    LogicalX + 1, LogicalY + DEFAULT_TEXT_FONT_SIZE);
  Data.FontFamily := DEFAULT_TEXT_FONT_FAMILY;
  Data.FontSize := DEFAULT_TEXT_FONT_SIZE;
  Data.Name := Format('Text %d', [FDocument.LayerCount]);
  Data.Opacity := 1.0;
  Data.Text := '';
  if FEditorState <> nil then
    Data.TextColor := FEditorState.Color1
  else
    Data.TextColor := clBlack;
  Data.Visible := True;
  ApplyVectArtObjectAttributes(CaptureVectArtSelectedAttributes(FDocument), Data);
  FTextLayerIndex := FDocument.InsertText(FDocument.LayerCount, Data);
  FDocument.SetSelectedLayers([FTextLayerIndex]);
  FTextBuffer := '';
  FTextCaretIndex := 0;
  FTextCompositionActive := False;
  FTextCompositionText := '';
  FTextNewLayer := True;
  FTextEditing := True;
  FTextEditor.Text := '';
  FTextEditor.Font.Name := Data.FontFamily;
  FTextEditor.Font.Size := Round(Data.FontSize);
  FTextEditor.Font.Style := Data.FontStyle;
  FTextEditor.Font.Color := Data.TextColor;
  UpdateTextEditorBounds;
  FTextEditor.Visible := True;
  FTextEditor.BringToFront;
  FTextEditor.SetFocus;
  RestoreWindowsIme(FTextEditor.Handle, FImeState);
end;

procedure TVectArtCanvasControl.BeginExistingTextEdit(Index, X, Y: Integer);
var
  Layer: TVectArtTextLayer;
  Layout: TVectArtTextLayout;
  LogicalPoint: TPointF;
  TextScaleX: Single;
  TextScaleY: Single;
begin
  if (FDocument = nil) or (Index <= 0) or
    (Index >= FDocument.LayerCount) or
    not (FDocument[Index] is TVectArtTextLayer) or FDocument[Index].Locked then
    Exit;
  Layer := TVectArtTextLayer(FDocument[Index]);
  FTextBeforeSelection := FDocument.GetSelectedLayerIndices;
  FDocument.SetSelectedLayers([Index]);
  FTextLayerIndex := Index;
  FTextOriginalData := CaptureVectArtTextData(Layer);
  FTextBuffer := Layer.Text;
  LogicalPoint := PointF((X - FCanvasBounds.Left) / FZoom,
    (Y - FCanvasBounds.Top) / FZoom);
  LogicalPoint := RotatePointAround(LogicalPoint, Layer.Bounds.CenterPoint,
    -Layer.RotationDegrees);
  if Layer.FlipHorizontal then
    LogicalPoint.X := 2 * Layer.Bounds.CenterPoint.X - LogicalPoint.X;
  if Layer.FlipVertical then
    LogicalPoint.Y := 2 * Layer.Bounds.CenterPoint.Y - LogicalPoint.Y;
  Layout := BuildVectArtTextLayout(Layer.Text, Layer.FontFamily,
    Layer.FontSize, Layer.FontStyle, Layer.LetterSpacingRatio,
    Layer.LineSpacingRatio, Layer.Vertical);
  TextScaleX := Layer.Bounds.Width / Max(Layout.Width, 1.0);
  TextScaleY := Layer.Bounds.Height / Max(Layout.Height, 1.0);
  FTextCaretIndex := VectArtTextCaretIndexAtPoint(FTextBuffer,
    Layer.FontFamily, Layer.FontSize,
    (LogicalPoint.X - Layer.Bounds.Left) / Max(TextScaleX, 0.000001),
    (LogicalPoint.Y - Layer.Bounds.Top) / Max(TextScaleY, 0.000001),
    Layer.FontStyle, Layer.LetterSpacingRatio, Layer.LineSpacingRatio,
    Layer.Vertical);
  FTextCompositionActive := False;
  FTextCompositionText := '';
  FTextNewLayer := False;
  FTextEditing := True;
  FTextEditor.Text := '';
  UpdateTextEditorBounds;
  FTextEditor.Visible := True;
  FTextEditor.BringToFront;
  FTextEditor.SetFocus;
  RestoreWindowsIme(FTextEditor.Handle, FImeState);
end;

procedure TVectArtCanvasControl.FinishTextEdit(Cancel,
  RestoreCanvasFocus: Boolean);
var
  AfterSelection: TArray<Integer>;
  CurrentData: TVectArtTextData;
  RemovedData: TVectArtTextData;
begin
  if not FTextEditing or FTextEnding then
    Exit;
  FTextEnding := True;
  try
    SuspendWindowsIme(FTextEditor.Handle, FImeState);
    FTextEditor.Visible := False;
    if (FDocument <> nil) and (FTextLayerIndex > 0) and
      (FTextLayerIndex < FDocument.LayerCount) and
      (FDocument[FTextLayerIndex] is TVectArtTextLayer) then
    begin
      CurrentData := CaptureVectArtTextData(
        TVectArtTextLayer(FDocument[FTextLayerIndex]));
      if FTextNewLayer then
      begin
        if Cancel or (CurrentData.Text = '') then
        begin
          FDocument.RemoveText(FTextLayerIndex, RemovedData);
          FDocument.SetSelectedLayers(FTextBeforeSelection);
        end
        else if EditHistory <> nil then
        begin
          AfterSelection := FDocument.GetSelectedLayerIndices;
          EditHistory.AddApplied(TVectArtInsertTextCommand.Create(FDocument,
            FTextLayerIndex, CurrentData, FTextBeforeSelection,
            AfterSelection));
        end;
      end
      else if Cancel then
        FDocument.SetTextData(FTextLayerIndex, FTextOriginalData)
      else if CurrentData.Text = '' then
        FDocument.SetTextData(FTextLayerIndex, FTextOriginalData)
      else if EditHistory <> nil then
        EditHistory.AddApplied(TVectArtTextDataCommand.Create(FDocument,
          FTextLayerIndex, FTextOriginalData, CurrentData));
    end;
    FTextEditing := False;
    FTextLayerIndex := -1;
    FTextNewLayer := False;
    FTextBuffer := '';
    FTextCaretIndex := 0;
    FTextCompositionActive := False;
    FTextCompositionText := '';
    FTextEditor.Text := '';
    if RestoreCanvasFocus and CanFocus then
      SetFocus;
    Invalidate;
  finally
    FTextEnding := False;
  end;
end;

function TVectArtCanvasControl.TextLayerAt(X, Y: Integer): Integer;
var
  I: Integer;
  Layer: TVectArtTextLayer;
  LogicalPoint: TPointF;
begin
  Result := -1;
  if (FDocument = nil) or (FZoom <= 0) then
    Exit;
  LogicalPoint := TPointF.Create((X - FCanvasBounds.Left) / FZoom,
    (Y - FCanvasBounds.Top) / FZoom);
  for I := FDocument.LayerCount - 1 downto 1 do
    if FDocument[I].Visible and (FDocument[I] is TVectArtTextLayer) then
    begin
      Layer := TVectArtTextLayer(FDocument[I]);
      if PointInRotatedRectangle(LogicalPoint, Layer.Bounds,
        Layer.RotationDegrees) then
        Exit(I);
    end;
end;

procedure TVectArtCanvasControl.TextEditorCommittedText(Sender: TObject;
  const Text: string);
begin
  if not FTextEditing or FTextEnding or (Text = '') then
    Exit;
  FTextCompositionActive := False;
  FTextCompositionText := '';
  InsertVectArtTextAtCaret(FTextBuffer, FTextCaretIndex, Text);
  UpdateTextLayerFromBuffer;
end;

procedure TVectArtCanvasControl.TextEditorComposition(Sender: TObject;
  const Text: string; CursorPosition: Integer; Active: Boolean);
begin
  if not FTextEditing or FTextEnding then
    Exit;
  FTextCompositionActive := Active;
  FTextCompositionText := Text;
  UpdateTextEditorBounds;
end;

procedure TVectArtCanvasControl.TextEditorExit(Sender: TObject);
begin
  if FTextEditing and not FTextEnding then
    FinishTextEdit(False, False);
end;

procedure TVectArtCanvasControl.TextEditorKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
var
  DeleteCount: Integer;
begin
  if not FTextEditing or FTextEnding or FTextCompositionActive then
    Exit;
  case Key of
    VK_ESCAPE:
      begin
        Key := 0;
        FinishTextEdit(True);
      end;
    VK_RETURN:
      begin
        Key := 0;
        InsertVectArtTextAtCaret(FTextBuffer, FTextCaretIndex, sLineBreak);
        UpdateTextLayerFromBuffer;
      end;
    VK_BACK:
      begin
        Key := 0;
        if FTextCaretIndex <= 0 then
          Exit;
        DeleteCount := 1;
        if (FTextCaretIndex >= 2) and
          (FTextBuffer[FTextCaretIndex - 1] = #13) and
          (FTextBuffer[FTextCaretIndex] = #10) then
          DeleteCount := 2
        else if (FTextCaretIndex >= 2) and
          (Ord(FTextBuffer[FTextCaretIndex - 1]) >= $D800) and
          (Ord(FTextBuffer[FTextCaretIndex - 1]) <= $DBFF) then
          DeleteCount := 2;
        Delete(FTextBuffer, FTextCaretIndex - DeleteCount + 1, DeleteCount);
        Dec(FTextCaretIndex, DeleteCount);
        UpdateTextLayerFromBuffer;
      end;
    VK_DELETE:
      begin
        Key := 0;
        if FTextCaretIndex >= Length(FTextBuffer) then
          Exit;
        DeleteCount := VectArtTextUnitLengthAt(FTextBuffer,
          FTextCaretIndex + 1);
        if (FTextBuffer[FTextCaretIndex + 1] = #13) and
          (FTextCaretIndex + 2 <= Length(FTextBuffer)) and
          (FTextBuffer[FTextCaretIndex + 2] = #10) then
          DeleteCount := 2;
        Delete(FTextBuffer, FTextCaretIndex + 1, DeleteCount);
        UpdateTextLayerFromBuffer;
      end;
    VK_LEFT:
      begin
        Key := 0;
        if FTextCaretIndex > 0 then
          Dec(FTextCaretIndex);
        if (FTextCaretIndex > 0) and
          (Ord(FTextBuffer[FTextCaretIndex]) >= $D800) and
          (Ord(FTextBuffer[FTextCaretIndex]) <= $DBFF) then
          Dec(FTextCaretIndex);
        if (FTextCaretIndex > 0) and
          (FTextBuffer[FTextCaretIndex] = #13) and
          (FTextBuffer[FTextCaretIndex + 1] = #10) then
          Dec(FTextCaretIndex);
        UpdateTextEditorBounds;
      end;
    VK_RIGHT:
      begin
        Key := 0;
        if FTextCaretIndex < Length(FTextBuffer) then
          Inc(FTextCaretIndex);
        if (FTextCaretIndex < Length(FTextBuffer)) and
          (Ord(FTextBuffer[FTextCaretIndex]) >= $D800) and
          (Ord(FTextBuffer[FTextCaretIndex]) <= $DBFF) then
          Inc(FTextCaretIndex);
        if (FTextCaretIndex < Length(FTextBuffer)) and
          (FTextBuffer[FTextCaretIndex] = #13) and
          (FTextBuffer[FTextCaretIndex + 1] = #10) then
          Inc(FTextCaretIndex);
        UpdateTextEditorBounds;
      end;
  end;
end;

procedure TVectArtCanvasControl.UpdateTextLayerFromBuffer;
var
  Data: TVectArtTextData;
  NewLayout: TVectArtTextLayout;
  OldLayout: TVectArtTextLayout;
  TextScaleX: Single;
  TextScaleY: Single;
begin
  if not FTextEditing or (FDocument = nil) or
    (FTextLayerIndex <= 0) or (FTextLayerIndex >= FDocument.LayerCount) or
    not (FDocument[FTextLayerIndex] is TVectArtTextLayer) then
    Exit;
  Data := CaptureVectArtTextData(TVectArtTextLayer(
    FDocument[FTextLayerIndex]));
  OldLayout := BuildVectArtTextLayout(Data.Text, Data.FontFamily,
    Data.FontSize, Data.FontStyle, Data.LetterSpacingRatio,
    Data.LineSpacingRatio, Data.Vertical);
  if FTextNewLayer or (Data.Text = '') then
  begin
    TextScaleX := 1.0;
    TextScaleY := 1.0;
  end
  else
  begin
    TextScaleX := Data.Bounds.Width / Max(OldLayout.Width, 1.0);
    TextScaleY := Data.Bounds.Height / Max(OldLayout.Height, 1.0);
  end;
  Data.Text := FTextBuffer;
  NewLayout := BuildVectArtTextLayout(Data.Text, Data.FontFamily,
    Data.FontSize, Data.FontStyle, Data.LetterSpacingRatio,
    Data.LineSpacingRatio, Data.Vertical);
  Data.Bounds.Right := Data.Bounds.Left +
    Max(NewLayout.Width * TextScaleX, 1.0);
  Data.Bounds.Bottom := Data.Bounds.Top +
    Max(NewLayout.Height * TextScaleY, 1.0);
  FDocument.SetTextData(FTextLayerIndex, Data);
  UpdateTextEditorBounds;
  Invalidate;
end;

procedure TVectArtCanvasControl.UpdateTextEditorBounds;
var
  LastBreak: Integer;
  Layout: TVectArtTextLayout;
  Layer: TVectArtTextLayer;
  Prefix: string;
  CurrentLine: string;
  CaretPoint: TPointF;
  EditWidth: Integer;
  Font: ISkFont;
  TextLayout: TVectArtTextLayout;
  TextScaleX: Single;
  TextScaleY: Single;
  X: Integer;
  Y: Integer;
begin
  if not FTextEditing or (FDocument = nil) or
    (FTextLayerIndex <= 0) or (FTextLayerIndex >= FDocument.LayerCount) or
    not (FDocument[FTextLayerIndex] is TVectArtTextLayer) then
    Exit;
  Layer := TVectArtTextLayer(FDocument[FTextLayerIndex]);
  Prefix := Copy(FTextBuffer, 1, FTextCaretIndex);
  Layout := BuildVectArtTextLayout(Prefix, Layer.FontFamily,
    Layer.FontSize, Layer.FontStyle, Layer.LetterSpacingRatio,
    Layer.LineSpacingRatio, Layer.Vertical);
  TextLayout := BuildVectArtTextLayout(Layer.Text, Layer.FontFamily,
    Layer.FontSize, Layer.FontStyle, Layer.LetterSpacingRatio,
    Layer.LineSpacingRatio, Layer.Vertical);
  TextScaleX := Layer.Bounds.Width / Max(TextLayout.Width, 1.0);
  TextScaleY := Layer.Bounds.Height / Max(TextLayout.Height, 1.0);
  LastBreak := LastDelimiter(#13#10, Prefix);
  if LastBreak > 0 then
    CurrentLine := Copy(Prefix, LastBreak + 1, MaxInt)
  else
    CurrentLine := Prefix;
  Font := CreateVectArtTextFont(Layer.FontFamily, Layer.FontSize,
    Layer.FontStyle, Layer.Vertical);
  if Layer.Vertical then
    CaretPoint := PointF(Layer.Bounds.Left +
      (TextLayout.Width - TextLayout.BaseLineHeight -
       (Length(Layout.Lines) - 1) * TextLayout.LineHeight) * TextScaleX,
      Layer.Bounds.Top + Min(VectArtTextUnitCount(CurrentLine) *
        TextLayout.CharacterAdvance, TextLayout.Height) * TextScaleY)
  else
    CaretPoint := PointF(Layer.Bounds.Left + MeasureVectArtText(CurrentLine,
      Font, Layer.FontSize * Layer.LetterSpacingRatio) * TextScaleX,
      Layer.Bounds.Top + (Length(Layout.Lines) - 1) * Layout.LineHeight *
        TextScaleY);
  if Layer.FlipHorizontal then
    CaretPoint.X := 2 * Layer.Bounds.CenterPoint.X - CaretPoint.X;
  if Layer.FlipVertical then
    CaretPoint.Y := 2 * Layer.Bounds.CenterPoint.Y - CaretPoint.Y;
  CaretPoint := RotatePointAround(CaretPoint, Layer.Bounds.CenterPoint,
    Layer.RotationDegrees);
  X := FCanvasBounds.Left + Round(CaretPoint.X * FZoom);
  Y := FCanvasBounds.Top + Round(CaretPoint.Y * FZoom);
  FTextEditor.Font.Name := Layer.FontFamily;
  FTextEditor.Font.Height := -Max(Round(Layer.FontSize * TextScaleY *
    FZoom), 1);
  FTextEditor.Font.Style := Layer.FontStyle;
  FTextEditor.Font.Color := Layer.TextColor;
  if Layer.Vertical then
    EditWidth := Max(Round(TextLayout.BaseLineHeight * TextScaleX *
      FZoom), TEXT_INPUT_EDIT_WIDTH)
  else
    EditWidth := TEXT_INPUT_EDIT_WIDTH;
  if FTextCompositionText <> '' then
    EditWidth := Max(EditWidth,
      Ceil(MeasureVectArtText(FTextCompositionText, Font,
        Layer.FontSize * Layer.LetterSpacingRatio) * TextScaleX *
        FZoom) + 8);
  FTextEditor.SetBounds(X, Y, EditWidth,
    Max(Round(TextLayout.BaseLineHeight * TextScaleY * FZoom), 1));
end;

function TVectArtCanvasControl.HasReferenceBackground: Boolean;
begin
  Result := (FReferenceBackground <> nil) and
    (FReferenceBackground.Width > 0) and
    (FReferenceBackground.Height > 0);
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
  UpdateTextEditorBounds;
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

procedure TVectArtCanvasControl.ObjectMenuExecuted(Sender: TObject);
begin
  Invalidate;
end;

procedure TVectArtCanvasControl.ShowObjectContextMenu(X, Y: Integer);
var
  ScreenPoint: TPoint;
begin
  if not PrepareObjectContextSelection(X, Y) then
    Exit;
  FObjectPopup.Document := FDocument;
  FObjectPopup.EditHistory := EditHistory;
  ScreenPoint := ClientToScreen(Point(X, Y));
  FObjectPopup.Popup(ScreenPoint.X, ScreenPoint.Y);
end;

function TVectArtCanvasControl.PrepareObjectContextSelection(
  X, Y: Integer): Boolean;
var
  LayerIndex: Integer;
begin
  Result := False;
  if (FDocument = nil) or (FEditorState = nil) then
    Exit;
  FInteraction.Configure(FDocument, FCanvasBounds, FZoom);
  LayerIndex := FInteraction.LayerAt(X, Y);
  if (LayerIndex > 0) and not FDocument.IsLayerSelected(LayerIndex) then
    FDocument.SelectedIndex := LayerIndex;
  Result := FDocument.SelectionCount > 0;
end;

function TVectArtCanvasControl.GetEditHistory: TVectArtEditHistory;
begin
  Result := FInteraction.EditHistory;
end;

procedure TVectArtCanvasControl.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  TextIndex: Integer;
begin
  if (Button = mbLeft) and FTextEditing then
  begin
    FinishTextEdit(False);
    if FEditorState <> nil then
      FEditorState.CurrentTool := vetSelect;
  end;
  FShapeCreation.Configure(FDocument, EditHistory, FEditorState,
    FCanvasBounds, FZoom);
  if (Button = mbRight) and (FEditorState <> nil) and
    (FEditorState.CurrentTool in [vetPath, vetBezier, vetClosedPath,
      vetClosedBezier]) and
    FShapeCreation.Active then
  begin
    if not FShapeCreation.FinishPath(False) then
      FShapeCreation.CancelPath;
    FEditorState.CurrentTool := vetSelect;
    Invalidate;
  end;
  if Button = mbRight then
  begin
    if FTextEditing then
      FinishTextEdit(False);
    if FEditorState <> nil then
      FEditorState.CurrentTool := vetSelect;
    FPanning := True;
    FPanMoved := False;
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
    if (FEditorState <> nil) and (FEditorState.CurrentTool = vetText) and
      PtInRect(FCanvasBounds, Point(X, Y)) then
    begin
      TextIndex := TextLayerAt(X, Y);
      if TextIndex > 0 then
        BeginExistingTextEdit(TextIndex, X, Y)
      else
        BeginNewTextEdit(X, Y);
      Cursor := crIBeam;
      Invalidate;
      Exit;
    end;
    FShapeCreation.Configure(FDocument, EditHistory, FEditorState,
      FCanvasBounds, FZoom);
    if FShapeCreation.MouseDown(Button, Shift, X, Y) then
    begin
      if (FEditorState <> nil) and
        not (FEditorState.CurrentTool in [vetPath, vetBezier,
          vetClosedPath, vetClosedBezier]) then
        MouseCapture := True;
      Cursor := crCross;
      Invalidate;
      Exit;
    end;
    if (FEditorState <> nil) and
      (FEditorState.CurrentTool in [vetRectangle, vetEllipse,
        vetRoundedRectangle, vetClosedPath, vetClosedBezier, vetLine,
        vetPath, vetBezier, vetFreehandLine, vetFreehandBezier, vetText, vetTemplate]) then
    begin
      if FEditorState.CurrentTool = vetText then
        Cursor := crIBeam
      else
        Cursor := crCross;
      Exit;
    end;
    FInteraction.Configure(FDocument, FCanvasBounds, FZoom);
    if FInteraction.MouseDown(Button, Shift, X, Y) then
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
    if not FPanMoved then
    begin
      FPanMoved := (Abs(X - FPanStartMouse.X) > RIGHT_PAN_THRESHOLD) or
        (Abs(Y - FPanStartMouse.Y) > RIGHT_PAN_THRESHOLD);
      if not FPanMoved then
        Exit;
    end;
    FPanOffset.X := FPanStartOffset.X + X - FPanStartMouse.X;
    FPanOffset.Y := FPanStartOffset.Y + Y - FPanStartMouse.Y;
    CalculateCanvasBounds;
    UpdateTextEditorBounds;
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
    (FEditorState.CurrentTool in [vetRectangle, vetEllipse,
      vetRoundedRectangle, vetClosedPath, vetClosedBezier, vetLine,
      vetPath, vetBezier, vetFreehandLine, vetFreehandBezier, vetText, vetTemplate]) then
  begin
    if FEditorState.CurrentTool = vetText then
      Cursor := crIBeam
    else
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
    if not FPanMoved then
      ShowObjectContextMenu(X, Y);
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
    Invalidate;
    Exit;
  end;
  inherited MouseUp(Button, Shift, X, Y);
end;

procedure TVectArtCanvasControl.Paint;
begin
  CalculateCanvasBounds;
  // 選択頂点や範囲選択はInteraction側で画面座標を生成する。
  // ズーム、パン、Resize後も描画直前に最新のBoundsと倍率へ同期する。
  FInteraction.Configure(FDocument, FCanvasBounds, FZoom);
  FShapeCreation.Configure(FDocument, EditHistory, FEditorState,
    FCanvasBounds, FZoom);
  UpdateRenderedDocument;
  if FDirect2DEnabled then
    try
      PaintDirect2D;
      Exit;
    except
      FDirect2DEnabled := False;
    end;
  PaintGDI;
end;

procedure TVectArtCanvasControl.UpdateRenderedDocument;
var
  Alpha: Integer;
  Destination: PByte;
  Height: Integer;
  Source: PVectArtRgbaPixel;
  PreviewStrokeWidth: Single;
  Width: Integer;
  X: Integer;
  Y: Integer;
begin
  if (FDocument = nil) or (FDocument.CanvasLayer = nil) then
  begin
    FRenderedDocument.SetSize(0, 0);
    FRenderedRevision := -1;
    Exit;
  end;
  // 縮小表示中にDocumentの論理画素数を丸ごと生成しない。
  // 表示寸法までで描けば、Direct2Dで同じBoundsへ転送した結果は維持できる。
  Width := Max(Min(FCanvasBounds.Width, FDocument.CanvasLayer.Width), 1);
  Height := Max(Min(FCanvasBounds.Height, FDocument.CanvasLayer.Height), 1);
  PreviewStrokeWidth := 0.0;
  if ENABLE_THIN_STROKE_PREVIEW and (FZoom > 0) then
    PreviewStrokeWidth := MIN_PREVIEW_STROKE_WIDTH_PIXELS / FZoom;
  if (FRenderedRevision = FDocument.Revision) and
    SameValue(FRenderedPreviewStrokeWidth, PreviewStrokeWidth) and
    (FRenderedDocument.Width = Width) and
    (FRenderedDocument.Height = Height) then
    Exit;

  RenderVectArtDocument(FDocument, FRenderBuffer, Width, Height,
    PreviewStrokeWidth);
  FRenderedDocument.PixelFormat := pf32bit;
  if (FRenderedDocument.Width <> Width) or
    (FRenderedDocument.Height <> Height) then
    FRenderedDocument.SetSize(Width, Height);
  FRenderedDocument.AlphaFormat := afPremultiplied;
  Source := FRenderBuffer.Data;
  for Y := 0 to Height - 1 do
  begin
    Destination := FRenderedDocument.ScanLine[Y];
    for X := 0 to Width - 1 do
    begin
      Alpha := Source^.A;
      Destination[0] := (Integer(Source^.B) * Alpha + 127) div 255;
      Destination[1] := (Integer(Source^.G) * Alpha + 127) div 255;
      Destination[2] := (Integer(Source^.R) * Alpha + 127) div 255;
      Destination[3] := Alpha;
      Inc(Destination, 4);
      Inc(Source);
    end;
  end;
  FRenderedRevision := FDocument.Revision;
  FRenderedPreviewStrokeWidth := PreviewStrokeWidth;
end;

procedure TVectArtCanvasControl.DrawSnapGuides(ACanvas: TCanvas);
var
  Guide: TVectArtDesignerSnapGuide;
  Guides: TArray<TVectArtDesignerSnapGuide>;
  TargetRect: TRect;
  P1, P2: TPoint;
  OldPenStyle: TPenStyle;
  OldBrushStyle: TBrushStyle;
  OldPenColor: TColor;
  OldPenWidth: Integer;
  function ScreenPoint(const P: TPointF): TPoint;
  begin
    Result := Point(Round(FCanvasBounds.Left + P.X * FZoom),
      Round(FCanvasBounds.Top + P.Y * FZoom));
  end;
begin
  OldPenStyle := ACanvas.Pen.Style;
  OldBrushStyle := ACanvas.Brush.Style;
  OldPenColor := ACanvas.Pen.Color;
  OldPenWidth := ACanvas.Pen.Width;
  Guides := FInteraction.SnapGuides;
  if FShapeCreation.Active then
    Guides := Guides + FShapeCreation.SnapGuides;
  for Guide in Guides do
  begin
    ACanvas.Pen.Color := TColor($00E6B050);
    ACanvas.Pen.Style := psDot;
    ACanvas.Pen.Width := 1;
    P1 := ScreenPoint(Guide.StartPoint);
    P2 := ScreenPoint(Guide.EndPoint);
    ACanvas.MoveTo(P1.X, P1.Y);
    ACanvas.LineTo(P2.X, P2.Y);
    if Guide.HighlightTarget then
    begin
      TargetRect := TRect.Create(ScreenPoint(Guide.TargetBounds.TopLeft),
        ScreenPoint(Guide.TargetBounds.BottomRight));
      ACanvas.Brush.Style := bsClear;
      ACanvas.Rectangle(TargetRect);
    end;
  end;
  ACanvas.Pen.Style := OldPenStyle;
  ACanvas.Brush.Style := OldBrushStyle;
  ACanvas.Pen.Color := OldPenColor;
  ACanvas.Pen.Width := OldPenWidth;
end;

procedure TVectArtCanvasControl.DrawSnapGuides(ACanvas: TDirect2DCanvas);
var
  Guide: TVectArtDesignerSnapGuide;
  Guides: TArray<TVectArtDesignerSnapGuide>;
  TargetRect: TRect;
  P1, P2: TPoint;
  OldPenStyle: TPenStyle;
  OldBrushStyle: TBrushStyle;
  OldPenColor: TColor;
  OldPenWidth: Integer;
  function ScreenPoint(const P: TPointF): TPoint;
  begin
    Result := Point(Round(FCanvasBounds.Left + P.X * FZoom),
      Round(FCanvasBounds.Top + P.Y * FZoom));
  end;
begin
  OldPenStyle := ACanvas.Pen.Style;
  OldBrushStyle := ACanvas.Brush.Style;
  OldPenColor := ACanvas.Pen.Color;
  OldPenWidth := ACanvas.Pen.Width;
  Guides := FInteraction.SnapGuides;
  if FShapeCreation.Active then
    Guides := Guides + FShapeCreation.SnapGuides;
  for Guide in Guides do
  begin
    ACanvas.Pen.Color := TColor($00E6B050);
    ACanvas.Pen.Style := psDot;
    ACanvas.Pen.Width := 1;
    P1 := ScreenPoint(Guide.StartPoint);
    P2 := ScreenPoint(Guide.EndPoint);
    ACanvas.MoveTo(P1.X, P1.Y);
    ACanvas.LineTo(P2.X, P2.Y);
    if Guide.HighlightTarget then
    begin
      TargetRect := TRect.Create(ScreenPoint(Guide.TargetBounds.TopLeft),
        ScreenPoint(Guide.TargetBounds.BottomRight));
      ACanvas.Brush.Style := bsClear;
      ACanvas.Rectangle(TargetRect);
    end;
  end;
  ACanvas.Pen.Style := OldPenStyle;
  ACanvas.Brush.Style := OldBrushStyle;
  ACanvas.Pen.Color := OldPenColor;
  ACanvas.Pen.Width := OldPenWidth;
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
  DocumentBitmap: ID2D1Bitmap;
  ReferenceBitmap: ID2D1Bitmap;
  ReferenceRect: TD2D1RectF;
  Handle: TVectArtSelectionHandle;
  RotationHandleIndex: Integer;
  I: Integer;
  LineEnd: TPoint;
  LineStart: TPoint;
  PathPreview: TArray<TPoint>;
  PathVertexRects: TArray<TRect>;
  RangeRect: TRect;
  Row: Integer;
  RowEnd: Integer;
  RowStart: Integer;
  SelectionGeometry: TVectArtSelectionGeometry;
  SelectionLocked: Boolean;
  SelectionOverlay: TVectArtSelectionOverlay;
  ShadowBounds: TRect;
  VisibleCanvasBounds: TRect;
begin
  Direct2DCanvas := TDirect2DCanvas.Create(Canvas, ClientRect);
  try
    Direct2DCanvas.BeginDraw;
    try
      Direct2DCanvas.Brush.Color := COLOR_EDITOR_SURROUND;
      Direct2DCanvas.FillRect(ClientRect);
      ShadowBounds := FCanvasBounds;
      OffsetRect(ShadowBounds, CANVAS_SHADOW_OFFSET, CANVAS_SHADOW_OFFSET);
      Direct2DCanvas.Brush.Color := COLOR_CANVAS_SHADOW;
      Direct2DCanvas.FillRect(ShadowBounds);

      CanvasLayer := nil;
      if FDocument <> nil then
        CanvasLayer := FDocument.CanvasLayer;
      if HasReferenceBackground then
      begin
        ReferenceBitmap := Direct2DCanvas.CreateBitmap(FReferenceBackground);
        if ReferenceBitmap = nil then
          raise EInvalidOp.Create('Direct2D reference background creation failed');
        ReferenceRect := D2D1RectF(FCanvasBounds.Left, FCanvasBounds.Top,
          FCanvasBounds.Right, FCanvasBounds.Bottom);
        Direct2DCanvas.RenderTarget.DrawBitmap(ReferenceBitmap,
          @ReferenceRect);
        ReferenceBitmap := nil;
      end
      else if (CanvasLayer <> nil) and CanvasLayer.Visible and
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

      if (FRenderedDocument.Width > 0) and
        (FRenderedDocument.Height > 0) then
      begin
        DocumentBitmap := Direct2DCanvas.CreateBitmap(FRenderedDocument);
        if DocumentBitmap = nil then
          raise EInvalidOp.Create('Direct2D document bitmap creation failed');
        ReferenceRect := D2D1RectF(FCanvasBounds.Left, FCanvasBounds.Top,
          FCanvasBounds.Right, FCanvasBounds.Bottom);
        Direct2DCanvas.RenderTarget.DrawBitmap(DocumentBitmap,
          @ReferenceRect);
        DocumentBitmap := nil;
      end;

      SelectionOverlay := BuildVectArtSelectionOverlay(FDocument,
        FInteraction, FCanvasBounds, FZoom);
      SelectionLocked := SelectionOverlay.Locked;
      if SelectionOverlay.Visible then
      begin
        SelectionGeometry := SelectionOverlay.Geometry;
        Direct2DCanvas.Brush.Style := bsSolid;
        Direct2DCanvas.Brush.Color := COLOR_SELECTION;
        Direct2DCanvas.Pen.Color := COLOR_SELECTION;
        if SelectionGeometry.DrawFrame then
          Direct2DCanvas.Polyline(SelectionGeometry.FramePoints);
        if not SelectionLocked then
        begin
          for Handle := vshTopLeft to vshLeft do
            if not SelectionGeometry.Handles[Handle].IsEmpty then
            begin
              Direct2DCanvas.Brush.Color := clWhite;
              Direct2DCanvas.FillRect(SelectionGeometry.Handles[Handle]);
              Direct2DCanvas.Brush.Color := COLOR_SELECTION;
              Direct2DCanvas.FrameRect(SelectionGeometry.Handles[Handle]);
            end;
          if SelectionOverlay.ShowRotationHandles then
            for RotationHandleIndex := 0 to 3 do
            begin
              if FInteraction.RotationSnapped then
                Direct2DCanvas.Brush.Color := TColor($00E6B050)
              else
                Direct2DCanvas.Brush.Color := TColor($00F0C060);
              Direct2DCanvas.FillRect(
                SelectionGeometry.RotationHandles[RotationHandleIndex]);
              Direct2DCanvas.Brush.Color := COLOR_SELECTION;
              Direct2DCanvas.FrameRect(
                SelectionGeometry.RotationHandles[RotationHandleIndex]);
            end;
        end;
      end;
      PathVertexRects := FInteraction.SelectedPathVertexRects;
      for I := 0 to High(PathVertexRects) do
      begin
        Direct2DCanvas.Brush.Color := TColor($00F0C060);
        Direct2DCanvas.FillRect(PathVertexRects[I]);
        Direct2DCanvas.Brush.Color := COLOR_SELECTION;
        Direct2DCanvas.FrameRect(PathVertexRects[I]);
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
        if FShapeCreation.PreviewIsEllipse then
        begin
          Direct2DCanvas.Brush.Style := bsClear;
          Direct2DCanvas.Pen.Color := COLOR_SELECTION;
          Direct2DCanvas.Ellipse(CreationRect);
        end
        else if FShapeCreation.PreviewIsRoundedRectangle then
        begin
          Direct2DCanvas.Brush.Style := bsClear;
          Direct2DCanvas.Pen.Color := COLOR_SELECTION;
          Direct2DCanvas.RoundRect(CreationRect.Left, CreationRect.Top,
            CreationRect.Right, CreationRect.Bottom,
            FShapeCreation.PreviewRoundedRadius * 2,
            FShapeCreation.PreviewRoundedRadius * 2);
        end
        else
        begin
          Direct2DCanvas.Brush.Style := bsSolid;
          Direct2DCanvas.Brush.Color := COLOR_SELECTION;
          Direct2DCanvas.FrameRect(CreationRect);
        end;
      end;
      if FShapeCreation.PreviewLine(LineStart, LineEnd) then
        DrawStyledPreviewLine(Direct2DCanvas, LineStart, LineEnd,
          FEditorState.Color1,
          FEditorState.LineStrokeWidth * FZoom,
          FEditorState.LineStrokeStyle, FEditorState.LineCap,
          FEditorState.LineAntiAlias, FEditorState.LineStartMarker,
          FEditorState.LineEndMarker, FEditorState.LineStartMarkerSize,
          FEditorState.LineEndMarkerSize);
      if FShapeCreation.PreviewPath(PathPreview) then
      begin
        Direct2DCanvas.Pen.Color := COLOR_SELECTION;
        Direct2DCanvas.Polyline(PathPreview);
      end;
    finally
      DrawSnapGuides(Direct2DCanvas);
      Direct2DCanvas.EndDraw;
    end;
  finally
    Direct2DCanvas.Free;
  end;
end;

procedure TVectArtCanvasControl.PaintGDI;
var
  CanvasLayer: TVectArtCanvasLayer;
  CreationRect: TRect;
  CellRect: TRect;
  Column: Integer;
  ColumnEnd: Integer;
  ColumnStart: Integer;
  Handle: TVectArtSelectionHandle;
  RotationHandleIndex: Integer;
  I: Integer;
  LineEnd: TPoint;
  LineStart: TPoint;
  PathPreview: TArray<TPoint>;
  PathVertexRects: TArray<TRect>;
  RangeRect: TRect;
  Row: Integer;
  RowEnd: Integer;
  RowStart: Integer;
  SelectionGeometry: TVectArtSelectionGeometry;
  SelectionLocked: Boolean;
  SelectionOverlay: TVectArtSelectionOverlay;
  ShadowBounds: TRect;
  VisibleCanvasBounds: TRect;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := COLOR_EDITOR_SURROUND;
  Canvas.FillRect(ClientRect);
  ShadowBounds := FCanvasBounds;
  OffsetRect(ShadowBounds, CANVAS_SHADOW_OFFSET, CANVAS_SHADOW_OFFSET);
  Canvas.Brush.Color := COLOR_CANVAS_SHADOW;
  Canvas.FillRect(ShadowBounds);

  CanvasLayer := nil;
  if FDocument <> nil then
    CanvasLayer := FDocument.CanvasLayer;
  if HasReferenceBackground then
  begin
    Canvas.StretchDraw(FCanvasBounds, FReferenceBackground);
  end
  else if (CanvasLayer <> nil) and CanvasLayer.Visible and
    not CanvasLayer.Transparent then
  begin
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

  DrawPremultipliedBitmap(Canvas, FCanvasBounds, FRenderedDocument);

  SelectionOverlay := BuildVectArtSelectionOverlay(FDocument,
    FInteraction, FCanvasBounds, FZoom);
  SelectionLocked := SelectionOverlay.Locked;
  if SelectionOverlay.Visible then
  begin
    SelectionGeometry := SelectionOverlay.Geometry;
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := COLOR_SELECTION;
    Canvas.Pen.Color := COLOR_SELECTION;
    if SelectionGeometry.DrawFrame then
      Canvas.Polyline(SelectionGeometry.FramePoints);
    if not SelectionLocked then
    begin
      for Handle := vshTopLeft to vshLeft do
        if not SelectionGeometry.Handles[Handle].IsEmpty then
        begin
          Canvas.Brush.Color := clWhite;
          Canvas.FillRect(SelectionGeometry.Handles[Handle]);
          Canvas.Brush.Color := COLOR_SELECTION;
          Canvas.FrameRect(SelectionGeometry.Handles[Handle]);
        end;
      if SelectionOverlay.ShowRotationHandles then
        for RotationHandleIndex := 0 to 3 do
        begin
          if FInteraction.RotationSnapped then
            Canvas.Brush.Color := TColor($00E6B050)
          else
            Canvas.Brush.Color := TColor($00F0C060);
          Canvas.FillRect(SelectionGeometry.RotationHandles[
            RotationHandleIndex]);
          Canvas.Brush.Color := COLOR_SELECTION;
          Canvas.FrameRect(SelectionGeometry.RotationHandles[
            RotationHandleIndex]);
        end;
    end;
  end;
  PathVertexRects := FInteraction.SelectedPathVertexRects;
  for I := 0 to High(PathVertexRects) do
  begin
    Canvas.Brush.Color := TColor($00F0C060);
    Canvas.FillRect(PathVertexRects[I]);
    Canvas.Brush.Color := COLOR_SELECTION;
    Canvas.FrameRect(PathVertexRects[I]);
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
    if FShapeCreation.PreviewIsEllipse then
    begin
      Canvas.Brush.Style := bsClear;
      Canvas.Pen.Color := COLOR_SELECTION;
      Canvas.Ellipse(CreationRect);
    end
    else if FShapeCreation.PreviewIsRoundedRectangle then
    begin
      Canvas.Brush.Style := bsClear;
      Canvas.Pen.Color := COLOR_SELECTION;
      Canvas.RoundRect(CreationRect.Left, CreationRect.Top,
        CreationRect.Right, CreationRect.Bottom,
        FShapeCreation.PreviewRoundedRadius * 2,
        FShapeCreation.PreviewRoundedRadius * 2);
    end
    else
    begin
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := COLOR_SELECTION;
      Canvas.FrameRect(CreationRect);
    end;
  end;
  if FShapeCreation.PreviewLine(LineStart, LineEnd) then
    DrawStyledPreviewLine(Canvas, LineStart, LineEnd,
      FEditorState.Color1, FEditorState.LineStrokeWidth * FZoom,
      FEditorState.LineStrokeStyle, FEditorState.LineCap,
      FEditorState.LineAntiAlias, FEditorState.LineStartMarker,
      FEditorState.LineEndMarker, FEditorState.LineStartMarkerSize,
      FEditorState.LineEndMarkerSize);
  if FShapeCreation.PreviewPath(PathPreview) then
  begin
    Canvas.Pen.Color := COLOR_SELECTION;
    Canvas.Polyline(PathPreview);
  end;
  DrawSnapGuides(Canvas);
end;

procedure TVectArtCanvasControl.SetReferenceBackgroundRgba(
  const Pixels: TBytes; Width, Height: Integer);
var
  Destination: PByte;
  Source: PByte;
  X: Integer;
  Y: Integer;
begin
  FReferenceBackground.SetSize(0, 0);
  if (Width <= 0) or (Height <= 0) or
    (Length(Pixels) <> NativeInt(Width) * Height * 4) then
  begin
    Invalidate;
    Exit;
  end;
  FReferenceBackground.PixelFormat := pf32bit;
  FReferenceBackground.SetSize(Width, Height);
  FReferenceBackground.AlphaFormat := afIgnored;
  Source := @Pixels[0];
  for Y := 0 to Height - 1 do
  begin
    Destination := FReferenceBackground.ScanLine[Y];
    for X := 0 to Width - 1 do
    begin
      Destination[0] := Source[2];
      Destination[1] := Source[1];
      Destination[2] := Source[0];
      Destination[3] := 255;
      Inc(Destination, 4);
      Inc(Source, 4);
    end;
  end;
  Invalidate;
end;

procedure TVectArtCanvasControl.Resize;
begin
  inherited Resize;
  CalculateCanvasBounds;
  UpdateTextEditorBounds;
  Invalidate;
end;

procedure TVectArtCanvasControl.SetDocument(const Value: TVectArtDocument);
begin
  if FDocument = Value then
    Exit;
  if FTextEditing then
    FinishTextEdit(False, False);
  FDocument := Value;
  FRenderedRevision := -1;
  FRenderedPreviewStrokeWidth := -1.0;
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
