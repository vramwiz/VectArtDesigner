// 角丸四角の作成時に使う輪郭点列と角丸半径を算出する。
// 作成後は通常のPathとして扱うため、変形時に角丸比率を再計算しない。
unit VectArtDesignerRoundedRectangleGeometry;

interface

uses
  System.Types;

function RoundedRectangleCreationRadius(const Bounds: TRect): Integer;
function BuildRoundedRectanglePathPoints(const Bounds: TRect;
  ArcSteps: Integer = 6): TArray<TPoint>;
function IsRoundedRectanglePathPoints(
  const Points: TArray<TPointF>): Boolean;

implementation

uses
  System.Math;

function IsRoundedRectanglePathPoints(
  const Points: TArray<TPointF>): Boolean;
var
  Bottom: Single;
  I: Integer;
  Left: Single;
  Right: Single;
  Tolerance: Single;
  Top: Single;
  function Near(A, B: Single): Boolean;
  begin
    Result := SameValue(A, B, Tolerance);
  end;
begin
  Result := Length(Points) = 28;
  if not Result then
    Exit;
  Left := Points[0].X;
  Right := Left;
  Top := Points[0].Y;
  Bottom := Top;
  for I := 1 to High(Points) do
  begin
    Left := Min(Left, Points[I].X);
    Right := Max(Right, Points[I].X);
    Top := Min(Top, Points[I].Y);
    Bottom := Max(Bottom, Points[I].Y);
  end;
  Tolerance := Max(Right - Left, Bottom - Top) * 0.0001 + 0.01;
  Result := (Right - Left > Tolerance) and (Bottom - Top > Tolerance) and
    Near(Points[0].Y, Top) and Near(Points[1].Y, Top) and
    Near(Points[7].X, Right) and Near(Points[8].X, Right) and
    Near(Points[14].Y, Bottom) and Near(Points[15].Y, Bottom) and
    Near(Points[21].X, Left) and Near(Points[22].X, Left) and
    Near(Points[0].X, Points[15].X) and
    Near(Points[1].X, Points[14].X) and
    Near(Points[7].Y, Points[22].Y) and
    Near(Points[8].Y, Points[21].Y);
  if not Result then
    Exit;
  // 4つの円弧が同じ巡回方向を保つことも確認し、一般の28点Pathとの誤認を避ける。
  for I := 2 to 7 do
    if (Points[I].X + Tolerance < Points[I - 1].X) or
      (Points[I].Y + Tolerance < Points[I - 1].Y) then
      Exit(False);
  for I := 9 to 14 do
    if (Points[I].X - Tolerance > Points[I - 1].X) or
      (Points[I].Y + Tolerance < Points[I - 1].Y) then
      Exit(False);
  for I := 16 to 21 do
    if (Points[I].X - Tolerance > Points[I - 1].X) or
      (Points[I].Y - Tolerance > Points[I - 1].Y) then
      Exit(False);
  for I := 23 to 27 do
    if (Points[I].X + Tolerance < Points[I - 1].X) or
      (Points[I].Y - Tolerance > Points[I - 1].Y) then
      Exit(False);
  Result := True;
end;

function BuildRoundedRectanglePathPoints(const Bounds: TRect;
  ArcSteps: Integer): TArray<TPoint>;
var
  Angle: Double;
  I: Integer;
  PointCount: Integer;
  Radius: Integer;
  procedure AddPoint(X, Y: Double);
  begin
    SetLength(Result, PointCount + 1);
    Result[PointCount] := Point(Round(X), Round(Y));
    Inc(PointCount);
  end;
begin
  Result := nil;
  Radius := RoundedRectangleCreationRadius(Bounds);
  if Bounds.IsEmpty or (Radius <= 0) or (ArcSteps <= 0) then
    Exit;

  PointCount := 0;
  AddPoint(Bounds.Left + Radius, Bounds.Top);
  AddPoint(Bounds.Right - Radius, Bounds.Top);
  for I := 1 to ArcSteps do
  begin
    Angle := -Pi / 2 + I * Pi / (2 * ArcSteps);
    AddPoint(Bounds.Right - Radius + Cos(Angle) * Radius,
      Bounds.Top + Radius + Sin(Angle) * Radius);
  end;
  AddPoint(Bounds.Right, Bounds.Bottom - Radius);
  for I := 1 to ArcSteps do
  begin
    Angle := I * Pi / (2 * ArcSteps);
    AddPoint(Bounds.Right - Radius + Cos(Angle) * Radius,
      Bounds.Bottom - Radius + Sin(Angle) * Radius);
  end;
  AddPoint(Bounds.Left + Radius, Bounds.Bottom);
  for I := 1 to ArcSteps do
  begin
    Angle := Pi / 2 + I * Pi / (2 * ArcSteps);
    AddPoint(Bounds.Left + Radius + Cos(Angle) * Radius,
      Bounds.Bottom - Radius + Sin(Angle) * Radius);
  end;
  AddPoint(Bounds.Left, Bounds.Top + Radius);
  for I := 1 to ArcSteps - 1 do
  begin
    Angle := Pi + I * Pi / (2 * ArcSteps);
    AddPoint(Bounds.Left + Radius + Cos(Angle) * Radius,
      Bounds.Top + Radius + Sin(Angle) * Radius);
  end;
end;

function RoundedRectangleCreationRadius(const Bounds: TRect): Integer;
begin
  if Bounds.IsEmpty then
    Exit(0);
  // 旧アプリの見た目に合わせ、短辺の制約内で横幅を1:8:1に分ける。
  Result := Min(Max(1, Bounds.Width div 10),
    Min(Bounds.Width div 2, Bounds.Height div 2));
end;

end.
