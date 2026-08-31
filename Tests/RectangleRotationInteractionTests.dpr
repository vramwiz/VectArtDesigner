program RectangleRotationInteractionTests;

{$APPTYPE CONSOLE}

// 四隅外側の回転マーカー操作とUndo／Redoを検証する。

uses
  System.Classes,
  System.Math,
  System.SysUtils,
  System.Types,
  Vcl.Controls,
  Vcl.Graphics,
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerEditCommands in
    'Source\Core\Commands\VectArtDesignerEditCommands.pas',
  VectArtDesignerEditHistory in
    'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerSelectionGeometry in
    'Source\Editor\VectArtDesignerSelectionGeometry.pas',
  VectArtDesignerCanvasInteraction in
    'Source\Editor\VectArtDesignerCanvasInteraction.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  Data: TVectArtRectangleData;
  Document: TVectArtDocument;
  Geometry: TVectArtSelectionGeometry;
  History: TVectArtEditHistory;
  Interaction: TVectArtCanvasInteraction;
  OuterBounds: TRectF;
  Quad: TVectArtScreenQuad;
  Rectangle: TVectArtRectangleLayer;
  RightHandlePoint: TPoint;
  ScreenRect: TRect;
begin
  Quad[0] := Point(100, 100);
  Quad[1] := Point(300, 100);
  Quad[2] := Point(300, 150);
  Quad[3] := Point(100, 150);
  Geometry := BuildRotatedSelectionGeometry(Quad, 12);
  Require((Geometry.FramePoints[0] = Point(88, 88)) and
    (Geometry.FramePoints[1] = Point(312, 88)) and
    (Geometry.FramePoints[2] = Point(312, 162)) and
    (Geometry.FramePoints[3] = Point(88, 162)),
    'Rotated selection frame offset is not uniform');
  Document := TVectArtDocument.Create;
  History := TVectArtEditHistory.Create;
  Interaction := TVectArtCanvasInteraction.Create;
  try
    Data.Bounds := TRectF.Create(100, 100, 200, 200);
    Data.FillColor := clWhite;
    Data.Locked := False;
    Data.Name := 'Rectangle 1';
    Data.Opacity := 1.0;
    Data.RotationDegrees := 0.0;
    Data.StrokeColor := clBlack;
    Data.MifStrokeStyle := vssSolid;
    Data.StrokeWidth := 0.0;
    Data.Visible := True;
    Document.InsertRectangle(1, Data);
    Document.SelectedIndex := 1;
    Interaction.EditHistory := History;
    Interaction.Configure(Document, Rect(0, 0, 1000, 1000), 1.0);

    Require(Interaction.CursorAt(82, 82) = RotationHandleCursor,
      'Rotation marker cursor differs');
    Require(Interaction.MouseDown(mbLeft, 82, 82),
      'Rotation marker did not start a drag');
    Require(Interaction.MouseMove([ssLeft], 218, 82),
      'Rotation drag was not applied');
    Require(Interaction.MouseUp(mbLeft), 'Rotation drag did not finish');
    Rectangle := TVectArtRectangleLayer(Document[1]);
    Require(SameValue(Rectangle.RotationDegrees, 90.0, 0.1),
      'Rotation angle differs');
    Require(History.CanUndo, 'Rotation was not added to edit history');
    History.Undo;
    Require(SameValue(Rectangle.RotationDegrees, 0.0, 0.1),
      'Rotation undo differs');
    History.Redo;
    Require(SameValue(Rectangle.RotationDegrees, 90.0, 0.1),
      'Rotation redo differs');

    Document.SetRectangleBounds(1, TRectF.Create(100, 100, 300, 200));
    Document.SetRectangleRotation(1, 30.0);
    Interaction.Configure(Document, Rect(0, 0, 1000, 1000), 1.0);
    Require(Interaction.MouseDown(mbLeft, 200, 150),
      'Second body click did not start');
    Require(Interaction.MouseUp(mbLeft), 'Second body click did not finish');
    Require(Interaction.AxisAlignedSelection,
      'Second body click did not select the outer frame');

    OuterBounds := QuadBounds(RectangleCorners(Rectangle.Bounds,
      Rectangle.RotationDegrees));
    ScreenRect := Rect(Round(OuterBounds.Left), Round(OuterBounds.Top),
      Round(OuterBounds.Right), Round(OuterBounds.Bottom));
    Geometry := BuildSelectionGeometry(ScreenRect,
      SelectionFrameOffset(Rectangle.StrokeWidth, 1.0));
    RightHandlePoint := Point(
      (Geometry.Handles[vshRight].Left +
       Geometry.Handles[vshRight].Right) div 2,
      (Geometry.Handles[vshRight].Top +
       Geometry.Handles[vshRight].Bottom) div 2);
    Require(Interaction.MouseDown(mbLeft, RightHandlePoint.X,
      RightHandlePoint.Y), 'Outer frame resize did not start');
    Require(Interaction.MouseMove([ssLeft], RightHandlePoint.X + 30,
      RightHandlePoint.Y), 'Outer frame resize was not applied');
    Require(Interaction.MouseUp(mbLeft), 'Outer frame resize did not finish');
    Require(SameValue(Rectangle.RotationDegrees, 30.0, 0.1),
      'Outer frame resize changed the rotation');
    Require(Rectangle.Bounds.Width > 200,
      Format('Outer frame resize did not enlarge the rotated rectangle: %.3f',
        [Rectangle.Bounds.Width]));
    Require(Interaction.AxisAlignedSelection,
      'Outer frame resize changed selection mode');
    Require(Interaction.MouseDown(mbLeft,
      Round((Rectangle.Bounds.Left + Rectangle.Bounds.Right) * 0.5),
      Round((Rectangle.Bounds.Top + Rectangle.Bounds.Bottom) * 0.5)),
      'Third body click did not start');
    Require(Interaction.MouseUp(mbLeft), 'Third body click did not finish');
    Require(not Interaction.AxisAlignedSelection,
      'Third body click did not restore the rotated frame');
    Writeln('Rectangle rotation interaction: PASS');
  finally
    Interaction.Free;
    History.Free;
    Document.Free;
  end;
end.
