program SvgDocumentRoundTrip;

{$APPTYPE CONSOLE}

// SVG固有情報を含む全レイヤーの可逆往復と、標準SVG要素の取り込みを検証する。

uses
  System.Classes,
  System.IOUtils,
  System.Math,
  System.NetEncoding,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
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
  if not SameValue(Expected, Actual, 0.0001) then
    raise Exception.CreateFmt('%s (expected %.9g, actual %.9g)',
      [MessageText, Expected, Actual]);
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
    Bitmap.SetSize(2, 2);
    Bitmap.Canvas.Brush.Color := clAqua;
    Bitmap.Canvas.FillRect(Rect(0, 0, 2, 2));
    Png.Assign(Bitmap);
    Png.SaveToStream(Stream);
    SetLength(Result, Stream.Size);
    Stream.Position := 0;
    if Length(Result) > 0 then
      Stream.ReadBuffer(Result[0], Length(Result));
  finally
    Stream.Free;
    Png.Free;
    Bitmap.Free;
  end;
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
  LockedFile: TFileStream;
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
    LineData.LineCap := vlcRound;
    LineData.AntiAlias := False;
    LineData.EndMarker := vlmStar;
    LineData.EndMarkerSize := 9.0;
    LineData.StartMarker := vlmOpenArrow;
    LineData.StartMarkerSize := 6.0;
    LineData.LineJoin := vljBevel;
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
    ImageData.PngData := CreatePlainPng;
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
    Require(SvgText.Contains('vad:start-marker="open-arrow"') and
      SvgText.Contains('stroke-width="1"'),
      'SVG open marker stroke does not follow the line width');
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
      (Line.StrokeStyle = LineData.StrokeStyle) and
      (Line.LineCap = LineData.LineCap) and
      (Line.LineJoin = LineData.LineJoin) and
      (Line.AntiAlias = LineData.AntiAlias) and
      (Line.EndMarker = LineData.EndMarker) and
      (Line.StartMarker = LineData.StartMarker) and
      SameValue(Line.EndMarkerSize, LineData.EndMarkerSize) and
      SameValue(Line.StartMarkerSize, LineData.StartMarkerSize),
      'Line stroke differs');
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
    TFile.WriteAllText(TestFileName, 'existing SVG must survive',
      TEncoding.UTF8);
    LockedFile := TFileStream.Create(TestFileName,
      fmOpenRead or fmShareDenyWrite);
    try
      Require(not TrySaveVectArtDocumentToSvgFile(SourceDocument,
        TestFileName, ErrorMessage),
        'Locked SVG was unexpectedly replaced');
    finally
      LockedFile.Free;
    end;
    Require(TFile.ReadAllText(TestFileName, TEncoding.UTF8) =
      'existing SVG must survive',
      'Failed SVG save damaged the existing file');
    Require(Length(TDirectory.GetFiles(ExtractFilePath(TestFileName),
      ExtractFileName(TestFileName) + '.*.tmp')) = 0,
      'Failed SVG save left a temporary file');
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
      'height="180"><line id="external-line" x1="12.5" y1="20" ' +
      'x2="140" y2="95.5" stroke="red" stroke-width="1" ' +
      'style="stroke:#123abc;stroke-width:2.5;stroke-dasharray:5 3;' +
      'stroke-linecap:square;stroke-linejoin:round;opacity:0.6;' +
      'stroke-opacity:0.5;' +
      'visibility:hidden"/></svg>';
    Require(TryLoadVectArtDocumentFromSvg(SvgText, ExternalDocument,
      ErrorMessage), ErrorMessage);
    Require((ExternalDocument.LayerCount = 2) and
      (ExternalDocument[1] is TVectArtLineLayer),
      'External SVG line was not imported');
    Line := TVectArtLineLayer(ExternalDocument[1]);
    Require(Line.Name = 'external-line', 'External SVG line name differs');
    RequireSameSingle(12.5, Line.StartPoint.X,
      'External SVG line start differs');
    RequireSameSingle(95.5, Line.EndPoint.Y,
      'External SVG line end differs');
    Require((Line.StrokeColor = TColor($00BC3A12)) and
      SameValue(Line.StrokeWidth, 2.5) and
      (Line.StrokeStyle = vssDashed) and (Line.LineCap = vlcSquare) and
      (Line.LineJoin = vljRound), 'External SVG line stroke differs');
    RequireSameSingle(0.3, Line.Opacity,
      'External SVG line opacity differs');
    Require(not Line.Visible, 'External SVG line visibility differs');
    SvgText := '<svg xmlns="http://www.w3.org/2000/svg" width="320" ' +
      'height="180"><line x1="0" y1="0" x2="100" y2="100"/></svg>';
    Require(TryLoadVectArtDocumentFromSvg(SvgText, ExternalDocument,
      ErrorMessage), ErrorMessage);
    Require(ExternalDocument.LayerCount = 1,
      'SVG line without a stroke should not create a visible layer');
    SvgText := '<svg xmlns="http://www.w3.org/2000/svg" width="320" ' +
      'height="180"><polyline id="external-polyline" ' +
      'points="0,10&#10; 30,40&#9;80,5" stroke="red" ' +
      'style="stroke:#112233;stroke-width:3.5;stroke-dasharray:8 4;' +
      'opacity:0.8;stroke-opacity:0.25;visibility:hidden"/>' +
      '<polygon points="100,20 180,25 160,90" fill="red" ' +
      'style="fill:#abcdef;stroke:#654321;stroke-width:2;' +
      'opacity:0.6;fill-opacity:0.5;stroke-opacity:0.5"/>' +
      '<polygon id="default-fill" points="200,20 260,20 230,70"/>' +
      '<polyline points="200,100 230,130 260,100"/></svg>';
    Require(TryLoadVectArtDocumentFromSvg(SvgText, ExternalDocument,
      ErrorMessage), ErrorMessage);
    Require((ExternalDocument.LayerCount = 4) and
      (ExternalDocument[1] is TVectArtPathLayer) and
      (ExternalDocument[2] is TVectArtPathLayer) and
      (ExternalDocument[3] is TVectArtPathLayer),
      'External SVG paths were not imported');
    Path := TVectArtPathLayer(ExternalDocument[1]);
    Require((Path.Name = 'external-polyline') and not Path.Closed and
      not Path.Filled and not Path.Visible,
      'External SVG polyline flags differ');
    Require((Length(Path.Points) = 3) and
      SameValue(Path.Points[1].X, 30.0) and
      SameValue(Path.Points[2].Y, 5.0),
      'External SVG polyline points differ');
    Require((Path.StrokeColor = TColor($00332211)) and
      SameValue(Path.StrokeWidth, 3.5) and
      (Path.StrokeStyle = vssDashed),
      'External SVG polyline stroke differs');
    RequireSameSingle(0.2, Path.Opacity,
      'External SVG polyline opacity differs');
    Path := TVectArtPathLayer(ExternalDocument[2]);
    Require((Path.Name = 'Path 2') and Path.Closed and Path.Filled and
      Path.Visible, 'External SVG polygon flags differ');
    Require((Path.FillColor = TColor($00EFCDAB)) and
      (Path.StrokeColor = TColor($00214365)) and
      SameValue(Path.StrokeWidth, 2.0),
      'External SVG polygon colors differ');
    RequireSameSingle(0.3, Path.Opacity,
      'External SVG polygon opacity differs');
    Path := TVectArtPathLayer(ExternalDocument[3]);
    Require((Path.Name = 'default-fill') and Path.Closed and Path.Filled and
      (Path.FillColor = clBlack) and (Path.StrokeWidth = 0),
      'External SVG polygon defaults differ');
    SvgText := '<svg xmlns="http://www.w3.org/2000/svg" width="320" ' +
      'height="180"><path id="straight-path" ' +
      'd="M10-5 L30 20 h15 v20 l-10,5 H20 V50 z" ' +
      'style="fill:#abcdef;stroke:#123456;stroke-width:2"/>' +
      '<path id="relative-path" d="m100 20 20 10 10-5" ' +
      'fill="none" stroke="blue"/>' +
      '<path id="curve-unsupported" d="M0 0 C10 10 20 10 30 0"/>' +
      '<rect id="path-survivor" x="1" y="2" width="3" ' +
      'height="4"/></svg>';
    Require(TryLoadVectArtDocumentFromSvg(SvgText, ExternalDocument,
      ErrorMessage), ErrorMessage);
    Require((ExternalDocument.LayerCount = 4) and
      (ExternalDocument[1] is TVectArtPathLayer) and
      (ExternalDocument[2] is TVectArtPathLayer) and
      (ExternalDocument[3] is TVectArtRectangleLayer),
      'Straight SVG path elements were not imported safely');
    Path := TVectArtPathLayer(ExternalDocument[1]);
    Require((Path.Name = 'straight-path') and Path.Closed and Path.Filled and
      (Length(Path.Points) = 7), 'Closed SVG path flags differ');
    Require(SameValue(Path.Points[0].X, 10.0) and
      SameValue(Path.Points[0].Y, -5.0) and
      SameValue(Path.Points[2].X, 45.0) and
      SameValue(Path.Points[3].Y, 40.0) and
      SameValue(Path.Points[6].Y, 50.0),
      'Closed SVG path points differ');
    Path := TVectArtPathLayer(ExternalDocument[2]);
    Require((Path.Name = 'relative-path') and not Path.Closed and
      not Path.Filled and (Length(Path.Points) = 3),
      'Relative SVG path flags differ');
    Require(SameValue(Path.Points[1].X, 120.0) and
      SameValue(Path.Points[1].Y, 30.0) and
      SameValue(Path.Points[2].X, 130.0) and
      SameValue(Path.Points[2].Y, 25.0),
      'Relative SVG path points differ');
    Require(TVectArtRectangleLayer(ExternalDocument[3]).Name =
      'path-survivor', 'Unsupported curve affected another SVG layer');
    SvgText := '<svg xmlns="http://www.w3.org/2000/svg" width="320" ' +
      'height="180"><g opacity="0.5"><rect id="group-rect" ' +
      'width="20" height="10" opacity="0.8"/>' +
      '<g visibility="hidden"><line id="group-line" x1="0" y1="0" ' +
      'x2="20" y2="20" stroke="red"/></g>' +
      '<path id="group-path" d="M0 30 L20 40" fill="none" ' +
      'stroke="blue"/></g><g transform="translate(100 0)">' +
      '<rect id="translated-group-rect" width="10" ' +
      'height="10"/></g></svg>';
    Require(TryLoadVectArtDocumentFromSvg(SvgText, ExternalDocument,
      ErrorMessage), ErrorMessage);
    Require((ExternalDocument.LayerCount = 5) and
      (ExternalDocument[1].Name = 'group-rect') and
      (ExternalDocument[2].Name = 'group-line') and
      (ExternalDocument[3].Name = 'group-path') and
      (ExternalDocument[4].Name = 'translated-group-rect'),
      'Nested SVG group order differs');
    RequireSameSingle(0.4, ExternalDocument[1].Opacity,
      'SVG group opacity differs');
    RequireSameSingle(0.5, ExternalDocument[2].Opacity,
      'Nested SVG group opacity differs');
    Require(not ExternalDocument[2].Visible,
      'Nested SVG group visibility differs');
    Require(ExternalDocument[3].Visible,
      'Visible SVG group child was hidden');
    Rectangle := TVectArtRectangleLayer(ExternalDocument[4]);
    Require(SameValue(Rectangle.Bounds.Left, 100.0) and
      SameValue(Rectangle.Bounds.Right, 110.0),
      'SVG translation was not applied to Rectangle');
    SvgText := '<svg xmlns="http://www.w3.org/2000/svg" width="320" ' +
      'height="180" style="shape-rendering:crispEdges"><g ' +
      'style="fill:#112233;stroke:#445566;stroke-width:3;' +
      'stroke-dasharray:6 2;stroke-linecap:round;' +
      'stroke-linejoin:bevel;fill-opacity:0.5;stroke-opacity:0.25">' +
      '<rect id="styled-group-rect" width="20" height="10"/>' +
      '<line id="styled-group-line" x1="0" y1="20" x2="20" ' +
      'y2="30"/><polygon id="styled-group-path" ' +
      'points="30,0 50,0 40,20"/><g stroke="blue">' +
      '<line id="overridden-group-line" x1="30" y1="30" x2="50" ' +
      'y2="40" style="stroke-width:2"/></g></g></svg>';
    Require(TryLoadVectArtDocumentFromSvg(SvgText, ExternalDocument,
      ErrorMessage), ErrorMessage);
    Require((ExternalDocument.LayerCount = 5) and
      (ExternalDocument[1] is TVectArtRectangleLayer) and
      (ExternalDocument[2] is TVectArtLineLayer) and
      (ExternalDocument[3] is TVectArtPathLayer) and
      (ExternalDocument[4] is TVectArtLineLayer),
      'Inherited SVG group styles did not preserve layer order');
    Rectangle := TVectArtRectangleLayer(ExternalDocument[1]);
    Require((Rectangle.FillColor = TColor($00332211)) and
      (Rectangle.StrokeColor = TColor($00665544)) and
      SameValue(Rectangle.StrokeWidth, 3.0) and
      (Rectangle.StrokeStyle = vssDashed),
      'Inherited SVG Rectangle style differs');
    RequireSameSingle(0.5, Rectangle.Opacity,
      'Inherited SVG Rectangle opacity differs');
    Line := TVectArtLineLayer(ExternalDocument[2]);
    Require((Line.StrokeColor = TColor($00665544)) and
      SameValue(Line.StrokeWidth, 3.0) and
      (Line.StrokeStyle = vssDashed) and (Line.LineCap = vlcRound) and
      (Line.LineJoin = vljBevel) and not Line.AntiAlias,
      'Inherited SVG Line style differs');
    RequireSameSingle(0.25, Line.Opacity,
      'Inherited SVG Line opacity differs');
    Path := TVectArtPathLayer(ExternalDocument[3]);
    Require((Path.FillColor = TColor($00332211)) and
      (Path.StrokeColor = TColor($00665544)) and
      SameValue(Path.StrokeWidth, 3.0) and
      (Path.StrokeStyle = vssDashed),
      'Inherited SVG Path style differs');
    RequireSameSingle(0.5, Path.Opacity,
      'Inherited SVG Path opacity differs');
    Line := TVectArtLineLayer(ExternalDocument[4]);
    Require((Line.StrokeColor = clBlue) and
      SameValue(Line.StrokeWidth, 2.0) and
      (Line.StrokeStyle = vssDashed),
      'Child SVG style did not override inherited style');
    SvgText := '<svg xmlns="http://www.w3.org/2000/svg" width="320" ' +
      'height="180"><g transform="matrix(1 0 0 1 5 0) ' +
      'translate(10 20) scale(2)">' +
      '<line id="transformed-line" x1="1" y1="2" x2="3" y2="4" ' +
      'stroke="red" stroke-width="2"/>' +
      '<g transform="rotate(90)"><polyline id="transformed-path" ' +
      'points="1,0 2,0" fill="none" stroke="blue"/></g>' +
      '<image id="transformed-image" x="0" y="0" width="1" ' +
      'height="1" href="data:image/png;base64,' +
      TNetEncoding.Base64.EncodeBytesToString(ImageData.PngData) +
      '"/><rect id="transformed-rectangle" width="10" ' +
      'height="10"/></g></svg>';
    Require(TryLoadVectArtDocumentFromSvg(SvgText, ExternalDocument,
      ErrorMessage), ErrorMessage);
    Require((ExternalDocument.LayerCount = 5) and
      (ExternalDocument[1] is TVectArtLineLayer) and
      (ExternalDocument[2] is TVectArtPathLayer) and
      (ExternalDocument[3] is TVectArtImageLayer) and
      (ExternalDocument[4] is TVectArtRectangleLayer),
      'Transformed SVG group layers differ');
    Line := TVectArtLineLayer(ExternalDocument[1]);
    Require(SameValue(Line.StartPoint.X, 17.0) and
      SameValue(Line.StartPoint.Y, 24.0) and
      SameValue(Line.EndPoint.X, 21.0) and
      SameValue(Line.EndPoint.Y, 28.0) and
      SameValue(Line.StrokeWidth, 4.0),
      'SVG group transform was not applied to Line');
    Path := TVectArtPathLayer(ExternalDocument[2]);
    Require(SameValue(Path.Points[0].X, 15.0) and
      SameValue(Path.Points[0].Y, 22.0) and
      SameValue(Path.Points[1].X, 15.0) and
      SameValue(Path.Points[1].Y, 24.0) and
      SameValue(Path.StrokeWidth, 2.0),
      'Nested SVG group transform was not applied to Path');
    Image := TVectArtImageLayer(ExternalDocument[3]);
    Require(SameValue(Image.Points[0].X, 15.0) and
      SameValue(Image.Points[0].Y, 20.0) and
      SameValue(Image.Points[1].X, 17.0) and
      SameValue(Image.Points[3].Y, 22.0),
      'SVG group transform was not applied to Image');
    Rectangle := TVectArtRectangleLayer(ExternalDocument[4]);
    Require(SameValue(Rectangle.Bounds.Left, 15.0) and
      SameValue(Rectangle.Bounds.Top, 20.0) and
      SameValue(Rectangle.Bounds.Width, 20.0) and
      SameValue(Rectangle.Bounds.Height, 20.0),
      'SVG group transform was not applied to Rectangle');
    SvgText := '<svg xmlns="http://www.w3.org/2000/svg" width="320" ' +
      'height="180"><g transform="translate(100 50) rotate(30) ' +
      'scale(2 3)"><rect id="orthogonal-rectangle" width="10" ' +
      'height="20" stroke="red" stroke-width="2"/></g>' +
      '<g transform="matrix(1 0 0.5 1 10 20)">' +
      '<rect id="sheared-rectangle" width="20" height="10" ' +
      'fill="#abcdef" stroke="blue" stroke-width="2"/></g></svg>';
    Require(TryLoadVectArtDocumentFromSvg(SvgText, ExternalDocument,
      ErrorMessage), ErrorMessage);
    Require((ExternalDocument.LayerCount = 3) and
      (ExternalDocument[1] is TVectArtRectangleLayer) and
      (ExternalDocument[2] is TVectArtPathLayer),
      'Transformed SVG rectangles were not classified');
    Rectangle := TVectArtRectangleLayer(ExternalDocument[1]);
    RequireSameSingle(20.0, Rectangle.Bounds.Width,
      'Orthogonal SVG rectangle width differs');
    RequireSameSingle(60.0, Rectangle.Bounds.Height,
      'Orthogonal SVG rectangle height differs');
    RequireSameSingle(30.0, Rectangle.RotationDegrees,
      'Orthogonal SVG rectangle rotation differs');
    RequireSameSingle(5.0, Rectangle.StrokeWidth,
      'Orthogonal SVG rectangle stroke differs');
    Path := TVectArtPathLayer(ExternalDocument[2]);
    Require((Path.Name = 'sheared-rectangle') and Path.Closed and
      Path.Filled and (Length(Path.Points) = 4),
      'Sheared SVG rectangle was not converted to Path');
    Require(SameValue(Path.Points[0].X, 10.0) and
      SameValue(Path.Points[0].Y, 20.0) and
      SameValue(Path.Points[1].X, 30.0) and
      SameValue(Path.Points[2].X, 35.0) and
      SameValue(Path.Points[2].Y, 30.0) and
      SameValue(Path.Points[3].X, 15.0),
      'Sheared SVG rectangle points differ');
    SvgText := '<svg xmlns="http://www.w3.org/2000/svg" width="320" ' +
      'height="180"><g transform="skewX(45)">' +
      '<rect id="skew-x-rectangle" width="10" height="10"/></g>' +
      '<line id="skew-y-line" x1="0" y1="0" x2="10" y2="0" ' +
      'stroke="red" transform="skewY(45)"/>' +
      '<g transform="skewX(90)"><line x1="0" y1="0" x2="10" ' +
      'y2="10" stroke="red"/></g>' +
      '<rect id="invalid-skew-survivor" width="5" height="5"/></svg>';
    Require(TryLoadVectArtDocumentFromSvg(SvgText, ExternalDocument,
      ErrorMessage), ErrorMessage);
    Require((ExternalDocument.LayerCount = 4) and
      (ExternalDocument[1] is TVectArtPathLayer) and
      (ExternalDocument[2] is TVectArtLineLayer) and
      (ExternalDocument[3].Name = 'invalid-skew-survivor'),
      'SVG skew transforms were not imported');
    Path := TVectArtPathLayer(ExternalDocument[1]);
    RequireSameSingle(0.0, Path.Points[0].X,
      'SVG skewX rectangle point 0 differs');
    RequireSameSingle(10.0, Path.Points[1].X,
      'SVG skewX rectangle point 1 differs');
    RequireSameSingle(20.0, Path.Points[2].X,
      'SVG skewX rectangle point 2 differs');
    RequireSameSingle(10.0, Path.Points[3].X,
      'SVG skewX rectangle point 3 differs');
    Line := TVectArtLineLayer(ExternalDocument[2]);
    RequireSameSingle(10.0, Line.EndPoint.X,
      'SVG skewY line X differs');
    RequireSameSingle(10.0, Line.EndPoint.Y,
      'SVG skewY line Y differs');
    SvgText := '<svg xmlns="http://www.w3.org/2000/svg" width="320" ' +
      'height="180"><image id="external-image" x="0" y="0" ' +
      'width="1" height="1" opacity="0.75" ' +
      'transform="matrix(80 10 -5 40 15 25)" ' +
      'href="data:image/png;base64,' +
      TNetEncoding.Base64.EncodeBytesToString(ImageData.PngData) +
      '"/></svg>';
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
    RequireSameSingle(35, Image.Points[1].Y,
      'External SVG image affine Y differs');
    RequireSameSingle(90, Image.Points[2].X,
      'External SVG image corner X differs');
    RequireSameSingle(65, Image.Points[3].Y,
      'External SVG image corner Y differs');
    RequireSameSingle(0.75, Image.Opacity,
      'External SVG image opacity differs');
    SvgText := '<svg xmlns="http://www.w3.org/2000/svg" width="320" ' +
      'height="180"><rect id="survivor" width="10" height="10"/>' +
      '<image width="10" height="10" ' +
      'href="data:image/png;base64,AAAA"/></svg>';
    Require(TryLoadVectArtDocumentFromSvg(SvgText, ExternalDocument,
      ErrorMessage), ErrorMessage);
    Require((ExternalDocument.LayerCount = 2) and
      (ExternalDocument[1] is TVectArtRectangleLayer),
      'Invalid SVG PNG was not skipped safely');
    ImageData.Name := 'Invalid PNG';
    ImageData.PngData := TBytes.Create(1, 2, 3);
    ExternalDocument.InsertImage(ExternalDocument.LayerCount, ImageData);
    Require(not TryCreateVectArtSvg(ExternalDocument, SvgText, ErrorMessage)
      and (ErrorMessage <> ''), 'Invalid PNG was accepted for SVG save');
    Writeln('SVG document round-trip: PASS');
  finally
    if TFile.Exists(TestFileName) then
      TFile.Delete(TestFileName);
    ExternalDocument.Free;
    TargetDocument.Free;
    SourceDocument.Free;
  end;
end.
