// 選択レイヤーの外形から、Canvasへ描く選択枠と操作ハンドルの配置状態を組み立てる。
// 本体の可視性とは分離し、非表示レイヤーも一覧で選択されている間は編集位置を示す。
unit VectArtDesignerSelectionOverlay;

interface

uses
  System.Types, VectArtDesignerCanvasInteraction, VectArtDesignerDocument,
  VectArtDesignerSelectionGeometry;

type
  TVectArtSelectionOverlay = record
    Geometry: TVectArtSelectionGeometry;
    Locked: Boolean;
    ShowRotationHandles: Boolean;
    Visible: Boolean;
  end;

function BuildVectArtSelectionOverlay(Document: TVectArtDocument;
  Interaction: TVectArtCanvasInteraction; const CanvasBounds: TRect;
  Zoom: Single): TVectArtSelectionOverlay;

implementation

uses
  System.Math, VectArtDesignerBezierGeometry, VectArtDesignerGeometry;

function BuildVectArtSelectionOverlay(Document: TVectArtDocument;
  Interaction: TVectArtCanvasInteraction; const CanvasBounds: TRect;
  Zoom: Single): TVectArtSelectionOverlay;
var
  I: Integer;
  J: Integer;
  ImageLayer: TVectArtImageLayer;
  Layer: TVectArtLayer;
  LayerRect: TRect;
  LineLayer: TVectArtLineLayer;
  LogicalQuad: TVectArtQuad;
  PathLayer: TVectArtPathLayer;
  RectangleLayer: TVectArtRectangleLayer;
  RotatedBounds: TRectF;
  ScreenQuad: TVectArtScreenQuad;
  SelectionFrameOffsetPixels: Integer;
  SelectionLayerRect: TRect;
  TextLayer: TVectArtTextLayer;
begin
  Result := Default(TVectArtSelectionOverlay);
  if (Document = nil) or (Document.SelectionCount = 0) then
    Exit;
  SelectionLayerRect := TRect.Empty;
  SelectionFrameOffsetPixels := SelectionFrameOffset(0, Zoom);

  // 非表示は本体描画とヒットテストだけを抑止し、明示選択された位置情報までは失わせない。
  for I := 1 to Document.LayerCount - 1 do
  begin
    Layer := Document[I];
    if not Document.IsLayerSelected(I) or
      not ((Layer is TVectArtRectangleLayer) or
        (Layer is TVectArtLineLayer) or
        (Layer is TVectArtPathLayer) or
        (Layer is TVectArtImageLayer) or
        (Layer is TVectArtTextLayer)) then
      Continue;
    Result.Locked := Result.Locked or Layer.Locked;
    if Layer is TVectArtRectangleLayer then
    begin
      RectangleLayer := TVectArtRectangleLayer(Layer);
      RotatedBounds := QuadBounds(RectangleCorners(RectangleLayer.Bounds,
        RectangleLayer.RotationDegrees));
      SelectionFrameOffsetPixels := Max(SelectionFrameOffsetPixels,
        SelectionFrameOffset(RectangleLayer.StrokeWidth, Zoom));
    end
    else if Layer is TVectArtLineLayer then
    begin
      LineLayer := TVectArtLineLayer(Layer);
      RotatedBounds := TRectF.Create(Min(LineLayer.StartPoint.X,
        LineLayer.EndPoint.X), Min(LineLayer.StartPoint.Y,
        LineLayer.EndPoint.Y), Max(LineLayer.StartPoint.X,
        LineLayer.EndPoint.X), Max(LineLayer.StartPoint.Y,
        LineLayer.EndPoint.Y));
      SelectionFrameOffsetPixels := Max(SelectionFrameOffsetPixels,
        SelectionFrameOffset(LineLayer.StrokeWidth, Zoom));
    end
    else if Layer is TVectArtPathLayer then
    begin
      PathLayer := TVectArtPathLayer(Layer);
      // Path枠は頂点編集とリサイズの基準なので、装飾マーカーでは広げない。
      RotatedBounds := PointsBounds(BuildPathDisplayPolyline(
        PathLayer.Points, PathLayer.Bezier, PathLayer.Closed, 16));
      SelectionFrameOffsetPixels := Max(SelectionFrameOffsetPixels,
        SelectionFrameOffset(PathLayer.StrokeWidth, Zoom));
    end
    else if Layer is TVectArtTextLayer then
    begin
      TextLayer := TVectArtTextLayer(Layer);
      RotatedBounds := QuadBounds(RectangleCorners(TextLayer.Bounds,
        TextLayer.RotationDegrees));
    end
    else
    begin
      ImageLayer := TVectArtImageLayer(Layer);
      RotatedBounds := TRectF.Create(ImageLayer.Points[0],
        ImageLayer.Points[0]);
      for J := 1 to High(ImageLayer.Points) do
      begin
        RotatedBounds.Left := Min(RotatedBounds.Left,
          ImageLayer.Points[J].X);
        RotatedBounds.Top := Min(RotatedBounds.Top,
          ImageLayer.Points[J].Y);
        RotatedBounds.Right := Max(RotatedBounds.Right,
          ImageLayer.Points[J].X);
        RotatedBounds.Bottom := Max(RotatedBounds.Bottom,
          ImageLayer.Points[J].Y);
      end;
    end;
    LayerRect := Rect(CanvasBounds.Left + Round(RotatedBounds.Left * Zoom),
      CanvasBounds.Top + Round(RotatedBounds.Top * Zoom),
      CanvasBounds.Left + Round(RotatedBounds.Right * Zoom),
      CanvasBounds.Top + Round(RotatedBounds.Bottom * Zoom));
    if LayerRect.Width = 0 then
      Inc(LayerRect.Right);
    if LayerRect.Height = 0 then
      Inc(LayerRect.Bottom);
    if SelectionLayerRect.IsEmpty then
      SelectionLayerRect := LayerRect
    else
      SelectionLayerRect := Rect(
        Min(SelectionLayerRect.Left, LayerRect.Left),
        Min(SelectionLayerRect.Top, LayerRect.Top),
        Max(SelectionLayerRect.Right, LayerRect.Right),
        Max(SelectionLayerRect.Bottom, LayerRect.Bottom));
  end;

  Result.Visible := (SelectionLayerRect.Width > 0) and
    (SelectionLayerRect.Height > 0);
  if not Result.Visible then
    Exit;
  if (Document.SelectionCount = 1) and (Document.SelectedIndex > 0) and
    (Document[Document.SelectedIndex] is TVectArtLineLayer) then
  begin
    LineLayer := TVectArtLineLayer(Document[Document.SelectedIndex]);
    Result.Geometry := BuildLineSelectionGeometry(Point(CanvasBounds.Left +
      Round(LineLayer.StartPoint.X * Zoom), CanvasBounds.Top +
      Round(LineLayer.StartPoint.Y * Zoom)), Point(CanvasBounds.Left +
      Round(LineLayer.EndPoint.X * Zoom), CanvasBounds.Top +
      Round(LineLayer.EndPoint.Y * Zoom)));
  end
  else if (Document.SelectionCount = 1) and
    (Document.SelectedIndex > 0) and
    (Document[Document.SelectedIndex] is TVectArtPathLayer) then
    Result.Geometry := BuildPathSelectionGeometry(SelectionLayerRect,
      SelectionFrameOffsetPixels)
  else if (Document.SelectionCount = 1) and
    (Document.SelectedIndex > 0) and
    (Document[Document.SelectedIndex] is TVectArtImageLayer) then
  begin
    ImageLayer := TVectArtImageLayer(Document[Document.SelectedIndex]);
    for I := 0 to High(ScreenQuad) do
      ScreenQuad[I] := Point(CanvasBounds.Left +
        Round(ImageLayer.Points[I].X * Zoom), CanvasBounds.Top +
        Round(ImageLayer.Points[I].Y * Zoom));
    Result.Geometry := BuildRotatedSelectionGeometry(ScreenQuad,
      SelectionFrameOffsetPixels);
  end
  else if (Interaction <> nil) and not Interaction.AxisAlignedSelection and
    (Document.SelectionCount = 1) and (Document.SelectedIndex > 0) and
    (Document[Document.SelectedIndex] is TVectArtRectangleLayer) then
  begin
    RectangleLayer := TVectArtRectangleLayer(
      Document[Document.SelectedIndex]);
    LogicalQuad := RectangleCorners(RectangleLayer.Bounds,
      RectangleLayer.RotationDegrees);
    for I := 0 to High(ScreenQuad) do
      ScreenQuad[I] := Point(CanvasBounds.Left +
        Round(LogicalQuad[I].X * Zoom), CanvasBounds.Top +
        Round(LogicalQuad[I].Y * Zoom));
    Result.Geometry := BuildRotatedSelectionGeometry(ScreenQuad,
      SelectionFrameOffsetPixels);
  end
  else
    Result.Geometry := BuildSelectionGeometry(SelectionLayerRect,
      SelectionFrameOffsetPixels);
  Result.ShowRotationHandles := not Result.Locked and
    (Interaction <> nil) and not Interaction.AxisAlignedSelection and
    (Document.SelectionCount = 1) and
    ((Document[Document.SelectedIndex] is TVectArtRectangleLayer) or
     (Document[Document.SelectedIndex] is TVectArtImageLayer));
end;

end.
