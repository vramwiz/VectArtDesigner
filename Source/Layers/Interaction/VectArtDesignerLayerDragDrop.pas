// レイヤー一覧D&Dの挿入境界計算と、並び替えのUndo／Redoを担当する。
// 一覧のマウス捕捉・挿入線・自動スクロールは表示Control側に残す。
unit VectArtDesignerLayerDragDrop;

interface

uses
  System.Types, VectArtDesignerDocument, VectArtDesignerEditCommands,
  VectArtDesignerLayerRenderer;

function VectArtDragSourcesEditable(Document: TVectArtDocument;
  const SourceIndices: TArray<Integer>): Boolean;
function VectArtLayerDropBoundary(Document: TVectArtDocument;
  const Entry: TVectArtLayerDisplayEntry; AboveTarget: Boolean): Integer;
function NearestVectArtLayerRow(Renderer: TVectArtLayerRenderer;
  const Bounds: TRect; Y: Integer): Integer;
function CreateVectArtLayerDropCommand(Document: TVectArtDocument;
  const SourceIndices: TArray<Integer>; InsertIndex: Integer):
  TVectArtEditCommand;

implementation

uses
  System.Generics.Collections, System.Math;

type
  TVectArtLayerOrderCommand = class(TVectArtEditCommand)
  private
    FAfterOrder: TArray<TVectArtLayerId>;
    FBeforeOrder: TArray<TVectArtLayerId>;
    FDocument: TVectArtDocument;
    FSelection: TArray<TVectArtLayerId>;
    procedure ApplyOrder(const Order: TArray<TVectArtLayerId>);
  public
    constructor Create(ADocument: TVectArtDocument;
      const ABeforeOrder, AAfterOrder,
      ASelection: TArray<TVectArtLayerId>);
    procedure Execute; override;
    procedure Undo; override;
  end;

function VectArtDragSourcesEditable(Document: TVectArtDocument;
  const SourceIndices: TArray<Integer>): Boolean;
var
  Index: Integer;
begin
  Result := (Document <> nil) and (Length(SourceIndices) > 0);
  if not Result then
    Exit;
  for Index in SourceIndices do
    if (Index <= 0) or (Index >= Document.LayerCount) or
      Document[Index].Locked then
      Exit(False);
end;

function VectArtLayerDropBoundary(Document: TVectArtDocument;
  const Entry: TVectArtLayerDisplayEntry; AboveTarget: Boolean): Integer;
var
  GroupIndices: TArray<Integer>;
begin
  Result := Entry.LayerIndex;
  if (Document = nil) or (Result <= 0) then
    Exit(-1);
  if Entry.GroupId <> VECTART_NO_GROUP then
  begin
    GroupIndices := Document.GetGroupLayerIndices(Entry.GroupId);
    // フラットグループの中間へ別レイヤーを差し込まず、一体の境界を使う。
    if Length(GroupIndices) > 0 then
      if AboveTarget then
        Result := GroupIndices[High(GroupIndices)] + 1
      else
        Result := GroupIndices[0];
  end
  else if AboveTarget then
    Inc(Result);
end;

function NearestVectArtLayerRow(Renderer: TVectArtLayerRenderer;
  const Bounds: TRect; Y: Integer): Integer;
var
  Distance: Integer;
  I: Integer;
  ItemRect: TRect;
  NearestDistance: Integer;
begin
  Result := -1;
  if Renderer = nil then
    Exit;
  NearestDistance := MaxInt;
  for I := 1 to Renderer.DisplayRowCount do
  begin
    ItemRect := Renderer.LayerItemRect(Bounds, I);
    Distance := Abs(Y - (ItemRect.Top + ItemRect.Bottom) div 2);
    if Distance < NearestDistance then
    begin
      NearestDistance := Distance;
      Result := I;
    end;
  end;
end;

procedure TVectArtLayerOrderCommand.ApplyOrder(
  const Order: TArray<TVectArtLayerId>);
var
  I: Integer;
  Index: Integer;
  SelectionIndices: TList<Integer>;
begin
  if FDocument = nil then
    Exit;
  FDocument.BeginUpdate;
  SelectionIndices := TList<Integer>.Create;
  try
    // LayerIdで解決し直すため、直前のUndo／RedoでIndexが変化していても安全。
    for I := 0 to High(Order) do
    begin
      Index := FDocument.IndexOfLayerId(Order[I]);
      if (Index > 0) and (Index <> I + 1) then
        FDocument.MoveLayer(Index, I + 1);
    end;
    for I := 0 to High(FSelection) do
    begin
      Index := FDocument.IndexOfLayerId(FSelection[I]);
      if Index > 0 then
        SelectionIndices.Add(Index);
    end;
    FDocument.SetSelectedLayers(SelectionIndices.ToArray);
  finally
    SelectionIndices.Free;
    FDocument.EndUpdate;
  end;
end;

constructor TVectArtLayerOrderCommand.Create(ADocument: TVectArtDocument;
  const ABeforeOrder, AAfterOrder, ASelection: TArray<TVectArtLayerId>);
begin
  inherited Create;
  FDocument := ADocument;
  FBeforeOrder := Copy(ABeforeOrder);
  FAfterOrder := Copy(AAfterOrder);
  FSelection := Copy(ASelection);
end;

procedure TVectArtLayerOrderCommand.Execute;
begin
  ApplyOrder(FAfterOrder);
end;

procedure TVectArtLayerOrderCommand.Undo;
begin
  ApplyOrder(FBeforeOrder);
end;

function CreateVectArtLayerDropCommand(Document: TVectArtDocument;
  const SourceIndices: TArray<Integer>; InsertIndex: Integer):
  TVectArtEditCommand;
var
  AfterOrder: TList<TVectArtLayerId>;
  BeforeOrder: TArray<TVectArtLayerId>;
  Destination: Integer;
  I: Integer;
  InsertPosition: Integer;
  OrderChanged: Boolean;
  SelectionIds: TArray<TVectArtLayerId>;
  SourceIds: TList<TVectArtLayerId>;
begin
  Result := nil;
  if not VectArtDragSourcesEditable(Document, SourceIndices) or
    (InsertIndex < 1) then
    Exit;
  SetLength(BeforeOrder, Document.LayerCount - 1);
  for I := 1 to Document.LayerCount - 1 do
    BeforeOrder[I - 1] := Document[I].LayerId;
  SetLength(SelectionIds, Length(SourceIndices));
  SourceIds := TList<TVectArtLayerId>.Create;
  AfterOrder := TList<TVectArtLayerId>.Create;
  try
    Destination := InsertIndex;
    for I := 0 to High(SourceIndices) do
    begin
      SelectionIds[I] := Document[SourceIndices[I]].LayerId;
      SourceIds.Add(SelectionIds[I]);
      if SourceIndices[I] < InsertIndex then
        Dec(Destination);
    end;
    for I := 0 to High(BeforeOrder) do
      if SourceIds.IndexOf(BeforeOrder[I]) < 0 then
        AfterOrder.Add(BeforeOrder[I]);
    InsertPosition := EnsureRange(Destination - 1, 0, AfterOrder.Count);
    // 逆順で同じ位置へ挿入すると、元の積層順を維持できる。
    for I := SourceIds.Count - 1 downto 0 do
      AfterOrder.Insert(InsertPosition, SourceIds[I]);
    OrderChanged := Length(BeforeOrder) <> AfterOrder.Count;
    if not OrderChanged then
      for I := 0 to High(BeforeOrder) do
        if BeforeOrder[I] <> AfterOrder[I] then
        begin
          OrderChanged := True;
          Break;
        end;
    if OrderChanged then
      Result := TVectArtLayerOrderCommand.Create(Document, BeforeOrder,
        AfterOrder.ToArray, SelectionIds);
  finally
    AfterOrder.Free;
    SourceIds.Free;
  end;
end;

end.
