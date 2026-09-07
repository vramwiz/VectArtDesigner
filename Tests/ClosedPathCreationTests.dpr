program ClosedPathCreationTests;

{$APPTYPE CONSOLE}

// Verify the dedicated sharp closed-path tool and its three paint modes.

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
  VectArtDesignerShapeCreation in
    'Source\Editor\VectArtDesignerShapeCreation.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure AddTriangle(Creation: TVectArtShapeCreation; OffsetX: Integer);
begin
  Require(Creation.MouseDown(mbLeft, [], OffsetX, 100),
    'Closed path first point failed');
  Creation.MouseMove([], OffsetX + 80, 100);
  Require(Creation.MouseDown(mbLeft, [], OffsetX + 80, 100),
    'Closed path second point failed');
  Creation.MouseMove([], OffsetX + 40, 180);
  Require(Creation.MouseDown(mbLeft, [], OffsetX + 40, 180),
    'Closed path third point failed');
end;

var
  Creation: TVectArtShapeCreation;
  Document: TVectArtDocument;
  EditorState: TVectArtEditorState;
  History: TVectArtEditHistory;
  Path: TVectArtPathLayer;
  Preview: TArray<TPoint>;
begin
  Document := TVectArtDocument.Create;
  EditorState := TVectArtEditorState.Create;
  History := TVectArtEditHistory.Create;
  Creation := TVectArtShapeCreation.Create;
  try
    EditorState.RectangleStrokeWidth := 2.0;
    EditorState.SelectClosedPathToolGroup;
    Creation.Configure(Document, History, EditorState,
      Rect(0, 0, 1000, 1000), 1.0);

    Require(Creation.MouseDown(mbLeft, [], 100, 100),
      'Outline path first point failed');
    Creation.MouseMove([], 180, 100);
    Require(Creation.MouseDown(mbLeft, [], 180, 100),
      'Outline path second point failed');
    Creation.MouseMove([], 140, 180);
    Require(Creation.PreviewPath(Preview) and (Length(Preview) = 4) and
      (Preview[0] = Preview[High(Preview)]),
      'Closed path preview did not return to its first point');
    Require(Creation.MouseDown(mbLeft, [], 140, 180),
      'Outline path third point failed');
    Require(Creation.MouseDown(mbLeft, [], 100, 100),
      'Outline path close failed');
    Path := TVectArtPathLayer(Document[1]);
    Require(Path.Closed and not Path.Bezier and not Path.Filled and
      SameValue(Path.StrokeWidth, 2.0) and (Length(Path.Points) = 3),
      'Outline-only closed path differs');

    EditorState.SelectClosedPathToolGroup;
    Require(EditorState.RectangleMode = vrmFill,
      'Closed path did not switch to fill-only mode');
    AddTriangle(Creation, 250);
    Require(Creation.FinishPath(False),
      'Fill-only closed path did not finish');
    Path := TVectArtPathLayer(Document[2]);
    Require(Path.Closed and Path.Filled and
      SameValue(Path.StrokeWidth, 0.0),
      'Fill-only closed path differs');

    EditorState.SelectClosedPathToolGroup;
    Require(EditorState.RectangleMode = vrmFillAndOutline,
      'Closed path did not switch to fill-and-outline mode');
    AddTriangle(Creation, 400);
    Require(Creation.MouseDown(mbLeft, [ssDouble], 440, 180),
      'Double-click did not finish the closed path');
    Path := TVectArtPathLayer(Document[3]);
    Require(Path.Closed and Path.Filled and
      SameValue(Path.StrokeWidth, 2.0),
      'Fill-and-outline closed path differs');

    Require(History.CanUndo, 'Closed path creation was not added to history');
    History.Undo;
    Require(Document.LayerCount = 3, 'Closed path creation undo failed');
    History.Redo;
    Require((Document.LayerCount = 4) and
      TVectArtPathLayer(Document[3]).Closed,
      'Closed path creation redo failed');
    Writeln('Closed path creation tests: PASS');
  finally
    Creation.Free;
    History.Free;
    EditorState.Free;
    Document.Free;
  end;
end.
