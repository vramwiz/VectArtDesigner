// スナップ候補の探索と、吸着理由を示すガイド線の論理座標を生成する。
unit VectArtDesignerSnapGeometry;

interface

uses
  System.Types, VectArtDesignerDocument;

type
  TVectArtDesignerSnapAxis = (slsaX, slsaY, slsaAngle);

  TVectArtDesignerSnapGuide = record
    Axis: TVectArtDesignerSnapAxis; // 一致した座標軸。
    StartPoint: TPointF;         // 一致関係を示す論理座標上の線分始点。
    EndPoint: TPointF;           // 一致関係を示す論理座標上の線分終点。
    TargetBounds: TRectF;        // 他オブジェクトが対象の場合の外接範囲。
    HighlightTarget: Boolean;    // TargetBoundsを強調表示する場合にTrue。
  end;

// 点をキャンバス、他オブジェクト、不可視グリッドへ吸着する。
function SnapVectArtDesignerPoint(Document: TVectArtDocument;
  const PointValue: TPointF; Zoom: Single; ExcludeSelected: Boolean;
  out SnappedPoint: TPointF;
  out Guides: TArray<TVectArtDesignerSnapGuide>): Boolean;

// 選択レイヤー内の移動対象以外の頂点を優先候補へ加えて点を吸着する。
function SnapVectArtDesignerPointWithCandidates(Document: TVectArtDocument;
  const PointValue: TPointF; Zoom: Single; ExcludeSelected: Boolean;
  const CandidatePoints: TArray<TPointF>; out SnappedPoint: TPointF;
  out Guides: TArray<TVectArtDesignerSnapGuide>): Boolean;

// 移動前の外接範囲を基準に、移動量を各辺と中心の候補へ吸着する。
function SnapVectArtDesignerMove(Document: TVectArtDocument;
  const MovingBounds: TRectF; const ProposedDelta: TPointF; Zoom: Single;
  out SnappedDelta: TPointF;
  out Guides: TArray<TVectArtDesignerSnapGuide>): Boolean;

// グループ内部などDocument選択外のレイヤーを除外して移動量を吸着する。
function SnapVectArtDesignerMoveForLayers(Document: TVectArtDocument;
  const MovingBounds: TRectF; const ProposedDelta: TPointF; Zoom: Single;
  const ExcludedLayers: TArray<TVectArtLayer>; out SnappedDelta: TPointF;
  out Guides: TArray<TVectArtDesignerSnapGuide>): Boolean;

// 指定角度が30度系または45度系の主要角度に近い場合、最も近い候補へ吸着する。
function SnapVectArtDesignerAngle(ProposedAngle: Single;
  out SnappedAngle: Single): Boolean;

implementation

uses
  System.Math, VectArtDesignerGeometry, VectArtDesignerBezierGeometry;

const
  SNAP_DISTANCE_PIXELS = 6.0;
  GRID_TARGET_PIXELS = 48.0;

type
  TVectArtDesignerBestSnap = record
    Found: Boolean;
    Adjustment: Single;
    TargetCoordinate: Single;
    SpanMinimum: Single;
    SpanMaximum: Single;
    TargetBounds: TRectF;
    HighlightTarget: Boolean;
  end;

function NormalizeAngleDelta(Value: Single): Single;
begin
  Result := Value;
  while Result > 180 do
    Result := Result - 360;
  while Result < -180 do
    Result := Result + 360;
end;

function SnapVectArtDesignerAngle(ProposedAngle: Single;
  out SnappedAngle: Single): Boolean;
const
  ANGLE_30_INTERVAL = 30.0;
  ANGLE_45_INTERVAL = 45.0;
  ANGLE_TOLERANCE = 5.0;
var
  Adjustment30: Single;
  Adjustment45: Single;
  Candidate30: Single;
  Candidate45: Single;
begin
  Candidate30 := Round(ProposedAngle / ANGLE_30_INTERVAL) *
    ANGLE_30_INTERVAL;
  Candidate45 := Round(ProposedAngle / ANGLE_45_INTERVAL) *
    ANGLE_45_INTERVAL;
  Adjustment30 := NormalizeAngleDelta(Candidate30 - ProposedAngle);
  Adjustment45 := NormalizeAngleDelta(Candidate45 - ProposedAngle);
  if Abs(Adjustment30) < Abs(Adjustment45) then
    SnappedAngle := ProposedAngle + Adjustment30
  else
    SnappedAngle := ProposedAngle + Adjustment45;
  Result := Abs(NormalizeAngleDelta(SnappedAngle - ProposedAngle)) <=
    ANGLE_TOLERANCE;
  if not Result then
    SnappedAngle := ProposedAngle;
end;

procedure ConsiderSnap(var Best: TVectArtDesignerBestSnap;
  SourceCoordinate, TargetCoordinate, Tolerance, SpanMinimum,
  SpanMaximum: Single; const TargetBounds: TRectF;
  HighlightTarget: Boolean);
var
  Adjustment: Single;
begin
  Adjustment := TargetCoordinate - SourceCoordinate;
  if Abs(Adjustment) > Tolerance then
    Exit;
  if Best.Found and (Abs(Best.Adjustment) <= Abs(Adjustment)) then
    Exit;
  Best.Found := True;
  Best.Adjustment := Adjustment;
  Best.TargetCoordinate := TargetCoordinate;
  Best.SpanMinimum := SpanMinimum;
  Best.SpanMaximum := SpanMaximum;
  Best.TargetBounds := TargetBounds;
  Best.HighlightTarget := HighlightTarget;
end;

function GridSpacing(Zoom: Single): Single;
var
  Magnitude: Single;
  Mantissa: Single;
  Wanted: Single;
begin
  Wanted := GRID_TARGET_PIXELS / Max(Zoom, 0.001);
  Magnitude := Power(10, Floor(Log10(Max(Wanted, 0.0001))));
  Mantissa := Wanted / Magnitude;
  if Mantissa < 1.5 then
    Result := Magnitude
  else if Mantissa < 3.5 then
    Result := 2 * Magnitude
  else if Mantissa < 7.5 then
    Result := 5 * Magnitude
  else
    Result := 10 * Magnitude;
end;

function LayerContainsAnyExcluded(Layer: TVectArtLayer;
  const ExcludedLayers: TArray<TVectArtLayer>): Boolean;
var
  Excluded: TVectArtLayer;
begin
  for Excluded in ExcludedLayers do
    if Layer = Excluded then
      Exit(True);
  Result := False;
end;

function TryGetVectArtDesignerLayerBounds(Layer: TVectArtLayer;
  out Bounds: TRectF): Boolean;
var
  I: Integer;
  Image: TVectArtImageLayer;
begin
  Result := True;
  if Layer is TVectArtRectangleLayer then
    Bounds := QuadBounds(RectangleCorners(TVectArtRectangleLayer(Layer).Bounds,
      TVectArtRectangleLayer(Layer).RotationDegrees))
  else if Layer is TVectArtTextLayer then
    Bounds := QuadBounds(RectangleCorners(TVectArtTextLayer(Layer).Bounds,
      TVectArtTextLayer(Layer).RotationDegrees))
  else if Layer is TVectArtLineLayer then
    Bounds := PointsBounds([TVectArtLineLayer(Layer).StartPoint,
      TVectArtLineLayer(Layer).EndPoint])
  else if Layer is TVectArtPathLayer then
    Bounds := PointsBounds(BuildPathDisplayPolyline(TVectArtPathLayer(Layer).Points,
      TVectArtPathLayer(Layer).Bezier, TVectArtPathLayer(Layer).Closed, 16))
  else if Layer is TVectArtImageLayer then
  begin
    Image := TVectArtImageLayer(Layer);
    Bounds := TRectF.Create(Image.Points[0], Image.Points[0]);
    for I := 1 to 3 do
    begin
      Bounds.Left := Min(Bounds.Left, Image.Points[I].X);
      Bounds.Top := Min(Bounds.Top, Image.Points[I].Y);
      Bounds.Right := Max(Bounds.Right, Image.Points[I].X);
      Bounds.Bottom := Max(Bounds.Bottom, Image.Points[I].Y);
    end;
  end
  else
    Result := False;
end;
procedure FindSemanticSnaps(Document: TVectArtDocument;
  const SourceX, SourceY: TArray<Single>; OffsetX, OffsetY, Tolerance: Single;
  ExcludeSelected: Boolean; const ExcludedLayers: TArray<TVectArtLayer>;
  var BestX, BestY: TVectArtDesignerBestSnap);
var
  Bounds: TRectF;
  CanvasBounds: TRectF;
  I: Integer;
  TargetX: array[0..2] of Single;
  TargetY: array[0..2] of Single;

  procedure ConsiderBounds(const TargetBounds: TRectF;
    HighlightTarget: Boolean);
  var
    SourceValue: Single;
    TargetValue: Single;
  begin
    TargetX[0] := TargetBounds.Left;
    TargetX[1] := (TargetBounds.Left + TargetBounds.Right) * 0.5;
    TargetX[2] := TargetBounds.Right;
    TargetY[0] := TargetBounds.Top;
    TargetY[1] := (TargetBounds.Top + TargetBounds.Bottom) * 0.5;
    TargetY[2] := TargetBounds.Bottom;
    for SourceValue in SourceX do
      for TargetValue in TargetX do
        ConsiderSnap(BestX, SourceValue + OffsetX, TargetValue, Tolerance,
          TargetBounds.Top, TargetBounds.Bottom, TargetBounds,
          HighlightTarget);
    for SourceValue in SourceY do
      for TargetValue in TargetY do
        ConsiderSnap(BestY, SourceValue + OffsetY, TargetValue, Tolerance,
          TargetBounds.Left, TargetBounds.Right, TargetBounds,
          HighlightTarget);
  end;

begin
  if (Document = nil) or (Document.CanvasLayer = nil) then
    Exit;
  CanvasBounds := TRectF.Create(0, 0, Document.CanvasLayer.Width, Document.CanvasLayer.Height);
  ConsiderBounds(CanvasBounds, False);
  for I := 1 to Document.LayerCount - 1 do
  begin
    if not Document[I].Visible or
      (ExcludeSelected and Document.IsLayerSelected(I)) or
      LayerContainsAnyExcluded(Document[I], ExcludedLayers) or
      not TryGetVectArtDesignerLayerBounds(Document[I], Bounds) then
      Continue;
    ConsiderBounds(Bounds, True);
  end;
end;

procedure FindGridSnap(const Sources: TArray<Single>; Offset, Tolerance,
  Spacing: Single; var Best: TVectArtDesignerBestSnap);
var
  Source: Single;
  Target: Single;
begin
  if Best.Found then
    Exit;
  for Source in Sources do
  begin
    Target := Round((Source + Offset) / Spacing) * Spacing;
    ConsiderSnap(Best, Source + Offset, Target, Tolerance, MaxSingle,
      -MaxSingle, TRectF.Empty, False);
  end;
end;

procedure FindPointSnaps(const PointValue: TPointF;
  const CandidatePoints: TArray<TPointF>; Tolerance: Single;
  var BestX, BestY: TVectArtDesignerBestSnap);
var
  CandidatePoint: TPointF;
begin
  for CandidatePoint in CandidatePoints do
  begin
    ConsiderSnap(BestX, PointValue.X, CandidatePoint.X, Tolerance,
      CandidatePoint.Y, CandidatePoint.Y, TRectF.Empty, False);
    ConsiderSnap(BestY, PointValue.Y, CandidatePoint.Y, Tolerance,
      CandidatePoint.X, CandidatePoint.X, TRectF.Empty, False);
  end;
end;

function BuildGuide(Axis: TVectArtDesignerSnapAxis;
  const Best: TVectArtDesignerBestSnap; SourceMinimum,
  SourceMaximum, FallbackHalfLength: Single): TVectArtDesignerSnapGuide;
var
  SpanMaximum: Single;
  SpanMinimum: Single;
begin
  Result.Axis := Axis;
  Result.TargetBounds := Best.TargetBounds;
  Result.HighlightTarget := Best.HighlightTarget;
  SpanMinimum := SourceMinimum;
  SpanMaximum := SourceMaximum;
  if Best.SpanMinimum <= Best.SpanMaximum then
  begin
    SpanMinimum := Min(SpanMinimum, Best.SpanMinimum);
    SpanMaximum := Max(SpanMaximum, Best.SpanMaximum);
  end;
  if SameValue(SpanMinimum, SpanMaximum) then
  begin
    SpanMinimum := SpanMinimum - FallbackHalfLength;
    SpanMaximum := SpanMaximum + FallbackHalfLength;
  end;
  if Axis = slsaX then
  begin
    Result.StartPoint := TPointF.Create(Best.TargetCoordinate,
      SpanMinimum);
    Result.EndPoint := TPointF.Create(Best.TargetCoordinate,
      SpanMaximum);
  end
  else
  begin
    Result.StartPoint := TPointF.Create(SpanMinimum,
      Best.TargetCoordinate);
    Result.EndPoint := TPointF.Create(SpanMaximum,
      Best.TargetCoordinate);
  end;
end;

function SnapVectArtDesignerPointCore(Document: TVectArtDocument;
  const PointValue: TPointF; Zoom: Single; ExcludeSelected: Boolean;
  const CandidatePoints: TArray<TPointF>;
  out SnappedPoint: TPointF;
  out Guides: TArray<TVectArtDesignerSnapGuide>): Boolean;
var
  BestX: TVectArtDesignerBestSnap;
  BestY: TVectArtDesignerBestSnap;
  Spacing: Single;
  Tolerance: Single;
begin
  BestX := Default(TVectArtDesignerBestSnap);
  BestY := Default(TVectArtDesignerBestSnap);
  SnappedPoint := PointValue;
  Guides := nil;
  if (Document = nil) or (Zoom <= 0) then
    Exit(False);
  Tolerance := SNAP_DISTANCE_PIXELS / Zoom;
  FindPointSnaps(PointValue, CandidatePoints, Tolerance, BestX, BestY);
  FindSemanticSnaps(Document, [PointValue.X], [PointValue.Y], 0, 0,
    Tolerance, ExcludeSelected, nil, BestX, BestY);
  Spacing := GridSpacing(Zoom);
  FindGridSnap([PointValue.X], 0, Tolerance, Spacing, BestX);
  FindGridSnap([PointValue.Y], 0, Tolerance, Spacing, BestY);
  if BestX.Found then
    SnappedPoint.X := SnappedPoint.X + BestX.Adjustment;
  if BestY.Found then
    SnappedPoint.Y := SnappedPoint.Y + BestY.Adjustment;
  if BestX.Found then
    Guides := Guides + [BuildGuide(slsaX, BestX, SnappedPoint.Y,
      SnappedPoint.Y, 8 / Zoom)];
  if BestY.Found then
    Guides := Guides + [BuildGuide(slsaY, BestY, SnappedPoint.X,
      SnappedPoint.X, 8 / Zoom)];
  Result := Length(Guides) > 0;
end;

function SnapVectArtDesignerPoint(Document: TVectArtDocument;
  const PointValue: TPointF; Zoom: Single; ExcludeSelected: Boolean;
  out SnappedPoint: TPointF;
  out Guides: TArray<TVectArtDesignerSnapGuide>): Boolean;
begin
  Result := SnapVectArtDesignerPointCore(Document, PointValue, Zoom,
    ExcludeSelected, nil, SnappedPoint, Guides);
end;

function SnapVectArtDesignerPointWithCandidates(Document: TVectArtDocument;
  const PointValue: TPointF; Zoom: Single; ExcludeSelected: Boolean;
  const CandidatePoints: TArray<TPointF>; out SnappedPoint: TPointF;
  out Guides: TArray<TVectArtDesignerSnapGuide>): Boolean;
begin
  Result := SnapVectArtDesignerPointCore(Document, PointValue, Zoom,
    ExcludeSelected, CandidatePoints, SnappedPoint, Guides);
end;

function SnapVectArtDesignerMoveCore(Document: TVectArtDocument;
  const MovingBounds: TRectF; const ProposedDelta: TPointF; Zoom: Single;
  const ExcludedLayers: TArray<TVectArtLayer>;
  out SnappedDelta: TPointF;
  out Guides: TArray<TVectArtDesignerSnapGuide>): Boolean;
var
  BestX: TVectArtDesignerBestSnap;
  BestY: TVectArtDesignerBestSnap;
  MovedBounds: TRectF;
  SourceX: TArray<Single>;
  SourceY: TArray<Single>;
  Spacing: Single;
  Tolerance: Single;
begin
  BestX := Default(TVectArtDesignerBestSnap);
  BestY := Default(TVectArtDesignerBestSnap);
  SnappedDelta := ProposedDelta;
  Guides := nil;
  if (Document = nil) or (Zoom <= 0) then
    Exit(False);
  SourceX := [MovingBounds.Left,
    (MovingBounds.Left + MovingBounds.Right) * 0.5, MovingBounds.Right];
  SourceY := [MovingBounds.Top,
    (MovingBounds.Top + MovingBounds.Bottom) * 0.5, MovingBounds.Bottom];
  Tolerance := SNAP_DISTANCE_PIXELS / Zoom;
  FindSemanticSnaps(Document, SourceX, SourceY, ProposedDelta.X,
    ProposedDelta.Y, Tolerance, True, ExcludedLayers, BestX, BestY);
  Spacing := GridSpacing(Zoom);
  FindGridSnap(SourceX, ProposedDelta.X, Tolerance, Spacing, BestX);
  FindGridSnap(SourceY, ProposedDelta.Y, Tolerance, Spacing, BestY);
  if BestX.Found then
    SnappedDelta.X := SnappedDelta.X + BestX.Adjustment;
  if BestY.Found then
    SnappedDelta.Y := SnappedDelta.Y + BestY.Adjustment;
  MovedBounds := MovingBounds;
  MovedBounds.Offset(SnappedDelta.X, SnappedDelta.Y);
  if BestX.Found then
    Guides := Guides + [BuildGuide(slsaX, BestX, MovedBounds.Top,
      MovedBounds.Bottom, 8 / Zoom)];
  if BestY.Found then
    Guides := Guides + [BuildGuide(slsaY, BestY, MovedBounds.Left,
      MovedBounds.Right, 8 / Zoom)];
  Result := Length(Guides) > 0;
end;

function SnapVectArtDesignerMove(Document: TVectArtDocument;
  const MovingBounds: TRectF; const ProposedDelta: TPointF; Zoom: Single;
  out SnappedDelta: TPointF;
  out Guides: TArray<TVectArtDesignerSnapGuide>): Boolean;
begin
  Result := SnapVectArtDesignerMoveCore(Document, MovingBounds, ProposedDelta,
    Zoom, nil, SnappedDelta, Guides);
end;

function SnapVectArtDesignerMoveForLayers(Document: TVectArtDocument;
  const MovingBounds: TRectF; const ProposedDelta: TPointF; Zoom: Single;
  const ExcludedLayers: TArray<TVectArtLayer>; out SnappedDelta: TPointF;
  out Guides: TArray<TVectArtDesignerSnapGuide>): Boolean;
begin
  Result := SnapVectArtDesignerMoveCore(Document, MovingBounds, ProposedDelta,
    Zoom, ExcludedLayers, SnappedDelta, Guides);
end;

end.
