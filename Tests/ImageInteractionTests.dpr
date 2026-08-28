program ImageInteractionTests;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.Math,
  System.SysUtils,
  System.Types,
  Vcl.Controls,
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

function RectCenter(const Value: TRect): TPoint;
begin
  Result := Point((Value.Left + Value.Right) div 2,
    (Value.Top + Value.Bottom) div 2);
end;

var
  Center: TPoint;
  Data: TVectArtImageData;
  Document: TVectArtDocument;
  Geometry: TVectArtSelectionGeometry;
  History: TVectArtEditHistory;
  I: Integer;
  ImageLayer: TVectArtImageLayer;
  ImageLayer2: TVectArtImageLayer;
  Interaction: TVectArtCanvasInteraction;
  RotationStart: TPoint;
  RotationTarget: TPoint;
  ScreenQuad: TVectArtScreenQuad;
begin
  Document := TVectArtDocument.Create;
  History := TVectArtEditHistory.Create;
  Interaction := TVectArtCanvasInteraction.Create;
  try
    Data.Name := 'Image 1';
    Data.Opacity := 1;
    Data.PngData := nil;
    Data.Points[0] := PointF(100, 100);
    Data.Points[1] := PointF(200, 100);
    Data.Points[2] := PointF(200, 200);
    Data.Points[3] := PointF(100, 200);
    Data.SourceKind := visImage;
    Data.Visible := True;
    Data.Locked := False;
    Document.InsertImage(1, Data);
    Interaction.EditHistory := History;
    Interaction.Configure(Document, Rect(0, 0, 1000, 1000), 1);

    Require(Interaction.MouseDown(mbLeft, 150, 150),
      'Image move did not start');
    Require(Document.SelectedIndex = 1, 'Image was not selected');
    Require(Interaction.MouseMove([ssLeft], 170, 180),
      'Image move was not applied');
    Require(Interaction.MouseUp(mbLeft), 'Image move did not finish');
    ImageLayer := TVectArtImageLayer(Document[1]);
    Require(SameValue(ImageLayer.Points[0].X, 120.0) and
      SameValue(ImageLayer.Points[0].Y, 130.0), 'Image move differs');
    History.Undo;
    Require(SameValue(ImageLayer.Points[0].X, 100.0) and
      SameValue(ImageLayer.Points[0].Y, 100.0), 'Image move undo differs');
    History.Redo;
    Require(SameValue(ImageLayer.Points[0].X, 120.0) and
      SameValue(ImageLayer.Points[0].Y, 130.0), 'Image move redo differs');
    History.Undo;

    Interaction.Configure(Document, Rect(0, 0, 1000, 1000), 1);
    for I := 0 to High(ScreenQuad) do
      ScreenQuad[I] := Point(Round(ImageLayer.Points[I].X),
        Round(ImageLayer.Points[I].Y));
    Geometry := BuildRotatedSelectionGeometry(ScreenQuad,
      SelectionFrameOffset(0, 1));
    Center := RectCenter(Geometry.Handles[vshTopLeft]);
    Require(Interaction.MouseDown(mbLeft, Center.X, Center.Y),
      'Image resize did not start');
    Require(Interaction.MouseMove([ssLeft], Center.X - 20,
      Center.Y - 10), 'Image resize was not applied');
    Require(Interaction.MouseUp(mbLeft), 'Image resize did not finish');
    Require(SameValue(ImageLayer.Points[0].X, 80.0, 0.01) and
      SameValue(ImageLayer.Points[0].Y, 90.0, 0.01),
      'Image corner resize differs');
    Require(SameValue(ImageLayer.Points[2].X, 200.0, 0.01) and
      SameValue(ImageLayer.Points[2].Y, 200.0, 0.01),
      'Image resize moved the opposite corner');
    History.Undo;
    Require(SameValue(ImageLayer.Points[0].X, 100.0, 0.01) and
      SameValue(ImageLayer.Points[0].Y, 100.0, 0.01),
      'Image resize undo differs');

    Interaction.Configure(Document, Rect(0, 0, 1000, 1000), 1);
    for I := 0 to High(ScreenQuad) do
      ScreenQuad[I] := Point(Round(ImageLayer.Points[I].X),
        Round(ImageLayer.Points[I].Y));
    Geometry := BuildRotatedSelectionGeometry(ScreenQuad,
      SelectionFrameOffset(0, 1));
    RotationStart := RectCenter(Geometry.RotationHandles[0]);
    Center := Point(150, 150);
    RotationTarget := Point(Center.X - (RotationStart.Y - Center.Y),
      Center.Y + (RotationStart.X - Center.X));
    Require(Interaction.MouseDown(mbLeft, RotationStart.X,
      RotationStart.Y), 'Image rotation did not start');
    Require(Interaction.MouseMove([ssLeft], RotationTarget.X,
      RotationTarget.Y), 'Image rotation was not applied');
    Require(Interaction.MouseUp(mbLeft), 'Image rotation did not finish');
    Require(SameValue(ImageLayer.Points[0].X, 200.0, 1.0) and
      SameValue(ImageLayer.Points[0].Y, 100.0, 1.0),
      'Image rotation differs');
    History.Undo;
    Require(SameValue(ImageLayer.Points[0].X, 100.0, 0.01) and
      SameValue(ImageLayer.Points[0].Y, 100.0, 0.01),
      'Image rotation undo differs');

    Data.Name := 'Image 2';
    Data.Points[0] := PointF(300, 100);
    Data.Points[1] := PointF(400, 100);
    Data.Points[2] := PointF(400, 200);
    Data.Points[3] := PointF(300, 200);
    Document.InsertImage(2, Data);
    ImageLayer2 := TVectArtImageLayer(Document[2]);
    Document.SetSelectedLayers([1, 2]);
    History.Clear;
    Interaction.Configure(Document, Rect(0, 0, 1000, 1000), 1);
    Require(Interaction.MouseDown(mbLeft, 150, 150),
      'Multiple image move did not start');
    Require(Interaction.MouseMove([ssLeft], 170, 180),
      'Multiple image move was not applied');
    Require(Interaction.MouseUp(mbLeft),
      'Multiple image move did not finish');
    Require(SameValue(ImageLayer.Points[0].X, 120.0, 0.01) and
      SameValue(ImageLayer.Points[0].Y, 130.0, 0.01) and
      SameValue(ImageLayer2.Points[0].X, 320.0, 0.01) and
      SameValue(ImageLayer2.Points[0].Y, 130.0, 0.01),
      'Multiple image move differs');
    History.Undo;
    Require(SameValue(ImageLayer.Points[0].X, 100.0, 0.01) and
      SameValue(ImageLayer2.Points[0].X, 300.0, 0.01),
      'Multiple image move undo differs');
    History.Redo;
    Require(SameValue(ImageLayer.Points[0].X, 120.0, 0.01) and
      SameValue(ImageLayer2.Points[0].X, 320.0, 0.01),
      'Multiple image move redo differs');
    History.Undo;

    Interaction.Configure(Document, Rect(0, 0, 1000, 1000), 1);
    Geometry := BuildSelectionGeometry(Rect(100, 100, 400, 200),
      SelectionFrameOffset(0, 1));
    Center := RectCenter(Geometry.Handles[vshTopLeft]);
    Require(Interaction.MouseDown(mbLeft, Center.X, Center.Y),
      'Multiple image resize did not start');
    Require(Interaction.MouseMove([ssLeft], Center.X - 50,
      Center.Y - 50), 'Multiple image resize was not applied');
    Require(Interaction.MouseUp(mbLeft),
      'Multiple image resize did not finish');
    Require(SameValue(ImageLayer.Points[0].X, 50.0, 0.1) and
      SameValue(ImageLayer.Points[0].Y, 50.0, 0.1),
      'Multiple image resize origin differs');
    Require(SameValue(ImageLayer2.Points[2].X, 400.0, 0.1) and
      SameValue(ImageLayer2.Points[2].Y, 200.0, 0.1),
      'Multiple image resize moved the opposite corner');
    History.Undo;
    Require(SameValue(ImageLayer.Points[0].X, 100.0, 0.01) and
      SameValue(ImageLayer.Points[0].Y, 100.0, 0.01) and
      SameValue(ImageLayer2.Points[0].X, 300.0, 0.01),
      'Multiple image resize undo differs');
    Writeln('Image interaction: PASS');
  finally
    Interaction.Free;
    History.Free;
    Document.Free;
  end;
end.
