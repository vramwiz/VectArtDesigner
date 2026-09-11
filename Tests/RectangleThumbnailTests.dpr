// 初期色の四角の枠を、一覧で使う両描画経路の画素で検証する。
// Non-symmetric texture pixels also guard the thumbnail row orientation.
program RectangleThumbnailTests;
{$APPTYPE CONSOLE}
uses System.Classes, System.SysUtils, System.Types, System.Skia,
  Winapi.Windows, Vcl.Graphics, Vcl.Direct2D, TextRendererSkiaBootstrap,
  TextRendererSkiaRuntime, VectArtDesignerDocument,
  VectArtDesignerLayerRenderer;

function VerticalTexture: TBytes;
var
  Image: ISkImage;
  Paint: ISkPaint;
  Stream: TMemoryStream;
  Surface: ISkSurface;
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
var
  Doc: TVectArtDocument;
  Renderer: TVectArtLayerRenderer;
  Bitmap: TBitmap;
  D2D: TDirect2DCanvas;
  Data: TVectArtRectangleData;
  Bounds, Row, Thumb: TRect;
  Backend, Mode, X, Y, Dark: Integer;
  Style: TVectArtFillStyle;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Doc := TVectArtDocument.Create;
  Renderer := TVectArtLayerRenderer.Create;
  Bitmap := TBitmap.Create;
  try
    Data := Default(TVectArtRectangleData);
    Data.Bounds := RectF(0,0,100,100);
    Data.FillColor := clWhite;
    Data.StrokeColor := clBlack;
    Data.Filled := True;
    Data.StrokeWidth := 1;
    Data.Opacity := 1;
    Data.Visible := True;
    Doc.InsertRectangle(1,Data);
    Renderer.Document := Doc;
    Bounds := Rect(0,0,320,160);
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(Bounds.Width,Bounds.Height);
    Row := Renderer.LayerItemRect(Bounds,1);
    Thumb := Rect(Row.Left+30,Row.Top+14,Row.Left+126,Row.Top+68);
    for Backend := 0 to 1 do
      for Mode := 0 to 2 do
      begin
        TVectArtRectangleLayer(Doc[1]).Filled := Mode <> 1;
        if Mode = 2 then TVectArtRectangleLayer(Doc[1]).StrokeWidth := 0
        else TVectArtRectangleLayer(Doc[1]).StrokeWidth := 1;
        if Backend = 0 then Renderer.DrawLayers(Bitmap.Canvas,Bounds)
        else
        begin
          D2D := TDirect2DCanvas.Create(Bitmap.Canvas,Bounds);
          try
            D2D.BeginDraw;
            Renderer.DrawLayers(D2D,Bounds);
            D2D.EndDraw;
          finally D2D.Free; end;
        end;
        Dark := 0;
        // サムネイル外枠や文字を除き、四角の左右辺だけを調べる。
        for Y := Thumb.Top+5 to Thumb.Bottom-6 do
          for X := Thumb.Left+18 to Thumb.Right-19 do
            if (ColorToRGB(Bitmap.Canvas.Pixels[X,Y]) and $FFFFFF) = 0 then Inc(Dark);
        Bitmap.SaveToFile(Format('TestOutput/rectangle-thumb-%d-%d.bmp',[Backend,Mode]));
        if ((Mode < 2) and (Dark = 0)) or ((Mode = 2) and (Dark > 0)) then
          raise Exception.CreateFmt('Wrong outline: backend=%d mode=%d pixels=%d',[Backend,Mode,Dark]);
      end;
    Style := Default(TVectArtFillStyle);
    Style.Kind := vfkTexture;
    Style.TexturePng := VerticalTexture;
    TVectArtRectangleLayer(Doc[1]).FillStyle := Style;
    TVectArtRectangleLayer(Doc[1]).Filled := True;
    TVectArtRectangleLayer(Doc[1]).StrokeWidth := 0;
    Doc.ChangedLayer(1);
    Renderer.DrawLayers(Bitmap.Canvas,Bounds);
    Bitmap.SaveToFile('TestOutput/rectangle-texture-thumbnail.bmp');
    X := (Thumb.Left + Thumb.Right) div 2;
    if GetRValue(Bitmap.Canvas.Pixels[X,Thumb.Top+8]) <=
      GetBValue(Bitmap.Canvas.Pixels[X,Thumb.Top+8]) then
      raise Exception.Create('Texture thumbnail top row was flipped');
    if GetBValue(Bitmap.Canvas.Pixels[X,Thumb.Bottom-9]) <=
      GetRValue(Bitmap.Canvas.Pixels[X,Thumb.Bottom-9]) then
      raise Exception.Create('Texture thumbnail bottom row was flipped');
    Writeln('PASS rectangle thumbnail: GDI/Direct2D, modes and texture orientation');
  finally
    Bitmap.Free; Renderer.Free; Doc.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
