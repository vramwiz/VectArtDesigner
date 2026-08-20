// 選択Rectangle一式の複製データ生成、挿入、選択更新を担当する。
unit VectArtDesignerLayerDuplication;

interface

uses
  VectArtDesignerDocument, VectArtDesignerEditHistory;

function CanDuplicateSelectedLayers(ADocument: TVectArtDocument): Boolean;
procedure DuplicateSelectedLayers(ADocument: TVectArtDocument;
  AEditHistory: TVectArtEditHistory);

implementation

uses
  System.Classes, System.Generics.Collections, System.SysUtils,
  VectArtDesignerLayerBatchCommands;

const
  DUPLICATE_OFFSET = 24;

function CanDuplicateSelectedLayers(ADocument: TVectArtDocument): Boolean;
var
  I: Integer;
begin
  Result := (ADocument <> nil) and (ADocument.SelectionCount > 0);
  if not Result then
    Exit;
  for I := 0 to ADocument.LayerCount - 1 do
    if ADocument.IsLayerSelected(I) and
      ((I = 0) or ADocument[I].Locked or
       not (ADocument[I] is TVectArtRectangleLayer)) then
      Exit(False);
end;

function CopyName(const SourceName: string; UsedNames: TStrings): string;
var
  Number: Integer;
begin
  Result := SourceName + ' Copy';
  Number := 2;
  while UsedNames.IndexOf(Result) >= 0 do
  begin
    Result := SourceName + ' Copy ' + Number.ToString;
    Inc(Number);
  end;
  UsedNames.Add(Result);
end;

procedure DuplicateSelectedLayers(ADocument: TVectArtDocument;
  AEditHistory: TVectArtEditHistory);
var
  AfterSelection: TArray<Integer>;
  BeforeSelection: TArray<Integer>;
  Data: TArray<TVectArtRectangleData>;
  DataList: TList<TVectArtRectangleData>;
  I: Integer;
  Index: Integer;
  NewIndices: TList<Integer>;
  RectangleData: TVectArtRectangleData;
  RectangleLayer: TVectArtRectangleLayer;
  StartIndex: Integer;
  UsedNames: TStringList;
begin
  if not CanDuplicateSelectedLayers(ADocument) then
    Exit;
  BeforeSelection := ADocument.GetSelectedLayerIndices;
  DataList := TList<TVectArtRectangleData>.Create;
  NewIndices := TList<Integer>.Create;
  UsedNames := TStringList.Create;
  try
    UsedNames.CaseSensitive := False;
    for I := 0 to ADocument.LayerCount - 1 do
      UsedNames.Add(ADocument[I].Name);
    for I := 1 to ADocument.LayerCount - 1 do
      if ADocument.IsLayerSelected(I) then
      begin
        RectangleLayer := TVectArtRectangleLayer(ADocument[I]);
        RectangleData.Bounds := RectangleLayer.Bounds;
        RectangleData.Bounds.Offset(DUPLICATE_OFFSET, DUPLICATE_OFFSET);
        RectangleData.FillColor := RectangleLayer.FillColor;
        RectangleData.Locked := False;
        RectangleData.Name := CopyName(RectangleLayer.Name, UsedNames);
        RectangleData.Opacity := RectangleLayer.Opacity;
        RectangleData.Visible := RectangleLayer.Visible;
        DataList.Add(RectangleData);
      end;

    StartIndex := ADocument.LayerCount;
    Data := DataList.ToArray;
    for I := 0 to High(Data) do
    begin
      Index := ADocument.InsertRectangle(ADocument.LayerCount, Data[I]);
      NewIndices.Add(Index);
    end;
    ADocument.SetSelectedLayers(NewIndices.ToArray);
    AfterSelection := ADocument.GetSelectedLayerIndices;
    if AEditHistory <> nil then
      AEditHistory.AddApplied(TVectArtInsertRectanglesCommand.Create(
        ADocument, StartIndex, Data, BeforeSelection, AfterSelection));
  finally
    UsedNames.Free;
    NewIndices.Free;
    DataList.Free;
  end;
end;

end.
