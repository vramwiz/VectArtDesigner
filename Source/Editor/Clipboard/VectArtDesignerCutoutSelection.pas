// Maintains the temporary raster-copy region independently from Document selection.
// Coordinates are stored in canvas space so zoom and pan never alter the copied area.
unit VectArtDesignerCutoutSelection;

interface

uses
  System.Classes, System.Types, Vcl.Controls, VectArtDesignerEditorState;

type
  TVectArtCutoutSelection = class
  private
    FActive: Boolean;
    FCanvasBounds: TRect;
    FCommitted: Boolean;
    FConfiguredMode: TVectArtCutoutMode;
    FCurrentPoint: TPointF;
    FEditorState: TVectArtEditorState;
    FModeKnown: Boolean;
    FPoints: TArray<TPointF>;
    FStartPoint: TPointF;
    FZoom: Single;
    function ClampScreenPoint(X, Y: Integer): TPoint;
    function LogicalPoint(const Value: TPoint): TPointF;
    procedure StartDrag(const Value: TPointF);
  public
    procedure Cancel;
    procedure Configure(AEditorState: TVectArtEditorState;
      const ACanvasBounds: TRect; AZoom: Single);
    function FinishPolygon: Boolean;
    function LogicalOutline: TArray<TPointF>;
    function MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer): Boolean;
    function MouseMove(Shift: TShiftState; X, Y: Integer): Boolean;
    function MouseUp(Button: TMouseButton; X, Y: Integer): Boolean;
    function ScreenBounds: TRect;
    function ScreenOutline: TArray<TPoint>;
    property Active: Boolean read FActive;
    property Committed: Boolean read FCommitted;
    property Mode: TVectArtCutoutMode read FConfiguredMode;
  end;

implementation

uses
  System.Math, VectArtDesignerFreehandGeometry;

const
  MIN_DRAG_SIZE = 2;
  POLYGON_CLOSE_DISTANCE = 8;
  FREEHAND_SAMPLE_DISTANCE = 2;
  FREEHAND_SIMPLIFY_TOLERANCE = 1.5;

procedure TVectArtCutoutSelection.Cancel;
begin
  FActive := False;
  FCommitted := False;
  FPoints := nil;
end;

function TVectArtCutoutSelection.ClampScreenPoint(X, Y: Integer): TPoint;
begin
  Result.X := EnsureRange(X, FCanvasBounds.Left, FCanvasBounds.Right);
  Result.Y := EnsureRange(Y, FCanvasBounds.Top, FCanvasBounds.Bottom);
end;

procedure TVectArtCutoutSelection.Configure(
  AEditorState: TVectArtEditorState; const ACanvasBounds: TRect;
  AZoom: Single);
begin
  if (AEditorState = nil) or (AEditorState.CurrentTool <> vetCutout) then
  begin
    if FActive or FCommitted then
      Cancel;
    FModeKnown := False;
  end
  else if FModeKnown and (FConfiguredMode <> AEditorState.CutoutMode) then
    Cancel;
  FEditorState := AEditorState;
  FCanvasBounds := ACanvasBounds;
  FZoom := AZoom;
  if (AEditorState <> nil) and (AEditorState.CurrentTool = vetCutout) then
  begin
    FConfiguredMode := AEditorState.CutoutMode;
    FModeKnown := True;
  end;
end;

function TVectArtCutoutSelection.FinishPolygon: Boolean;
begin
  Result := FActive and (FConfiguredMode = vcmPolygon) and
    (Length(FPoints) >= 3);
  if not Result then
    Exit;
  FActive := False;
  FCommitted := True;
end;

function TVectArtCutoutSelection.LogicalOutline: TArray<TPointF>;
var
  LeftValue: Single;
  TopValue: Single;
  RightValue: Single;
  BottomValue: Single;
begin
  if not (FActive or FCommitted) then
    Exit(nil);
  if FConfiguredMode in [vcmRectangle, vcmEllipse] then
  begin
    LeftValue := Min(FStartPoint.X, FCurrentPoint.X);
    TopValue := Min(FStartPoint.Y, FCurrentPoint.Y);
    RightValue := Max(FStartPoint.X, FCurrentPoint.X);
    BottomValue := Max(FStartPoint.Y, FCurrentPoint.Y);
    Result := [PointF(LeftValue, TopValue), PointF(RightValue, TopValue),
      PointF(RightValue, BottomValue), PointF(LeftValue, BottomValue)];
  end
  else
    Result := Copy(FPoints);
end;

function TVectArtCutoutSelection.LogicalPoint(const Value: TPoint): TPointF;
begin
  if FZoom <= 0 then
    Exit(TPointF.Zero);
  Result := PointF((Value.X - FCanvasBounds.Left) / FZoom,
    (Value.Y - FCanvasBounds.Top) / FZoom);
end;

function TVectArtCutoutSelection.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer): Boolean;
var
  PointValue: TPointF;
  ScreenPointValue: TPoint;
begin
  Result := (Button = mbLeft) and FModeKnown and (FZoom > 0) and
    PtInRect(FCanvasBounds, Point(X, Y));
  if not Result then
    Exit;
  ScreenPointValue := ClampScreenPoint(X, Y);
  PointValue := LogicalPoint(ScreenPointValue);
  if FConfiguredMode = vcmPolygon then
  begin
    if (ssDouble in Shift) and (Length(FPoints) >= 3) then
    begin
      FinishPolygon;
      Exit;
    end;
    if not FActive then
    begin
      Cancel;
      FActive := True;
      FPoints := [PointValue];
    end
    else if (Length(FPoints) >= 3) and
      (Hypot((PointValue.X - FPoints[0].X) * FZoom,
        (PointValue.Y - FPoints[0].Y) * FZoom) <= POLYGON_CLOSE_DISTANCE) then
      FinishPolygon
    else
      FPoints := FPoints + [PointValue];
    FCurrentPoint := PointValue;
    Exit;
  end;
  StartDrag(PointValue);
end;

function TVectArtCutoutSelection.MouseMove(Shift: TShiftState;
  X, Y: Integer): Boolean;
var
  PointValue: TPointF;
begin
  Result := FActive;
  if not Result then
    Exit;
  PointValue := LogicalPoint(ClampScreenPoint(X, Y));
  FCurrentPoint := PointValue;
  if FConfiguredMode = vcmPolygon then
    Exit;
  if not (ssLeft in Shift) then
  begin
    Cancel;
    Exit;
  end;
  if (FConfiguredMode = vcmFreehand) and
    (Hypot((PointValue.X - FPoints[High(FPoints)].X) * FZoom,
      (PointValue.Y - FPoints[High(FPoints)].Y) * FZoom) >=
      FREEHAND_SAMPLE_DISTANCE) then
    FPoints := FPoints + [PointValue];
end;

function TVectArtCutoutSelection.MouseUp(Button: TMouseButton;
  X, Y: Integer): Boolean;
var
  ScreenPoints: TArray<TPoint>;
  I: Integer;
begin
  Result := (Button = mbLeft) and FActive and
    (FConfiguredMode <> vcmPolygon);
  if not Result then
    Exit;
  FCurrentPoint := LogicalPoint(ClampScreenPoint(X, Y));
  if FConfiguredMode = vcmFreehand then
  begin
    if Hypot((FCurrentPoint.X - FPoints[High(FPoints)].X) * FZoom,
      (FCurrentPoint.Y - FPoints[High(FPoints)].Y) * FZoom) >=
      FREEHAND_SAMPLE_DISTANCE then
      FPoints := FPoints + [FCurrentPoint];
    SetLength(ScreenPoints, Length(FPoints));
    for I := 0 to High(FPoints) do
      ScreenPoints[I] := Point(Round(FPoints[I].X * FZoom),
        Round(FPoints[I].Y * FZoom));
    ScreenPoints := SimplifyFreehandPolyline(ScreenPoints,
      FREEHAND_SIMPLIFY_TOLERANCE);
    SetLength(FPoints, Length(ScreenPoints));
    for I := 0 to High(ScreenPoints) do
      FPoints[I] := PointF(ScreenPoints[I].X / FZoom,
        ScreenPoints[I].Y / FZoom);
    FCommitted := Length(FPoints) >= 3;
  end
  else
    FCommitted := (Abs(FCurrentPoint.X - FStartPoint.X) * FZoom >=
      MIN_DRAG_SIZE) and (Abs(FCurrentPoint.Y - FStartPoint.Y) * FZoom >=
      MIN_DRAG_SIZE);
  FActive := False;
  if not FCommitted then
    FPoints := nil;
end;

function TVectArtCutoutSelection.ScreenBounds: TRect;
var
  Outline: TArray<TPoint>;
  I: Integer;
begin
  Outline := ScreenOutline;
  if Length(Outline) = 0 then
    Exit(TRect.Empty);
  Result := Rect(Outline[0].X, Outline[0].Y, Outline[0].X,
    Outline[0].Y);
  for I := 1 to High(Outline) do
  begin
    Result.Left := Min(Result.Left, Outline[I].X);
    Result.Top := Min(Result.Top, Outline[I].Y);
    Result.Right := Max(Result.Right, Outline[I].X);
    Result.Bottom := Max(Result.Bottom, Outline[I].Y);
  end;
end;

function TVectArtCutoutSelection.ScreenOutline: TArray<TPoint>;
var
  I: Integer;
  Logical: TArray<TPointF>;
begin
  Logical := LogicalOutline;
  SetLength(Result, Length(Logical));
  for I := 0 to High(Logical) do
    Result[I] := Point(Round(FCanvasBounds.Left + Logical[I].X * FZoom),
      Round(FCanvasBounds.Top + Logical[I].Y * FZoom));
  if (FConfiguredMode = vcmRectangle) and (Length(Result) > 0) then
    Result := Result + [Result[0]]
  else if (FConfiguredMode in [vcmPolygon, vcmFreehand]) and
    (Length(Result) > 0) then
  begin
    if FActive and (FConfiguredMode = vcmPolygon) then
      Result := Result + [Point(Round(FCanvasBounds.Left +
        FCurrentPoint.X * FZoom), Round(FCanvasBounds.Top +
        FCurrentPoint.Y * FZoom)), Result[0]]
    else if FCommitted then
      Result := Result + [Result[0]];
  end;
end;

procedure TVectArtCutoutSelection.StartDrag(const Value: TPointF);
begin
  Cancel;
  FActive := True;
  FStartPoint := Value;
  FCurrentPoint := Value;
  if FConfiguredMode = vcmFreehand then
    FPoints := [Value];
end;

end.
