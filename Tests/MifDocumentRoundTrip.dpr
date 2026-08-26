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
  Data: TVectArtRectangleData;
  ErrorMessage: string;
  LineData: TVectArtLineData;
  Memory: TMemoryStream;
  ReadContainer: TVectArtMifContainer;
  Reader: IVectArtMifContainerReader;
  SourceDocument: TVectArtDocument;
  TargetDocument: TVectArtDocument;
  TargetRectangle: TVectArtRectangleLayer;
  TargetLine: TVectArtLineLayer;
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
    Data.RotationDegrees := 15.0;
    Data.StrokeColor := TColor($000040C0);
    Data.StrokeStyle := vssLongDash;
    Data.StrokeWidth := 4.0;
    Data.Visible := True;
    Data.Locked := True;
    SourceDocument.InsertRectangle(1, Data);
    LineData.StartPoint := TPointF.Create(80, 300);
    LineData.EndPoint := TPointF.Create(500, 210);
    LineData.Locked := False;
    LineData.Name := 'MIF line';
    LineData.Opacity := 0.8;
    LineData.StrokeColor := TColor($00CC4400);
    LineData.StrokeStyle := vssDashDot;
    LineData.StrokeWidth := 7.0;
    LineData.Visible := True;
    SourceDocument.InsertLine(2, LineData);

    Require(TryCreateVectArtMifFromDocument(SourceDocument, Container,
      ErrorMessage), ErrorMessage);
    Require(Container.ChunkCount = 12, 'Unexpected MIF chunk count');
    Require((Length(Container[0].Data) = 4) and
      (Container[0].Data[0] = 0) and (Container[0].Data[1] = 0) and
      (Container[0].Data[2] = 0) and (Container[0].Data[3] = 10),
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
    Require(TargetDocument.LayerCount = 3, 'Layer count differs');
    TargetRectangle := TVectArtRectangleLayer(TargetDocument[1]);
    Require(TargetRectangle.Name = 'Rectangle 1', 'Imported layer name differs');
    Require(not TargetRectangle.Locked, 'Imported layer must be unlocked');
    Require(SameValue(TargetRectangle.Opacity, Round(0.625 * 255) / 255,
      0.000001), 'Opacity differs');
    Require(SameValue((TargetRectangle.Bounds.Left +
      TargetRectangle.Bounds.Right) * 0.5, 130.0, 0.75),
      'Bounds center X differs');
    Require(SameValue((TargetRectangle.Bounds.Top +
      TargetRectangle.Bounds.Bottom) * 0.5, 115.0, 0.75),
      'Bounds center Y differs');
    Require(SameValue(TargetRectangle.Bounds.Width, 180.0, 1.5),
      'Bounds width differs');
    Require(SameValue(TargetRectangle.Bounds.Height, 130.0, 1.5),
      'Bounds height differs');
    Require(SameValue(TargetRectangle.RotationDegrees, 15.0, 1.0),
      'Rotation differs');
    Require(ColorToRGB(TargetRectangle.StrokeColor) =
      ColorToRGB(Data.StrokeColor), 'Stroke color differs');
    Require(SameValue(TargetRectangle.StrokeWidth, Data.StrokeWidth,
      0.000001), 'Stroke width differs');
    Require(TargetRectangle.StrokeStyle = Data.StrokeStyle,
      'Stroke style differs');
    TargetLine := TVectArtLineLayer(TargetDocument[2]);
    Require(SameValue(TargetLine.StartPoint.X, LineData.StartPoint.X, 0.01)
      and SameValue(TargetLine.StartPoint.Y, LineData.StartPoint.Y, 0.01)
      and SameValue(TargetLine.EndPoint.X, LineData.EndPoint.X, 0.01)
      and SameValue(TargetLine.EndPoint.Y, LineData.EndPoint.Y, 0.01),
      'Line points differ');
    Require(ColorToRGB(TargetLine.StrokeColor) =
      ColorToRGB(LineData.StrokeColor), 'Line color differs');
    Require(SameValue(TargetLine.StrokeWidth, LineData.StrokeWidth,
      0.000001), 'Line width differs');
    Require(TargetLine.StrokeStyle = LineData.StrokeStyle,
      'Line style differs');
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
