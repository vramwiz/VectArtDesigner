// 選択全体を共通軸で反転し、図形種別ごとの更新を1件のUndo操作にまとめる。
// 単一選択は自身、複数選択は共通外接範囲の中心を軸とし、1件の履歴へまとめる。
unit VectArtDesignerLayerFlipOperations;

interface

uses
  VectArtDesignerDocument, VectArtDesignerEditHistory;

type
  TVectArtFlipDirection = (vfdHorizontal, vfdVertical);

function CanFlipVectArtSelection(Document: TVectArtDocument): Boolean;
procedure FlipVectArtSelection(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory; Direction: TVectArtFlipDirection);

implementation

uses
  System.Math, System.Types, VectArtDesignerBezierGeometry,
  VectArtDesignerEditCommands, VectArtDesignerGeometry;

function ReflectPoint(const Point, AxisCenter: TPointF;
  Direction: TVectArtFlipDirection): TPointF;
begin
  Result := Point;
  if Direction = vfdHorizontal then
    Result.X := 2 * AxisCenter.X - Point.X
  else
    Result.Y := 2 * AxisCenter.Y - Point.Y;
end;

procedure ReflectBoundsCenter(var Bounds: TRectF;
  const AxisCenter: TPointF; Direction: TVectArtFlipDirection);
var
  Center: TPointF;
  NewCenter: TPointF;
begin
  Center := Bounds.CenterPoint;
  NewCenter := ReflectPoint(Center, AxisCenter, Direction);
  Bounds.Offset(NewCenter.X - Center.X, NewCenter.Y - Center.Y);
end;

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

function CanFlipVectArtSelection(Document: TVectArtDocument): Boolean;
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

procedure AddRectangleFlip(Command: TVectArtCompoundCommand;
  Document: TVectArtDocument; Index: Integer; const AxisCenter: TPointF;
  Direction: TVectArtFlipDirection);
var
  Layer: TVectArtRectangleLayer;
  NewBounds: TRectF;
begin
  Layer := TVectArtRectangleLayer(Document[Index]);
  NewBounds := Layer.Bounds;
  ReflectBoundsCenter(NewBounds, AxisCenter, Direction);
  Command.Add(TVectArtBoundsCommand.Create(Document, [Index],
    [Layer.Bounds], [NewBounds]));
  Command.Add(TVectArtRotationCommand.Create(Document, Index,
    Layer.RotationDegrees, -Layer.RotationDegrees));
end;

procedure AddTextFlip(Command: TVectArtCompoundCommand;
  Document: TVectArtDocument; Index: Integer; const AxisCenter: TPointF;
  Direction: TVectArtFlipDirection);
var
  AfterData: TVectArtTextData;
  BeforeData: TVectArtTextData;
begin
  BeforeData := CaptureVectArtTextData(
    TVectArtTextLayer(Document[Index]));
  AfterData := BeforeData;
  ReflectBoundsCenter(AfterData.Bounds, AxisCenter, Direction);
  AfterData.RotationDegrees := -AfterData.RotationDegrees;
  if Direction = vfdHorizontal then
    AfterData.FlipHorizontal := not AfterData.FlipHorizontal
  else
    AfterData.FlipVertical := not AfterData.FlipVertical;
  Command.Add(TVectArtTextDataCommand.Create(Document, Index,
    BeforeData, AfterData));
end;

procedure AddLineFlip(Command: TVectArtCompoundCommand;
  Document: TVectArtDocument; Index: Integer; const AxisCenter: TPointF;
  Direction: TVectArtFlipDirection);
var
  Layer: TVectArtLineLayer;
begin
  Layer := TVectArtLineLayer(Document[Index]);
  Command.Add(TVectArtLinePointsCommand.Create(Document, Index,
    Layer.StartPoint, Layer.EndPoint,
    ReflectPoint(Layer.StartPoint, AxisCenter, Direction),
    ReflectPoint(Layer.EndPoint, AxisCenter, Direction)));
end;

procedure AddPathFlip(Command: TVectArtCompoundCommand;
  Document: TVectArtDocument; Index: Integer; const AxisCenter: TPointF;
  Direction: TVectArtFlipDirection);
var
  I: Integer;
  Layer: TVectArtPathLayer;
  NewPoints: TArray<TPointF>;
begin
  Layer := TVectArtPathLayer(Document[Index]);
  NewPoints := Copy(Layer.Points);
  for I := 0 to High(NewPoints) do
    NewPoints[I] := ReflectPoint(NewPoints[I], AxisCenter, Direction);
  Command.Add(TVectArtPathPointsCommand.Create(Document, Index,
    Layer.Points, NewPoints));
end;

procedure AddImageFlip(Command: TVectArtCompoundCommand;
  Document: TVectArtDocument; Index: Integer; const AxisCenter: TPointF;
  Direction: TVectArtFlipDirection);
var
  I: Integer;
  Layer: TVectArtImageLayer;
  NewPoints: TVectArtImagePoints;
begin
  Layer := TVectArtImageLayer(Document[Index]);
  NewPoints := Layer.Points;
  for I := 0 to High(NewPoints) do
    NewPoints[I] := ReflectPoint(NewPoints[I], AxisCenter, Direction);
  Command.Add(TVectArtImagePointsCommand.Create(Document, Index,
    Layer.Points, NewPoints));
end;

procedure FlipVectArtSelection(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory; Direction: TVectArtFlipDirection);
var
  AxisCenter: TPointF;
  Command: TVectArtCompoundCommand;
  I: Integer;
begin
  if not CanFlipVectArtSelection(Document) then
    Exit;
  AxisCenter := SelectionCenter(Document);
  Command := TVectArtCompoundCommand.Create;
  for I := 1 to Document.LayerCount - 1 do
    if Document.IsLayerSelected(I) then
      if Document[I] is TVectArtRectangleLayer then
        AddRectangleFlip(Command, Document, I, AxisCenter, Direction)
      else if Document[I] is TVectArtTextLayer then
        AddTextFlip(Command, Document, I, AxisCenter, Direction)
      else if Document[I] is TVectArtLineLayer then
        AddLineFlip(Command, Document, I, AxisCenter, Direction)
      else if Document[I] is TVectArtPathLayer then
        AddPathFlip(Command, Document, I, AxisCenter, Direction)
      else if Document[I] is TVectArtImageLayer then
        AddImageFlip(Command, Document, I, AxisCenter, Direction);
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
