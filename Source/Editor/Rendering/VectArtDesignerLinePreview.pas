// 作図中の直線プレビューをGDI／Direct2Dへ同じ線種と端点形状で描画する。
// Documentや入力状態は持たず、確定前表示に必要な画面座標だけを受け取る。
unit VectArtDesignerLinePreview;

interface

uses
  System.Types, Vcl.Direct2D, Vcl.Graphics, VectArtDesignerDocument;

procedure DrawStyledPreviewLine(Target: TCanvas; const StartPoint,
  EndPoint: TPoint; Color: TColor; Width: Single;
  Style: TVectArtStrokeStyle; LineCap: TVectArtLineCap;
  AntiAlias: Boolean; StartMarker, EndMarker: TVectArtLineMarker;
  StartMarkerSize, EndMarkerSize: Single); overload;
procedure DrawStyledPreviewLine(Target: TDirect2DCanvas;
  const StartPoint, EndPoint: TPoint; Color: TColor; Width: Single;
  Style: TVectArtStrokeStyle; LineCap: TVectArtLineCap;
  AntiAlias: Boolean; StartMarker, EndMarker: TVectArtLineMarker;
  StartMarkerSize, EndMarkerSize: Single); overload;

implementation

uses
  System.Math, Winapi.D2D1, VectArtDesignerGeometry;

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
  StartMarkerSize, EndMarkerSize: Single);
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
  // GDIには形状単位のアンチエイリアス切替がないため、引数はDirect2D版とのAPI統一に使う。
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
    if Length(MarkerPoints) < 2 then
      Continue;
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
  StartMarkerSize, EndMarkerSize: Single);
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
    if Length(MarkerPoints) < 2 then
      Continue;
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
  // 後続の選択枠などが高品質描画へ戻ることを呼出側へ要求しない。
  Target.RenderTarget.SetAntialiasMode(D2D1_ANTIALIAS_MODE_PER_PRIMITIVE);
end;

end.
