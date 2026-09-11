// Verifies that the compact texture sample represents the complete image.
program ColorSwatchTextureTests;
{$APPTYPE CONSOLE}
uses
  System.Classes, System.SysUtils, System.Types, System.Skia, Winapi.Windows,
  Vcl.Forms, Vcl.Graphics, TextRendererSkiaBootstrap, TextRendererSkiaRuntime,
  VectArtDesignerDocument, VectArtDesignerColorSwatch;

function VerticalTexture: TBytes;
var Image: ISkImage; Paint: ISkPaint; Stream: TMemoryStream; Surface: ISkSurface;
begin
  Surface := TSkSurface.MakeRaster(100,100);
  Surface.Canvas.Clear($FFFF0000);
  Paint := TSkPaint.Create;
  Paint.Color := $FF0000FF;
  Surface.Canvas.DrawRect(RectF(0,50,100,100),Paint);
  Image := Surface.MakeImageSnapshot;
  Stream := TMemoryStream.Create;
  try
    Image.EncodeToStream(Stream);
    SetLength(Result,Stream.Size);
    if Stream.Size > 0 then Move(Stream.Memory^,Result[0],Stream.Size);
  finally Stream.Free; end;
end;

var Bitmap: TBitmap; Fill: TVectArtFillStyle; Form: TForm;
  Swatch: TVectArtColorSwatch; X: Integer;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Form := TForm.Create(nil);
  Bitmap := TBitmap.Create;
  try
    Swatch := TVectArtColorSwatch.Create(Form);
    Swatch.Parent := Form;
    Swatch.SetBounds(0,0,120,40);
    Form.ClientWidth := 120;
    Form.ClientHeight := 40;
    Form.Show;
    Application.ProcessMessages;
    Fill := Default(TVectArtFillStyle);
    Fill.Kind := vfkTexture;
    Fill.TexturePng := VerticalTexture;
    Swatch.Value := clWhite;
    Swatch.FillStyle := Fill;
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(Swatch.Width,Swatch.Height);
    Swatch.PaintTo(Bitmap.Canvas.Handle,0,0);
    Bitmap.SaveToFile('TestOutput/color-swatch-texture.bmp');
    X := 25;
    if GetRValue(Bitmap.Canvas.Pixels[X,10]) <=
      GetBValue(Bitmap.Canvas.Pixels[X,10]) then
      raise Exception.Create('Texture sample does not show the image top');
    if GetBValue(Bitmap.Canvas.Pixels[X,29]) <=
      GetRValue(Bitmap.Canvas.Pixels[X,29]) then
      raise Exception.Create('Texture sample does not show the image bottom');
    Writeln('PASS texture swatch shows the complete image');
  finally
    Bitmap.Free;
    Form.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
