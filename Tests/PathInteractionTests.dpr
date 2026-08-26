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
  Data: TVectArtPathData;
  Document: TVectArtDocument;
  History: TVectArtEditHistory;
  Interaction: TVectArtCanvasInteraction;
  Operations: TVectArtLayerOperations;
  Path: TVectArtPathLayer;
begin
  Document := TVectArtDocument.Create;
  History := TVectArtEditHistory.Create;
  Interaction := TVectArtCanvasInteraction.Create;
  Operations := TVectArtLayerOperations.Create;
  try
    Data.Name := 'Path 1';
    Data.Points := [PointF(100, 100), PointF(200, 100),
      PointF(200, 200), PointF(100, 200)];
    Data.Closed := True;
    Data.Filled := True;
    Data.FillColor := clBlue;
    Data.StrokeColor := clBlack;
    Data.StrokeStyle := vssSolid;
    Data.StrokeWidth := 2;
    Data.Opacity := 1;
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
    Operations.Free;
    Interaction.Free;
    History.Free;
    Document.Free;
  end;
end.
