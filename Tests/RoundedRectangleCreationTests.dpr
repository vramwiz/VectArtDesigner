program RoundedRectangleCreationTests;

{$APPTYPE CONSOLE}

// Verify fixed 1:8:1 rounded-rectangle creation as a transformable Path.

uses
  System.Classes,
  System.Math,
  System.SysUtils,
  System.Types,
  Vcl.Controls,
  Vcl.Graphics,
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerEditorState in
    'Source\Core\VectArtDesignerEditorState.pas',
  VectArtDesignerEditCommands in
    'Source\Core\Commands\VectArtDesignerEditCommands.pas',
  VectArtDesignerLayerStructureCommands in
    'Source\Core\Commands\VectArtDesignerLayerStructureCommands.pas',
  VectArtDesignerEditHistory in
    'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerBezierGeometry in
    'Source\Editor\Geometry\VectArtDesignerBezierGeometry.pas',
  VectArtDesignerFreehandGeometry in
    'Source\Editor\Geometry\VectArtDesignerFreehandGeometry.pas',
  VectArtDesignerRoundedRectangleGeometry in
    'Source\Editor\Geometry\VectArtDesignerRoundedRectangleGeometry.pas',
  VectArtDesignerSelectionGeometry in
    'Source\Editor\Geometry\VectArtDesignerSelectionGeometry.pas',
  VectArtDesignerCanvasInteraction in
    'Source\Editor\VectArtDesignerCanvasInteraction.pas',
  VectArtDesignerShapeCreation in
    'Source\Editor\VectArtDesignerShapeCreation.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure DragRoundedRectangle(Creation: TVectArtShapeCreation;
  Left, Top, Right, Bottom: Integer);
begin
  Require(Creation.MouseDown(mbLeft, [], Left, Top),
    'Rounded rectangle mouse down failed');
  Require(Creation.MouseMove([ssLeft], Right, Bottom),
    'Rounded rectangle mouse move failed');
  Require(Creation.MouseUp(mbLeft, [], Right, Bottom),
    'Rounded rectangle mouse up failed');
end;

var
  Creation: TVectArtShapeCreation;
  Document: TVectArtDocument;
  EditorState: TVectArtEditorState;
  History: TVectArtEditHistory;
  Interaction: TVectArtCanvasInteraction;
  Path: TVectArtPathLayer;
begin
  Document := TVectArtDocument.Create;
  EditorState := TVectArtEditorState.Create;
  History := TVectArtEditHistory.Create;
  Interaction := TVectArtCanvasInteraction.Create;
  Creation := TVectArtShapeCreation.Create;
  try
    Require(EditorState.RectangleMode = vrmFillAndOutline,'Default shape must have visible fill');
    EditorState.RectangleMode := vrmOutline;
    EditorState.RectangleStrokeWidth := 2.0;
    EditorState.SelectRoundedRectangleToolGroup;
    Creation.Configure(Document, History, EditorState,
      Rect(0, 0, 1000, 1000), 1.0);

    DragRoundedRectangle(Creation, 100, 100, 300, 200);
    Path := TVectArtPathLayer(Document[1]);
    Require((Path.Name = 'Rounded Rectangle 1') and Path.Closed and
      Path.BoundsEditing and
      not Path.Bezier and not Path.Filled and
      SameValue(Path.StrokeWidth, 2.0) and (Length(Path.Points) = 28),
      'Outline rounded rectangle differs');
    Require(SameValue(Path.Points[0].X, 120.0) and
      SameValue(Path.Points[1].X, 280.0) and
      SameValue(Path.Points[0].Y, 100.0) and
      SameValue(Path.Points[1].Y, 100.0),
      'Rounded rectangle does not use the 1:8:1 top-edge ratio');
    Require(IsRoundedRectanglePathPoints(Path.Points),
      'Rounded rectangle point pattern was not recognized');
    Interaction.EditHistory := History;
    Interaction.Configure(Document, Rect(0, 0, 1000, 1000), 1.0);
    Require(Length(Interaction.SelectedPathVertexRects) = 0,
      'Rounded rectangle exposed corner-arc vertices');
    Require(Interaction.CursorAt(309, 209) = crSizeNWSE,
      'Rounded rectangle did not expose a rectangular resize handle');
    Require(Interaction.MouseDown(mbLeft, 309, 209),
      'Rounded rectangle resize did not start');
    Require(Interaction.MouseMove([ssLeft], 409, 259),
      'Rounded rectangle resize was not applied');
    Require(Interaction.MouseUp(mbLeft),
      'Rounded rectangle resize did not finish');
    Path := TVectArtPathLayer(Document[1]);
    Require((Path.Points[7].X > 390.0) and
      (Path.Points[14].Y > 240.0) and
      IsRoundedRectanglePathPoints(Path.Points),
      'Rounded rectangle was not transformed by its outer bounds');
    History.Undo;
    Require(SameValue(Path.Points[7].X, 300.0) and
      SameValue(Path.Points[14].Y, 200.0),
      'Rounded rectangle bounds resize undo failed');

    EditorState.SelectRoundedRectangleToolGroup;
    Require(EditorState.RectangleMode = vrmFill,
      'Rounded rectangle did not switch to fill-only mode');
    DragRoundedRectangle(Creation, 350, 100, 550, 200);
    Path := TVectArtPathLayer(Document[2]);
    Require(Path.Closed and Path.Filled and
      SameValue(Path.StrokeWidth, 0.0),
      'Fill-only rounded rectangle differs');

    EditorState.SelectRoundedRectangleToolGroup;
    Require(EditorState.RectangleMode = vrmFillAndOutline,
      'Rounded rectangle did not switch to fill-and-outline mode');
    DragRoundedRectangle(Creation, 600, 100, 800, 200);
    Path := TVectArtPathLayer(Document[3]);
    Require(Path.Closed and Path.Filled and
      SameValue(Path.StrokeWidth, 2.0),
      'Fill-and-outline rounded rectangle differs');

    Require(History.CanUndo,
      'Rounded rectangle creation was not added to history');
    History.Undo;
    Require(Document.LayerCount = 3,
      'Rounded rectangle creation undo failed');
    History.Redo;
    Require((Document.LayerCount = 4) and
      (Document[3] is TVectArtPathLayer),
      'Rounded rectangle creation redo failed');
    Writeln('Rounded rectangle creation tests: PASS');
  finally
    Creation.Free;
    Interaction.Free;
    History.Free;
    EditorState.Free;
    Document.Free;
  end;
end.
