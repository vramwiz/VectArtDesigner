program CutoutSelectionTests;

{$APPTYPE CONSOLE}

// Verify the four transient cutout input modes without changing Document data.

uses
  System.Classes,
  System.Math,
  System.SysUtils,
  System.Types,
  Vcl.Controls,
  Vcl.Graphics,
  VectArtDesignerGeometry in
    'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerEditorState in
    'Source\Core\VectArtDesignerEditorState.pas',
  VectArtDesignerFreehandGeometry in
    'Source\Editor\Geometry\VectArtDesignerFreehandGeometry.pas',
  VectArtDesignerCutoutSelection in
    'Source\Editor\Clipboard\VectArtDesignerCutoutSelection.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  EditorState: TVectArtEditorState;
  Outline: TArray<TPointF>;
  ScreenOutline: TArray<TPoint>;
  Selection: TVectArtCutoutSelection;
begin
  EditorState := TVectArtEditorState.Create;
  Selection := TVectArtCutoutSelection.Create;
  try
    EditorState.SelectCutoutToolGroup;
    Selection.Configure(EditorState, Rect(100, 50, 500, 350), 2.0);
    Require(Selection.MouseDown(mbLeft, [], 120, 70),
      'Rectangle cutout did not start');
    Require(Selection.MouseMove([ssLeft], 220, 170),
      'Rectangle cutout did not move');
    Require(Selection.MouseUp(mbLeft, 220, 170) and Selection.Committed,
      'Rectangle cutout did not commit');
    Outline := Selection.LogicalOutline;
    Require((Length(Outline) = 4) and SameValue(Outline[0].X, 10.0) and
      SameValue(Outline[0].Y, 10.0) and SameValue(Outline[2].X, 60.0) and
      SameValue(Outline[2].Y, 60.0),
      'Rectangle cutout coordinates differ');

    EditorState.SelectCutoutToolGroup;
    Selection.Configure(EditorState, Rect(100, 50, 500, 350), 2.0);
    Require((Selection.Mode = vcmEllipse) and not Selection.Committed,
      'Changing cutout mode did not clear the previous region');
    Require(Selection.MouseDown(mbLeft, [], 140, 90) and
      Selection.MouseMove([ssLeft], 240, 190) and
      Selection.MouseUp(mbLeft, 240, 190) and Selection.Committed,
      'Ellipse cutout did not commit');

    EditorState.SelectCutoutToolGroup;
    Selection.Configure(EditorState, Rect(100, 50, 500, 350), 2.0);
    Require(Selection.MouseDown(mbLeft, [], 120, 70),
      'Polygon first point failed');
    Selection.MouseMove([], 260, 80);
    Require(Selection.MouseDown(mbLeft, [], 260, 80),
      'Polygon second point failed');
    Selection.MouseMove([], 180, 220);
    Require(Selection.MouseDown(mbLeft, [], 180, 220),
      'Polygon third point failed');
    Require(Selection.FinishPolygon and Selection.Committed and
      (Length(Selection.LogicalOutline) = 3),
      'Polygon cutout did not close');

    EditorState.SelectCutoutToolGroup;
    Selection.Configure(EditorState, Rect(100, 50, 500, 350), 2.0);
    Require(Selection.MouseDown(mbLeft, [], 120, 70),
      'Freehand cutout did not start');
    Selection.MouseMove([ssLeft], 260, 80);
    Selection.MouseMove([ssLeft], 300, 220);
    Selection.MouseMove([ssLeft], 170, 250);
    Require(Selection.MouseUp(mbLeft, 120, 70) and Selection.Committed,
      'Freehand cutout did not close');
    ScreenOutline := Selection.ScreenOutline;
    Require((Length(ScreenOutline) >= 4) and
      (ScreenOutline[0] = ScreenOutline[High(ScreenOutline)]),
      'Freehand preview is not closed');

    Selection.Cancel;
    Require(not Selection.Active and not Selection.Committed and
      (Length(Selection.LogicalOutline) = 0),
      'Cancel retained a cutout region');
    Writeln('Cutout selection tests: PASS');
  finally
    Selection.Free;
    EditorState.Free;
  end;
end.
