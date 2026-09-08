// Checks semantic snapping, zoom tolerance, modifiers and undo through public input APIs.
program SnapInteractionTests;

{$APPTYPE CONSOLE}

uses
  System.Classes, System.SysUtils, System.Types, System.Math, Vcl.Controls,
  VectArtDesignerDocument, VectArtDesignerEditHistory,
  VectArtDesignerEditorState, VectArtDesignerCanvasInteraction,
  VectArtDesignerShapeCreation, VectArtDesignerSnapGeometry,
  VectArtDesignerLayerGroupOperations;

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then
    raise Exception.Create(MessageText);
end;

procedure CheckVertexSnap;
var
  D: TVectArtDocument;
  Input: TVectArtCanvasInteraction;
  Path: TVectArtPathData;
begin
  D := TVectArtDocument.Create;
  Input := TVectArtCanvasInteraction.Create;
  try
    D.SetCanvasSize(400, 300);
    Path := Default(TVectArtPathData);
    Path.Visible := True;
    Path.Opacity := 1;
    Path.Points := [PointF(77, 73), PointF(123, 119), PointF(211, 223)];
    D.InsertPath(1, Path);
    D.SelectedIndex := 1;
    Input.Configure(D, Rect(0, 0, 400, 300), 1);
    Check(Input.MouseDown(mbLeft, [], 77, 73), 'Begin vertex drag');
    Input.MouseMove([ssLeft], 121, 221);
    Check(TVectArtPathLayer(D[1]).Points[0] = PointF(123, 223), 'Same-path vertex alignment');
    Input.MouseMove([ssLeft, ssAlt], 121, 221);
    Check(TVectArtPathLayer(D[1]).Points[0] = PointF(121, 221), 'Alt vertex bypass');
    Input.MouseUp(mbLeft);
  finally
    Input.Free;
    D.Free;
  end;
end;

procedure CheckGroupSnap;
var
  D: TVectArtDocument;
  H: TVectArtEditHistory;
  Input: TVectArtCanvasInteraction;
  R: TVectArtRectangleData;
  L: TVectArtLineData;
begin
  D := TVectArtDocument.Create;
  H := TVectArtEditHistory.Create;
  Input := TVectArtCanvasInteraction.Create;
  try
    D.SetCanvasSize(400, 300);
    R := Default(TVectArtRectangleData);
    R.Visible := True;
    R.Filled := True;
    R.Opacity := 1;
    R.Bounds := RectF(140, 130, 180, 170);
    D.InsertRectangle(1, R);
    R.Bounds := RectF(20, 20, 60, 60);
    D.InsertRectangle(2, R);
    L := Default(TVectArtLineData);
    L.Visible := True;
    L.Opacity := 1;
    L.StartPoint := PointF(65, 20);
    L.EndPoint := PointF(85, 60);
    D.InsertLine(3, L);
    D.SetSelectedLayers([2, 3]);
    GroupVectArtSelection(D, H);
    Input.EditHistory := H;
    Input.Configure(D, Rect(0, 0, 400, 300), 1);
    Input.MouseDown(mbLeft, [], 40, 40);
    Input.MouseMove([ssLeft], 138, 129);
    Check(Length(Input.SnapGuides) > 0, 'Group snap guides');
    Check(SameValue(TVectArtLineLayer(D[3]).EndPoint.X, 180), 'Group outer edge snap');
    Check(SameValue(TVectArtLineLayer(D[3]).StartPoint.X -
      TVectArtRectangleLayer(D[2]).Bounds.Left, 45), 'Group relative X');
    Check(SameValue(TVectArtLineLayer(D[3]).StartPoint.Y,
      TVectArtRectangleLayer(D[2]).Bounds.Top), 'Group relative Y');
    Input.MouseUp(mbLeft);
    H.Undo;
    Check(TVectArtLineLayer(D[3]).StartPoint = PointF(65, 20), 'Group snap undo');
  finally
    Input.Free;
    H.Free;
    D.Free;
  end;
end;

var
  Document: TVectArtDocument;
  History: TVectArtEditHistory;
  State: TVectArtEditorState;
  Interaction: TVectArtCanvasInteraction;
  Creation: TVectArtShapeCreation;
  Data: TVectArtRectangleData;
  P: TPointF;
  Guides: TArray<TVectArtDesignerSnapGuide>;
  Angle: Single;
begin
  CheckVertexSnap;
  CheckGroupSnap;
  Document := TVectArtDocument.Create;
  History := TVectArtEditHistory.Create;
  State := TVectArtEditorState.Create;
  Interaction := TVectArtCanvasInteraction.Create;
  Creation := TVectArtShapeCreation.Create;
  try
    Document.SetCanvasSize(400, 300);
    Data := Default(TVectArtRectangleData);
    Data.Visible := True;
    Data.Filled := True;
    Data.Opacity := 1;
    Data.Bounds := RectF(140, 130, 180, 170);
    Document.InsertRectangle(1, Data);
    Data.Bounds := RectF(20, 20, 60, 60);
    Document.InsertRectangle(2, Data);
    Document.SetSelectedLayers([2]);
    SnapVectArtDesignerPoint(Document, PointF(138, 127), 1, True, P, Guides);
    Check(SameValue(P.X, 140) and SameValue(P.Y, 130), 'Semantic point snap');
    Check((Length(Guides) = 2) and Guides[0].HighlightTarget, 'Target guides');
    SnapVectArtDesignerPoint(Document, PointF(136, 126), 2, True, P, Guides);
    Check(SameValue(P.X, 136) and SameValue(P.Y, 126), 'Screen pixel tolerance');
    SnapVectArtDesignerPoint(Document, PointF(2, 3), 1, True, P, Guides);
    Check(P = PointF(0, 0), 'Top-left canvas origin');
    SnapVectArtDesignerPoint(Document, PointF(197, 148), 1, True, P, Guides);
    Check(P = PointF(200, 150), 'Canvas center');
    Check(SnapVectArtDesignerAngle(43, Angle) and SameValue(Angle, 45), '45 degree snap');
    Check(SnapVectArtDesignerAngle(28, Angle) and SameValue(Angle, 30), '30 degree snap');
    Check(not SnapVectArtDesignerAngle(22, Angle), 'Angle outside tolerance');

    Interaction.EditHistory := History;
    Interaction.Configure(Document, Rect(0, 0, 400, 300), 1);
    Check(Interaction.MouseDown(mbLeft, [], 40, 40), 'Begin move');
    Interaction.MouseMove([ssLeft], 138, 129);
    Check(TVectArtRectangleLayer(Document[2]).Bounds.TopLeft = PointF(120, 110), 'Move snap');
    Check(Length(Interaction.SnapGuides) > 0, 'Move guides');
    Interaction.MouseMove([ssLeft, ssAlt], 138, 129);
    Check(TVectArtRectangleLayer(Document[2]).Bounds.TopLeft = PointF(118, 109), 'Alt bypass');
    Check(Length(Interaction.SnapGuides) = 0, 'Alt clears guides');
    Interaction.MouseMove([ssLeft], 138, 129);
    Interaction.MouseUp(mbLeft);
    Check(Length(Interaction.SnapGuides) = 0, 'Release clears guides');
    History.Undo;
    Check(TVectArtRectangleLayer(Document[2]).Bounds.TopLeft = PointF(20, 20), 'Undo move');
    History.Redo;
    Check(TVectArtRectangleLayer(Document[2]).Bounds.TopLeft = PointF(120, 110), 'Redo move');
    History.Undo;

    Check(Interaction.MouseDown(mbLeft, [], 68, 40), 'Begin right resize');
    Interaction.MouseMove([ssLeft], 146, 40);
    Check(SameValue(TVectArtRectangleLayer(Document[2]).Bounds.Right, 140), 'Resize edge snap');
    Check(SameValue(TVectArtRectangleLayer(Document[2]).Bounds.Top, 20), 'Resize keeps inactive axis');
    Check((Length(Interaction.SnapGuides) = 1) and
      (Interaction.SnapGuides[0].Axis = slsaX), 'Resize active-axis guides');
    Interaction.MouseUp(mbLeft);
    History.Undo;

    State.CurrentTool := vetLine;
    Creation.Configure(Document, History, State, Rect(0, 0, 400, 300), 1);
    Creation.MouseDown(mbLeft, [ssAlt], 70, 80);
    Creation.MouseMove([ssLeft, ssShift], 117, 89);
    Creation.MouseUp(mbLeft, [ssShift], 117, 89);
    Check(TVectArtLineLayer(Document[3]).EndPoint = PointF(117, 80), 'Shift horizontal creation');
    History.Undo;
    Creation.MouseDown(mbLeft, [ssAlt], 70, 80);
    Creation.MouseMove([ssLeft], 138, 127);
    Creation.MouseUp(mbLeft, [], 138, 127);
    Check(TVectArtLineLayer(Document[3]).EndPoint = PointF(140, 130), 'Creation commits snapped preview');
    Writeln('PASS snap geometry, movement, modifiers, creation and undo/redo');
  finally
    Creation.Free;
    Interaction.Free;
    State.Free;
    History.Free;
    Document.Free;
  end;
end.
