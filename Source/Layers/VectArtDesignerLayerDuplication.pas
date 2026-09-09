// 選択された全対応レイヤーの複製、挿入、選択更新を担当する。
unit VectArtDesignerLayerDuplication;

interface

uses
  VectArtDesignerDocument, VectArtDesignerEditHistory;

function CanDuplicateSelectedLayers(ADocument: TVectArtDocument): Boolean;
procedure DuplicateSelectedLayers(ADocument: TVectArtDocument;
  AEditHistory: TVectArtEditHistory);

implementation

uses
  System.Classes, System.Generics.Collections, System.SysUtils, System.Types,
  VectArtDesignerEditCommands, VectArtDesignerLayerDataTransfer;

const
  DUPLICATE_OFFSET = 24;

type
  TVectArtDuplicateItem = record
    Kind: TVectArtLayerKind;
    RectangleData: TVectArtRectangleData;
    LineData: TVectArtLineData;
    PathData: TVectArtPathData;
    ImageData: TVectArtImageData;
    TextData: TVectArtTextData;
  end;

  TVectArtDuplicateCommand = class(TVectArtEditCommand)
  private
    FAfterSelection: TArray<Integer>;
    FBeforeSelection: TArray<Integer>;
    FDocument: TVectArtDocument;
    FItems: TArray<TVectArtDuplicateItem>;
    FStartIndex: Integer;
  public
    constructor Create(ADocument: TVectArtDocument; AStartIndex: Integer;
      const AItems: TArray<TVectArtDuplicateItem>; const ABeforeSelection,
      AAfterSelection: TArray<Integer>);
    procedure Execute; override;
    procedure Undo; override;
  end;

function CanDuplicateSelectedLayers(ADocument: TVectArtDocument): Boolean;
var
  I: Integer;
begin
  Result := (ADocument <> nil) and (ADocument.SelectionCount > 0);
  if not Result then
    Exit;
  for I := 0 to ADocument.LayerCount - 1 do
    if ADocument.IsLayerSelected(I) then
    begin
      if (I = 0) or ADocument[I].Locked then
        Exit(False);
      case ADocument[I].Kind of
        vlkRectangle, vlkLine, vlkPath, vlkImage, vlkText:
          ;
      else
        Exit(False);
      end;
    end;
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

constructor TVectArtDuplicateCommand.Create(ADocument: TVectArtDocument;
  AStartIndex: Integer; const AItems: TArray<TVectArtDuplicateItem>;
  const ABeforeSelection, AAfterSelection: TArray<Integer>);
var
  I: Integer;
begin
  inherited Create;
  FDocument := ADocument;
  FStartIndex := AStartIndex;
  FItems := Copy(AItems);
  // Undo履歴を元レイヤーの寿命から独立させる必要がある配列だけを複製する。
  for I := 0 to High(FItems) do
  begin
    FItems[I].PathData.Points := Copy(AItems[I].PathData.Points);
    FItems[I].ImageData.PngData := Copy(AItems[I].ImageData.PngData);
  end;
  FBeforeSelection := Copy(ABeforeSelection);
  FAfterSelection := Copy(AAfterSelection);
end;

procedure TVectArtDuplicateCommand.Execute;
var
  I: Integer;
begin
  if FDocument = nil then
    Exit;
  FDocument.BeginUpdate;
  try
    for I := 0 to High(FItems) do
      case FItems[I].Kind of
        vlkRectangle:
          FDocument.InsertRectangle(FStartIndex + I,
            FItems[I].RectangleData);
        vlkLine:
          FDocument.InsertLine(FStartIndex + I, FItems[I].LineData);
        vlkPath:
          FDocument.InsertPath(FStartIndex + I, FItems[I].PathData);
        vlkImage:
          FDocument.InsertImage(FStartIndex + I, FItems[I].ImageData);
        vlkText:
          FDocument.InsertText(FStartIndex + I, FItems[I].TextData);
      end;
    FDocument.SetSelectedLayers(FAfterSelection);
  finally
    FDocument.EndUpdate;
  end;
end;

procedure TVectArtDuplicateCommand.Undo;
var
  I: Integer;
  ImageData: TVectArtImageData;
  LineData: TVectArtLineData;
  PathData: TVectArtPathData;
  RectangleData: TVectArtRectangleData;
  TextData: TVectArtTextData;
begin
  if FDocument = nil then
    Exit;
  FDocument.BeginUpdate;
  try
    for I := High(FItems) downto 0 do
      case FItems[I].Kind of
        vlkRectangle:
          FDocument.RemoveRectangle(FStartIndex + I, RectangleData);
        vlkLine:
          FDocument.RemoveLine(FStartIndex + I, LineData);
        vlkPath:
          FDocument.RemovePath(FStartIndex + I, PathData);
        vlkImage:
          FDocument.RemoveImage(FStartIndex + I, ImageData);
        vlkText:
          FDocument.RemoveText(FStartIndex + I, TextData);
      end;
    FDocument.SetSelectedLayers(FBeforeSelection);
  finally
    FDocument.EndUpdate;
  end;
end;

procedure DuplicateSelectedLayers(ADocument: TVectArtDocument;
  AEditHistory: TVectArtEditHistory);
var
  AfterSelection: TArray<Integer>;
  BeforeSelection: TArray<Integer>;
  Command: TVectArtDuplicateCommand;
  GroupMap: TDictionary<TVectArtGroupId, TVectArtGroupId>;
  I: Integer;
  Item: TVectArtDuplicateItem;
  Items: TList<TVectArtDuplicateItem>;
  J: Integer;
  Layer: TVectArtLayer;
  NewGroupId: TVectArtGroupId;
  OldGroupId: TVectArtGroupId;
  StartIndex: Integer;
  UsedNames: TStringList;
begin
  if not CanDuplicateSelectedLayers(ADocument) then
    Exit;
  BeforeSelection := ADocument.GetSelectedLayerIndices;
  StartIndex := ADocument.LayerCount;
  Items := TList<TVectArtDuplicateItem>.Create;
  GroupMap := TDictionary<TVectArtGroupId, TVectArtGroupId>.Create;
  UsedNames := TStringList.Create;
  try
    UsedNames.CaseSensitive := False;
    for I := 0 to ADocument.LayerCount - 1 do
      UsedNames.Add(ADocument[I].Name);
    for I := 1 to ADocument.LayerCount - 1 do
      if ADocument.IsLayerSelected(I) then
      begin
        Layer := ADocument[I];
        Item := Default(TVectArtDuplicateItem);
        Item.Kind := Layer.Kind;
        OldGroupId := Layer.GroupId;
        NewGroupId := VECTART_NO_GROUP;
        if OldGroupId <> VECTART_NO_GROUP then
        begin
          if not GroupMap.TryGetValue(OldGroupId, NewGroupId) then
          begin
            NewGroupId := ADocument.AllocateGroupId;
            GroupMap.Add(OldGroupId, NewGroupId);
          end;
        end;
        case Item.Kind of
          vlkRectangle:
            begin
              Item.RectangleData := CaptureVectArtRectangleData(
                TVectArtRectangleLayer(Layer));
              Item.RectangleData.Bounds.Offset(DUPLICATE_OFFSET,
                DUPLICATE_OFFSET);
              Item.RectangleData.GroupId := NewGroupId;
              Item.RectangleData.Locked := False;
              Item.RectangleData.Name := CopyName(Layer.Name, UsedNames);
            end;
          vlkLine:
            begin
              Item.LineData := CaptureVectArtLineData(
                TVectArtLineLayer(Layer));
              Item.LineData.StartPoint.Offset(DUPLICATE_OFFSET,
                DUPLICATE_OFFSET);
              Item.LineData.EndPoint.Offset(DUPLICATE_OFFSET,
                DUPLICATE_OFFSET);
              Item.LineData.GroupId := NewGroupId;
              Item.LineData.Locked := False;
              Item.LineData.Name := CopyName(Layer.Name, UsedNames);
            end;
          vlkPath:
            begin
              Item.PathData := CaptureVectArtPathData(
                TVectArtPathLayer(Layer));
              for J := 0 to High(Item.PathData.Points) do
                Item.PathData.Points[J].Offset(DUPLICATE_OFFSET,
                  DUPLICATE_OFFSET);
              Item.PathData.GroupId := NewGroupId;
              Item.PathData.Locked := False;
              Item.PathData.Name := CopyName(Layer.Name, UsedNames);
            end;
          vlkImage:
            begin
              Item.ImageData := CaptureVectArtImageData(
                TVectArtImageLayer(Layer));
              for J := 0 to High(Item.ImageData.Points) do
                Item.ImageData.Points[J].Offset(DUPLICATE_OFFSET,
                  DUPLICATE_OFFSET);
              Item.ImageData.GroupId := NewGroupId;
              Item.ImageData.Locked := False;
              Item.ImageData.Name := CopyName(Layer.Name, UsedNames);
            end;
          vlkText:
            begin
              Item.TextData := CaptureVectArtTextData(
                TVectArtTextLayer(Layer));
              Item.TextData.Bounds.Offset(DUPLICATE_OFFSET,
                DUPLICATE_OFFSET);
              Item.TextData.GroupId := NewGroupId;
              Item.TextData.Locked := False;
              Item.TextData.Name := CopyName(Layer.Name, UsedNames);
            end;
        end;
        Items.Add(Item);
      end;

    SetLength(AfterSelection, Items.Count);
    for I := 0 to High(AfterSelection) do
      AfterSelection[I] := StartIndex + I;
    Command := TVectArtDuplicateCommand.Create(ADocument, StartIndex,
      Items.ToArray, BeforeSelection, AfterSelection);
    Command.Execute;
    if AEditHistory <> nil then
      AEditHistory.AddApplied(Command)
    else
      Command.Free;
  finally
    UsedNames.Free;
    GroupMap.Free;
    Items.Free;
  end;
end;

end.
