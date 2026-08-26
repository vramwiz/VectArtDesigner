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
  Line: TVectArtLineLayer;
  LineData: TVectArtLineData;
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
    SourceDocument.SelectedIndex := 3;

    Require(TryCreateVectArtSvg(SourceDocument, SvgText, ErrorMessage),
      ErrorMessage);
    Require(SvgText.Contains('xmlns:vad='), 'VAD namespace is missing');
    Require(SvgText.Contains('<rect '), 'SVG rect is missing');
    Require(SvgText.Contains('<line '), 'SVG line is missing');
    Require(TryLoadVectArtDocumentFromSvg(SvgText, TargetDocument,
      ErrorMessage), ErrorMessage);
    Require((TargetDocument.CanvasLayer.Width = 854) and
      (TargetDocument.CanvasLayer.Height = 480), 'Canvas size differs');
    Require(TargetDocument.CanvasLayer.Transparent,
      'Canvas transparency differs');
    Require(TargetDocument.CanvasLayer.BackgroundColor = TColor($00332211),
      'Canvas background differs');
    Require(TargetDocument.LayerCount = 4, 'Layer count differs');
    Require(TargetDocument.SelectedIndex = 3, 'Selection differs');
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
    Require(TrySaveVectArtDocumentToSvgFile(SourceDocument, TestFileName,
      ErrorMessage), ErrorMessage);
    Require(TryLoadVectArtDocumentFromSvgFile(TestFileName, TargetDocument,
      ErrorMessage), ErrorMessage);
    Require(TVectArtRectangleLayer(TargetDocument[1]).Name = Data.Name,
      'File round-trip name differs');

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
    Writeln('SVG document round-trip: PASS');
  finally
    if TFile.Exists(TestFileName) then
      TFile.Delete(TestFileName);
    ExternalDocument.Free;
    TargetDocument.Free;
    SourceDocument.Free;
  end;
end.
