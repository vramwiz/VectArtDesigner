// 塗り・線・文字で共有するMIFペイント属性を読み書きする。未検証の画像テクスチャは独自属性へ変換しない。
unit VectArtDesignerMifPaint;

interface

uses System.SysUtils, Vcl.Graphics, VectArtDesignerDocument;
function CreateTexturePng(Color: TColor): TBytes;
function CreateFillTexturePng(Color: TColor; const Fill: TVectArtFillStyle; Stroke: Boolean = False): TBytes;
function ReadFillTexture(const Png: TBytes): TVectArtFillStyle;

implementation

uses System.Classes, System.Types, System.Skia, VectArtDesignerRenderer, VectArtDesignerFillPaint,
  VectArtDesignerMifPngMetadata, VectArtDesignerMifPlacement, VectArtDesignerMifRaster;

function CreateTexturePng(Color: TColor): TBytes;
var
  BgrColor: Int32;
begin
  Result := CreateSolidPng(64, 64, Color);
  AddText(Result, 'object type', 'texture');
  AddImagePlacementMetadata(Result, TRectF.Create(0, 0, 63, 63), 255,
    False);
  AddWadaString(Result, 'texture object type', 'color');
  BgrColor := ColorToRGB(Color);
  AddWadaInteger(Result, 'texture color1', BgrColor);
  AddWadaInteger(Result, 'texture color2', 0);
  AddWadaInteger(Result, 'texture angle', 0);
  AddWadaInteger(Result, 'texture level', 0);
  AddWadaString(Result, 'texture pathname', '@');
end;

function CreateFillTexturePng(Color: TColor; const Fill: TVectArtFillStyle; Stroke: Boolean = False): TBytes;
var Pixels: TArray<TVectArtRgbaPixel>; Surface: ISkSurface; Paint: ISkPaint;
    Info: TSkImageInfo; Angle: Integer;
begin
  if Fill.Kind = vfkSolid then Exit(CreateTexturePng(Color));
  if not (Fill.Kind in [vfkLinearHorizontal,vfkLinearVertical,vfkRadial,vfkCircle,vfkSquare,vfkWave,vfkSpectrum]) then
    raise EWriteError.Create('This fill type has no verified native MIF mapping yet');
  SetLength(Pixels,64*64);
  Info := TSkImageInfo.Create(64,64,TSkColorType.RGBA8888,TSkAlphaType.Unpremul);
  Surface := TSkSurface.MakeRasterDirect(Info,@Pixels[0],64*4);
  Paint := TSkPaint.Create;
  if Stroke then SetStrokePaint(Paint,Color,Fill,RectF(0,0,64,64),1,1)
  else SetFillPaint(Paint,Color,Fill,RectF(0,0,64,64),1);
  Surface.Canvas.DrawPaint(Paint); Surface.Flush;
  Result := EncodeRgba(@Pixels[0],64,64);
  AddText(Result,'object type','texture');
  AddImagePlacementMetadata(Result,RectF(0,0,63,63),255,False);
  // WebArtの放射状サンプルと同じ属性を使い、図形として再編集できるようにする。
  if Fill.Kind = vfkRadial then
    AddWadaString(Result,'texture object type','gradation radiate')
  else if Fill.Kind = vfkCircle then
    AddWadaString(Result,'texture object type','gradation circle')
  else if Fill.Kind = vfkSquare then
    AddWadaString(Result,'texture object type','gradation square')
  else if Fill.Kind = vfkWave then
    AddWadaString(Result,'texture object type','gradation wave')
  else if Fill.Kind = vfkSpectrum then
    AddWadaString(Result,'texture object type','spectrum linear')
  else AddWadaString(Result,'texture object type','gradation linear');
  AddWadaInteger(Result,'texture color1',ColorToRGB(Color));
  AddWadaInteger(Result,'texture color2',ColorToRGB(Fill.Color2));
  Angle := Fill.Angle;
  if Fill.Kind in [vfkRadial,vfkCircle,vfkSquare,vfkWave] then Angle := 0;
  if Fill.Kind = vfkLinearVertical then Angle := 90;
  AddWadaInteger(Result,'texture angle',Angle);
  if Fill.Kind = vfkWave then AddWadaInteger(Result,'texture level',Fill.WaveCount)
  else AddWadaInteger(Result,'texture level',0);
  AddWadaString(Result,'texture pathname','@');
end;
function ReadFillTexture(const Png: TBytes): TVectArtFillStyle;
var Kind: string; Angle, C: Int32;
begin
  Result := Default(TVectArtFillStyle);
  if TryReadPngString(Png,'waDA','texture object type',Kind) and
    (SameText(Kind,'gradation linear') or SameText(Kind,'gradation radiate') or
      SameText(Kind,'gradation circle') or SameText(Kind,'gradation square') or
      SameText(Kind,'gradation wave') or SameText(Kind,'spectrum linear')) then
  begin
    C := 0; Angle := 0;
    TryReadPngInteger(Png,'texture color2',C);
    TryReadPngInteger(Png,'texture angle',Angle);
    Result.Angle := Angle;
    Result.Color2 := TColor(C);
    Result.Kind := vfkLinearHorizontal;
    if Angle = 90 then Result.Kind := vfkLinearVertical;
    if SameText(Kind,'spectrum linear') then Result.Kind := vfkSpectrum;
    if SameText(Kind,'gradation wave') then
    begin
      Result.Kind := vfkWave;
      Result.Angle := 0;
      TryReadPngInteger(Png,'texture level',Result.WaveCount);
    end;
    if SameText(Kind,'gradation square') then
    begin
      Result.Kind := vfkSquare;
      Result.Angle := 0;
    end;
    if SameText(Kind,'gradation circle') then
    begin
      Result.Kind := vfkCircle;
      Result.Angle := 0;
    end;
    if SameText(Kind,'gradation radiate') then
    begin
      Result.Kind := vfkRadial;
      Result.Angle := 0;
    end;
  end;
end;

end.
