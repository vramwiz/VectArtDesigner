program MifWebArtLineImport;

{$APPTYPE CONSOLE}

// WebArt Designer製の直線MIFをelement type 6として取り込めることを検証する。

uses
  System.Math,
  System.SysUtils,
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
  VectArtDesignerMifContainer in
    'Source\Persistence\Mif\VectArtDesignerMifContainer.pas',
  VectArtDesignerMifDocument in
    'Source\Persistence\Mif\VectArtDesignerMifDocument.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  Container: TVectArtMifContainer;
  Document: TVectArtDocument;
  ErrorMessage: string;
  Line: TVectArtLineLayer;
  Reader: IVectArtMifContainerReader;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Container := nil;
  Document := TVectArtDocument.Create;
  try
    Reader := CreateVectArtMifContainerReader;
    Require(Reader.TryReadFile('mif' + PathDelim + #$7DDA + '.mif',
      Container, ErrorMessage), ErrorMessage);
    Require(TryLoadVectArtDocumentFromMif(Container, Document, ErrorMessage),
      ErrorMessage);
    Require((Document.LayerCount = 2) and
      (Document[1] is TVectArtLineLayer), 'Line layer was not imported');
    Line := TVectArtLineLayer(Document[1]);
    Require(SameValue(Line.StartPoint.X, 848.0, 0.01) and
      SameValue(Line.StartPoint.Y, 456.0, 0.01) and
      SameValue(Line.EndPoint.X, 1082.0, 0.01) and
      SameValue(Line.EndPoint.Y, 456.0, 0.01), 'Line endpoints differ');
    Require(SameValue(Line.StrokeWidth, 100.0, 0.000001),
      'Line stroke width differs');
    Require(Line.StrokeStyle = vssLongDash, 'Line stroke style differs');
    Require(Line.LineCap = vlcRound, 'Line cap differs');
    Require(Line.LineJoin = vljRound, 'Line join differs');
    Require(Line.AntiAlias, 'Line anti-alias differs');
    Require(Line.EndMarker = vlmStar, 'Line end marker differs');
    Require(Line.StartMarker = vlmOpenArrow, 'Line start marker differs');
    Require(SameValue(Line.EndMarkerSize, 11.0),
      'Line end marker size differs');
    Require(SameValue(Line.StartMarkerSize, 11.0),
      'Line start marker size differs');
    Require(ColorToRGB(Line.StrokeColor) = ColorToRGB(clBlack),
      'Line stroke color differs');
    Writeln('WebArt line import: PASS');
  finally
    Container.Free;
    Document.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
