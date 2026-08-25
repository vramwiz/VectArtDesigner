program MifDocumentRoundTrip;

{$APPTYPE CONSOLE}

// 互換MIFではアプリ固有情報を失っても、対応する表示情報を再読込できることを検証する。

uses
  System.Classes,
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
  Data: TVectArtRectangleData;
  ErrorMessage: string;
  Memory: TMemoryStream;
  ReadContainer: TVectArtMifContainer;
  Reader: IVectArtMifContainerReader;
  SourceDocument: TVectArtDocument;
  TargetDocument: TVectArtDocument;
  TargetRectangle: TVectArtRectangleLayer;
  Writer: IVectArtMifContainerWriter;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  SourceDocument := TVectArtDocument.Create;
  TargetDocument := TVectArtDocument.Create;
  Container := nil;
  ReadContainer := nil;
  Memory := TMemoryStream.Create;
  try
    SourceDocument.SetCanvasSize(640, 360);
    SourceDocument.CanvasLayer.BackgroundColor := TColor($00302010);
    Data.Name := 'MIF layer';
    Data.Bounds := TRectF.Create(40, 50, 220, 180);
    Data.FillColor := TColor($00A06020);
    Data.Opacity := 0.625;
    Data.Visible := True;
    Data.Locked := True;
    SourceDocument.InsertRectangle(1, Data);

    Require(TryCreateVectArtMifFromDocument(SourceDocument, Container,
      ErrorMessage), ErrorMessage);
    Require(Container.ChunkCount = 8, 'Unexpected MIF chunk count');
    Require((Length(Container[0].Data) = 4) and
      (Container[0].Data[0] = 0) and (Container[0].Data[1] = 0) and
      (Container[0].Data[2] = 0) and (Container[0].Data[3] = 6),
      'MHDR chunk count differs');
    Writer := CreateVectArtMifContainerWriter;
    Require(Writer.TryWriteFile(Container, ChangeFileExt(ParamStr(0), '.mif'),
      ErrorMessage), ErrorMessage);
    Require(Writer.TryWrite(Container, Memory, ErrorMessage), ErrorMessage);
    Reader := CreateVectArtMifContainerReader;
    Require(Reader.TryRead(Memory, ReadContainer, ErrorMessage), ErrorMessage);
    Require(TryLoadVectArtDocumentFromMif(ReadContainer, TargetDocument,
      ErrorMessage), ErrorMessage);
    Require((TargetDocument.CanvasLayer.Width = 640) and
      (TargetDocument.CanvasLayer.Height = 360), 'Canvas size differs');
    Require(TargetDocument.LayerCount = 2, 'Layer count differs');
    TargetRectangle := TVectArtRectangleLayer(TargetDocument[1]);
    Require(TargetRectangle.Name = 'Rectangle 1', 'Imported layer name differs');
    Require(not TargetRectangle.Locked, 'Imported layer must be unlocked');
    Require(SameValue(TargetRectangle.Opacity, Round(0.625 * 255) / 255,
      0.000001), 'Opacity differs');
    Require(SameValue(TargetRectangle.Bounds.Right, 220), 'Bounds differ');
    Writeln('MIF document round-trip: PASS');
  finally
    Memory.Free;
    ReadContainer.Free;
    Container.Free;
    TargetDocument.Free;
    SourceDocument.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
