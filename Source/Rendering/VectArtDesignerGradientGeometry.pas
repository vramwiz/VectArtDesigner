// 線形グラデーションの正規化座標を計算する。描画とSVGで同じ色の到達位置を使う。
unit VectArtDesignerGradientGeometry;
interface
uses System.Types;
procedure LinearGradientEndpoints(Angle: Integer; out StartPoint, EndPoint: TPointF);
implementation
uses System.Math;
procedure LinearGradientEndpoints(Angle: Integer; out StartPoint, EndPoint: TPointF);
var DX,DY,Extent: Single;
begin
  DX := Cos(DegToRad(Angle mod 360)); DY := Sin(DegToRad(Angle mod 360));
  // 単位矩形の全体を投影し、斜め方向でも両端の色が角へ届くようにする。
  Extent := (Abs(DX)+Abs(DY))/2;
  StartPoint := PointF(0.5-DX*Extent,0.5-DY*Extent);
  EndPoint := PointF(0.5+DX*Extent,0.5+DY*Extent);
end;
end.