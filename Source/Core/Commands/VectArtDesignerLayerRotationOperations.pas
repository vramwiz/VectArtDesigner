// Rotates the current selection around a shared center as one undoable edit.
// 固定角度だけを扱い、任意角度の入力はオブジェクト設定側へ委ねる。
unit VectArtDesignerLayerRotationOperations;

interface

uses
  VectArtDesignerDocument, VectArtDesignerEditHistory;

function CanRotateVectArtSelection(Document: TVectArtDocument): Boolean;
procedure RotateVectArtSelection(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory; AngleDegrees: Single);

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

function CanRotateVectArtSelection(Document: TVectArtDocument): Boolean;
var
  I: Integer;
begin
  Result := (Document <> nil) and (Document.SelectionCount > 0);
  if not Result then
    Exit;
  for I := 1 to Document.LayerCount - 1 do
    if Document.IsLayerSelected(I) and Document[I].Locked then
      Exit(False);
end;

function SelectionCenter(Document: TVectArtDocument): TPointF;
var
  Bounds: TRectF;
  I: Integer;
  LayerBounds: TRectF;
  Valid: Boolean;
begin
  Bounds := TRectF.Empty;
  Valid := False;
  for I := 1 to Document.LayerCount - 1 do
    if Document.IsLayerSelected(I) and TryLayerBounds(Document[I],
      LayerBounds) then
    begin
      if Valid then
        Bounds := TRectF.Union(Bounds, LayerBounds)
      else
      begin
        Bounds := LayerBounds;
        Valid := True;
      end;
    end;
  if Valid then
    Result := Bounds.CenterPoint
  else
    Result := TPointF.Zero;
end;

procedure RotateBoundsCenter(var Bounds: TRectF; const Center: TPointF;
  AngleDegrees: Single);
var
  CurrentCenter: TPointF;
  NewCenter: TPointF;
begin
  CurrentCenter := Bounds.CenterPoint;
  NewCenter := RotatePointAround(CurrentCenter, Center, AngleDegrees);
  Bounds.Offset(NewCenter.X - CurrentCenter.X,
    NewCenter.Y - CurrentCenter.Y);
end;

procedure AddRectangleRotation(Command: TVectArtCompoundCommand;
  Document: TVectArtDocument; Index: Integer; const Center: TPointF;
  AngleDegrees: Single);
var
  Layer: TVectArtRectangleLayer;
  NewBounds: TRectF;
begin
  Layer := TVectArtRectangleLayer(Document[Index]);
  NewBounds := Layer.Bounds;
  RotateBoundsCenter(NewBounds, Center, AngleDegrees);
  Command.Add(TVectArtBoundsCommand.Create(Document, [Index],
    [Layer.Bounds], [NewBounds]));
  Command.Add(TVectArtRotationCommand.Create(Document, Index,
    Layer.RotationDegrees, Layer.RotationDegrees + AngleDegrees));
end;

procedure AddTextRotation(Command: TVectArtCompoundCommand;
  Document: TVectArtDocument; Index: Integer; const Center: TPointF;
  AngleDegrees: Single);
var
  AfterData: TVectArtTextData;
  BeforeData: TVectArtTextData;
begin
  BeforeData := CaptureVectArtTextData(
    TVectArtTextLayer(Document[Index]));
  AfterData := BeforeData;
  RotateBoundsCenter(AfterData.Bounds, Center, AngleDegrees);
  AfterData.RotationDegrees := AfterData.RotationDegrees + AngleDegrees;
  Command.Add(TVectArtTextDataCommand.Create(Document, Index,
    BeforeData, AfterData));
end;

procedure AddLineRotation(Command: TVectArtCompoundCommand;
  Document: TVectArtDocument; Index: Integer; const Center: TPointF;
  AngleDegrees: Single);
var
  Layer: TVectArtLineLayer;
begin
  Layer := TVectArtLineLayer(Document[Index]);
  Command.Add(TVectArtLinePointsCommand.Create(Document, Index,
    Layer.StartPoint, Layer.EndPoint,
    RotatePointAround(Layer.StartPoint, Center, AngleDegrees),
    RotatePointAround(Layer.EndPoint, Center, AngleDegrees)));
end;

procedure AddPathRotation(Command: TVectArtCompoundCommand;
  Document: TVectArtDocument; Index: Integer; const Center: TPointF;
  AngleDegrees: Single);
var
  I: Integer;
  Layer: TVectArtPathLayer;
  NewPoints: TArray<TPointF>;
begin
  Layer := TVectArtPathLayer(Document[Index]);
  NewPoints := Copy(Layer.Points);
  for I := 0 to High(NewPoints) do
    NewPoints[I] := RotatePointAround(NewPoints[I], Center, AngleDegrees);
  Command.Add(TVectArtPathPointsCommand.Create(Document, Index,
    Layer.Points, NewPoints));
end;

procedure AddImageRotation(Command: TVectArtCompoundCommand;
  Document: TVectArtDocument; Index: Integer; const Center: TPointF;
  AngleDegrees: Single);
var
  I: Integer;
  Layer: TVectArtImageLayer;
  NewPoints: TVectArtImagePoints;
begin
  Layer := TVectArtImageLayer(Document[Index]);
  NewPoints := Layer.Points;
  for I := 0 to High(NewPoints) do
    NewPoints[I] := RotatePointAround(NewPoints[I], Center, AngleDegrees);
  Command.Add(TVectArtImagePointsCommand.Create(Document, Index,
    Layer.Points, NewPoints));
end;

procedure RotateVectArtSelection(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory; AngleDegrees: Single);
var
  Center: TPointF;
  Command: TVectArtCompoundCommand;
  I: Integer;
begin
  if not CanRotateVectArtSelection(Document) or
    SameValue(NormalizeAngleDegrees(AngleDegrees), 0.0) then
    Exit;
  Center := SelectionCenter(Document);
  Command := TVectArtCompoundCommand.Create;
  for I := 1 to Document.LayerCount - 1 do
    if Document.IsLayerSelected(I) then
      if Document[I] is TVectArtRectangleLayer then
        AddRectangleRotation(Command, Document, I, Center, AngleDegrees)
      else if Document[I] is TVectArtTextLayer then
        AddTextRotation(Command, Document, I, Center, AngleDegrees)
      else if Document[I] is TVectArtLineLayer then
        AddLineRotation(Command, Document, I, Center, AngleDegrees)
      else if Document[I] is TVectArtPathLayer then
        AddPathRotation(Command, Document, I, Center, AngleDegrees)
      else if Document[I] is TVectArtImageLayer then
        AddImageRotation(Command, Document, I, Center, AngleDegrees);
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
