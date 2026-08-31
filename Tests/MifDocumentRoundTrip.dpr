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

function HasExportIssue(const Report: TMifExportReport; LayerIndex: Integer;
  Kind: TMifExportIssueKind; const MessageFragment: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(Report.Issues) do
    if (Report.Issues[I].LayerIndex = LayerIndex) and
      (Report.Issues[I].Kind = Kind) and
      ((MessageFragment = '') or
      (Pos(MessageFragment, Report.Issues[I].MessageText) > 0)) then
      Exit(True);
end;

function ReadUInt32BE(const Bytes: TBytes; Offset: Integer): UInt32;
begin
  Result := (UInt32(Bytes[Offset]) shl 24) or
    (UInt32(Bytes[Offset + 1]) shl 16) or
    (UInt32(Bytes[Offset + 2]) shl 8) or UInt32(Bytes[Offset + 3]);
end;

function TryFindWadaValue(const Png: TBytes; const Key: string;
  ValueSize: Integer; out ValueOffset: Integer): Boolean;
var
  ChunkLength: Integer;
  ChunkType: string;
  KeyEnd: Integer;
  Offset: Integer;
begin
  Result := False;
  ValueOffset := -1;
  Offset := 8;
  while Offset + 12 <= Length(Png) do
  begin
    ChunkLength := Integer(ReadUInt32BE(Png, Offset));
    if (ChunkLength < 0) or (Offset + 12 + ChunkLength > Length(Png)) then
      Exit;
    ChunkType := TEncoding.ASCII.GetString(Png, Offset + 4, 4);
    if ChunkType = 'waDA' then
    begin
      KeyEnd := Offset + 8;
      while (KeyEnd < Offset + 8 + ChunkLength) and
        (Png[KeyEnd] <> 0) do
        Inc(KeyEnd);
      if (KeyEnd < Offset + 8 + ChunkLength) and
        SameText(TEncoding.UTF8.GetString(Png, Offset + 8,
          KeyEnd - Offset - 8), Key) and
        (KeyEnd + 1 + ValueSize <= Offset + 8 + ChunkLength) then
      begin
        ValueOffset := KeyEnd + 1;
        Exit(True);
      end;
    end;
    Inc(Offset, ChunkLength + 12);
  end;
end;

function ReadWadaInteger(const Png: TBytes; const Key: string): Int32;
var
  Bits: UInt32;
  ValueOffset: Integer;
begin
  Require(TryFindWadaValue(Png, Key, SizeOf(Result), ValueOffset),
    'Missing waDA integer: ' + Key);
  Bits := ReadUInt32BE(Png, ValueOffset);
  Move(Bits, Result, SizeOf(Result));
end;

function ReadWadaDouble(const Png: TBytes; const Key: string): Double;
var
  Bits: UInt64;
  I: Integer;
  ValueOffset: Integer;
begin
  Require(TryFindWadaValue(Png, Key, SizeOf(Result), ValueOffset),
    'Missing waDA double: ' + Key);
  Bits := 0;
  for I := 0 to 7 do
    Bits := (Bits shl 8) or Png[ValueOffset + I];
  Move(Bits, Result, SizeOf(Result));
end;

function BytesEqual(const Left, Right: TBytes): Boolean;
begin
  Result := Length(Left) = Length(Right);
  if Result and (Length(Left) > 0) then
    Result := CompareMem(@Left[0], @Right[0], Length(Left));
end;

procedure RequireMatrixMapsPoint(const Png: TBytes; PointIndex: Integer;
  A, B, C, D, E, F: Double);
var
  ImageX: Int32;
  ImageY: Int32;
  OriginalX: Int32;
  OriginalY: Int32;
begin
  ImageX := ReadWadaInteger(Png, Format('image position%d x', [PointIndex]));
  ImageY := ReadWadaInteger(Png, Format('image position%d y', [PointIndex]));
  OriginalX := ReadWadaInteger(Png,
    Format('vector original position%d x', [PointIndex]));
  OriginalY := ReadWadaInteger(Png,
    Format('vector original position%d y', [PointIndex]));
  Require(Round(A * OriginalX + C * OriginalY + E) = ImageX,
    Format('Vector matrix does not map position%d X', [PointIndex]));
  Require(Round(B * OriginalX + D * OriginalY + F) = ImageY,
    Format('Vector matrix does not map position%d Y', [PointIndex]));
end;

var
  Container: TVectArtMifContainer;
  Data: TVectArtRectangleData;
  ErrorMessage: string;
  ExactContainer: TVectArtMifContainer;
  ExactDocument: TVectArtDocument;
  ExportReport: TMifExportReport;
  I: Integer;
  MatrixA: Double;
  MatrixB: Double;
  MatrixC: Double;
  MatrixD: Double;
  MatrixE: Double;
  MatrixF: Double;
  LineData: TVectArtLineData;
  PathData: TVectArtPathData;
  Memory: TMemoryStream;
  ReadContainer: TVectArtMifContainer;
  ReferenceContainer: TVectArtMifContainer;
  Reader: IVectArtMifContainerReader;
  SourceDocument: TVectArtDocument;
  TargetDocument: TVectArtDocument;
  TargetRectangle: TVectArtRectangleLayer;
  TargetLine: TVectArtLineLayer;
  TargetPath: TVectArtPathLayer;
  TwoPointContainer: TVectArtMifContainer;
  TwoPointDocument: TVectArtDocument;
  TwoPointReadDocument: TVectArtDocument;
  UnsupportedContainer: TVectArtMifContainer;
  UnsupportedDocument: TVectArtDocument;
  Writer: IVectArtMifContainerWriter;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  SourceDocument := TVectArtDocument.Create;
  TargetDocument := TVectArtDocument.Create;
  Container := nil;
  ExactContainer := nil;
  ExactDocument := TVectArtDocument.Create;
  ReadContainer := nil;
  ReferenceContainer := nil;
  TwoPointContainer := nil;
  TwoPointDocument := TVectArtDocument.Create;
  TwoPointReadDocument := TVectArtDocument.Create;
  UnsupportedContainer := nil;
  UnsupportedDocument := TVectArtDocument.Create;
  Memory := TMemoryStream.Create;
  try
    Data := Default(TVectArtRectangleData);
    Data.Name := 'Rectangle 1';
    Data.Bounds := TRectF.Create(40, 50, 220, 180);
    Data.FillColor := clWhite;
    Data.Opacity := 1.0;
    Data.Visible := True;
    ExactDocument.InsertRectangle(1, Data);
    LineData := Default(TVectArtLineData);
    LineData.AntiAlias := True;
    LineData.EndPoint := TPointF.Create(300, 200);
    LineData.EndMarkerSize := 4.0;
    LineData.Name := 'Line 1';
    LineData.Opacity := 1.0;
    LineData.StartMarkerSize := 4.0;
    LineData.StartPoint := TPointF.Create(100, 100);
    LineData.StrokeColor := clBlack;
    LineData.StrokeWidth := 1.0;
    LineData.Visible := True;
    ExactDocument.InsertLine(2, LineData);
    PathData := Default(TVectArtPathData);
    PathData.Name := 'Path 1';
    PathData.Points := [PointF(100, 200), PointF(200, 250),
      PointF(300, 200)];
    PathData.FillColor := clWhite;
    PathData.Opacity := 1.0;
    PathData.StrokeColor := clBlack;
    PathData.StrokeWidth := 1.0;
    PathData.Visible := True;
    ExactDocument.InsertPath(3, PathData);
    Require(TryCreateVectArtMifFromDocument(ExactDocument, nil,
      ExactContainer, ExportReport, ErrorMessage), ErrorMessage);
    Require(ExportReport.Compatibility = mecExact,
      'Exactly representable document was reported as incompatible');
    Require(Length(ExportReport.Issues) = 0,
      'Exactly representable document has export issues');

    PathData := Default(TVectArtPathData);
    PathData.Name := 'Path 1';
    PathData.Points := [PointF(100, 100)];
    PathData.Opacity := 1.0;
    PathData.StrokeColor := clBlack;
    PathData.StrokeWidth := 1.0;
    PathData.Visible := True;
    UnsupportedDocument.InsertPath(1, PathData);
    Require(not TryCreateVectArtMifFromDocument(UnsupportedDocument, nil,
      UnsupportedContainer, ExportReport, ErrorMessage),
      'One-point Path unexpectedly generated a MIF');
    Require((UnsupportedContainer = nil) and
      (ExportReport.Compatibility = mecUnsupported),
      'One-point Path was not reported as unsupported');
    Require(HasExportIssue(ExportReport, 1, meikUnsupported, '頂点'),
      'One-point Path issue details are missing');

    PathData.Points := [PointF(100, 100), PointF(300, 200)];
    PathData.Name := 'Two-point path';
    TwoPointDocument.InsertPath(1, PathData);
    Require(TryCreateVectArtMifFromDocument(TwoPointDocument, nil,
      TwoPointContainer, ExportReport, ErrorMessage), ErrorMessage);
    Require((ExportReport.Compatibility = mecNeedsConfirmation) and
      HasExportIssue(ExportReport, 1, meikConversion, 'Line 1'),
      'Two-point Path conversion was not reported');
    Require(TryLoadVectArtDocumentFromMif(TwoPointContainer,
      TwoPointReadDocument, ErrorMessage), ErrorMessage);
    Require((TwoPointReadDocument.LayerCount = 2) and
      (TwoPointReadDocument[1] is TVectArtLineLayer),
      'Two-point Path was not converted to a Line as reported');
    TargetLine := TVectArtLineLayer(TwoPointReadDocument[1]);
    Require(SameValue(TargetLine.StartPoint.X, 100.0, 0.000001) and
      SameValue(TargetLine.StartPoint.Y, 100.0, 0.000001) and
      SameValue(TargetLine.EndPoint.X, 300.0, 0.000001) and
      SameValue(TargetLine.EndPoint.Y, 200.0, 0.000001),
      'Two-point Path endpoints changed during Line conversion');

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
    LineData.LineCap := vlcRound;
    LineData.AntiAlias := False;
    LineData.EndMarker := vlmSlash;
    LineData.EndMarkerSize := 100.0;
    LineData.StartMarker := vlmConcaveArrow;
    LineData.StartMarkerSize := 6.0;
    LineData.LineJoin := vljBevel;
    LineData.Name := 'MIF line';
    LineData.Opacity := 0.8;
    LineData.StrokeColor := TColor($00CC4400);
    LineData.StrokeStyle := vssDashDot;
    LineData.StrokeWidth := 7.0;
    LineData.Visible := True;
    SourceDocument.InsertLine(2, LineData);
    PathData.Name := 'MIF polygon';
    PathData.Points := [PointF(300, 40), PointF(520, 70),
      PointF(470, 170), PointF(330, 150)];
    PathData.Closed := True;
    PathData.Filled := True;
    PathData.FillColor := TColor($0080C040);
    PathData.StrokeColor := TColor($004020D0);
    PathData.StrokeStyle := vssShortDash;
    PathData.StrokeWidth := 3.0;
    PathData.Opacity := 0.7;
    PathData.Visible := True;
    PathData.Locked := False;
    SourceDocument.InsertPath(3, PathData);

    Require(TryCreateVectArtMifFromDocument(SourceDocument, nil, Container,
      ExportReport, ErrorMessage), ErrorMessage);
    Require(ExportReport.Compatibility = mecNeedsConfirmation,
      'MIF export compatibility warning was not reported');
    Require(Length(ExportReport.Issues) >= 4,
      'MIF export issue details are missing');
    Require((ExportReport.Issues[0].LayerIndex = 1) and
      (ExportReport.Issues[0].Kind = meikConversion),
      'Rectangle conversion issue was not reported first');
    Require(HasExportIssue(ExportReport, 2, meikConversion,
      '終点マーカーサイズ'),
      'Line marker-size conversion was not reported');
    Require(not HasExportIssue(ExportReport, 2, meikUnchecked, ''),
      'Line is still reported as unchecked');
    Require(HasExportIssue(ExportReport, 3, meikConversion, '不透明度'),
      'Path opacity conversion was not reported');
    Require(not HasExportIssue(ExportReport, 3, meikUnchecked, ''),
      'Path is still reported as unchecked');
    Require(Container.ChunkCount = 16, 'Unexpected MIF chunk count');
    Require((Length(Container[0].Data) = 4) and
      (Container[0].Data[0] = 0) and (Container[0].Data[1] = 0) and
      (Container[0].Data[2] = 0) and (Container[0].Data[3] = 14),
      'MHDR chunk count differs');
    MatrixA := ReadWadaDouble(Container[3].Data, 'vector matrix a');
    MatrixB := ReadWadaDouble(Container[3].Data, 'vector matrix b');
    MatrixC := ReadWadaDouble(Container[3].Data, 'vector matrix c');
    MatrixD := ReadWadaDouble(Container[3].Data, 'vector matrix d');
    MatrixE := ReadWadaDouble(Container[3].Data, 'vector matrix e');
    MatrixF := ReadWadaDouble(Container[3].Data, 'vector matrix f');
    for I := 1 to 4 do
      RequireMatrixMapsPoint(Container[3].Data, I, MatrixA, MatrixB,
        MatrixC, MatrixD, MatrixE, MatrixF);
    Reader := CreateVectArtMifContainerReader;
    Require(Reader.TryReadFile('mif' + PathDelim + #$56DB#$89D2 + '_' +
      #$56DE#$8EE2 + '2.mif', ReferenceContainer, ErrorMessage),
      ErrorMessage);
    Require(BytesEqual(Container[5].Data, ReferenceContainer[5].Data),
      'New rectangle vector payload differs from WebArt reference');
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
    Require(TargetDocument.LayerCount = 4, 'Layer count differs');
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
    Require(TargetLine.LineCap = LineData.LineCap,
      'Line cap differs');
    Require(TargetLine.LineJoin = LineData.LineJoin,
      'Line join differs');
    Require(TargetLine.AntiAlias = LineData.AntiAlias,
      'Line anti-alias differs');
    Require(TargetLine.EndMarker = LineData.EndMarker,
      'Line end marker differs');
    Require(TargetLine.StartMarker = LineData.StartMarker,
      'Line start marker differs');
    Require(SameValue(TargetLine.EndMarkerSize, 20.0),
      'Line end marker size was not converted as reported');
    Require(SameValue(TargetLine.StartMarkerSize, LineData.StartMarkerSize),
      'Line start marker size differs');
    TargetPath := TVectArtPathLayer(TargetDocument[3]);
    Require((Length(TargetPath.Points) = Length(PathData.Points)) and
      TargetPath.Closed and TargetPath.Filled, 'Path properties differ');
    Require(SameValue(TargetPath.Points[2].X, PathData.Points[2].X,
      0.000001) and SameValue(TargetPath.Points[2].Y,
      PathData.Points[2].Y, 0.000001), 'Path points differ');
    Require(ColorToRGB(TargetPath.FillColor) =
      ColorToRGB(PathData.FillColor), 'Path fill color differs');
    Require(ColorToRGB(TargetPath.StrokeColor) =
      ColorToRGB(PathData.StrokeColor), 'Path stroke color differs');
    Require(SameValue(TargetPath.StrokeWidth, PathData.StrokeWidth,
      0.000001), 'Path stroke width differs');
    Require(TargetPath.StrokeStyle = PathData.StrokeStyle,
      'Path stroke style differs');
    Writeln('MIF document round-trip: PASS');
  finally
    Memory.Free;
    ReadContainer.Free;
    ReferenceContainer.Free;
    ExactContainer.Free;
    ExactDocument.Free;
    TwoPointContainer.Free;
    TwoPointDocument.Free;
    TwoPointReadDocument.Free;
    UnsupportedContainer.Free;
    UnsupportedDocument.Free;
    Container.Free;
    TargetDocument.Free;
    SourceDocument.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
