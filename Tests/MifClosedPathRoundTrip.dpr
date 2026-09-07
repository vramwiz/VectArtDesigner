program MifClosedPathRoundTrip;

{$APPTYPE CONSOLE}

// Verify all closed-path paint modes through generated WebArt MIF data.

uses
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
  VectArtDesignerTextGeometry in
    'Source\Core\VectArtDesignerTextGeometry.pas',
  VectArtDesignerBezierGeometry in
    'Source\Editor\VectArtDesignerBezierGeometry.pas',
  VectArtDesignerRoundedRectangleGeometry in
    'Source\Editor\VectArtDesignerRoundedRectangleGeometry.pas',
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

procedure AddPath(Document: TVectArtDocument; const Name: string;
  OffsetX: Single; Filled: Boolean; StrokeWidth: Single;
  Bezier: Boolean = False);
var
  Data: TVectArtPathData;
begin
  Data := Default(TVectArtPathData);
  Data.Name := Name;
  Data.Points := [PointF(OffsetX, 20), PointF(OffsetX + 60, 20),
    PointF(OffsetX + 40, 80), PointF(OffsetX - 10, 60)];
  Data.Bezier := Bezier;
  Data.Closed := True;
  Data.Filled := Filled;
  Data.FillColor := clLime;
  Data.LineCap := vlcButt;
  Data.LineJoin := vljMiter;
  Data.AntiAlias := True;
  Data.Opacity := 1.0;
  Data.StrokeColor := clBlue;
  Data.StrokeStyle := vssSolid;
  Data.StrokeWidth := StrokeWidth;
  Data.Visible := True;
  Document.InsertPath(Document.LayerCount, Data);
end;

procedure AddRoundedRectangle(Document: TVectArtDocument);
var
  Data: TVectArtPathData;
  I: Integer;
  ScreenPoints: TArray<TPoint>;
begin
  Data := Default(TVectArtPathData);
  ScreenPoints := BuildRoundedRectanglePathPoints(Rect(450, 20, 650, 120));
  SetLength(Data.Points, Length(ScreenPoints));
  for I := 0 to High(ScreenPoints) do
    Data.Points[I] := PointF(ScreenPoints[I].X, ScreenPoints[I].Y);
  Data.Name := 'Rounded Rectangle 1';
  Data.BoundsEditing := True;
  Data.Closed := True;
  Data.Filled := True;
  Data.FillColor := clLime;
  Data.LineCap := vlcButt;
  Data.LineJoin := vljMiter;
  Data.AntiAlias := True;
  Data.Opacity := 1.0;
  Data.StrokeColor := clBlue;
  Data.StrokeStyle := vssSolid;
  Data.StrokeWidth := 2.0;
  Data.Visible := True;
  Document.InsertPath(Document.LayerCount, Data);
end;

var
  Container: TVectArtMifContainer;
  ErrorMessage: string;
  Path: TVectArtPathLayer;
  SourceDocument: TVectArtDocument;
  TargetDocument: TVectArtDocument;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Container := nil;
  SourceDocument := TVectArtDocument.Create;
  TargetDocument := TVectArtDocument.Create;
  try
    AddPath(SourceDocument, 'Path 1', 30, False, 2.0);
    AddPath(SourceDocument, 'Path 2', 130, True, 0.0);
    AddPath(SourceDocument, 'Path 3', 230, True, 2.0);
    AddPath(SourceDocument, 'Path 4', 330, True, 2.0, True);
    AddRoundedRectangle(SourceDocument);
    Require(TryCreateVectArtMifFromDocument(SourceDocument, Container,
      ErrorMessage), ErrorMessage);
    Require(TryLoadVectArtDocumentFromMif(Container, TargetDocument,
      ErrorMessage), ErrorMessage);
    Require(TargetDocument.LayerCount = 6,
      'Closed path MIF layer count differs');

    Path := TVectArtPathLayer(TargetDocument[1]);
    Require(Path.Closed and not Path.Filled and
      SameValue(Path.StrokeWidth, 2.0),
      'Outline-only closed path MIF differs');
    Path := TVectArtPathLayer(TargetDocument[2]);
    Require(Path.Closed and Path.Filled and
      SameValue(Path.StrokeWidth, 0.0),
      'Fill-only closed path MIF differs');
    Path := TVectArtPathLayer(TargetDocument[3]);
    Require(Path.Closed and Path.Filled and
      SameValue(Path.StrokeWidth, 2.0),
      'Fill-and-outline closed path MIF differs');
    Path := TVectArtPathLayer(TargetDocument[4]);
    Require(Path.Closed and not Path.Bezier and Path.Filled and
      (Length(Path.Points) > 4),
      'Closed Bezier was not preserved as a closed MIF polyline');
    Path := TVectArtPathLayer(TargetDocument[5]);
    Require(Path.Closed and Path.BoundsEditing and
      IsRoundedRectanglePathPoints(Path.Points),
      'Rounded rectangle bounds editing was not restored from MIF');
    Writeln('MIF closed path round-trip: PASS');
  finally
    Container.Free;
    TargetDocument.Free;
    SourceDocument.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
