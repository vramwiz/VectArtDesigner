program PathInteractionTests;

{$APPTYPE CONSOLE}

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
  VectArtDesignerLayerBatchCommands in
    'Source\Core\Commands\VectArtDesignerLayerBatchCommands.pas',
  VectArtDesignerEditHistory in
    'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerSelectionGeometry in
    'Source\Editor\VectArtDesignerSelectionGeometry.pas',
  VectArtDesignerCanvasInteraction in
    'Source\Editor\VectArtDesignerCanvasInteraction.pas',
  VectArtDesignerBezierGeometry in
    'Source\Editor\VectArtDesignerBezierGeometry.pas',
  VectArtDesignerFreehandGeometry in
    'Source\Editor\VectArtDesignerFreehandGeometry.pas',
  VectArtDesignerShapeCreation in
    'Source\Editor\VectArtDesignerShapeCreation.pas',
  VectArtDesignerLayerDuplication in
    'Source\Layers\VectArtDesignerLayerDuplication.pas',
  VectArtDesignerLayerOperations in
    'Source\Layers\VectArtDesignerLayerOperations.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  BezierDisplayPoints: TArray<TPointF>;
  Data: TVectArtPathData;
  Creation: TVectArtShapeCreation;
  Document: TVectArtDocument;
  EditorState: TVectArtEditorState;
  History: TVectArtEditHistory;
  Interaction: TVectArtCanvasInteraction;
  Operations: TVectArtLayerOperations;
  Path: TVectArtPathLayer;
  SimplifiedPoints: TArray<TPoint>;
begin
  Document := TVectArtDocument.Create;
  EditorState := TVectArtEditorState.Create;
  History := TVectArtEditHistory.Create;
  Interaction := TVectArtCanvasInteraction.Create;
  Creation := TVectArtShapeCreation.Create;
  Operations := TVectArtLayerOperations.Create;
  try
    Require(not FreehandPointIsFarEnough(Point(0, 0), Point(1, 1), 2),
      'Freehand sampling accepted a point below the minimum distance');
    Require(FreehandPointIsFarEnough(Point(0, 0), Point(2, 0), 2),
      'Freehand sampling rejected a point at the minimum distance');
    SimplifiedPoints := SimplifyFreehandPolyline([
      Point(0, 0), Point(5, 0), Point(10, 0), Point(10, 10)], 1.5);
    Require((Length(SimplifiedPoints) = 3) and
      (SimplifiedPoints[0] = Point(0, 0)) and
      (SimplifiedPoints[1] = Point(10, 0)) and
      (SimplifiedPoints[2] = Point(10, 10)),
      'Freehand simplification did not preserve the corner and endpoints');

    Data.Name := 'Path 1';
    Data.Points := [PointF(100, 100), PointF(200, 100),
      PointF(200, 200), PointF(100, 200)];
    Data.Closed := True;
    Data.EndMarker := vlmNone;
    Data.EndMarkerSize := 4.0;
    Data.Filled := True;
    Data.FillColor := clBlue;
    Data.LineCap := vlcSquare;
    Data.LineJoin := vljBevel;
    Data.AntiAlias := True;
    Data.StrokeColor := clBlack;
    Data.StrokeStyle := vssSolid;
    Data.StrokeWidth := 2;
    Data.Opacity := 1;
    Data.StartMarker := vlmNone;
    Data.StartMarkerSize := 4.0;
    Data.Visible := True;
    Data.Locked := False;
    Document.InsertPath(1, Data);
    Interaction.EditHistory := History;
    Interaction.Configure(Document, Rect(0, 0, 1000, 1000), 1);
    Require(Interaction.MouseDown(mbLeft, 150, 150),
      'Path move did not start');
    Require(Interaction.MouseMove([ssLeft], 170, 180),
      'Path move was not applied');
    Require(Interaction.MouseUp(mbLeft), 'Path move did not finish');
    Path := TVectArtPathLayer(Document[1]);
    Require(SameValue(Path.Points[0].X, 120.0) and
      SameValue(Path.Points[0].Y, 130.0), 'Path move differs');
    History.Undo;
    Require(SameValue(Path.Points[0].X, 100.0) and
      SameValue(Path.Points[0].Y, 100.0), 'Path move undo differs');

    Interaction.Configure(Document, Rect(0, 0, 1000, 1000), 1);
    Require(Interaction.MouseDown(mbLeft, 100, 100),
      'Path vertex drag did not start');
    Require(Document.IsInteractiveUpdate,
      'Path vertex drag did not begin an interactive document update');
    Require(Interaction.MouseMove([ssLeft], 80, 90),
      'Path vertex drag was not applied');
    Require(Interaction.MouseUp(mbLeft), 'Path vertex drag did not finish');
    Require(not Document.IsInteractiveUpdate,
      'Path vertex drag did not end its interactive document update');
    Require(SameValue(Path.Points[0].X, 80.0) and
      SameValue(Path.Points[0].Y, 90.0), 'Path vertex differs');
    History.Undo;
    Require(SameValue(Path.Points[0].X, 100.0) and
      SameValue(Path.Points[0].Y, 100.0), 'Path vertex undo differs');

    Document.SetPathLineCap(1, vlcRound);
    History.AddApplied(TVectArtPathLineCapCommand.Create(Document, 1,
      vlcSquare, vlcRound));
    Document.SetPathLineJoin(1, vljRound);
    History.AddApplied(TVectArtPathLineJoinCommand.Create(Document, 1,
      vljBevel, vljRound));
    Require((Path.LineCap = vlcRound) and (Path.LineJoin = vljRound),
      'Path line cap or join edit differs');
    History.Undo;
    Require(Path.LineJoin = vljBevel, 'Path line join undo differs');
    History.Undo;
    Require(Path.LineCap = vlcSquare, 'Path line cap undo differs');
    History.Redo;
    History.Redo;
    Require((Path.LineCap = vlcRound) and (Path.LineJoin = vljRound),
      'Path line cap or join redo differs');
    Document.SetPathAntiAlias(1, False);
    History.AddApplied(TVectArtPathAntiAliasCommand.Create(Document, 1,
      True, False));
    Require(not Path.AntiAlias, 'Path anti-alias edit differs');
    History.Undo;
    Require(Path.AntiAlias, 'Path anti-alias undo differs');
    History.Redo;
    Require(not Path.AntiAlias, 'Path anti-alias redo differs');
    Document.SetPathStartMarker(1, vlmOpenArrow);
    History.AddApplied(TVectArtPathStartMarkerCommand.Create(Document, 1,
      vlmNone, vlmOpenArrow));
    Document.SetPathEndMarker(1, vlmStar);
    History.AddApplied(TVectArtPathEndMarkerCommand.Create(Document, 1,
      vlmNone, vlmStar));
    Document.SetPathStartMarkerSize(1, 6.0);
    History.AddApplied(TVectArtPathMarkerSizeCommand.Create(Document, 1,
      True, 4.0, 6.0));
    Document.SetPathEndMarkerSize(1, 9.0);
    History.AddApplied(TVectArtPathMarkerSizeCommand.Create(Document, 1,
      False, 4.0, 9.0));
    Require((Path.StartMarker = vlmOpenArrow) and
      (Path.EndMarker = vlmStar) and
      SameValue(Path.StartMarkerSize, 6.0) and
      SameValue(Path.EndMarkerSize, 9.0), 'Path marker edit differs');
    History.Undo;
    Require(SameValue(Path.EndMarkerSize, 4.0),
      'Path end marker size undo differs');
    History.Redo;
    Require(SameValue(Path.EndMarkerSize, 9.0),
      'Path end marker size redo differs');
    Path.Closed := False;
    Document.SetPathPoints(1, [PointF(100, 100), PointF(200, 100)]);
    Document.SetPathStartMarker(1, vlmNone);
    Document.SetPathEndMarker(1, vlmCircle);
    Document.SetPathEndMarkerSize(1, 10.0);
    Document.SetSelectedLayers([]);
    Interaction.Configure(Document, Rect(0, 0, 1000, 1000), 1);
    Require(Interaction.MouseDown(mbLeft, 190, 92),
      'Open Path marker was not hit-testable');
    Require(Document.SelectedIndex = 1,
      'Open Path marker did not select its Path');
    Interaction.MouseUp(mbLeft);
    Path.Closed := True;
    Document.SetPathPoints(1, [PointF(100, 100), PointF(200, 100),
      PointF(200, 200), PointF(100, 200)]);

    EditorState.CurrentTool := vetPath;
    EditorState.PathLineCap := vlcRound;
    EditorState.PathLineJoin := vljBevel;
    EditorState.PathAntiAlias := False;
    EditorState.PathStartMarker := vlmDiamond;
    EditorState.PathStartMarkerSize := 7.0;
    EditorState.PathEndMarker := vlmCircle;
    EditorState.PathEndMarkerSize := 8.0;
    Creation.Configure(Document, History, EditorState,
      Rect(0, 0, 1000, 1000), 1);
    Require(Creation.MouseDown(mbLeft, [], 300, 300),
      'Path creation first point failed');
    Creation.MouseMove([], 450, 300);
    Require(Creation.MouseDown(mbLeft, [], 450, 300),
      'Path creation second point failed');
    Creation.MouseMove([], 400, 450);
    Require(Creation.MouseDown(mbLeft, [], 400, 450),
      'Path creation third point failed');
    Require(Creation.MouseDown(mbLeft, [], 300, 300),
      'Path creation close failed');
    Require((Document.LayerCount = 3) and
      (Document[2] is TVectArtPathLayer), 'Created path differs');
    Require(TVectArtPathLayer(Document[2]).Closed and
      (Length(TVectArtPathLayer(Document[2]).Points) = 3) and
      (TVectArtPathLayer(Document[2]).LineCap = vlcRound) and
      (TVectArtPathLayer(Document[2]).LineJoin = vljBevel) and
      not TVectArtPathLayer(Document[2]).AntiAlias and
      (TVectArtPathLayer(Document[2]).StartMarker = vlmDiamond) and
      SameValue(TVectArtPathLayer(Document[2]).StartMarkerSize, 7.0) and
      (TVectArtPathLayer(Document[2]).EndMarker = vlmCircle) and
      SameValue(TVectArtPathLayer(Document[2]).EndMarkerSize, 8.0),
      'Created closed path properties differ');
    History.Undo;
    Require(Document.LayerCount = 2, 'Path creation undo differs');

    EditorState.CurrentTool := vetBezier;
    Creation.Configure(Document, History, EditorState,
      Rect(0, 0, 1000, 1000), 1);
    Require(Creation.MouseDown(mbLeft, [], 300, 300),
      'Bezier creation first anchor failed');
    Creation.MouseMove([], 400, 200);
    Require(Creation.MouseDown(mbLeft, [], 400, 200),
      'Bezier creation second anchor failed');
    Creation.MouseMove([], 500, 300);
    Require(Creation.MouseDown(mbLeft, [], 500, 300),
      'Bezier creation third anchor failed');
    Require(Creation.FinishPath(False), 'Bezier creation finish failed');
    Require((Document.LayerCount = 3) and
      (Document[2] is TVectArtPathLayer), 'Created Bezier path differs');
    Path := TVectArtPathLayer(Document[2]);
    Require(Path.Bezier and not Path.Closed and
      (Length(Path.Points) = 3), 'Bezier anchors were not preserved');
    Require(SameValue(Path.Points[0].X, 300.0) and
      SameValue(Path.Points[0].Y, 300.0) and
      SameValue(Path.Points[High(Path.Points)].X, 500.0) and
      SameValue(Path.Points[High(Path.Points)].Y, 300.0),
      'Bezier path endpoints differ');
    BezierDisplayPoints := BuildSmoothBezierPolyline(Path.Points, False, 12);
    Require((Length(BezierDisplayPoints) = 25) and
      (BezierDisplayPoints[6].Y < 249.0),
      'Bezier path was not curved between anchors');
    Interaction.Configure(Document, Rect(0, 0, 1000, 1000), 1);
    Require(Length(Interaction.SelectedPathVertexRects) = 3,
      'Bezier selection displayed generated subdivision points');
    History.Undo;
    Require(Document.LayerCount = 2, 'Bezier creation undo differs');

    EditorState.CurrentTool := vetFreehandLine;
    Creation.Configure(Document, History, EditorState,
      Rect(0, 0, 1000, 1000), 1);
    Require(Creation.MouseDown(mbLeft, [], 300, 300),
      'Freehand polyline did not start');
    Creation.MouseMove([ssLeft], 310, 300);
    Creation.MouseMove([ssLeft], 320, 300);
    Creation.MouseMove([ssLeft], 320, 310);
    Creation.MouseMove([ssLeft], 320, 320);
    Require(Creation.MouseUp(mbLeft, [], 320, 330),
      'Freehand polyline did not finish');
    Require((Document.LayerCount = 3) and
      (Document[2] is TVectArtPathLayer),
      'Freehand polyline did not create a Path');
    Path := TVectArtPathLayer(Document[2]);
    Require(not Path.Bezier and not Path.Closed and
      (Length(Path.Points) = 3),
      'Freehand polyline was not simplified to sharp vertices');
    Require(SameValue(Path.Points[0].X, 300.0) and
      SameValue(Path.Points[0].Y, 300.0) and
      SameValue(Path.Points[1].X, 320.0) and
      SameValue(Path.Points[1].Y, 300.0) and
      SameValue(Path.Points[2].X, 320.0) and
      SameValue(Path.Points[2].Y, 330.0),
      'Freehand polyline vertices differ');
    History.Undo;
    Require(Document.LayerCount = 2,
      'Freehand polyline creation undo differs');

    EditorState.CurrentTool := vetFreehandBezier;
    Creation.Configure(Document, History, EditorState,
      Rect(0, 0, 1000, 1000), 1);
    Require(Creation.MouseDown(mbLeft, [], 300, 300),
      'Freehand Bezier did not start');
    Creation.MouseMove([ssLeft], 350, 250);
    Creation.MouseMove([ssLeft], 400, 300);
    Require(Creation.MouseUp(mbLeft, [], 450, 250),
      'Freehand Bezier did not finish');
    Require((Document.LayerCount = 3) and
      (Document[2] is TVectArtPathLayer),
      'Freehand Bezier did not create a Path');
    Path := TVectArtPathLayer(Document[2]);
    Require(Path.Bezier and not Path.Closed and
      (Length(Path.Points) >= 3),
      'Freehand Bezier was not converted on mouse release');
    BezierDisplayPoints := BuildSmoothBezierPolyline(Path.Points, False, 12);
    Require(Length(BezierDisplayPoints) > Length(Path.Points),
      'Freehand Bezier did not produce a continuous curve');
    History.Undo;
    Require(Document.LayerCount = 2,
      'Freehand Bezier creation undo differs');

    Operations.Document := Document;
    Operations.EditHistory := History;
    Require(Operations.CanExecute(vlaDelete), 'Path delete is disabled');
    Operations.Execute(vlaDelete);
    Require(Document.LayerCount = 1, 'Path delete differs');
    History.Undo;
    Require((Document.LayerCount = 2) and
      (Document[1] is TVectArtPathLayer), 'Path delete undo differs');
    Writeln('Path interaction: PASS');
  finally
    Creation.Free;
    Operations.Free;
    Interaction.Free;
    History.Free;
    EditorState.Free;
    Document.Free;
  end;
end.
