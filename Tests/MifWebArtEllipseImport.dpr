program MifWebArtEllipseImport;

{$APPTYPE CONSOLE}

// Verify WebArt ellipse import, payload preservation, and generated type-2 data.

uses
  System.Math,
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
  VectArtDesignerTextGeometry in
    'Source\Core\VectArtDesignerTextGeometry.pas',
  VectArtDesignerBezierGeometry in
    'Source\Editor\Geometry\VectArtDesignerBezierGeometry.pas',
  VectArtDesignerRoundedRectangleGeometry in
    'Source\Editor\Geometry\VectArtDesignerRoundedRectangleGeometry.pas',
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

function BytesEqual(const Left, Right: TBytes): Boolean;
begin
  Result := Length(Left) = Length(Right);
  if Result and (Length(Left) > 0) then
    Result := CompareMem(@Left[0], @Right[0], Length(Left));
end;

var
  Container: TVectArtMifContainer;
  Data: TVectArtRectangleData;
  Document: TVectArtDocument;
  Ellipse: TVectArtRectangleLayer;
  ErrorMessage: string;
  GeneratedContainer: TVectArtMifContainer;
  GeneratedDocument: TVectArtDocument;
  Reader: IVectArtMifContainerReader;
  SavedContainer: TVectArtMifContainer;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Container := nil;
  SavedContainer := nil;
  GeneratedContainer := nil;
  Document := TVectArtDocument.Create;
  GeneratedDocument := TVectArtDocument.Create;
  try
    Reader := CreateVectArtMifContainerReader;
    Require(Reader.TryReadFile('mif' + PathDelim + #$4E38 + '.mif',
      Container, ErrorMessage), ErrorMessage);
    Require(TryLoadVectArtDocumentFromMif(Container, Document, ErrorMessage),
      ErrorMessage);
    Require((Document.LayerCount = 2) and
      (Document[1] is TVectArtRectangleLayer),
      'Ellipse layer count differs');
    Ellipse := TVectArtRectangleLayer(Document[1]);
    Require(Ellipse.Shape = vpsEllipse, 'MIF element type 2 was not imported');
    Require(SameValue(Ellipse.Bounds.Left, 105) and
      SameValue(Ellipse.Bounds.Top, 105) and
      SameValue(Ellipse.Bounds.Right, 213) and
      SameValue(Ellipse.Bounds.Bottom, 177),
      'Imported ellipse bounds differ');
    Require(Ellipse.Filled and (Ellipse.StrokeWidth > 0),
      'Imported ellipse paint mode differs');

    Require(TryCreateVectArtMifFromDocument(Document, Container,
      SavedContainer, ErrorMessage), ErrorMessage);
    Require((SavedContainer.ChunkCount = Container.ChunkCount) and
      BytesEqual(SavedContainer[5].Data, Container[5].Data),
      'Ellipse vector payload was not preserved');

    Data := Default(TVectArtRectangleData);
    Data.Bounds := TRectF.Create(20, 30, 140, 90);
    Data.FillColor := clLime;
    Data.Filled := False;
    Data.Locked := False;
    Data.Name := 'Ellipse 1';
    Data.Opacity := 1.0;
    Data.RotationDegrees := 0.0;
    Data.Shape := vpsEllipse;
    Data.StrokeColor := clBlue;
    Data.StrokeStyle := vssSolid;
    Data.StrokeWidth := 2.0;
    Data.Visible := True;
    GeneratedDocument.InsertRectangle(1, Data);
    Require(TryCreateVectArtMifFromDocument(GeneratedDocument,
      GeneratedContainer, ErrorMessage), ErrorMessage);
    Document.Free;
    Document := TVectArtDocument.Create;
    Require(TryLoadVectArtDocumentFromMif(GeneratedContainer, Document,
      ErrorMessage), ErrorMessage);
    Ellipse := TVectArtRectangleLayer(Document[1]);
    Require((Ellipse.Shape = vpsEllipse) and not Ellipse.Filled and
      SameValue(Ellipse.StrokeWidth, 2.0),
      'Generated ellipse MIF did not round-trip');
    Writeln('WebArt ellipse import: PASS');
  finally
    GeneratedContainer.Free;
    SavedContainer.Free;
    Container.Free;
    GeneratedDocument.Free;
    Document.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
