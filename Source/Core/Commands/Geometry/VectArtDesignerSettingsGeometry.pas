// 情報ページから指定された位置・寸法をモデルへ適用し、対応するUndoを登録する。
// 文字、画像の軸、Pathの点列、四角の複数選択で既存の変形規則を維持する。
unit VectArtDesignerSettingsGeometry;
interface
uses VectArtDesignerDocument, VectArtDesignerEditHistory;
procedure ApplyVectArtSettingsGeometry(Document: TVectArtDocument; History: TVectArtEditHistory;
  XValue, YValue, WidthValue, HeightValue: Double);
implementation
uses System.Types, System.Math, VectArtDesignerEditCommands,
  VectArtDesignerSettingsSelection, VectArtDesignerGeometry, VectArtDesignerTextGeometry;
procedure ApplyVectArtSettingsGeometry(Document: TVectArtDocument; History: TVectArtEditHistory;
  XValue, YValue, WidthValue, HeightValue: Double);
var
  Bounds: TRectF;
  I: Integer;
  LayerIndices: TArray<Integer>;
  NewBounds: TArray<TRectF>;
  NewImagePoints: TVectArtImagePoints;
  NewSelectionBounds: TRectF;
  OldBounds: TArray<TRectF>;
  OldPoints: TArray<TPointF>;
  OldImagePoints: TVectArtImagePoints;
  OldSelectionBounds: TRectF;
  PathLayer: TVectArtPathLayer;
  NewTextData: TVectArtTextData;
  OldTextData: TVectArtTextData;
  ImageLayer: TVectArtImageLayer;
  PathPoints: TArray<TPointF>;
  PointIndex: Integer;
  ScaleX: Single;
  ScaleY: Single;
  ULength: Single;
  VLength: Single;

begin
  if (Document=nil) or (Document.SelectionCount=0) or
    SelectedLayersHaveLock(Document) then Exit;
  WidthValue := Max(WidthValue, 1.0);
  HeightValue := Max(HeightValue, 1.0);
  if (Document.SelectionCount = 1) and
    (Document[Document.SelectedIndex] is TVectArtTextLayer) then
  begin
    OldTextData := CaptureVectArtTextData(
      TVectArtTextLayer(Document[Document.SelectedIndex]));
    NewTextData := OldTextData;
    NewTextData.Bounds := RectF(XValue, YValue, XValue + WidthValue,
      YValue + HeightValue);
    Document.SetTextData(Document.SelectedIndex, NewTextData);
    if History <> nil then
      History.AddApplied(TVectArtTextDataCommand.Create(Document,
        Document.SelectedIndex, OldTextData, NewTextData));
    Exit;
  end;
  if (Document.SelectionCount = 1) and
    (Document[Document.SelectedIndex] is TVectArtImageLayer) then
  begin
    ImageLayer := TVectArtImageLayer(Document[Document.SelectedIndex]);
    OldImagePoints := ImageLayer.Points;
    ULength := Hypot(OldImagePoints[1].X - OldImagePoints[0].X,
      OldImagePoints[1].Y - OldImagePoints[0].Y);
    VLength := Hypot(OldImagePoints[3].X - OldImagePoints[0].X,
      OldImagePoints[3].Y - OldImagePoints[0].Y);
    if (ULength <= 0) or (VLength <= 0) then
    begin
      Exit;
    end;
    NewImagePoints[0] := TPointF.Create(XValue, YValue);
    NewImagePoints[1] := TPointF.Create(XValue +
      (OldImagePoints[1].X - OldImagePoints[0].X) / ULength * WidthValue,
      YValue + (OldImagePoints[1].Y - OldImagePoints[0].Y) / ULength *
        WidthValue);
    NewImagePoints[3] := TPointF.Create(XValue +
      (OldImagePoints[3].X - OldImagePoints[0].X) / VLength * HeightValue,
      YValue + (OldImagePoints[3].Y - OldImagePoints[0].Y) / VLength *
        HeightValue);
    NewImagePoints[2] := TPointF.Create(NewImagePoints[1].X +
      NewImagePoints[3].X - NewImagePoints[0].X,
      NewImagePoints[1].Y + NewImagePoints[3].Y - NewImagePoints[0].Y);
    Document.SetImagePoints(Document.SelectedIndex, NewImagePoints);
    if History <> nil then
      History.AddApplied(TVectArtImagePointsCommand.Create(Document,
        Document.SelectedIndex, OldImagePoints, NewImagePoints));
    Exit;
  end;
  if (Document.SelectionCount = 1) and
    (Document[Document.SelectedIndex] is TVectArtPathLayer) then
  begin
    PathLayer := TVectArtPathLayer(Document[Document.SelectedIndex]);
    OldPoints := Copy(PathLayer.Points);
    OldSelectionBounds := PointsBounds(OldPoints);
    if SameValue(OldSelectionBounds.Width, 0.0) or
      SameValue(OldSelectionBounds.Height, 0.0) then
    begin
      Exit;
    end;
    ScaleX := WidthValue / OldSelectionBounds.Width;
    ScaleY := HeightValue / OldSelectionBounds.Height;
    SetLength(PathPoints, Length(OldPoints));
    for PointIndex := 0 to High(OldPoints) do
      PathPoints[PointIndex] := TPointF.Create(
        XValue + (OldPoints[PointIndex].X - OldSelectionBounds.Left) * ScaleX,
        YValue + (OldPoints[PointIndex].Y - OldSelectionBounds.Top) * ScaleY);
    Document.SetPathPoints(Document.SelectedIndex, PathPoints);
    if History <> nil then
      History.AddApplied(TVectArtPathPointsCommand.Create(Document,
        Document.SelectedIndex, OldPoints, PathPoints));
    Exit;
  end;
  if not SelectedBounds(Document, OldSelectionBounds) then
    Exit;
  NewSelectionBounds := TRectF.Create(XValue, YValue, XValue + WidthValue,
    YValue + HeightValue);
  ScaleX := NewSelectionBounds.Width / OldSelectionBounds.Width;
  ScaleY := NewSelectionBounds.Height / OldSelectionBounds.Height;
  LayerIndices := GetSelectedRectangleIndices(Document);
  SetLength(OldBounds, Length(LayerIndices));
  SetLength(NewBounds, Length(LayerIndices));
  for I := 0 to High(LayerIndices) do
  begin
    OldBounds[I] := TVectArtRectangleLayer(
      Document[LayerIndices[I]]).Bounds;
    Bounds := OldBounds[I];
    NewBounds[I].Left := NewSelectionBounds.Left +
      (Bounds.Left - OldSelectionBounds.Left) * ScaleX;
    NewBounds[I].Right := NewSelectionBounds.Left +
      (Bounds.Right - OldSelectionBounds.Left) * ScaleX;
    NewBounds[I].Top := NewSelectionBounds.Top +
      (Bounds.Top - OldSelectionBounds.Top) * ScaleY;
    NewBounds[I].Bottom := NewSelectionBounds.Top +
      (Bounds.Bottom - OldSelectionBounds.Top) * ScaleY;
    Document.SetRectangleBounds(LayerIndices[I], NewBounds[I]);
  end;
  if (History <> nil) and
    (not SameValue(OldSelectionBounds.Left, NewSelectionBounds.Left) or
     not SameValue(OldSelectionBounds.Top, NewSelectionBounds.Top) or
     not SameValue(OldSelectionBounds.Right, NewSelectionBounds.Right) or
     not SameValue(OldSelectionBounds.Bottom, NewSelectionBounds.Bottom)) then
    History.AddApplied(TVectArtBoundsCommand.Create(Document,
      LayerIndices, OldBounds, NewBounds));
end;


end.
