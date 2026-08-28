program SvgDocumentRoundTrip;

{$APPTYPE CONSOLE}

// SVG固有情報を含む可逆往復と、標準rectだけのSVG取り込みを検証する。

uses
  System.IOUtils,
  System.Math,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  VectArtDesignerDocument in
    'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerSvgDocument in
    'Source\Persistence\Svg\VectArtDesignerSvgDocument.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure RequireSameSingle(Expected, Actual: Single;
  const MessageText: string);
begin
  Require(SameValue(Expected, Actual, 0.000001), MessageText);
end;

var
  Data: TVectArtRectangleData;
  Data2: TVectArtRectangleData;
  ErrorMessage: string;
  ExternalDocument: TVectArtDocument;
  Image: TVectArtImageLayer;
  ImageData: TVectArtImageData;
  Line: TVectArtLineLayer;
  LineData: TVectArtLineData;
  Path: TVectArtPathLayer;
  PathData: TVectArtPathData;
  Rectangle: TVectArtRectangleLayer;
  SourceDocument: TVectArtDocument;
  SvgText: string;
  TargetDocument: TVectArtDocument;
  TestFileName: string;
begin
  SourceDocument := TVectArtDocument.Create;
  TargetDocument := TVectArtDocument.Create;
  ExternalDocument := TVectArtDocument.Create;
  TestFileName := TPath.Combine(TPath.GetTempPath,
    'VectArtDesignerSvgDocumentRoundTrip.svg');
  try
    SourceDocument.SetCanvasSize(854, 480);
    SourceDocument.CanvasLayer.BackgroundColor := TColor($00332211);
    SourceDocument.CanvasLayer.Transparent := True;
    Data.Name := '四角 & "A"';
    Data.Bounds := TRectF.Create(10.25, -5.5, 210.75, 94.125);
    Data.FillColor := clBtnFace;
    Data.Opacity := 0.625;
    Data.RotationDegrees := 27.5;
    Data.StrokeColor := TColor($00112233);
    Data.StrokeStyle := vssDashDotDot;
    Data.StrokeWidth := 3.5;
    Data.Visible := False;
    Data.Locked := True;
    SourceDocument.InsertRectangle(1, Data);
    Data2.Name := '前面';
    Data2.Bounds := TRectF.Create(300, 120, 420, 240);
    Data2.FillColor := clRed;
    Data2.Opacity := 1.0;
    Data2.RotationDegrees := 0.0;
    Data2.StrokeColor := clBlack;
    Data2.StrokeStyle := vssSolid;
    Data2.StrokeWidth := 0.0;
    Data2.Visible := True;
    Data2.Locked := False;
    SourceDocument.InsertRectangle(2, Data2);
    LineData.StartPoint := TPointF.Create(50, 60);
    LineData.EndPoint := TPointF.Create(500, 300);
    LineData.Locked := False;
    LineData.Name := '斜線';
    LineData.Opacity := 0.8;
    LineData.StrokeColor := TColor($0000AAFF);
    LineData.StrokeStyle := vssShortDash;
    LineData.StrokeWidth := 6.0;
    LineData.Visible := True;
    SourceDocument.InsertLine(3, LineData);
    PathData.Name := 'Polygon';
    PathData.Points := [PointF(520, 40), PointF(760, 80),
      PointF(700, 220), PointF(560, 180)];
    PathData.Closed := True;
    PathData.Filled := True;
    PathData.FillColor := TColor($004080C0);
    PathData.Locked := False;
    PathData.Opacity := 0.7;
    PathData.StrokeColor := TColor($00AA2200);
    PathData.StrokeStyle := vssLongDash;
    PathData.StrokeWidth := 4;
    PathData.Visible := True;
    SourceDocument.InsertPath(4, PathData);
    ImageData.Name := 'Logo image';
    ImageData.Locked := True;
    ImageData.Opacity := 0.45;
    ImageData.PngData := [$89, $50, $4E, $47, $0D, $0A];
    ImageData.Points[0] := PointF(700, 300);
    ImageData.Points[1] := PointF(580, 280);
    ImageData.Points[2] := PointF(565, 370);
    ImageData.Points[3] := PointF(685, 390);
    ImageData.SourceKind := visLogo;
    ImageData.Visible := False;
    SourceDocument.InsertImage(5, ImageData);
    SourceDocument.SelectedIndex := 5;

    Require(TryCreateVectArtSvg(SourceDocument, SvgText, ErrorMessage),
      ErrorMessage);
    Require(SvgText.Contains('xmlns:vad='), 'VAD namespace is missing');
    Require(SvgText.Contains('<rect '), 'SVG rect is missing');
    Require(SvgText.Contains('<line '), 'SVG line is missing');
    Require(SvgText.Contains('<polygon '), 'SVG polygon is missing');
    Require(SvgText.Contains('<image '), 'SVG image is missing');
    Require(SvgText.Contains('data:image/png;base64,'),
      'SVG embedded PNG is missing');
    Require(TryLoadVectArtDocumentFromSvg(SvgText, TargetDocument,
      ErrorMessage), ErrorMessage);
    Require((TargetDocument.CanvasLayer.Width = 854) and
      (TargetDocument.CanvasLayer.Height = 480), 'Canvas size differs');
    Require(TargetDocument.CanvasLayer.Transparent,
      'Canvas transparency differs');
    Require(TargetDocument.CanvasLayer.BackgroundColor = TColor($00332211),
      'Canvas background differs');
    Require(TargetDocument.LayerCount = 6, 'Layer count differs');
    Require(TargetDocument.SelectedIndex = 5, 'Selection differs');
    Rectangle := TVectArtRectangleLayer(TargetDocument[1]);
    Require(Rectangle.Name = Data.Name, 'Layer name differs');
    Require(Rectangle.Locked, 'Layer lock differs');
    Require(not Rectangle.Visible, 'Layer visibility differs');
    Require(Rectangle.FillColor = Data.FillColor, 'Fill color differs');
    Require(Rectangle.StrokeColor = Data.StrokeColor,
      'Stroke color differs');
    Require(SameValue(Rectangle.StrokeWidth, Data.StrokeWidth),
      'Stroke width differs');
    Require(Rectangle.StrokeStyle = Data.StrokeStyle,
      'Stroke style differs');
    RequireSameSingle(Data.Bounds.Left, Rectangle.Bounds.Left,
      'Left differs');
    RequireSameSingle(Data.Bounds.Top, Rectangle.Bounds.Top, 'Top differs');
    RequireSameSingle(Data.Bounds.Right, Rectangle.Bounds.Right,
      'Right differs');
    RequireSameSingle(Data.Bounds.Bottom, Rectangle.Bounds.Bottom,
      'Bottom differs');
    RequireSameSingle(Data.Opacity, Rectangle.Opacity, 'Opacity differs');
    RequireSameSingle(Data.RotationDegrees, Rectangle.RotationDegrees,
      'Rotation differs');
    Rectangle := TVectArtRectangleLayer(TargetDocument[2]);
    Require(Rectangle.Name = Data2.Name, 'Front layer name differs');
    Require(Rectangle.FillColor = Data2.FillColor,
      'Front layer fill differs');
    Require(Rectangle.Visible and not Rectangle.Locked,
      'Front layer flags differ');
    Line := TVectArtLineLayer(TargetDocument[3]);
    Require(Line.Name = LineData.Name, 'Line name differs');
    RequireSameSingle(LineData.StartPoint.X, Line.StartPoint.X,
      'Line start differs');
    RequireSameSingle(LineData.EndPoint.Y, Line.EndPoint.Y,
      'Line end differs');
    Require((Line.StrokeColor = LineData.StrokeColor) and
      (Line.StrokeStyle = LineData.StrokeStyle), 'Line stroke differs');
    Path := TVectArtPathLayer(TargetDocument[4]);
    Require((Length(Path.Points) = Length(PathData.Points)) and
      Path.Closed and Path.Filled, 'Path properties differ');
    RequireSameSingle(PathData.Points[2].X, Path.Points[2].X,
      'Path point X differs');
    RequireSameSingle(PathData.Points[2].Y, Path.Points[2].Y,
      'Path point Y differs');
    Require((Path.FillColor = PathData.FillColor) and
      (Path.StrokeColor = PathData.StrokeColor) and
      (Path.StrokeStyle = PathData.StrokeStyle), 'Path style differs');
    Image := TVectArtImageLayer(TargetDocument[5]);
    Require((Image.Name = ImageData.Name) and Image.Locked and
      not Image.Visible and (Image.SourceKind = visLogo),
      'Image properties differ');
    RequireSameSingle(ImageData.Opacity, Image.Opacity,
      'Image opacity differs');
    Require((Length(Image.PngData) = Length(ImageData.PngData)) and
      (Image.PngData[4] = ImageData.PngData[4]),
      'Image PNG data differs');
    RequireSameSingle(ImageData.Points[0].X, Image.Points[0].X,
      'Image point 0 X differs');
    RequireSameSingle(ImageData.Points[1].Y, Image.Points[1].Y,
      'Image point 1 Y differs');
    RequireSameSingle(ImageData.Points[2].X, Image.Points[2].X,
      'Image point 2 X differs');
    RequireSameSingle(ImageData.Points[3].Y, Image.Points[3].Y,
      'Image point 3 Y differs');
    Require(TrySaveVectArtDocumentToSvgFile(SourceDocument, TestFileName,
      ErrorMessage), ErrorMessage);
    Require(TryLoadVectArtDocumentFromSvgFile(TestFileName, TargetDocument,
      ErrorMessage), ErrorMessage);
    Require(TVectArtRectangleLayer(TargetDocument[1]).Name = Data.Name,
      'File round-trip name differs');
    Require(TVectArtImageLayer(TargetDocument[5]).Name = ImageData.Name,
      'File round-trip image differs');

    SvgText := '<svg xmlns="http://www.w3.org/2000/svg" width="320" ' +
      'height="180"><rect id="external" x="12.5" y="20" width="40" ' +
      'height="30" style="fill:#12ab34;opacity:0.5"/></svg>';
    Require(TryLoadVectArtDocumentFromSvg(SvgText, ExternalDocument,
      ErrorMessage), ErrorMessage);
    Require(ExternalDocument.LayerCount = 2,
      'External SVG rectangle was not imported');
    Rectangle := TVectArtRectangleLayer(ExternalDocument[1]);
    Require(Rectangle.Name = 'external', 'External SVG name differs');
    Require(Rectangle.FillColor = TColor($0034AB12),
      'External SVG fill differs');
    RequireSameSingle(0.5, Rectangle.Opacity,
      'External SVG opacity differs');
    SvgText := '<svg xmlns="http://www.w3.org/2000/svg" width="320" ' +
      'height="180"><image id="external-image" x="15" y="25" ' +
      'width="80" height="40" opacity="0.75" ' +
      'href="data:image/png;base64,iVBORw0K"/></svg>';
    Require(TryLoadVectArtDocumentFromSvg(SvgText, ExternalDocument,
      ErrorMessage), ErrorMessage);
    Require(ExternalDocument.LayerCount = 2,
      'External SVG image was not imported');
    Image := TVectArtImageLayer(ExternalDocument[1]);
    Require(Image.Name = 'external-image',
      'External SVG image name differs');
    RequireSameSingle(15, Image.Points[0].X,
      'External SVG image X differs');
    RequireSameSingle(95, Image.Points[1].X,
      'External SVG image width differs');
    RequireSameSingle(65, Image.Points[3].Y,
      'External SVG image height differs');
    RequireSameSingle(0.75, Image.Opacity,
      'External SVG image opacity differs');
    Writeln('SVG document round-trip: PASS');
  finally
    if TFile.Exists(TestFileName) then
      TFile.Delete(TestFileName);
    ExternalDocument.Free;
    TargetDocument.Free;
    SourceDocument.Free;
  end;
end.
