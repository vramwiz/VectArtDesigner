// 提供MIFのvector effect shadow属性と、影を含む画像の配置を変換する。
unit VectArtDesignerMifShadow;
interface
uses System.SysUtils, System.Types, VectArtDesignerDocument;
function ReadMifShadow(const Png: TBytes): TVectArtShadow;
procedure WriteMifShadow(var Png: TBytes; const Shadow: TVectArtShadow);
procedure ReadShadowRectangleGeometry(const Png: TBytes; var Data: TVectArtRectangleData);
function CreateShadowRaster(Layer: TVectArtLayer; out Bounds: TRectF): TBytes;
implementation
uses System.Math, Vcl.Graphics, VectArtDesignerMifPngMetadata,
  VectArtDesignerMifRaster, VectArtDesignerRenderer, VectArtDesignerGeometry,
  VectArtDesignerBezierGeometry, VectArtDesignerObjectAttributes, VectArtDesignerShadowPaint;
function ReadMifShadow(const Png: TBytes): TVectArtShadow;
var Kind: string; V: Int32;
begin
  Result := Default(TVectArtShadow);
  if not TryReadPngString(Png,'waDA','vector effect object type',Kind) or (Kind<>'shadow') then Exit;
  Result.Enabled := True;
  if TryReadPngInteger(Png,'vector effect color',V) then Result.Color := TColor(V);
  if TryReadPngInteger(Png,'vector effect level',V) then Result.Blur := EnsureRange(V,0,100);
  if TryReadPngInteger(Png,'vector effect offset x',V) then Result.OffsetX := EnsureRange(V,-10000,10000);
  if TryReadPngInteger(Png,'vector effect offset y',V) then Result.OffsetY := EnsureRange(V,-10000,10000);
end;
procedure WriteMifShadow(var Png: TBytes; const Shadow: TVectArtShadow);
begin
  if not Shadow.Enabled then
  begin AddWadaString(Png,'vector effect object type','none'); Exit; end;
  AddWadaString(Png,'vector effect object type','shadow');
  AddWadaInteger(Png,'vector effect level',Shadow.Blur);
  AddWadaInteger(Png,'vector effect color',ColorToRGB(Shadow.Color));
  AddWadaInteger(Png,'vector effect offset x',Shadow.OffsetX);
  AddWadaInteger(Png,'vector effect offset y',Shadow.OffsetY);
  AddWadaInteger(Png,'vector effect direction',0);
end;
procedure ReadShadowRectangleGeometry(const Png: TBytes; var Data: TVectArtRectangleData);
var L,T,R,B: Int32; A,MB,C,D,E,F: Double; P1,P2,P3,P4,Center: TPointF; W,H: Single;
begin
  if not Data.Shadow.Enabled then Exit;
  // image positionは影の余白込みなので、本体はoriginal positionとmatrixから復元する。
  if not TryReadPngInteger(Png,'vector original position1 x',L) or
    not TryReadPngInteger(Png,'vector original position1 y',T) or
    not TryReadPngInteger(Png,'vector original position3 x',R) or
    not TryReadPngInteger(Png,'vector original position3 y',B) then Exit;
  A:=1; MB:=0; C:=0; D:=1; E:=0; F:=0;
  TryReadPngDouble(Png,'vector matrix a',A); TryReadPngDouble(Png,'vector matrix b',MB);
  TryReadPngDouble(Png,'vector matrix c',C); TryReadPngDouble(Png,'vector matrix d',D);
  TryReadPngDouble(Png,'vector matrix e',E); TryReadPngDouble(Png,'vector matrix f',F);
  P1:=PointF(A*L+C*T+E,MB*L+D*T+F); P2:=PointF(A*R+C*T+E,MB*R+D*T+F);
  P3:=PointF(A*R+C*B+E,MB*R+D*B+F); P4:=PointF(A*L+C*B+E,MB*L+D*B+F);
  Center:=PointF((P1.X+P3.X)*0.5,(P1.Y+P3.Y)*0.5);
  W:=Hypot(P2.X-P1.X,P2.Y-P1.Y)+1; H:=Hypot(P4.X-P1.X,P4.Y-P1.Y)+1;
  Data.RotationDegrees:=RadToDeg(ArcTan2(P2.Y-P1.Y,P2.X-P1.X));
  if Abs(Data.RotationDegrees)<0.001 then Data.Bounds:=RectF(P1.X,P1.Y,P1.X+W,P1.Y+H)
  else Data.Bounds:=RectF(Center.X+0.5-W*0.5,Center.Y+0.5-H*0.5,Center.X+0.5+W*0.5,Center.Y+0.5+H*0.5);
end;
function CreateShadowRaster(Layer: TVectArtLayer; out Bounds: TRectF): TBytes;
var Doc: TVectArtDocument; Buffer: TVectArtRenderBuffer; R: TVectArtRectangleData;
  P: TVectArtPathData; A: TVectArtObjectAttributes; W,H: Integer;
begin
  Doc:=TVectArtDocument.Create; Buffer:=TVectArtRenderBuffer.Create;
  try
    A:=CaptureVectArtObjectAttributes(Layer);
    // レイヤー不透明度はimage alphaで保存するため、埋込画像では重ねて適用しない。
    A.Opacity:=1;
    if Layer is TVectArtRectangleLayer then
    begin
      R:=Default(TVectArtRectangleData); R.Bounds:=TVectArtRectangleLayer(Layer).Bounds;
      R.Shape:=TVectArtRectangleLayer(Layer).Shape; R.RotationDegrees:=TVectArtRectangleLayer(Layer).RotationDegrees;
      R.Visible:=True; ApplyVectArtObjectAttributes(A,R); Doc.InsertRectangle(1,R);
      Bounds:=QuadBounds(RectangleCorners(R.Bounds,R.RotationDegrees));
    end
    else
    begin
      P:=Default(TVectArtPathData); P.Points:=Copy(TVectArtPathLayer(Layer).Points);
      P.Closed:=TVectArtPathLayer(Layer).Closed; P.Bezier:=TVectArtPathLayer(Layer).Bezier;
      P.Visible:=True; ApplyVectArtObjectAttributes(A,P); Doc.InsertPath(1,P);
      Bounds:=PointsBounds(BuildPathDisplayPolyline(P.Points,P.Bezier,P.Closed,16));
    end;
    Bounds.Inflate(A.StrokeWidth*0.5+1,A.StrokeWidth*0.5+1);
    Bounds:=ShadowBounds(Bounds,Layer.Shadow);
    Bounds:=RectF(Floor(Bounds.Left),Floor(Bounds.Top),Ceil(Bounds.Right),Ceil(Bounds.Bottom));
    W:=Ceil(Bounds.Width); H:=Ceil(Bounds.Height);
    RenderVectArtDocumentRegion(Doc,Buffer,W,H,Bounds,VECTART_NO_GROUP,0,False);
    Result:=EncodeRgba(Buffer.Data,W,H);
    // image positionの右下はPNG最終画素の包含座標。
    Bounds.Right:=Bounds.Right-1; Bounds.Bottom:=Bounds.Bottom-1;
  finally Buffer.Free; Doc.Free; end;
end;
end.
