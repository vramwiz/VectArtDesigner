// SVGのペイント参照と定義を生成する。標準表現のない方式は表示PNGと再編集情報を組み合わせる。
unit VectArtDesignerSvgPaintWriter;

interface

uses System.Types, Vcl.Graphics, VectArtDesignerDocument;
function FillReference(Color: TColor; const Fill: TVectArtFillStyle; Index: Integer): string;
function FillDefinition(Color: TColor; const Fill: TVectArtFillStyle; Index: Integer;
  const Bounds: TRectF; Padding: Single = 0; TextPaint: Boolean = False): string;

implementation

uses System.Classes, System.SysUtils, System.UITypes, System.Skia, System.Math, System.Math.Vectors,
  System.NetEncoding, Winapi.Windows, VectArtDesignerFillPaint,
  VectArtDesignerGradientGeometry, VectArtDesignerSvgPrimitives;

function FillReference(Color: TColor; const Fill: TVectArtFillStyle; Index: Integer): string;
begin
  if Fill.Kind = vfkSolid then Result := SvgColor(Color)
  else Result := Format('url(#vad-fill-%d)',[Index]);
end;
// 標準SVGに対応する塗りがない場合は、表示用PNGと再編集用の2色を保存する。
function RasterFillPng(Color: TColor; const Fill: TVectArtFillStyle;
  const Bounds: TRectF; Stroke: Boolean = False; Padding: Single = 0; TextPaint: Boolean = False): TBytes;
var Pixels: TBytes; Info: TSkImageInfo; Surface: ISkSurface; Paint: ISkPaint;
    W,H: Integer; Scale: Double; Area: TRectF;
begin
  Area := Bounds; Area.Inflate(Padding,Padding);
  Scale := Min(1,2048/Max(1,Max(Area.Width,Area.Height)));
  W := Max(1,Ceil(Area.Width*Scale)); H := Max(1,Ceil(Area.Height*Scale));
  SetLength(Pixels,W*H*4);
  Info := TSkImageInfo.Create(W,H,TSkColorType.RGBA8888,TSkAlphaType.Unpremul);
  Surface := TSkSurface.MakeRasterDirect(Info,@Pixels[0],W*4);
  if Surface = nil then raise EWriteError.Create('Cannot render gradient fill');
  Paint := TSkPaint.Create;
  if Stroke then
  begin
    Surface.Canvas.Scale(W/Max(1,Area.Width),H/Max(1,Area.Height));
    Surface.Canvas.Translate(-Area.Left,-Area.Top);
    if TextPaint then
    begin
      SetTextPaint(Paint,Color,Fill,Bounds.Width,Bounds.Height,Bounds.Width,Bounds.Height,1);
      if Paint.Shader <> nil then
        Paint.Shader := Paint.Shader.MakeWithLocalMatrix(TMatrix.CreateTranslation(Bounds.Left,Bounds.Top));
    end
    else SetStrokePaint(Paint,Color,Fill,Bounds,1,1);
  end
  else SetFillPaint(Paint,Color,Fill,RectF(0,0,W,H),1);
  Surface.Canvas.DrawPaint(Paint); Surface.Flush;
  Result := TSkImageEncoder.Encode(Info,@Pixels[0],W*4,TSkEncodedImageFormat.PNG);
  if Length(Result) = 0 then raise EWriteError.Create('Cannot encode gradient fill');
end;
// 定義IDは塗りに正のレイヤー番号、線に負の番号を使い、両者を独立させる。
function FillDefinition(Color: TColor; const Fill: TVectArtFillStyle; Index: Integer; const Bounds: TRectF; Padding: Single = 0; TextPaint: Boolean = False): string;
var Tag, Attr: string; StartPoint,EndPoint: TPointF; Area: TRectF;
    Colors: TArray<TAlphaColor>; Positions: TArray<Single>; J: Integer; Image: ISkImage;
begin
  Result := '';
  if Fill.Kind = vfkSolid then Exit;
  if TextPaint and (Fill.Kind <> vfkSquare) then
    Exit(FillDefinition(Color,Fill,Index,StrokePaintBounds(Bounds,0,Fill.Kind),Padding,False));
  if Fill.Kind = vfkSpectrum then
  begin
    SpectrumGradientEndpoints(Fill.Angle,Bounds,StartPoint,EndPoint);
    SpectrumColors(Color,Colors,Positions);
    Result := Format('<linearGradient id="vad-fill-%d" gradientUnits="userSpaceOnUse" data-vad-fill="spectrum" data-vad-color1="%s" data-vad-angle="%d" x1="%s" y1="%s" x2="%s" y2="%s">',
      [Index,SvgColor(Color),Fill.Angle,SvgNumber(StartPoint.X),SvgNumber(StartPoint.Y),
       SvgNumber(EndPoint.X),SvgNumber(EndPoint.Y)]);
    for J := 0 to High(Colors) do
      Result := Result+'<stop offset="'+SvgNumber(Positions[J])+'" stop-color="'+
        SvgColor(TColor(RGB((Colors[J] shr 16) and $FF,(Colors[J] shr 8) and $FF,Colors[J] and $FF)))+'"/>';
    Result := Result+'</linearGradient>';
    Exit;
  end;
  if Fill.Kind in [vfkCircle,vfkSquare,vfkWave] then
  begin
    Tag := 'circle';
    if Fill.Kind = vfkSquare then Tag := 'square';
    if Fill.Kind = vfkWave then Tag := 'wave';
    if Index < 0 then
    begin
      // 線の外側とマーカーまで描き、patternの境界で色が繰り返されないようにする。
      Area := Bounds; Area.Inflate(Padding+1,Padding+1);
      Exit(Format('<pattern id="vad-fill-%d" patternUnits="userSpaceOnUse" x="%s" y="%s" width="%s" height="%s" data-vad-fill="%s" data-vad-color1="%s" data-vad-color2="%s" data-vad-wave-count="%d"><image x="%s" y="%s" width="%s" height="%s" preserveAspectRatio="none" href="data:image/png;base64,%s"/></pattern>',
        [Index,SvgNumber(Area.Left),SvgNumber(Area.Top),SvgNumber(Area.Width),SvgNumber(Area.Height),
         Tag,SvgColor(Color),SvgColor(Fill.Color2),Fill.WaveCount,SvgNumber(Area.Left),SvgNumber(Area.Top),
         SvgNumber(Area.Width),SvgNumber(Area.Height),TNetEncoding.Base64.EncodeBytesToString(RasterFillPng(Color,Fill,Bounds,True,Padding+1,TextPaint))]));
    end;
    Exit(Format('<pattern id="vad-fill-%d" width="1" height="1" patternContentUnits="objectBoundingBox" data-vad-fill="%s" data-vad-color1="%s" data-vad-color2="%s" data-vad-wave-count="%d"><image width="1" height="1" preserveAspectRatio="none" href="data:image/png;base64,%s"/></pattern>',
      [Index,Tag,SvgColor(Color),SvgColor(Fill.Color2),Fill.WaveCount,
       TNetEncoding.Base64.EncodeBytesToString(RasterFillPng(Color,Fill,Bounds))]));
  end;
  // 実寸配置はuserSpaceOnUseで表し、面積を持たない水平・垂直Lineでも同じ画像を使えるようにする。
  if Fill.Kind = vfkTexture then
  begin
    Image := TSkImage.MakeFromEncoded(Fill.TexturePng);
    if Image = nil then raise EWriteError.Create('Invalid texture PNG');
    Exit(Format('<pattern id="vad-fill-%d" patternUnits="userSpaceOnUse" x="%s" y="%s" width="%d" height="%d"><image width="%d" height="%d" preserveAspectRatio="none" href="data:image/png;base64,%s"/></pattern>',
      [Index,SvgNumber(Bounds.Left),SvgNumber(Bounds.Top),Image.Width,Image.Height,
       Image.Width,Image.Height,TNetEncoding.Base64.EncodeBytesToString(Fill.TexturePng)]));
  end;
  Tag := 'linearGradient'; Attr := 'x1="0" y1="0" x2="1" y2="0"';
  if (Fill.Kind = vfkLinearHorizontal) and (Fill.Angle mod 360 <> 0) then
  begin
    LinearGradientEndpoints(Fill.Angle,StartPoint,EndPoint);
    Attr := 'x1="'+SvgNumber(StartPoint.X)+'" y1="'+SvgNumber(StartPoint.Y)+
      '" x2="'+SvgNumber(EndPoint.X)+'" y2="'+SvgNumber(EndPoint.Y)+'"';
  end;
  if Fill.Kind = vfkLinearVertical then Attr := 'x1="0" y1="0" x2="0" y2="1"';
  if (Index < 0) and (Fill.Kind in [vfkLinearHorizontal,vfkLinearVertical]) then
  begin
    J := Fill.Angle;
    if Fill.Kind = vfkLinearVertical then J := 90;
    SpectrumGradientEndpoints(J,Bounds,StartPoint,EndPoint);
    Attr := 'gradientUnits="userSpaceOnUse" x1="'+SvgNumber(StartPoint.X)+
      '" y1="'+SvgNumber(StartPoint.Y)+'" x2="'+SvgNumber(EndPoint.X)+
      '" y2="'+SvgNumber(EndPoint.Y)+'"';
  end;
  if Fill.Kind = vfkRadial then
  begin
    Tag := 'radialGradient';
    StartPoint := Bounds.CenterPoint;
    if Index < 0 then StartPoint.Offset(0.5,0.5);
    // 実座標で円を定義し、objectBoundingBoxによる楕円化を避ける。
    Attr := 'gradientUnits="userSpaceOnUse" cx="'+SvgNumber(StartPoint.X)+
      '" cy="'+SvgNumber(StartPoint.Y)+
      '" r="'+SvgNumber(Hypot(Bounds.Width,Bounds.Height)*0.5)+'"';
  end;
  Result := Format('<%s id="vad-fill-%d" %s><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></%s>',
    [Tag,Index,Attr,SvgColor(Color),SvgColor(Fill.Color2),Tag]);
end;

end.
