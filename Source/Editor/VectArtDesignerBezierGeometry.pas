// アンカー列を通る滑らかな3次ベジェ曲線の制御点と描画用点列を生成する。
// Documentのアンカーを正本とし、分割点は描画・当たり判定・互換出力だけに使用する。
unit VectArtDesignerBezierGeometry;

interface

uses
  System.Types;

procedure SmoothBezierSegmentControls(const Anchors: TArray<TPointF>;
  Closed: Boolean; SegmentIndex: Integer; out Control1, Control2: TPointF);
function BuildSmoothBezierPolyline(const Anchors: TArray<TPointF>;
  Closed: Boolean; StepsPerSegment: Integer): TArray<TPointF>;
function BuildPathDisplayPolyline(const Anchors: TArray<TPointF>;
  Bezier, Closed: Boolean; StepsPerSegment: Integer): TArray<TPointF>;
function BuildSmoothBezierPreview(const Anchors: TArray<TPoint>;
  StepsPerSegment: Integer): TArray<TPoint>;

implementation

uses
  System.Math;

function CubicPoint(const StartPoint, Control1, Control2,
  EndPoint: TPointF; Parameter: Single): TPointF;
var
  Inverse: Single;
begin
  Inverse := 1.0 - Parameter;
  Result.X := Inverse * Inverse * Inverse * StartPoint.X +
    3.0 * Inverse * Inverse * Parameter * Control1.X +
    3.0 * Inverse * Parameter * Parameter * Control2.X +
    Parameter * Parameter * Parameter * EndPoint.X;
  Result.Y := Inverse * Inverse * Inverse * StartPoint.Y +
    3.0 * Inverse * Inverse * Parameter * Control1.Y +
    3.0 * Inverse * Parameter * Parameter * Control2.Y +
    Parameter * Parameter * Parameter * EndPoint.Y;
end;

procedure SmoothBezierSegmentControls(const Anchors: TArray<TPointF>;
  Closed: Boolean; SegmentIndex: Integer; out Control1, Control2: TPointF);
var
  EndPoint: TPointF;
  NextPoint: TPointF;
  PreviousPoint: TPointF;
  StartPoint: TPointF;
begin
  StartPoint := Anchors[SegmentIndex];
  EndPoint := Anchors[(SegmentIndex + 1) mod Length(Anchors)];
  if Closed then
  begin
    PreviousPoint := Anchors[(SegmentIndex + Length(Anchors) - 1) mod
      Length(Anchors)];
    NextPoint := Anchors[(SegmentIndex + 2) mod Length(Anchors)];
  end
  else
  begin
    if SegmentIndex = 0 then
      PreviousPoint := StartPoint
    else
      PreviousPoint := Anchors[SegmentIndex - 1];
    if SegmentIndex + 2 > High(Anchors) then
      NextPoint := EndPoint
    else
      NextPoint := Anchors[SegmentIndex + 2];
  end;
  Control1 := TPointF.Create(
    StartPoint.X + (EndPoint.X - PreviousPoint.X) / 6.0,
    StartPoint.Y + (EndPoint.Y - PreviousPoint.Y) / 6.0);
  Control2 := TPointF.Create(
    EndPoint.X - (NextPoint.X - StartPoint.X) / 6.0,
    EndPoint.Y - (NextPoint.Y - StartPoint.Y) / 6.0);
end;

function BuildSmoothBezierPolyline(const Anchors: TArray<TPointF>;
  Closed: Boolean; StepsPerSegment: Integer): TArray<TPointF>;
var
  Control1: TPointF;
  Control2: TPointF;
  EndPoint: TPointF;
  I: Integer;
  OutputIndex: Integer;
  SegmentCount: Integer;
  StartPoint: TPointF;
  Step: Integer;
begin
  if Length(Anchors) = 0 then
    Exit(nil);
  if Length(Anchors) = 1 then
    Exit(Copy(Anchors));
  StepsPerSegment := Max(StepsPerSegment, 1);
  SegmentCount := High(Anchors);
  if Closed then
    Inc(SegmentCount);
  SetLength(Result, 1 + SegmentCount * StepsPerSegment);
  Result[0] := Anchors[0];
  OutputIndex := 1;
  for I := 0 to SegmentCount - 1 do
  begin
    StartPoint := Anchors[I];
    EndPoint := Anchors[(I + 1) mod Length(Anchors)];
    SmoothBezierSegmentControls(Anchors, Closed, I, Control1, Control2);
    for Step := 1 to StepsPerSegment do
    begin
      Result[OutputIndex] := CubicPoint(StartPoint, Control1, Control2,
        EndPoint, Step / StepsPerSegment);
      Inc(OutputIndex);
    end;
  end;
end;

function BuildPathDisplayPolyline(const Anchors: TArray<TPointF>;
  Bezier, Closed: Boolean; StepsPerSegment: Integer): TArray<TPointF>;
begin
  if Bezier then
    Result := BuildSmoothBezierPolyline(Anchors, Closed, StepsPerSegment)
  else
    Result := Copy(Anchors);
end;

function BuildSmoothBezierPreview(const Anchors: TArray<TPoint>;
  StepsPerSegment: Integer): TArray<TPoint>;
var
  FloatAnchors: TArray<TPointF>;
  FloatPoints: TArray<TPointF>;
  I: Integer;
begin
  SetLength(FloatAnchors, Length(Anchors));
  for I := 0 to High(Anchors) do
    FloatAnchors[I] := TPointF.Create(Anchors[I].X, Anchors[I].Y);
  FloatPoints := BuildSmoothBezierPolyline(FloatAnchors, False,
    StepsPerSegment);
  SetLength(Result, Length(FloatPoints));
  for I := 0 to High(FloatPoints) do
    Result[I] := Point(Round(FloatPoints[I].X), Round(FloatPoints[I].Y));
end;

end.
