program MifWebArtRectangleImport;

{$APPTYPE CONSOLE}

// WebArt Designer製の四角MIFを読み込み、互換ベクターペイロードを保存時にも維持できることを検証する。

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
  Document: TVectArtDocument;
  ErrorMessage: string;
  I: Integer;
  InputFileName: string;
  Reader: IVectArtMifContainerReader;
  Rectangle: TVectArtRectangleLayer;
  RectangleCount: Integer;
  SavedContainer: TVectArtMifContainer;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Container := nil;
  SavedContainer := nil;
  Document := TVectArtDocument.Create;
  try
    if ParamCount > 0 then
      InputFileName := ParamStr(1)
    else
      InputFileName := 'mif' + PathDelim + #$56DB#$89D2 + '.mif';
    Reader := CreateVectArtMifContainerReader;
    Require(Reader.TryReadFile(InputFileName, Container, ErrorMessage),
      ErrorMessage);
    Require(TryLoadVectArtDocumentFromMif(Container, Document, ErrorMessage),
      ErrorMessage);
    RectangleCount := (Container.ChunkCount - 4) div 4;
    Require(RectangleCount > 0, 'Rectangle source chunks were not found');
    Require(Document.LayerCount = RectangleCount + 1,
      'Rectangle count differs');
    if ParamCount = 0 then
    begin
      Require((Document.CanvasLayer.Width = 640) and
        (Document.CanvasLayer.Height = 480), 'Canvas size differs');
      Rectangle := TVectArtRectangleLayer(Document[1]);
      Require(SameValue(Rectangle.Bounds.Left, 113), 'Left differs');
      Require(SameValue(Rectangle.Bounds.Top, 105), 'Top differs');
      Require(SameValue(Rectangle.Bounds.Right, 290), 'Right differs');
      Require(SameValue(Rectangle.Bounds.Bottom, 203), 'Bottom differs');
      Require(ColorToRGB(Rectangle.FillColor) = ColorToRGB(clWhite),
        'Fill color differs');
      Require(SameValue(Rectangle.Opacity, 1.0), 'Opacity differs');
      Require(Rectangle.Visible, 'Visibility differs');
    end;
    Require(TryCreateVectArtMifFromDocument(Document, Container,
      SavedContainer, ErrorMessage), ErrorMessage);
    Require(SavedContainer.ChunkCount = Container.ChunkCount,
      'Saved chunk count differs');
    Require((Length(SavedContainer[0].Data) = 4) and
      (SavedContainer[0].Data[0] = 0) and
      (SavedContainer[0].Data[1] = 0) and
      (SavedContainer[0].Data[2] = 0) and
      (SavedContainer[0].Data[3] = SavedContainer.ChunkCount - 2),
      'MHDR does not match the outer chunk count');
    for I := 0 to RectangleCount - 1 do
      Require(BytesEqual(SavedContainer[5 + I * 4].Data,
        Container[5 + I * 4].Data),
        Format('Rectangle %d vector payload was not preserved', [I + 1]));
    Writeln('WebArt rectangle import: PASS');
  finally
    SavedContainer.Free;
    Container.Free;
    Document.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
