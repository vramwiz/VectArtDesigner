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
  ImageData: TVectArtImageData;
  PathData: TVectArtPathData;
  ErrorMessage: string;
  Rectangle: TVectArtRectangleLayer;
  TargetLine: TVectArtLineLayer;
  TargetImage: TVectArtImageLayer;
  TargetPath: TVectArtPathLayer;
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
    Data.MifStrokeStyle := vssLongDashDot;
    Data.StrokeWidth := 3.5;
    Data.Visible := True;
    SourceDocument.InsertRectangle(SourceDocument.LayerCount, Data);
    LineData.StartPoint := TPointF.Create(20, 30);
    LineData.EndPoint := TPointF.Create(220, 130);
    LineData.Locked := False;
    LineData.LineCap := vlcSquare;
    LineData.MifAntiAlias := False;
    LineData.MifEndMarker := vlmCircle;
    LineData.MifEndMarkerSize := 9.0;
    LineData.MifStartMarker := vlmDiamond;
    LineData.MifStartMarkerSize := 6.0;
    LineData.LineJoin := vljBevel;
    LineData.Name := 'Line 1';
    LineData.Opacity := 0.75;
    LineData.StrokeColor := clRed;
    LineData.MifStrokeStyle := vssMediumDash;
    LineData.StrokeWidth := 5.0;
    LineData.Visible := True;
    SourceDocument.InsertLine(SourceDocument.LayerCount, LineData);
    PathData.Name := 'Path 1';
    PathData.Points := [PointF(300, 40), PointF(500, 80),
      PointF(440, 220)];
    PathData.Closed := True;
    PathData.Filled := True;
    PathData.FillColor := clLime;
    PathData.Locked := False;
    PathData.Opacity := 0.6;
    PathData.StrokeColor := clBlue;
    PathData.MifStrokeStyle := vssDashDotDot;
    PathData.StrokeWidth := 4.0;
    PathData.Visible := True;
    SourceDocument.InsertPath(SourceDocument.LayerCount, PathData);
    ImageData.Name := 'Image 1';
    ImageData.Locked := False;
    ImageData.Opacity := 0.45;
    ImageData.PngData := [$89, $50, $4E, $47];
    ImageData.Points[0] := PointF(600, 100);
    ImageData.Points[1] := PointF(500, 100);
    ImageData.Points[2] := PointF(500, 180);
    ImageData.Points[3] := PointF(600, 180);
    ImageData.SourceKind := visLogo;
    ImageData.Visible := True;
    SourceDocument.InsertImage(SourceDocument.LayerCount, ImageData);
    SourceDocument.CanvasLayer.Transparent := True;
    SourceDocument.SelectedIndex := 4;

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
    Require(TargetDocument.SelectedIndex = 4, 'Selection differs');
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
    Require(Rectangle.MifStrokeStyle = Data.MifStrokeStyle,
      'Layer stroke style differs');
    Require(SameValue(Rectangle.Bounds.Left, 12.5), 'Bounds differ');
    TargetLine := TVectArtLineLayer(TargetDocument[2]);
    Require(TargetLine.Name = LineData.Name, 'Line name differs');
    Require(SameValue(TargetLine.StartPoint.X, LineData.StartPoint.X) and
      SameValue(TargetLine.EndPoint.Y, LineData.EndPoint.Y),
      'Line points differ');
    Require((TargetLine.StrokeColor = LineData.StrokeColor) and
      SameValue(TargetLine.StrokeWidth, LineData.StrokeWidth) and
      (TargetLine.MifStrokeStyle = LineData.MifStrokeStyle) and
      (TargetLine.LineCap = LineData.LineCap) and
      (TargetLine.LineJoin = LineData.LineJoin) and
      (TargetLine.MifAntiAlias = LineData.MifAntiAlias) and
      (TargetLine.MifEndMarker = LineData.MifEndMarker) and
      (TargetLine.MifStartMarker = LineData.MifStartMarker) and
      SameValue(TargetLine.MifEndMarkerSize, LineData.MifEndMarkerSize) and
      SameValue(TargetLine.MifStartMarkerSize, LineData.MifStartMarkerSize),
      'Line stroke differs');
    TargetPath := TVectArtPathLayer(TargetDocument[3]);
    Require((Length(TargetPath.Points) = 3) and TargetPath.Closed and
      TargetPath.Filled, 'Path properties differ');
    Require(SameValue(TargetPath.Points[1].X, PathData.Points[1].X) and
      SameValue(TargetPath.Points[2].Y, PathData.Points[2].Y),
      'Path points differ');
    Require((TargetPath.FillColor = PathData.FillColor) and
      (TargetPath.StrokeColor = PathData.StrokeColor) and
      SameValue(TargetPath.StrokeWidth, PathData.StrokeWidth) and
      (TargetPath.MifStrokeStyle = PathData.MifStrokeStyle),
      'Path style differs');
    TargetImage := TVectArtImageLayer(TargetDocument[4]);
    Require((TargetImage.Name = ImageData.Name) and
      (TargetImage.SourceKind = visLogo) and
      SameValue(TargetImage.Opacity, ImageData.Opacity),
      'Image properties differ');
    Require((Length(TargetImage.PngData) = Length(ImageData.PngData)) and
      (TargetImage.PngData[2] = ImageData.PngData[2]),
      'Image PNG data differs');
    Require(SameValue(TargetImage.Points[0].X,
      ImageData.Points[0].X) and SameValue(TargetImage.Points[2].Y,
      ImageData.Points[2].Y), 'Image points differ');

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
