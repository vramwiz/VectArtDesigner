// Verifies flat grouping, atomic selection, regrouping, and undo/redo.
program LayerGroupOperationsTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerEditCommands in
    'Source\Core\Commands\VectArtDesignerEditCommands.pas',
  VectArtDesignerEditHistory in
    'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerLayerBatchCommands in
    'Source\Core\Commands\VectArtDesignerLayerBatchCommands.pas',
  VectArtDesignerLayerGroupOperations in
    'Source\Core\Commands\VectArtDesignerLayerGroupOperations.pas',
  VectArtDesignerLayerDuplication in
    'Source\Layers\VectArtDesignerLayerDuplication.pas';

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function RectangleData(const Name: string; Left: Single): TVectArtRectangleData;
begin
  Result := Default(TVectArtRectangleData);
  Result.Name := Name;
  Result.Bounds := TRectF.Create(Left, 10, Left + 20, 30);
  Result.FillColor := clWhite;
  Result.Filled := True;
  Result.Opacity := 1;
  Result.StrokeColor := clBlack;
  Result.StrokeStyle := vssSolid;
  Result.Visible := True;
end;

var
  Data: TVectArtRectangleData;
  Document: TVectArtDocument;
  FirstGroup: TVectArtGroupId;
  History: TVectArtEditHistory;
begin
  Document := TVectArtDocument.Create;
  History := TVectArtEditHistory.Create;
  try
    Document.InsertRectangle(1, RectangleData('First', 10));
    Document.InsertRectangle(2, RectangleData('Second', 40));
    Document.InsertRectangle(3, RectangleData('Third', 70));

    Document.SetSelectedLayers([1, 2]);
    Check(CanGroupVectArtSelection(Document), 'Initial selection cannot group');
    GroupVectArtSelection(Document, History);
    FirstGroup := Document[1].GroupId;
    Check((FirstGroup <> VECTART_NO_GROUP) and
      (Document[2].GroupId = FirstGroup), 'Group membership was not applied');
    Check(not CanGroupVectArtSelection(Document),
      'Already grouped selection was allowed to group again');

    Document.SelectedIndex := 1;
    Check((Document.SelectionCount = 2) and Document.IsLayerSelected(2),
      'Selecting one member did not select the full group');
    Document.ToggleSelectedLayer(2);
    Check(Document.SelectionCount = 0,
      'Toggling one member did not clear the full group');

    Document.SetSelectedLayers([1, 3]);
    Check(Document.SelectionCount = 3,
      'Selecting a group member did not expand before regrouping');
    GroupVectArtSelection(Document, History);
    Check((Document[1].GroupId = Document[2].GroupId) and
      (Document[2].GroupId = Document[3].GroupId) and
      (Document[1].GroupId <> FirstGroup), 'Regrouping created nesting');

    History.Undo;
    Check((Document[1].GroupId = FirstGroup) and
      (Document[2].GroupId = FirstGroup) and
      (Document[3].GroupId = VECTART_NO_GROUP),
      'Regroup undo did not restore flat memberships');
    History.Redo;
    Check(CanUngroupVectArtSelection(Document),
      'Regrouped selection cannot ungroup');
    UngroupVectArtSelection(Document, History);
    Check((Document[1].GroupId = VECTART_NO_GROUP) and
      (Document[2].GroupId = VECTART_NO_GROUP) and
      (Document[3].GroupId = VECTART_NO_GROUP),
      'Ungroup did not clear memberships');
    History.Undo;
    Check((Document[1].GroupId <> VECTART_NO_GROUP) and
      (Document[1].GroupId = Document[3].GroupId),
      'Ungroup undo did not restore membership');

    Check(Document.RemoveRectangle(1, Data), 'Grouped layer removal failed');
    Check(Data.GroupId <> VECTART_NO_GROUP,
      'Removal data did not retain group membership');
    Document.InsertRectangle(1, Data);
    Check(Document[1].GroupId = Data.GroupId,
      'Insertion did not restore group membership');

    Document.SelectedIndex := 1;
    DuplicateSelectedLayers(Document, History);
    Check((Document.LayerCount = 7) and (Document.SelectionCount = 3) and
      (Document[4].GroupId <> VECTART_NO_GROUP) and
      (Document[4].GroupId = Document[6].GroupId) and
      (Document[4].GroupId <> Document[1].GroupId),
      'Grouped duplication did not create an independent flat group');
    History.Undo;
    Check(Document.LayerCount = 4, 'Grouped duplication undo failed');
    History.Redo;
    Check((Document.LayerCount = 7) and
      (Document[4].GroupId = Document[6].GroupId),
      'Grouped duplication redo lost membership');

    Document.SetLayerLocked(4, True);
    Document.SelectedIndex := 4;
    Check(not CanUngroupVectArtSelection(Document),
      'Locked group was allowed to ungroup');
    Writeln('PASS flat grouping, selection and undo/redo');
  finally
    History.Free;
    Document.Free;
  end;
end.
