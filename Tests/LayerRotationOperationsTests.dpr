// Fixed-angle selection rotation and undo/redo coverage for editable layers.
program LayerRotationOperationsTests;

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerEditHistory in 'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerEditCommands in 'Source\Core\Commands\VectArtDesignerEditCommands.pas',
  VectArtDesignerLayerRotationOperations in 'Source\Core\Commands\VectArtDesignerLayerRotationOperations.pas',
  VectArtDesignerBezierGeometry in 'Source\Editor\Geometry\VectArtDesignerBezierGeometry.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure Near(Actual, Expected: Single; const MessageText: string);
begin
  Require(SameValue(Actual, Expected, 0.001), MessageText);
end;

function RectangleData: TVectArtRectangleData;
begin
  Result := Default(TVectArtRectangleData);
  Result.Bounds := RectF(10, 10, 30, 30);
  Result.FillColor := clWhite;
  Result.Filled := True;
  Result.Name := 'Rectangle';
  Result.Opacity := 1;
  Result.Shape := vpsRectangle;
  Result.StrokeColor := clBlack;
  Result.StrokeStyle := vssSolid;
  Result.StrokeWidth := 1;
  Result.Visible := True;
end;

function LineData: TVectArtLineData;
begin
  Result := Default(TVectArtLineData);
  Result.Name := 'Line';
  Result.Opacity := 1;
  Result.StartPoint := PointF(100, 10);
  Result.EndPoint := PointF(120, 30);
  Result.StrokeColor := clBlack;
  Result.StrokeStyle := vssSolid;
  Result.StrokeWidth := 1;
  Result.Visible := True;
end;

function TextData: TVectArtTextData;
begin
  Result := Default(TVectArtTextData);
  Result.Bounds := RectF(20, 40, 100, 80);
  Result.FlipHorizontal := True;
  Result.FontFamily := 'Segoe UI';
  Result.FontSize := 20;
  Result.Name := 'Text';
  Result.Opacity := 1;
  Result.RotationDegrees := 20;
  Result.Text := 'Rotate';
  Result.TextColor := clBlack;
  Result.Visible := True;
end;

procedure Run;
var
  Document: TVectArtDocument;
  History: TVectArtEditHistory;
  ImageData: TVectArtImageData;
  ImageLayer: TVectArtImageLayer;
  LineLayer: TVectArtLineLayer;
  PathData: TVectArtPathData;
  PathLayer: TVectArtPathLayer;
  RectangleLayer: TVectArtRectangleLayer;
  TextLayer: TVectArtTextLayer;
begin
  Document := TVectArtDocument.Create;
  History := TVectArtEditHistory.Create;
  try
    Document.InsertRectangle(Document.LayerCount, RectangleData);
    Document.InsertLine(Document.LayerCount, LineData);
    Document.SetSelectedLayers([1, 2]);
    RotateVectArtSelection(Document, History, 90);
    RectangleLayer := TVectArtRectangleLayer(Document[1]);
    LineLayer := TVectArtLineLayer(Document[2]);
    Near(RectangleLayer.Bounds.Left, 55, 'shared-center rectangle X');
    Near(RectangleLayer.Bounds.Top, -35, 'shared-center rectangle Y');
    Near(RectangleLayer.RotationDegrees, 90, 'rectangle angle');
    Near(LineLayer.StartPoint.X, 75, 'shared-center line start X');
    Near(LineLayer.StartPoint.Y, 55, 'shared-center line start Y');
    Require(History.CanUndo, 'rotation was not added to history');
    History.Undo;
    Near(RectangleLayer.Bounds.Left, 10, 'rectangle undo');
    Near(RectangleLayer.RotationDegrees, 0, 'angle undo');
    Near(LineLayer.StartPoint.X, 100, 'line undo');
    History.Redo;
    Near(RectangleLayer.RotationDegrees, 90, 'angle redo');

    Document.InsertText(Document.LayerCount, TextData);
    Document.SetSelectedLayers([3]);
    RotateVectArtSelection(Document, History, -90);
    TextLayer := TVectArtTextLayer(Document[3]);
    Near(TextLayer.RotationDegrees, -70, 'text angle');
    Require(TextLayer.FlipHorizontal and not TextLayer.FlipVertical,
      'text flip state changed during rotation');
    History.Undo;
    Near(TextLayer.RotationDegrees, 20, 'text angle undo');

    PathData := Default(TVectArtPathData);
    PathData.Name := 'Path';
    PathData.Opacity := 1;
    PathData.Points := [PointF(10, 100), PointF(30, 120),
      PointF(20, 140)];
    PathData.StrokeColor := clBlack;
    PathData.StrokeStyle := vssSolid;
    PathData.StrokeWidth := 1;
    PathData.Visible := True;
    Document.InsertPath(Document.LayerCount, PathData);
    ImageData := Default(TVectArtImageData);
    ImageData.Name := 'Image';
    ImageData.Opacity := 1;
    ImageData.Points[0] := PointF(100, 100);
    ImageData.Points[1] := PointF(120, 100);
    ImageData.Points[2] := PointF(120, 120);
    ImageData.Points[3] := PointF(100, 120);
    ImageData.Visible := True;
    Document.InsertImage(Document.LayerCount, ImageData);
    Document.SetSelectedLayers([4, 5]);
    RotateVectArtSelection(Document, History, 180);
    PathLayer := TVectArtPathLayer(Document[4]);
    ImageLayer := TVectArtImageLayer(Document[5]);
    Near(PathLayer.Points[0].X, 120, 'path 180-degree rotation X');
    Near(PathLayer.Points[0].Y, 140, 'path 180-degree rotation Y');
    Near(ImageLayer.Points[0].X, 30, 'image 180-degree rotation X');
    Near(ImageLayer.Points[0].Y, 140, 'image 180-degree rotation Y');

    PathLayer.Locked := True;
    Require(not CanRotateVectArtSelection(Document),
      'locked selection should not be rotatable');
  finally
    History.Free;
    Document.Free;
  end;
end;

begin
  try
    Run;
    Writeln('LayerRotationOperationsTests: OK');
  except
    on E: Exception do
    begin
      Writeln('LayerRotationOperationsTests: FAILED: ', E.Message);
      Halt(1);
    end;
  end;
end.
