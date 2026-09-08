// 選択レイヤーの表示切替を1件のUndo操作として適用する。
// 混在選択は全件を隠し、全件が非表示の場合だけ再表示へ切り替える。
unit VectArtDesignerLayerVisibilityOperations;

interface

uses
  VectArtDesignerDocument, VectArtDesignerEditHistory;

function IsVectArtSelectionHidden(Document: TVectArtDocument): Boolean;
procedure ToggleVectArtSelectionHidden(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory);

implementation

uses
  VectArtDesignerEditCommands;

function IsVectArtSelectionHidden(Document: TVectArtDocument): Boolean;
var
  I: Integer;
begin
  Result := (Document <> nil) and (Document.SelectionCount > 0);
  if not Result then
    Exit;
  for I := 1 to Document.LayerCount - 1 do
    if Document.IsLayerSelected(I) and Document[I].Visible then
      Exit(False);
end;

procedure ToggleVectArtSelectionHidden(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory);
var
  Command: TVectArtCompoundCommand;
  I: Integer;
  NewVisible: Boolean;
begin
  if (Document = nil) or (Document.SelectionCount = 0) then
    Exit;
  NewVisible := IsVectArtSelectionHidden(Document);
  Command := TVectArtCompoundCommand.Create;
  for I := 1 to Document.LayerCount - 1 do
    if Document.IsLayerSelected(I) and
      (Document[I].Visible <> NewVisible) then
      Command.Add(TVectArtLayerBooleanCommand.Create(Document, I,
        vlbpVisible, Document[I].Visible, NewVisible));
  if Command.Count = 0 then
  begin
    Command.Free;
    Exit;
  end;
  Document.BeginUpdate;
  try
    Command.Execute;
  finally
    Document.EndUpdate;
  end;
  if EditHistory <> nil then
    EditHistory.AddApplied(Command)
  else
    Command.Free;
end;

end.
