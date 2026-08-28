program MifWebArtImageImport;

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
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerDocumentJson in
    'Source\Persistence\VectArtDesignerDocumentJson.pas',
  VectArtDesignerRenderer in
    'Source\Rendering\VectArtDesignerRenderer.pas',
  VectArtDesignerLayerRenderer in
    'Source\Layers\VectArtDesignerLayerRenderer.pas',
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
  Bitmap: TBitmap;
  Document: TVectArtDocument;
  ErrorMessage: string;
  I: NativeInt;
  ImageLayer: TVectArtImageLayer;
  ItemRect: TRect;
  LayerRenderer: TVectArtLayerRenderer;
  ModifiedPoints: TVectArtImagePoints;
  NonCheckerPixelCount: Integer;
  OpaquePixelCount: Integer;
  PixelColor: TColor;
  Rendered: TVectArtRenderBuffer;
  SavedContainer: TVectArtMifContainer;
  X: Integer;
  Y: Integer;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Document := TVectArtDocument.Create;
  Rendered := TVectArtRenderBuffer.Create;
  Bitmap := TBitmap.Create;
  LayerRenderer := TVectArtLayerRenderer.Create;
  try
    LoadDocument('mif' + PathDelim + #$753B + #$50CF + '.mif', Document);
    Require(Document.LayerCount = 4, 'Multiple images were not imported');
    for I := 1 to 3 do
      Require((Document[I] is TVectArtImageLayer) and
        (TVectArtImageLayer(Document[I]).SourceKind = visImage),
        'Ordinary image layer differs');
    Require(Document[2] is TVectArtImageLayer,
      'Horizontally flipped image is missing');
    ImageLayer := TVectArtImageLayer(Document[2]);
    Require(ImageLayer.Points[1].X < ImageLayer.Points[0].X,
      'Horizontal flip placement was not preserved');
    RenderVectArtDocument(Document, Rendered, Document.CanvasLayer.Width,
      Document.CanvasLayer.Height);
    OpaquePixelCount := 0;
    for I := 0 to Rendered.PixelCount - 1 do
      if Rendered.Pixels[I].A > 0 then
        Inc(OpaquePixelCount);
    Require(OpaquePixelCount > 100, 'Imported images were not rendered');
    Bitmap.SetSize(320, 480);
    LayerRenderer.Document := Document;
    LayerRenderer.DrawLayers(Bitmap.Canvas, Rect(0, 0, 320, 480));
    ItemRect := LayerRenderer.LayerItemRect(Rect(0, 0, 320, 480), 1);
    NonCheckerPixelCount := 0;
    for Y := ItemRect.Top + 15 to ItemRect.Top + 66 do
      for X := ItemRect.Left + 31 to ItemRect.Left + 124 do
      begin
        PixelColor := ColorToRGB(Bitmap.Canvas.Pixels[X, Y]);
        if (PixelColor <> ColorToRGB(clWhite)) and
          (PixelColor <> ColorToRGB(TColor($00B8B8B8))) then
          Inc(NonCheckerPixelCount);
      end;
    Require(NonCheckerPixelCount > 100,
      'Image layer thumbnail was not rendered');
    ModifiedPoints := TVectArtImageLayer(Document[1]).Points;
    for I := 0 to High(ModifiedPoints) do
      ModifiedPoints[I] := TPointF.Create(ModifiedPoints[I].X + 17,
        ModifiedPoints[I].Y + 9);
    Document.SetImagePoints(1, ModifiedPoints);
    SavedContainer := nil;
    try
      Require(TryCreateVectArtMifFromDocument(Document, SavedContainer,
        ErrorMessage), ErrorMessage);
      Require(SavedContainer.ChunkCount = 10,
        'Multiple-image MIF chunk count differs');
      Require(TryLoadVectArtDocumentFromMif(SavedContainer, Document,
        ErrorMessage), ErrorMessage);
      Require(Document.LayerCount = 4,
        'Multiple images did not survive MIF round trip');
      Require((TVectArtImageLayer(Document[1]).Points[0].X =
        ModifiedPoints[0].X) and
        (TVectArtImageLayer(Document[1]).Points[0].Y =
        ModifiedPoints[0].Y), 'Edited image placement was not saved');
    finally
      SavedContainer.Free;
    end;

    LoadDocument('mif' + PathDelim + #$6587 + #$5B57 + '.mif', Document);
    Require((Document.LayerCount = 2) and
      (Document[1] is TVectArtImageLayer), 'Logo was not imported');
    Require(TVectArtImageLayer(Document[1]).SourceKind = visLogo,
      'Logo source kind differs');
    SavedContainer := nil;
    try
      Require(TryCreateVectArtMifFromDocument(Document, SavedContainer,
        ErrorMessage), ErrorMessage);
      Require(TryLoadVectArtDocumentFromMif(SavedContainer, Document,
        ErrorMessage), ErrorMessage);
      Require((Document.LayerCount = 2) and
        (Document[1] is TVectArtImageLayer) and
        (TVectArtImageLayer(Document[1]).SourceKind = visLogo),
        'Logo did not survive MIF round trip');
    finally
      SavedContainer.Free;
    end;
    Writeln('WebArt image and logo import: PASS');
  finally
    LayerRenderer.Free;
    Bitmap.Free;
    Rendered.Free;
    Document.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
