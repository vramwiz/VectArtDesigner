program VectArtRendererTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  TextRendererSkiaBootstrap in
    'Lib\TextRenderer\TextRendererSkiaBootstrap.pas',
  TextRendererSkiaRuntime in
    'Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  VectArtDesignerDocument in
    'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerRenderer in
    'Source\Rendering\VectArtDesignerRenderer.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function PixelAt(Buffer: TVectArtRenderBuffer;
  X, Y: Integer): PVectArtRgbaPixel;
begin
  Result := Buffer.Data;
  Inc(Result, NativeInt(Y) * Buffer.Width + X);
end;

var
  Data: TVectArtRectangleData;
  Destination: TVectArtRenderBuffer;
  Document: TVectArtDocument;
  I: NativeInt;
  Pixel: PVectArtRgbaPixel;
  Rendered: TVectArtRenderBuffer;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Document := TVectArtDocument.Create;
  Rendered := TVectArtRenderBuffer.Create;
  Destination := TVectArtRenderBuffer.Create;
  try
    Document.CanvasLayer.Width := 8;
    Document.CanvasLayer.Height := 8;
    RenderVectArtDocument(Document, Rendered, 8, 8);
    Require(PixelAt(Rendered, 3, 3)^.A = 0,
      'Empty document is not transparent');

    Data.Bounds := TRectF.Create(2, 2, 6, 6);
    Data.FillColor := TColor($000000FF);
    Data.Locked := False;
    Data.Name := 'Rectangle 1';
    Data.Opacity := 0.5;
    Data.Visible := True;
    Document.InsertRectangle(Document.LayerCount, Data);
    RenderVectArtDocument(Document, Rendered, 8, 8);
    Pixel := PixelAt(Rendered, 3, 3);
    Require((Pixel^.R >= 250) and (Pixel^.G <= 5) and (Pixel^.B <= 5),
      'Rectangle color differs');
    Require((Pixel^.A >= 127) and (Pixel^.A <= 128),
      'Rectangle opacity differs');
    Require(PixelAt(Rendered, 0, 0)^.A = 0,
      'Outside rectangle is not transparent');

    Destination.SetSize(8, 8);
    Pixel := Destination.Data;
    for I := 0 to Destination.PixelCount - 1 do
    begin
      Pixel^.R := 0;
      Pixel^.G := 0;
      Pixel^.B := 255;
      Pixel^.A := 255;
      Inc(Pixel);
    end;
    CompositeVectArtRgba(Rendered, Destination.Data, 8, 8);
    Pixel := PixelAt(Destination, 3, 3);
    Require((Pixel^.R >= 127) and (Pixel^.R <= 128) and
      (Pixel^.B >= 127) and (Pixel^.B <= 128) and (Pixel^.A = 255),
      'RGBA source-over composition differs');
    Writeln('VectArt shared renderer: PASS');
  finally
    Destination.Free;
    Rendered.Free;
    Document.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
