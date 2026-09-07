// 手書き入力の画面座標サンプリングと頂点整理を担当する。
// 入力密度に依存する冗長点だけを除去し、両端と許容誤差を超える折れ角は維持する。
unit VectArtDesignerFreehandGeometry;

interface

uses
  System.Types;

function FreehandPointIsFarEnough(const PreviousPoint,
  NextPoint: TPoint; MinimumDistance: Single): Boolean;
function SimplifyFreehandPolyline(const Points: TArray<TPoint>;
  Tolerance: Single): TArray<TPoint>;

implementation

uses
  System.Math;

function DistanceToSegment(const PointValue, StartPoint,
  EndPoint: TPoint): Single;
var
  DX: Single;
  DY: Single;
  Projection: Single;
  SegmentLengthSquared: Single;
begin
  DX := EndPoint.X - StartPoint.X;
  DY := EndPoint.Y - StartPoint.Y;
  SegmentLengthSquared := DX * DX + DY * DY;
  if SegmentLengthSquared > 0 then
    Projection := EnsureRange(((PointValue.X - StartPoint.X) * DX +
      (PointValue.Y - StartPoint.Y) * DY) / SegmentLengthSquared, 0.0, 1.0)
  else
    Projection := 0.0;
  Result := Hypot(PointValue.X - (StartPoint.X + Projection * DX),
    PointValue.Y - (StartPoint.Y + Projection * DY));
end;

function FreehandPointIsFarEnough(const PreviousPoint,
  NextPoint: TPoint; MinimumDistance: Single): Boolean;
begin
  Result := Hypot(NextPoint.X - PreviousPoint.X,
    NextPoint.Y - PreviousPoint.Y) >= Max(MinimumDistance, 0.0);
end;

function SimplifyFreehandPolyline(const Points: TArray<TPoint>;
  Tolerance: Single): TArray<TPoint>;
var
  Distance: Single;
  FarthestDistance: Single;
  FarthestIndex: Integer;
  FirstIndex: Integer;
  FirstStack: TArray<Integer>;
  I: Integer;
  Keep: TArray<Boolean>;
  LastIndex: Integer;
  LastStack: TArray<Integer>;
  OutputIndex: Integer;
  StackCount: Integer;
begin
  if Length(Points) <= 2 then
    Exit(Copy(Points));
  Tolerance := Max(Tolerance, 0.0);
  SetLength(Keep, Length(Points));
  Keep[0] := True;
  Keep[High(Points)] := True;
  // 再帰を使わず、長い手書き軌跡でも呼出しスタックを消費しない。
  SetLength(FirstStack, Length(Points) * 2);
  SetLength(LastStack, Length(Points) * 2);
  StackCount := 1;
  FirstStack[0] := 0;
  LastStack[0] := High(Points);
  while StackCount > 0 do
  begin
    Dec(StackCount);
    FirstIndex := FirstStack[StackCount];
    LastIndex := LastStack[StackCount];
    FarthestDistance := -1.0;
    FarthestIndex := -1;
    for I := FirstIndex + 1 to LastIndex - 1 do
    begin
      Distance := DistanceToSegment(Points[I], Points[FirstIndex],
        Points[LastIndex]);
      if Distance > FarthestDistance then
      begin
        FarthestDistance := Distance;
        FarthestIndex := I;
      end;
    end;
    if (FarthestIndex < 0) or (FarthestDistance <= Tolerance) then
      Continue;
    Keep[FarthestIndex] := True;
    FirstStack[StackCount] := FirstIndex;
    LastStack[StackCount] := FarthestIndex;
    Inc(StackCount);
    FirstStack[StackCount] := FarthestIndex;
    LastStack[StackCount] := LastIndex;
    Inc(StackCount);
  end;
  SetLength(Result, Length(Points));
  OutputIndex := 0;
  for I := 0 to High(Points) do
    if Keep[I] then
    begin
      Result[OutputIndex] := Points[I];
      Inc(OutputIndex);
    end;
  SetLength(Result, OutputIndex);
end;

end.
