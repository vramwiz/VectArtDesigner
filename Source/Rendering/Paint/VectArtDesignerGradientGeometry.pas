// 線形グラデーションの正規化座標を計算する。描画とSVGで同じ色の到達位置を使う。
unit VectArtDesignerGradientGeometry;
interface
uses System.Types;
procedure LinearGradientEndpoints(Angle: Integer; out StartPoint, EndPoint: TPointF);
procedure SpectrumGradientEndpoints(Angle: Integer; const Bounds: TRectF;
  out StartPoint,EndPoint: TPointF);
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
procedure SpectrumGradientEndpoints(Angle: Integer; const Bounds: TRectF;
  out StartPoint,EndPoint: TPointF);
var DX,DY,Extent: Single; Center: TPointF;
begin
  // 元MIFは実座標の投影距離で色相を一周させる。整数画素中心も合わせる。
  DX := Cos(DegToRad(Angle mod 360)); DY := Sin(DegToRad(Angle mod 360));
  Extent := (Abs(DX)*Bounds.Width+Abs(DY)*Bounds.Height)*0.5;
  Center := PointF((Bounds.Left+Bounds.Right)*0.5+0.5,(Bounds.Top+Bounds.Bottom)*0.5+0.5);
  StartPoint := PointF(Center.X-DX*Extent,Center.Y-DY*Extent);
  EndPoint := PointF(Center.X+DX*Extent,Center.Y+DY*Extent);
end;
end.