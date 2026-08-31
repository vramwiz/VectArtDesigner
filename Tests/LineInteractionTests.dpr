program LineInteractionTests;

{$APPTYPE CONSOLE}

// 直線ツールの作成、選択、移動、端点編集、Undoを検証する。

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
  VectArtDesignerSelectionGeometry in
    'Source\Editor\VectArtDesignerSelectionGeometry.pas',
  VectArtDesignerCanvasInteraction in
    'Source\Editor\VectArtDesignerCanvasInteraction.pas',
  VectArtDesignerShapeCreation in
    'Source\Editor\VectArtDesignerShapeCreation.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  Creation: TVectArtShapeCreation;
  Document: TVectArtDocument;
  EditorState: TVectArtEditorState;
  History: TVectArtEditHistory;
  Geometry: TVectArtSelectionGeometry;
  Interaction: TVectArtCanvasInteraction;
  Line: TVectArtLineLayer;
  LineLength: Double;
  StartHandlePoint: TPoint;
  TargetHandlePoint: TPoint;
  UnitX: Double;
  UnitY: Double;
begin
  Document := TVectArtDocument.Create;
  EditorState := TVectArtEditorState.Create;
  History := TVectArtEditHistory.Create;
  Interaction := TVectArtCanvasInteraction.Create;
  Creation := TVectArtShapeCreation.Create;
  try
    EditorState.CurrentTool := vetLine;
    EditorState.LineStrokeColor := clRed;
    EditorState.LineCap := vlcRound;
    EditorState.LineAntiAlias := False;
    EditorState.LineEndMarker := vlmArrow;
    EditorState.LineEndMarkerSize := 9.0;
    EditorState.LineStartMarker := vlmArrow;
    EditorState.LineStartMarkerSize := 6.0;
    EditorState.LineJoin := vljBevel;
    EditorState.LineStrokeWidth := 4.0;
    EditorState.LineStrokeStyle := vssDashDot;
    Creation.Configure(Document, History, EditorState,
      Rect(0, 0, 1000, 1000), 1.0);
    Require(Creation.MouseDown(mbLeft, [], 100, 100),
      'Line creation did not start');
    Require(Creation.MouseMove([ssLeft], 300, 200),
      'Line creation preview did not move');
    Require(Creation.MouseUp(mbLeft, [], 300, 200),
      'Line creation did not finish');
    Require((Document.LayerCount = 2) and
      (Document[1] is TVectArtLineLayer), 'Line layer was not created');
    Line := TVectArtLineLayer(Document[1]);
    Require((Line.StrokeColor = clRed) and
      SameValue(Line.StrokeWidth, 4.0) and
      (Line.StrokeStyle = vssDashDot) and (Line.LineCap = vlcRound) and
      (Line.LineJoin = vljBevel) and not Line.AntiAlias and
      (Line.EndMarker = vlmArrow) and (Line.StartMarker = vlmArrow) and
      SameValue(Line.EndMarkerSize, 9.0) and
      SameValue(Line.StartMarkerSize, 6.0),
      'Created line style differs');

    EditorState.CurrentTool := vetSelect;
    Interaction.EditHistory := History;
    Interaction.Configure(Document, Rect(0, 0, 1000, 1000), 1.0);
    Require(Interaction.CursorAt(200, 150) = crSizeAll,
      'Line body cursor differs');
    Require(Interaction.MouseDown(mbLeft, 200, 150),
      'Line move did not start');
    Require(Interaction.MouseMove([ssLeft], 220, 160),
      'Line move was not applied');
    Require(Interaction.MouseUp(mbLeft), 'Line move did not finish');
    Require(SameValue(Line.StartPoint.X, 120.0) and
      SameValue(Line.StartPoint.Y, 110.0) and
      SameValue(Line.EndPoint.X, 320.0) and
      SameValue(Line.EndPoint.Y, 210.0), 'Line move differs');

    Interaction.Configure(Document, Rect(0, 0, 1000, 1000), 1.0);
    Geometry := BuildLineSelectionGeometry(Point(120, 110),
      Point(320, 210));
    Require(not Geometry.DrawFrame, 'Line selection frame is visible');
    Require(not IsRectEmpty(Geometry.Handles[vshTopLeft]) and
      not IsRectEmpty(Geometry.Handles[vshBottomRight]) and
      IsRectEmpty(Geometry.Handles[vshTop]) and
      IsRectEmpty(Geometry.Handles[vshTopRight]) and
      IsRectEmpty(Geometry.Handles[vshRight]) and
      IsRectEmpty(Geometry.Handles[vshBottom]) and
      IsRectEmpty(Geometry.Handles[vshBottomLeft]) and
      IsRectEmpty(Geometry.Handles[vshLeft]),
      'Line selection must have only two endpoint handles');
    StartHandlePoint := Point(
      (Geometry.Handles[vshTopLeft].Left +
      Geometry.Handles[vshTopLeft].Right) div 2,
      (Geometry.Handles[vshTopLeft].Top +
      Geometry.Handles[vshTopLeft].Bottom) div 2);
    LineLength := Hypot(200.0, 100.0);
    UnitX := 200.0 / LineLength;
    UnitY := 100.0 / LineLength;
    TargetHandlePoint := Point(
      Round(80.0 - UnitX * LineSelectionHandleDistance),
      Round(90.0 - UnitY * LineSelectionHandleDistance));
    Require(Interaction.MouseDown(mbLeft, StartHandlePoint.X,
      StartHandlePoint.Y),
      'Line start handle did not start');
    Require(Interaction.MouseMove([ssLeft], TargetHandlePoint.X,
      TargetHandlePoint.Y),
      'Line start handle did not move');
    Require(Interaction.MouseUp(mbLeft), 'Line endpoint edit did not finish');
    Require(SameValue(Line.StartPoint.X, 80.0, 0.75) and
      SameValue(Line.StartPoint.Y, 90.0, 0.75), 'Line start point differs');
    History.Undo;
    Require(SameValue(Line.StartPoint.X, 120.0) and
      SameValue(Line.StartPoint.Y, 110.0), 'Line endpoint undo differs');
    Writeln('Line creation and interaction: PASS');
  finally
    Creation.Free;
    Interaction.Free;
    History.Free;
    EditorState.Free;
    Document.Free;
  end;
end.
