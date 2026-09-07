program EllipseInteractionTests;

{$APPTYPE CONSOLE}

// 楕円ツールの3描画モード、Shift正円化、作成Undoを検証する。

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
    'Source\Editor\VectArtDesignerBezierGeometry.pas',
  VectArtDesignerFreehandGeometry in
    'Source\Editor\VectArtDesignerFreehandGeometry.pas',
  VectArtDesignerRoundedRectangleGeometry in
    'Source\Editor\VectArtDesignerRoundedRectangleGeometry.pas',
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
  Ellipse: TVectArtRectangleLayer;
  History: TVectArtEditHistory;
  Preview: TRect;
begin
  Document := TVectArtDocument.Create;
  EditorState := TVectArtEditorState.Create;
  History := TVectArtEditHistory.Create;
  Creation := TVectArtShapeCreation.Create;
  try
    EditorState.RectangleStrokeWidth := 2.0;
    EditorState.SelectEllipseToolGroup;
    Creation.Configure(Document, History, EditorState,
      Rect(0, 0, 1000, 1000), 1.0);

    Require(Creation.MouseDown(mbLeft, [], 100, 100),
      'Ellipse creation did not start');
    Require(Creation.MouseMove([ssLeft, ssShift], 160, 130),
      'Ellipse preview did not move');
    Preview := Creation.PreviewRect;
    Require(Creation.PreviewIsEllipse, 'Ellipse preview kind differs');
    Require((Preview.Left = 100) and (Preview.Top = 100) and
      (Preview.Right = 160) and (Preview.Bottom = 160),
      'Shift did not constrain the ellipse preview to a circle');
    Require(Creation.MouseUp(mbLeft, [ssShift], 160, 130),
      'Ellipse creation did not finish');
    Require((Document.LayerCount = 2) and
      (Document[1] is TVectArtRectangleLayer),
      'Ellipse layer was not created');
    Ellipse := TVectArtRectangleLayer(Document[1]);
    Require((Ellipse.Shape = vpsEllipse) and
      SameValue(Ellipse.Bounds.Width, Ellipse.Bounds.Height),
      'Created ellipse is not a circle');
    Require(not Ellipse.Filled and SameValue(Ellipse.StrokeWidth, 2.0),
      'Outline-only ellipse style differs');

    EditorState.SelectEllipseToolGroup;
    Require(EditorState.RectangleMode = vrmFill,
      'Ellipse did not switch to fill-only mode');
    Require(Creation.MouseDown(mbLeft, [], 200, 100) and
      Creation.MouseMove([ssLeft], 280, 140) and
      Creation.MouseUp(mbLeft, [], 280, 140),
      'Fill-only ellipse creation failed');
    Ellipse := TVectArtRectangleLayer(Document[2]);
    Require(Ellipse.Filled and SameValue(Ellipse.StrokeWidth, 0.0),
      'Fill-only ellipse style differs');

    EditorState.SelectEllipseToolGroup;
    Require(EditorState.RectangleMode = vrmFillAndOutline,
      'Ellipse did not switch to fill-and-outline mode');
    Require(Creation.MouseDown(mbLeft, [], 300, 100) and
      Creation.MouseMove([ssLeft], 380, 140) and
      Creation.MouseUp(mbLeft, [], 380, 140),
      'Fill-and-outline ellipse creation failed');
    Ellipse := TVectArtRectangleLayer(Document[3]);
    Require(Ellipse.Filled and SameValue(Ellipse.StrokeWidth, 2.0),
      'Fill-and-outline ellipse style differs');

    Require(History.CanUndo, 'Ellipse creation was not added to history');
    History.Undo;
    Require(Document.LayerCount = 3, 'Ellipse creation undo failed');
    History.Redo;
    Require((Document.LayerCount = 4) and
      (TVectArtRectangleLayer(Document[3]).Shape = vpsEllipse),
      'Ellipse creation redo failed');
    Writeln('Ellipse interaction tests: PASS');
  finally
    Creation.Free;
    History.Free;
    EditorState.Free;
    Document.Free;
  end;
end.
