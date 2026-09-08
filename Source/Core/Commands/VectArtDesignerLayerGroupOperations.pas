// Manages flat group membership as one undoable document edit.
// Groups never own layers; membership changes preserve the document layer order.
unit VectArtDesignerLayerGroupOperations;

interface

uses
  VectArtDesignerDocument, VectArtDesignerEditHistory;

function CanGroupVectArtSelection(Document: TVectArtDocument): Boolean;
function CanUngroupVectArtSelection(Document: TVectArtDocument): Boolean;
procedure GroupVectArtSelection(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory);
procedure UngroupVectArtSelection(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory);

implementation

uses
  VectArtDesignerEditCommands;

type
  TVectArtLayerGroupCommand = class(TVectArtEditCommand)
  private
    FDocument: TVectArtDocument;
    FLayerIds: TArray<TVectArtLayerId>;
    FNewGroupIds: TArray<TVectArtGroupId>;
    FOldGroupIds: TArray<TVectArtGroupId>;
    procedure Apply(const GroupIds: TArray<TVectArtGroupId>);
  public
    constructor Create(ADocument: TVectArtDocument;
      const LayerIndices: TArray<Integer>;
      const NewGroupIds: TArray<TVectArtGroupId>);
    procedure Execute; override;
    procedure Undo; override;
  end;

function SelectionContainsLockedLayer(Document: TVectArtDocument): Boolean;
var
  Index: Integer;
begin
  Result := True;
  if Document = nil then
    Exit;
  for Index in Document.GetSelectedLayerIndices do
    if Document[Index].Locked then
      Exit;
  Result := False;
end;

function CanGroupVectArtSelection(Document: TVectArtDocument): Boolean;
var
  First: Boolean;
  GroupId: TVectArtGroupId;
  Index: Integer;
begin
  Result := (Document <> nil) and (Document.SelectionCount >= 2) and
    not SelectionContainsLockedLayer(Document);
  if not Result then
    Exit;
  First := True;
  GroupId := VECTART_NO_GROUP;
  for Index in Document.GetSelectedLayerIndices do
    if First then
    begin
      GroupId := Document[Index].GroupId;
      First := False;
    end
    else if Document[Index].GroupId <> GroupId then
      Exit(True);
  // 同一グループへの再割当ては履歴を増やすだけなので操作として提供しない。
  Result := GroupId = VECTART_NO_GROUP;
end;

function CanUngroupVectArtSelection(Document: TVectArtDocument): Boolean;
var
  GroupId: TVectArtGroupId;
  Index: Integer;
begin
  Result := (Document <> nil) and (Document.SelectionCount > 0) and
    not SelectionContainsLockedLayer(Document);
  if not Result then
    Exit;
  GroupId := VECTART_NO_GROUP;
  for Index in Document.GetSelectedLayerIndices do
  begin
    if Document[Index].GroupId = VECTART_NO_GROUP then
      Exit(False);
    if GroupId = VECTART_NO_GROUP then
      GroupId := Document[Index].GroupId
    else if Document[Index].GroupId <> GroupId then
      Exit(False);
  end;
end;

procedure GroupVectArtSelection(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory);
var
  Command: TVectArtLayerGroupCommand;
  GroupId: TVectArtGroupId;
  GroupIds: TArray<TVectArtGroupId>;
  I: Integer;
  Selection: TArray<Integer>;
begin
  if not CanGroupVectArtSelection(Document) then
    Exit;
  Selection := Document.GetSelectedLayerIndices;
  GroupId := Document.AllocateGroupId;
  SetLength(GroupIds, Length(Selection));
  for I := 0 to High(GroupIds) do
    GroupIds[I] := GroupId;
  Command := TVectArtLayerGroupCommand.Create(Document, Selection, GroupIds);
  Command.Execute;
  if EditHistory <> nil then
    EditHistory.AddApplied(Command)
  else
    Command.Free;
end;

procedure UngroupVectArtSelection(Document: TVectArtDocument;
  EditHistory: TVectArtEditHistory);
var
  Command: TVectArtLayerGroupCommand;
  GroupIds: TArray<TVectArtGroupId>;
  Selection: TArray<Integer>;
begin
  if not CanUngroupVectArtSelection(Document) then
    Exit;
  Selection := Document.GetSelectedLayerIndices;
  SetLength(GroupIds, Length(Selection));
  Command := TVectArtLayerGroupCommand.Create(Document, Selection, GroupIds);
  Command.Execute;
  if EditHistory <> nil then
    EditHistory.AddApplied(Command)
  else
    Command.Free;
end;

{ TVectArtLayerGroupCommand }

procedure TVectArtLayerGroupCommand.Apply(
  const GroupIds: TArray<TVectArtGroupId>);
var
  I: Integer;
  Index: Integer;
  Selection: TArray<Integer>;
begin
  if FDocument = nil then
    Exit;
  SetLength(Selection, 0);
  FDocument.BeginUpdate;
  try
    for I := 0 to High(FLayerIds) do
    begin
      Index := FDocument.IndexOfLayerId(FLayerIds[I]);
      if Index > 0 then
        FDocument.SetLayerGroup(Index, GroupIds[I]);
    end;
    SetLength(Selection, Length(FLayerIds));
    for I := 0 to High(FLayerIds) do
      Selection[I] := FDocument.IndexOfLayerId(FLayerIds[I]);
    FDocument.SetSelectedLayers(Selection);
  finally
    FDocument.EndUpdate;
  end;
end;

constructor TVectArtLayerGroupCommand.Create(ADocument: TVectArtDocument;
  const LayerIndices: TArray<Integer>;
  const NewGroupIds: TArray<TVectArtGroupId>);
var
  I: Integer;
begin
  inherited Create;
  FDocument := ADocument;
  SetLength(FLayerIds, Length(LayerIndices));
  SetLength(FOldGroupIds, Length(LayerIndices));
  FNewGroupIds := Copy(NewGroupIds);
  for I := 0 to High(LayerIndices) do
  begin
    FLayerIds[I] := ADocument[LayerIndices[I]].LayerId;
    FOldGroupIds[I] := ADocument[LayerIndices[I]].GroupId;
  end;
end;

procedure TVectArtLayerGroupCommand.Execute;
begin
  Apply(FNewGroupIds);
end;

procedure TVectArtLayerGroupCommand.Undo;
begin
  Apply(FOldGroupIds);
end;

end.
