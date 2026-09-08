// MIF画像の配置と数値属性の変換を担当する。座標・線幅の丸めを入出力で統一する。
unit VectArtDesignerMifPlacement;

interface

uses System.SysUtils, System.Types, VectArtDesignerDocument, VectArtDesignerGeometry;
function MifImageCoordinate(Value: Single): Integer;
function MifAlpha(Opacity: Single): Integer;
procedure AddImagePlacementMetadata(var Png: TBytes;
  const Bounds: TRectF; Alpha: Integer; Hidden: Boolean); overload;
procedure AddImagePlacementMetadata(var Png: TBytes;
  const Quad: TVectArtQuad; Alpha: Integer; Hidden: Boolean); overload;
procedure UpdateImagePlacementMetadata(var Png: TBytes;
  const Points: TVectArtImagePoints; Alpha: Integer; Hidden: Boolean);

// 線幅の下限はMIFの図形種別で異なるため、入出力で同じ規則を使う。
function MifPathStrokeWidth(Value: Single): Double;
function MifLineStrokeWidth(Value: Single): Double;

implementation

uses System.Math, VectArtDesignerMifPngMetadata;

function MifImageCoordinate(Value: Single): Integer;
begin
  Result := Round(Value);
end;

procedure AddImagePlacementMetadata(var Png: TBytes;
  const Bounds: TRectF; Alpha: Integer; Hidden: Boolean); overload;
begin
  AddWadaInteger(Png, 'image position1 x', MifImageCoordinate(Bounds.Left));
  AddWadaInteger(Png, 'image position1 y', MifImageCoordinate(Bounds.Top));
  AddWadaInteger(Png, 'image position2 x', MifImageCoordinate(Bounds.Right));
  AddWadaInteger(Png, 'image position2 y', MifImageCoordinate(Bounds.Top));
  AddWadaInteger(Png, 'image position3 x', MifImageCoordinate(Bounds.Right));
  AddWadaInteger(Png, 'image position3 y', MifImageCoordinate(Bounds.Bottom));
  AddWadaInteger(Png, 'image position4 x', MifImageCoordinate(Bounds.Left));
  AddWadaInteger(Png, 'image position4 y', MifImageCoordinate(Bounds.Bottom));
  AddWadaInteger(Png, 'image alpha', EnsureRange(Alpha, 0, 255));
  AddWadaInteger(Png, 'image hidden', Ord(Hidden));
end;

procedure UpdateImagePlacementMetadata(var Png: TBytes;
  const Points: TVectArtImagePoints; Alpha: Integer; Hidden: Boolean);
var
  I: Integer;
begin
  for I := 0 to High(Points) do
  begin
    UpdateWadaInteger(Png, Format('image position%d x', [I + 1]),
      MifImageCoordinate(Points[I].X));
    UpdateWadaInteger(Png, Format('image position%d y', [I + 1]),
      MifImageCoordinate(Points[I].Y));
  end;
  UpdateWadaInteger(Png, 'image alpha', EnsureRange(Alpha, 0, 255));
  UpdateWadaInteger(Png, 'image hidden', Ord(Hidden));
end;

procedure AddImagePlacementMetadata(var Png: TBytes;
  const Quad: TVectArtQuad; Alpha: Integer; Hidden: Boolean); overload;
var
  I: Integer;
begin
  for I := 0 to High(Quad) do
  begin
    AddWadaInteger(Png, Format('image position%d x', [I + 1]),
      MifImageCoordinate(Quad[I].X));
    AddWadaInteger(Png, Format('image position%d y', [I + 1]),
      MifImageCoordinate(Quad[I].Y));
  end;
  AddWadaInteger(Png, 'image alpha', EnsureRange(Alpha, 0, 255));
  AddWadaInteger(Png, 'image hidden', Ord(Hidden));
end;

function MifAlpha(Opacity: Single): Integer;
begin
  Result := EnsureRange(Round(Opacity * 255), 0, 255);
end;


function MifPathStrokeWidth(Value: Single): Double;
begin
  Result := Max(Value, 0.0);
end;

function MifLineStrokeWidth(Value: Single): Double;
begin
  Result := Max(Value, 0.1);
end;

end.
