program MifWebArtPathImport;

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  TextRendererSkiaBootstrap in
    'Lib\TextRenderer\TextRendererSkiaBootstrap.pas',
  TextRendererSkiaRuntime in
    'Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  VectArtDesignerDocument in
    'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerBezierGeometry in
    'Source\Editor\VectArtDesignerBezierGeometry.pas',
  VectArtDesignerDocumentJson in
    'Source\Persistence\VectArtDesignerDocumentJson.pas',
  VectArtDesignerRenderer in
    'Source\Rendering\VectArtDesignerRenderer.pas',
  VectArtDesignerMifContainer in
    'Source\Persistence\Mif\VectArtDesignerMifContainer.pas',
  VectArtDesignerMifDocument in
    'Source\Persistence\Mif\VectArtDesignerMifDocument.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure LoadDocument(const FileName: string; Document: TVectArtDocument);
var
  Container: TVectArtMifContainer;
  ErrorMessage: string;
  Reader: IVectArtMifContainerReader;
begin
  Container := nil;
  Reader := CreateVectArtMifContainerReader;
  try
    Require(Reader.TryReadFile(FileName, Container, ErrorMessage),
      ErrorMessage);
    Require(TryLoadVectArtDocumentFromMif(Container, Document, ErrorMessage),
      ErrorMessage);
  finally
    Container.Free;
  end;
end;

var
  Document: TVectArtDocument;
  I: NativeInt;
  OpaquePixelCount: Integer;
  Path: TVectArtPathLayer;
  Rendered: TVectArtRenderBuffer;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Document := TVectArtDocument.Create;
  Rendered := TVectArtRenderBuffer.Create;
  try
    LoadDocument('mif' + PathDelim + #$9023 + #$7D9A + #$76F4 +
      #$7DDA + '.mif', Document);
    Require((Document.LayerCount = 2) and
      (Document[1] is TVectArtPathLayer),
      'Continuous line path was not imported');
    Path := TVectArtPathLayer(Document[1]);
    Require((Length(Path.Points) = 176) and not Path.Closed and
      not Path.Filled, 'Continuous line path properties differ');
    Require(SameValue(Path.Points[0].X, 151.0, 0.01) and
      SameValue(Path.Points[0].Y, 82.0, 0.01),
      'Continuous line first point differs');
    RenderVectArtDocument(Document, Rendered, Document.CanvasLayer.Width,
      Document.CanvasLayer.Height);
    OpaquePixelCount := 0;
    for I := 0 to Rendered.PixelCount - 1 do
      if Rendered.Pixels[I].A > 0 then
        Inc(OpaquePixelCount);
    Require(OpaquePixelCount > 100, 'Continuous line was not rendered');

    LoadDocument('mif' + PathDelim + #$591A + #$89D2 + #$5F62 +
      '.mif', Document);
    Require((Document.LayerCount = 4) and
      (Document[1] is TVectArtPathLayer), 'Polygon path was not imported');
    Path := TVectArtPathLayer(Document[1]);
    Require((Length(Path.Points) = 5) and Path.Closed and Path.Filled,
      'Polygon path properties differ');
    Require(SameValue(Path.Points[0].X, 131.0, 0.01) and
      SameValue(Path.Points[0].Y, 111.0, 0.01),
      'Polygon first point differs');
    Writeln('WebArt path import: PASS');
  finally
    Rendered.Free;
    Document.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
