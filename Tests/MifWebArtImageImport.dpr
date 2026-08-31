program MifWebArtImageImport;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.Math,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
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

function HasExportIssue(const Report: TMifExportReport; LayerIndex: Integer;
  Kind: TMifExportIssueKind): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(Report.Issues) do
    if (Report.Issues[I].LayerIndex = LayerIndex) and
      (Report.Issues[I].Kind = Kind) then
      Exit(True);
end;

function CreatePlainPng: TBytes;
var
  Bitmap: TBitmap;
  Png: TPngImage;
  Stream: TMemoryStream;
begin
  Bitmap := TBitmap.Create;
  Png := TPngImage.Create;
  Stream := TMemoryStream.Create;
  try
    Bitmap.SetSize(8, 8);
    Bitmap.Canvas.Brush.Color := clRed;
    Bitmap.Canvas.FillRect(Rect(0, 0, 8, 8));
    Png.Assign(Bitmap);
    Png.SaveToStream(Stream);
    SetLength(Result, Stream.Size);
    if Stream.Size > 0 then
    begin
      Stream.Position := 0;
      Stream.ReadBuffer(Result[0], Stream.Size);
    end;
  finally
    Stream.Free;
    Png.Free;
    Bitmap.Free;
  end;
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
  ExportReport: TMifExportReport;
  I: NativeInt;
  ImageLayer: TVectArtImageLayer;
  InvalidContainer: TVectArtMifContainer;
  InvalidDocument: TVectArtDocument;
  InvalidImageData: TVectArtImageData;
  ItemRect: TRect;
  LayerRenderer: TVectArtLayerRenderer;
  ModifiedPoints: TVectArtImagePoints;
  NonCheckerPixelCount: Integer;
  OpaquePixelCount: Integer;
  PixelColor: TColor;
  PlainContainer: TVectArtMifContainer;
  PlainDocument: TVectArtDocument;
  PlainReadDocument: TVectArtDocument;
  Rendered: TVectArtRenderBuffer;
  SavedContainer: TVectArtMifContainer;
  X: Integer;
  Y: Integer;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Document := TVectArtDocument.Create;
  InvalidContainer := nil;
  InvalidDocument := TVectArtDocument.Create;
  PlainContainer := nil;
  PlainDocument := TVectArtDocument.Create;
  PlainReadDocument := TVectArtDocument.Create;
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
      ModifiedPoints[I] := TPointF.Create(ModifiedPoints[I].X + 17.25,
        ModifiedPoints[I].Y + 9.5);
    Document.SetImagePoints(1, ModifiedPoints);
    ImageLayer := TVectArtImageLayer(Document[1]);
    ImageLayer.Opacity := 0.5;
    ImageLayer.Locked := True;
    SavedContainer := nil;
    try
      Require(TryCreateVectArtMifFromDocument(Document, nil, SavedContainer,
        ExportReport, ErrorMessage), ErrorMessage);
      Require((ExportReport.Compatibility = mecNeedsConfirmation) and
        HasExportIssue(ExportReport, 1, meikConversion),
        'Image conversion warning was not reported');
      Require(SavedContainer.ChunkCount = 10,
        'Multiple-image MIF chunk count differs');
      Require(TryLoadVectArtDocumentFromMif(SavedContainer, Document,
        ErrorMessage), ErrorMessage);
      Require(Document.LayerCount = 4,
        'Multiple images did not survive MIF round trip');
      Require((TVectArtImageLayer(Document[1]).Points[0].X =
        Round(ModifiedPoints[0].X)) and
        (TVectArtImageLayer(Document[1]).Points[0].Y =
        Round(ModifiedPoints[0].Y)), 'Edited image placement was not saved');
      Require(SameValue(TVectArtImageLayer(Document[1]).Opacity,
        128 / 255.0, 0.000001) and
        not TVectArtImageLayer(Document[1]).Locked,
        'Image opacity or lock conversion differs from the report');
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
      Require(TryCreateVectArtMifFromDocument(Document, nil, SavedContainer,
        ExportReport, ErrorMessage), ErrorMessage);
      Require(ExportReport.Compatibility = mecExact,
        'Unchanged Logo was not reported as exactly representable');
      Require(TryLoadVectArtDocumentFromMif(SavedContainer, Document,
        ErrorMessage), ErrorMessage);
      Require((Document.LayerCount = 2) and
        (Document[1] is TVectArtImageLayer) and
        (TVectArtImageLayer(Document[1]).SourceKind = visLogo),
        'Logo did not survive MIF round trip');
    finally
      SavedContainer.Free;
    end;

    InvalidImageData := Default(TVectArtImageData);
    InvalidImageData.Name := 'Image 1';
    InvalidImageData.Opacity := 1.0;
    InvalidImageData.PngData := TBytes.Create(1, 2, 3);
    InvalidImageData.Points[0] := PointF(0, 0);
    InvalidImageData.Points[1] := PointF(100, 0);
    InvalidImageData.Points[2] := PointF(100, 100);
    InvalidImageData.Points[3] := PointF(0, 100);
    InvalidImageData.Visible := True;
    InvalidDocument.InsertImage(1, InvalidImageData);
    Require(not TryCreateVectArtMifFromDocument(InvalidDocument, nil,
      InvalidContainer, ExportReport, ErrorMessage),
      'Invalid PNG unexpectedly generated a MIF');
    Require((InvalidContainer = nil) and
      (ExportReport.Compatibility = mecUnsupported) and
      HasExportIssue(ExportReport, 1, meikUnsupported),
      'Invalid PNG was not reported as unsupported');

    InvalidImageData.PngData := CreatePlainPng;
    PlainDocument.InsertImage(1, InvalidImageData);
    Require(TryCreateVectArtMifFromDocument(PlainDocument, nil,
      PlainContainer, ExportReport, ErrorMessage), ErrorMessage);
    Require(ExportReport.Compatibility = mecExact,
      'Plain PNG was not reported as exactly representable');
    Require(TryLoadVectArtDocumentFromMif(PlainContainer,
      PlainReadDocument, ErrorMessage), ErrorMessage);
    Require((PlainReadDocument.LayerCount = 2) and
      (PlainReadDocument[1] is TVectArtImageLayer) and
      (TVectArtImageLayer(PlainReadDocument[1]).SourceKind = visImage),
      'Plain PNG did not survive MIF round trip as an Image');
    Writeln('WebArt image and logo import: PASS');
  finally
    InvalidContainer.Free;
    InvalidDocument.Free;
    PlainContainer.Free;
    PlainDocument.Free;
    PlainReadDocument.Free;
    LayerRenderer.Free;
    Bitmap.Free;
    Rendered.Free;
    Document.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
