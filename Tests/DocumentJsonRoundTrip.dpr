program DocumentJsonRoundTrip;

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  System.Types,
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerDocumentJson in
    'Source\Persistence\VectArtDesignerDocumentJson.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  ErrorMessage: string;
  Rectangle: TVectArtRectangleLayer;
  Serialized: string;
  SourceDocument: TVectArtDocument;
  TargetDocument: TVectArtDocument;
begin
  SourceDocument := TVectArtDocument.Create;
  TargetDocument := TVectArtDocument.Create;
  try
    SourceDocument.CanvasLayer.Transparent := True;
    SourceDocument.SetRectangleBounds(1,
      TRectF.Create(12.5, 24.25, 640.75, 480.5));
    SourceDocument.Layers[1].Name := '日本語レイヤー';
    SourceDocument.SetLayerOpacity(1, 0.625);
    SourceDocument.SetLayerLocked(1, True);
    SourceDocument.SelectedIndex := 1;

    Serialized := SerializeVectArtDocument(SourceDocument);
    Require(TryDeserializeVectArtDocument(Serialized, TargetDocument,
      ErrorMessage), ErrorMessage);
    Require(TargetDocument.LayerCount = SourceDocument.LayerCount,
      'Layer count differs');
    Require(TargetDocument.CanvasLayer.Transparent,
      'Canvas transparency differs');
    Require(TargetDocument.SelectedIndex = 1, 'Selection differs');
    Rectangle := TVectArtRectangleLayer(TargetDocument.Layers[1]);
    Require(Rectangle.Name = '日本語レイヤー', 'Layer name differs');
    Require(Rectangle.Locked, 'Layer lock differs');
    Require(SameValue(Rectangle.Opacity, 0.625), 'Layer opacity differs');
    Require(SameValue(Rectangle.Bounds.Left, 12.5), 'Bounds differ');

    Require(not TryDeserializeVectArtDocument('{broken', TargetDocument,
      ErrorMessage), 'Invalid JSON was accepted');
    Require(TargetDocument.LayerCount = SourceDocument.LayerCount,
      'Invalid JSON changed the document');
    Writeln('Document JSON round-trip: PASS');
  finally
    TargetDocument.Free;
    SourceDocument.Free;
  end;
end.
