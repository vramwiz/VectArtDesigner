// Selection-axis reflection and undo/redo coverage for every editable layer.
program LayerFlipOperationsTests;

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerEditHistory in 'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerEditCommands in 'Source\Core\Commands\VectArtDesignerEditCommands.pas',
  VectArtDesignerLayerFlipOperations in 'Source\Core\Commands\Transform\VectArtDesignerLayerFlipOperations.pas',
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

function RectangleData(const Bounds: TRectF): TVectArtRectangleData;
begin
  Result := Default(TVectArtRectangleData);
  Result.Bounds := Bounds;
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
  Result.FontFamily := 'Segoe UI';
  Result.FontSize := 20;
  Result.Name := 'Text';
  Result.Opacity := 1;
  Result.RotationDegrees := 20;
  Result.Text := 'Mirror';
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
    Document.InsertRectangle(Document.LayerCount,
      RectangleData(RectF(10, 10, 30, 30)));
    Document.InsertLine(Document.LayerCount, LineData);
    Document.SetSelectedLayers([1, 2]);
    FlipVectArtSelection(Document, History, vfdHorizontal);
    RectangleLayer := TVectArtRectangleLayer(Document[1]);
    LineLayer := TVectArtLineLayer(Document[2]);
    Near(RectangleLayer.Bounds.Left, 100, 'shared-axis rectangle flip');
    Near(RectangleLayer.Bounds.Right, 120, 'shared-axis rectangle width');
    Near(LineLayer.StartPoint.X, 30, 'shared-axis line start');
    Near(LineLayer.EndPoint.X, 10, 'shared-axis line end');
    Require(History.CanUndo, 'flip was not added to history');
    History.Undo;
    Near(RectangleLayer.Bounds.Left, 10, 'rectangle undo');
    Near(LineLayer.StartPoint.X, 100, 'line undo');
    History.Redo;
    Near(RectangleLayer.Bounds.Left, 100, 'rectangle redo');

    Document.InsertText(Document.LayerCount, TextData);
    Document.SetSelectedLayers([3]);
    FlipVectArtSelection(Document, History, vfdHorizontal);
    TextLayer := TVectArtTextLayer(Document[3]);
    Require(TextLayer.FlipHorizontal, 'text glyph flip was not retained');
    Require(not TextLayer.FlipVertical, 'wrong text flip axis changed');
    Near(TextLayer.RotationDegrees, -20, 'text rotation was not reflected');
    History.Undo;
    Require(not TextLayer.FlipHorizontal, 'text flip undo failed');
    Near(TextLayer.RotationDegrees, 20, 'text rotation undo failed');

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
    FlipVectArtSelection(Document, History, vfdVertical);
    PathLayer := TVectArtPathLayer(Document[4]);
    ImageLayer := TVectArtImageLayer(Document[5]);
    Near(PathLayer.Points[0].Y, 140, 'path vertical flip');
    Near(ImageLayer.Points[0].Y, 140, 'image vertical flip');
    Near(ImageLayer.Points[3].Y, 120, 'image corner orientation flip');

    PathLayer.Locked := True;
    Require(not CanFlipVectArtSelection(Document),
      'locked selection should not be flippable');
  finally
    History.Free;
    Document.Free;
  end;
end;

begin
  try
    Run;
    Writeln('LayerFlipOperationsTests: OK');
  except
    on E: Exception do
    begin
      Writeln('LayerFlipOperationsTests: FAILED: ', E.Message);
      Halt(1);
    end;
  end;
end.
