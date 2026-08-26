program DocumentJsonRoundTrip;

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerDocumentJson in
    'Source\Persistence\VectArtDesignerDocumentJson.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  Data: TVectArtRectangleData;
  LineData: TVectArtLineData;
  ErrorMessage: string;
  Rectangle: TVectArtRectangleLayer;
  TargetLine: TVectArtLineLayer;
  Serialized: string;
  SourceDocument: TVectArtDocument;
  TargetDocument: TVectArtDocument;
begin
  SourceDocument := TVectArtDocument.Create;
  TargetDocument := TVectArtDocument.Create;
  try
    Require(SourceDocument.LayerCount = 1,
      'New document contains unexpected object layers');
    SourceDocument.SetCanvasSize(2560, 1440);
    Require((SourceDocument.CanvasLayer.Width = 2560) and
      (SourceDocument.CanvasLayer.Height = 1440),
      'Canvas size update failed');
    Serialized := SerializeVectArtDocument(SourceDocument);
    Require(TryDeserializeVectArtDocument(Serialized, TargetDocument,
      ErrorMessage), ErrorMessage);
    Require(TargetDocument.LayerCount = 1,
      'Empty document round-trip created object layers');
    Require(TargetDocument.SelectedIndex = -1,
      'Empty document selection differs');

    Data.Bounds := TRectF.Create(12.5, 24.25, 640.75, 480.5);
    Data.FillColor := TColor($00E2904A);
    Data.Locked := True;
    Data.Name := '日本語レイヤー';
    Data.Opacity := 0.625;
    Data.RotationDegrees := 27.5;
    Data.StrokeColor := TColor($00112233);
    Data.StrokeStyle := vssLongDashDot;
    Data.StrokeWidth := 3.5;
    Data.Visible := True;
    SourceDocument.InsertRectangle(SourceDocument.LayerCount, Data);
    LineData.StartPoint := TPointF.Create(20, 30);
    LineData.EndPoint := TPointF.Create(220, 130);
    LineData.Locked := False;
    LineData.Name := 'Line 1';
    LineData.Opacity := 0.75;
    LineData.StrokeColor := clRed;
    LineData.StrokeStyle := vssMediumDash;
    LineData.StrokeWidth := 5.0;
    LineData.Visible := True;
    SourceDocument.InsertLine(SourceDocument.LayerCount, LineData);
    SourceDocument.CanvasLayer.Transparent := True;
    SourceDocument.SelectedIndex := 2;

    Serialized := SerializeVectArtDocument(SourceDocument);
    Require(TryDeserializeVectArtDocument(Serialized, TargetDocument,
      ErrorMessage), ErrorMessage);
    Require(TargetDocument.LayerCount = SourceDocument.LayerCount,
      'Layer count differs');
    Require(TargetDocument.CanvasLayer.Transparent,
      'Canvas transparency differs');
    Require((TargetDocument.CanvasLayer.Width = 2560) and
      (TargetDocument.CanvasLayer.Height = 1440),
      'Canvas size differs');
    Require(TargetDocument.SelectedIndex = 2, 'Selection differs');
    Rectangle := TVectArtRectangleLayer(TargetDocument.Layers[1]);
    Require(Rectangle.Name = '日本語レイヤー', 'Layer name differs');
    Require(Rectangle.Locked, 'Layer lock differs');
    Require(SameValue(Rectangle.Opacity, 0.625), 'Layer opacity differs');
    Require(SameValue(Rectangle.RotationDegrees, 27.5),
      'Layer rotation differs');
    Require(Rectangle.StrokeColor = Data.StrokeColor,
      'Layer stroke color differs');
    Require(SameValue(Rectangle.StrokeWidth, Data.StrokeWidth),
      'Layer stroke width differs');
    Require(Rectangle.StrokeStyle = Data.StrokeStyle,
      'Layer stroke style differs');
    Require(SameValue(Rectangle.Bounds.Left, 12.5), 'Bounds differ');
    TargetLine := TVectArtLineLayer(TargetDocument[2]);
    Require(TargetLine.Name = LineData.Name, 'Line name differs');
    Require(SameValue(TargetLine.StartPoint.X, LineData.StartPoint.X) and
      SameValue(TargetLine.EndPoint.Y, LineData.EndPoint.Y),
      'Line points differ');
    Require((TargetLine.StrokeColor = LineData.StrokeColor) and
      SameValue(TargetLine.StrokeWidth, LineData.StrokeWidth) and
      (TargetLine.StrokeStyle = LineData.StrokeStyle),
      'Line stroke differs');

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
