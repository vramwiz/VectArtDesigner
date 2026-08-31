program LayerDeleteActionTests;

{$APPTYPE CONSOLE}

// Deleteキーと操作バーが共有する複数レイヤー削除とUndoを検証する。

uses
  System.Math,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerEditCommands in
    'Source\Core\Commands\VectArtDesignerEditCommands.pas',
  VectArtDesignerLayerStructureCommands in
    'Source\Core\Commands\VectArtDesignerLayerStructureCommands.pas',
  VectArtDesignerLayerBatchCommands in
    'Source\Core\Commands\VectArtDesignerLayerBatchCommands.pas',
  VectArtDesignerEditHistory in
    'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerEditorState in
    'Source\Core\VectArtDesignerEditorState.pas',
  VectArtDesignerLayerDuplication in
    'Source\Layers\VectArtDesignerLayerDuplication.pas',
  VectArtDesignerLayerOperations in
    'Source\Layers\VectArtDesignerLayerOperations.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function RectangleData(const Name: string; Left: Single): TVectArtRectangleData;
begin
  Result.Bounds := TRectF.Create(Left, 10, Left + 20, 30);
  Result.FillColor := clWhite;
  Result.Locked := False;
  Result.Name := Name;
  Result.Opacity := 1.0;
  Result.RotationDegrees := 0.0;
  Result.StrokeColor := clBlack;
  Result.StrokeStyle := vssSolid;
  Result.StrokeWidth := 0.0;
  Result.Visible := True;
end;

function ImageData(const Name: string; Left: Single): TVectArtImageData;
begin
  Result.Name := Name;
  Result.Locked := False;
  Result.Opacity := 0.75;
  Result.PngData := [$89, $50, $4E, $47];
  Result.Points[0] := PointF(Left, 100);
  Result.Points[1] := PointF(Left + 40, 100);
  Result.Points[2] := PointF(Left + 40, 140);
  Result.Points[3] := PointF(Left, 140);
  Result.SourceKind := visImage;
  Result.Visible := True;
end;

var
  Document: TVectArtDocument;
  History: TVectArtEditHistory;
  Image1Index: Integer;
  Image2Index: Integer;
  ImageLayer: TVectArtImageLayer;
  Operations: TVectArtLayerOperations;
begin
  Document := TVectArtDocument.Create;
  History := TVectArtEditHistory.Create;
  Operations := TVectArtLayerOperations.Create;
  try
    Document.InsertRectangle(1, RectangleData('Rectangle 1', 10));
    Document.InsertRectangle(2, RectangleData('Rectangle 2', 40));
    Document.InsertRectangle(3, RectangleData('Rectangle 3', 70));
    Document.SetSelectedLayers([2]);
    Operations.Document := Document;
    Operations.EditHistory := History;
    Require(Operations.CanExecute(vlaDelete), 'Delete must be enabled');
    Operations.Execute(vlaDelete);
    Require(Document.LayerCount = 3, 'An unselected layer was deleted');
    Require(Document[1].Name = 'Rectangle 1',
      'Layer before the selection was not preserved');
    Require(Document[2].Name = 'Rectangle 3',
      'Layer after the selection was not preserved');
    Require(History.CanUndo, 'Delete was not added to edit history');
    History.Undo;
    Require(Document.LayerCount = 4, 'Delete undo did not restore layer');
    Require(Document[2].Name = 'Rectangle 2',
      'Delete undo restored the layer at the wrong position');
    Require(Document.IsLayerSelected(2) and
      (Document.SelectionCount = 1),
      'Delete undo did not restore selection');

    Document.SetSelectedLayers([1, 3]);
    Operations.Execute(vlaDelete);
    Require(Document.LayerCount = 2,
      'Non-contiguous delete removed an unselected layer');
    Require(Document[1].Name = 'Rectangle 2',
      'Non-contiguous delete did not preserve the unselected layer');
    History.Undo;
    Require(Document.LayerCount = 4,
      'Non-contiguous delete undo did not restore layers');
    Require(Document.IsLayerSelected(1) and Document.IsLayerSelected(3) and
      (Document.SelectionCount = 2),
      'Non-contiguous delete undo did not restore selection');

    Image1Index := Document.InsertImage(Document.LayerCount,
      ImageData('Image 1', 100));
    Image2Index := Document.InsertImage(Document.LayerCount,
      ImageData('Image 2', 200));
    Document.SetSelectedLayers([Image1Index, Image2Index]);
    History.Clear;
    Require(Operations.CanExecute(vlaDuplicate),
      'Image duplicate must be enabled');
    Operations.Execute(vlaDuplicate);
    Require(Document.LayerCount = 8,
      'Image duplicate count differs');
    Require((Document[6].Name = 'Image 1 Copy') and
      (Document[7].Name = 'Image 2 Copy'),
      'Image duplicate names differ');
    ImageLayer := TVectArtImageLayer(Document[6]);
    Require(SameValue(ImageLayer.Points[0].X, 124.0) and
      SameValue(ImageLayer.Points[0].Y, 124.0),
      'Image duplicate offset differs');
    Require((Length(ImageLayer.PngData) = 4) and
      (ImageLayer.PngData[1] = $50), 'Image duplicate PNG differs');
    Require(Document.IsLayerSelected(6) and Document.IsLayerSelected(7) and
      (Document.SelectionCount = 2),
      'Image duplicates were not selected');
    History.Undo;
    Require(Document.LayerCount = 6,
      'Image duplicate undo did not remove copies');
    Require(Document.IsLayerSelected(Image1Index) and
      Document.IsLayerSelected(Image2Index),
      'Image duplicate undo did not restore selection');
    History.Redo;
    Require((Document.LayerCount = 8) and
      (Document[6] is TVectArtImageLayer) and
      (Document[7] is TVectArtImageLayer),
      'Image duplicate redo differs');
    Writeln('Layer delete action: PASS');
  finally
    Operations.Free;
    History.Free;
    Document.Free;
  end;
end.
