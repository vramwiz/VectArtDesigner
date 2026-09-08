// Verifies that a flat group moves mixed layer kinds as one undoable edit.
program GroupMixedInteractionTests;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  Vcl.Controls,
  Vcl.Graphics,
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerBezierGeometry in
    'Source\Editor\Geometry\VectArtDesignerBezierGeometry.pas',
  VectArtDesignerSelectionGeometry in
    'Source\Editor\Geometry\VectArtDesignerSelectionGeometry.pas',
  VectArtDesignerCanvasInteraction in
    'Source\Editor\VectArtDesignerCanvasInteraction.pas',
  VectArtDesignerEditCommands in
    'Source\Core\Commands\VectArtDesignerEditCommands.pas',
  VectArtDesignerEditHistory in
    'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerLayerGroupOperations in
    'Source\Core\Commands\VectArtDesignerLayerGroupOperations.pas';

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  Document: TVectArtDocument;
  History: TVectArtEditHistory;
  Interaction: TVectArtCanvasInteraction;
  LineData: TVectArtLineData;
  PathData: TVectArtPathData;
  RectangleData: TVectArtRectangleData;
begin
  Document := TVectArtDocument.Create;
  History := TVectArtEditHistory.Create;
  Interaction := TVectArtCanvasInteraction.Create;
  try
    RectangleData := Default(TVectArtRectangleData);
    RectangleData.Name := 'Rectangle';
    RectangleData.Bounds := RectF(10, 10, 40, 40);
    RectangleData.Filled := True;
    RectangleData.FillColor := clWhite;
    RectangleData.Opacity := 1;
    RectangleData.Visible := True;
    Document.InsertRectangle(1, RectangleData);

    LineData := Default(TVectArtLineData);
    LineData.Name := 'Line';
    LineData.StartPoint := PointF(50, 20);
    LineData.EndPoint := PointF(80, 20);
    LineData.Opacity := 1;
    LineData.StrokeWidth := 2;
    LineData.Visible := True;
    Document.InsertLine(2, LineData);

    PathData := Default(TVectArtPathData);
    PathData.Name := 'Path';
    PathData.Points := [PointF(90, 10), PointF(110, 20), PointF(90, 30)];
    PathData.Opacity := 1;
    PathData.StrokeWidth := 2;
    PathData.Visible := True;
    Document.InsertPath(3, PathData);

    Document.SetSelectedLayers([1, 2, 3]);
    GroupVectArtSelection(Document, History);
    Interaction.EditHistory := History;
    // Alt isolates the exact mixed-layer transform from snapping.
    Interaction.Configure(Document, Rect(0, 0, 300, 300), 1);
    Check(Interaction.MouseDown(mbLeft, [], 25, 25),
      'Group move did not start');
    Check(Interaction.MouseMove([ssLeft, ssAlt], 35, 40),
      'Group move did not update');
    Check(Interaction.MouseUp(mbLeft), 'Group move did not finish');

    Check(Document[1] is TVectArtRectangleLayer,
      'Rectangle layer changed kind');
    Check(TVectArtRectangleLayer(Document[1]).Bounds.Left = 20,
      'Rectangle did not move with group');
    Check(TVectArtLineLayer(Document[2]).StartPoint = PointF(60, 35),
      'Line did not move with group');
    Check(TVectArtPathLayer(Document[3]).Points[0] = PointF(100, 25),
      'Path did not move with group');

    History.Undo;
    Check(TVectArtRectangleLayer(Document[1]).Bounds.Left = 10,
      'Rectangle move undo failed');
    Check(TVectArtLineLayer(Document[2]).StartPoint = PointF(50, 20),
      'Line move undo failed');
    Check(TVectArtPathLayer(Document[3]).Points[0] = PointF(90, 10),
      'Path move undo failed');
    History.Redo;
    Check(TVectArtPathLayer(Document[3]).Points[0] = PointF(100, 25),
      'Group move redo failed');
    History.Undo;

    // The shared selection frame is expanded by the largest selected stroke.
    Check(Interaction.MouseDown(mbLeft, [], 119, 49),
      'Group resize did not start');
    Check(Interaction.MouseMove([ssLeft, ssAlt], 219, 79),
      'Group resize did not update');
    Check(Interaction.MouseUp(mbLeft), 'Group resize did not finish');
    Check(TVectArtRectangleLayer(Document[1]).Bounds.Right = 70,
      'Rectangle did not resize with group');
    Check(TVectArtLineLayer(Document[2]).StartPoint = PointF(90, 30),
      'Line did not resize with group');
    Check(TVectArtPathLayer(Document[3]).Points[0] = PointF(170, 10),
      'Path did not resize with group');
    History.Undo;
    Check(TVectArtPathLayer(Document[3]).Points[0] = PointF(90, 10),
      'Group resize undo failed');
    Writeln('PASS mixed flat-group move/resize and undo/redo');
  finally
    Interaction.Free;
    History.Free;
    Document.Free;
  end;
end.
