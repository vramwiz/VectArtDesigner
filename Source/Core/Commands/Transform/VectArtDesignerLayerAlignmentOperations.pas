// 選択全体の外接範囲を基準に各レイヤーを整列し、1件のUndo操作にまとめる。
unit VectArtDesignerLayerAlignmentOperations;

interface

uses
  VectArtDesignerDocument, VectArtDesignerEditHistory;

type
  TVectArtAlignment = (vaaLeft, vaaHorizontalCenter, vaaRight,
    vaaTop, vaaVerticalCenter, vaaBottom, vaaCenter);

function CanAlignVectArtSelection(Document: TVectArtDocument): Boolean;
procedure AlignVectArtSelection(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory; Alignment: TVectArtAlignment);

implementation

uses
  System.Math, System.Types, VectArtDesignerBezierGeometry,
  VectArtDesignerEditCommands, VectArtDesignerGeometry;

function ImageBounds(const Points: TVectArtImagePoints): TRectF;
var
  I: Integer;
begin
  Result := TRectF.Create(Points[0], Points[0]);
  for I := 1 to High(Points) do
  begin
    Result.Left := Min(Result.Left, Points[I].X);
    Result.Top := Min(Result.Top, Points[I].Y);
    Result.Right := Max(Result.Right, Points[I].X);
    Result.Bottom := Max(Result.Bottom, Points[I].Y);
  end;
end;

function TryLayerBounds(Layer: TVectArtLayer; out Bounds: TRectF): Boolean;
var
  Image: TVectArtImageLayer;
  Line: TVectArtLineLayer;
  Path: TVectArtPathLayer;
  Rectangle: TVectArtRectangleLayer;
  Text: TVectArtTextLayer;
begin
  Result := True;
  if Layer is TVectArtRectangleLayer then
  begin
    Rectangle := TVectArtRectangleLayer(Layer);
    Bounds := QuadBounds(RectangleCorners(Rectangle.Bounds,
      Rectangle.RotationDegrees));
  end
  else if Layer is TVectArtTextLayer then
  begin
    Text := TVectArtTextLayer(Layer);
    Bounds := QuadBounds(RectangleCorners(Text.Bounds,
      Text.RotationDegrees));
  end
  else if Layer is TVectArtLineLayer then
  begin
    Line := TVectArtLineLayer(Layer);
    Bounds := RectF(Min(Line.StartPoint.X, Line.EndPoint.X),
      Min(Line.StartPoint.Y, Line.EndPoint.Y),
      Max(Line.StartPoint.X, Line.EndPoint.X),
      Max(Line.StartPoint.Y, Line.EndPoint.Y));
  end
  else if Layer is TVectArtPathLayer then
  begin
    Path := TVectArtPathLayer(Layer);
    Bounds := PointsBounds(BuildPathDisplayPolyline(Path.Points,
      Path.Bezier, Path.Closed, 16));
  end
  else if Layer is TVectArtImageLayer then
  begin
    Image := TVectArtImageLayer(Layer);
    Bounds := ImageBounds(Image.Points);
  end
  else
    Result := False;
end;

function CanAlignVectArtSelection(Document: TVectArtDocument): Boolean;
var
  Bounds: TRectF;
  I: Integer;
begin
  Result := (Document <> nil) and (Document.SelectionCount > 1);
  if not Result then
    Exit;
  for I := 1 to Document.LayerCount - 1 do
    if Document.IsLayerSelected(I) and
      (Document[I].Locked or not TryLayerBounds(Document[I], Bounds)) then
      Exit(False);
end;

function SelectionBounds(Document: TVectArtDocument): TRectF;
var
  I: Integer;
  LayerBounds: TRectF;
  Valid: Boolean;
begin
  Result := TRectF.Empty;
  Valid := False;
  for I := 1 to Document.LayerCount - 1 do
    if Document.IsLayerSelected(I) and TryLayerBounds(Document[I],
      LayerBounds) then
    begin
      if Valid then
        Result := TRectF.Union(Result, LayerBounds)
      else
      begin
        Result := LayerBounds;
        Valid := True;
      end;
    end;
end;

procedure AlignmentOffset(const LayerBounds, Bounds: TRectF;
  Alignment: TVectArtAlignment; out DX, DY: Single);
begin
  DX := 0;
  DY := 0;
  case Alignment of
    vaaLeft:
      DX := Bounds.Left - LayerBounds.Left;
    vaaHorizontalCenter:
      DX := Bounds.CenterPoint.X - LayerBounds.CenterPoint.X;
    vaaRight:
      DX := Bounds.Right - LayerBounds.Right;
    vaaTop:
      DY := Bounds.Top - LayerBounds.Top;
    vaaVerticalCenter:
      DY := Bounds.CenterPoint.Y - LayerBounds.CenterPoint.Y;
    vaaBottom:
      DY := Bounds.Bottom - LayerBounds.Bottom;
    vaaCenter:
      begin
        DX := Bounds.CenterPoint.X - LayerBounds.CenterPoint.X;
        DY := Bounds.CenterPoint.Y - LayerBounds.CenterPoint.Y;
      end;
  end;
end;

procedure AddLayerTranslation(Command: TVectArtCompoundCommand;
  Document: TVectArtDocument; Index: Integer; DX, DY: Single);
var
  I: Integer;
  Image: TVectArtImageLayer;
  Line: TVectArtLineLayer;
  NewBounds: TRectF;
  NewImagePoints: TVectArtImagePoints;
  NewPathPoints: TArray<TPointF>;
  Path: TVectArtPathLayer;
  Rectangle: TVectArtRectangleLayer;
  Text: TVectArtTextLayer;
begin
  if SameValue(DX, 0.0) and SameValue(DY, 0.0) then
    Exit;
  if Document[Index] is TVectArtRectangleLayer then
  begin
    Rectangle := TVectArtRectangleLayer(Document[Index]);
    NewBounds := Rectangle.Bounds;
    NewBounds.Offset(DX, DY);
    Command.Add(TVectArtBoundsCommand.Create(Document, [Index],
      [Rectangle.Bounds], [NewBounds]));
  end
  else if Document[Index] is TVectArtTextLayer then
  begin
    Text := TVectArtTextLayer(Document[Index]);
    NewBounds := Text.Bounds;
    NewBounds.Offset(DX, DY);
    Command.Add(TVectArtBoundsCommand.Create(Document, [Index],
      [Text.Bounds], [NewBounds]));
  end
  else if Document[Index] is TVectArtLineLayer then
  begin
    Line := TVectArtLineLayer(Document[Index]);
    Command.Add(TVectArtLinePointsCommand.Create(Document, Index,
      Line.StartPoint, Line.EndPoint,
      Line.StartPoint + TPointF.Create(DX, DY),
      Line.EndPoint + TPointF.Create(DX, DY)));
  end
  else if Document[Index] is TVectArtPathLayer then
  begin
    Path := TVectArtPathLayer(Document[Index]);
    NewPathPoints := Copy(Path.Points);
    for I := 0 to High(NewPathPoints) do
      NewPathPoints[I] := NewPathPoints[I] + TPointF.Create(DX, DY);
    Command.Add(TVectArtPathPointsCommand.Create(Document, Index,
      Path.Points, NewPathPoints));
  end
  else if Document[Index] is TVectArtImageLayer then
  begin
    Image := TVectArtImageLayer(Document[Index]);
    NewImagePoints := Image.Points;
    for I := 0 to High(NewImagePoints) do
      NewImagePoints[I] := NewImagePoints[I] + TPointF.Create(DX, DY);
    Command.Add(TVectArtImagePointsCommand.Create(Document, Index,
      Image.Points, NewImagePoints));
  end;
end;

procedure AlignVectArtSelection(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory; Alignment: TVectArtAlignment);
var
  Bounds: TRectF;
  Command: TVectArtCompoundCommand;
  DX: Single;
  DY: Single;
  I: Integer;
  LayerBounds: TRectF;
begin
  if not CanAlignVectArtSelection(Document) then
    Exit;
  Bounds := SelectionBounds(Document);
  Command := TVectArtCompoundCommand.Create;
  for I := 1 to Document.LayerCount - 1 do
    if Document.IsLayerSelected(I) and TryLayerBounds(Document[I],
      LayerBounds) then
    begin
      AlignmentOffset(LayerBounds, Bounds, Alignment, DX, DY);
      AddLayerTranslation(Command, Document, I, DX, DY);
    end;
  if Command.Count = 0 then
  begin
    Command.Free;
    Exit;
  end;
  Document.BeginUpdate;
  try
    Command.Execute;
  finally
    Document.EndUpdate;
  end;
  if EditHistory <> nil then
    EditHistory.AddApplied(Command)
  else
    Command.Free;
end;

end.
