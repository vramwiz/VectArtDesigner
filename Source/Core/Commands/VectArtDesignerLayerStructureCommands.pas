// Rectangleレイヤーの挿入、削除、積層順変更をUndo／Redo可能にする。
unit VectArtDesignerLayerStructureCommands;

interface

uses
  VectArtDesignerDocument, VectArtDesignerEditCommands;

type
  TVectArtInsertRectangleCommand = class(TVectArtEditCommand)
  private
    FAfterSelection: TArray<Integer>;
    FBeforeSelection: TArray<Integer>;
    FData: TVectArtRectangleData;
    FDocument: TVectArtDocument;
    FIndex: Integer;
  public
    constructor Create(ADocument: TVectArtDocument; Index: Integer;
      const Data: TVectArtRectangleData; const BeforeSelection,
      AfterSelection: TArray<Integer>);
    procedure Execute; override;
    procedure Undo; override;
  end;

  TVectArtDeleteRectangleCommand = class(TVectArtEditCommand)
  private
    FAfterSelection: TArray<Integer>;
    FBeforeSelection: TArray<Integer>;
    FData: TVectArtRectangleData;
    FDocument: TVectArtDocument;
    FIndex: Integer;
  public
    constructor Create(ADocument: TVectArtDocument; Index: Integer;
      const Data: TVectArtRectangleData; const BeforeSelection,
      AfterSelection: TArray<Integer>);
    procedure Execute; override;
    procedure Undo; override;
  end;

  TVectArtMoveLayerCommand = class(TVectArtEditCommand)
  private
    FAfterSelection: TArray<Integer>;
    FBeforeSelection: TArray<Integer>;
    FDocument: TVectArtDocument;
    FNewIndex: Integer;
    FOldIndex: Integer;
  public
    constructor Create(ADocument: TVectArtDocument; OldIndex,
      NewIndex: Integer; const BeforeSelection,
      AfterSelection: TArray<Integer>);
    procedure Execute; override;
    procedure Undo; override;
  end;

implementation

{ TVectArtInsertRectangleCommand }

constructor TVectArtInsertRectangleCommand.Create(
  ADocument: TVectArtDocument; Index: Integer;
  const Data: TVectArtRectangleData; const BeforeSelection,
  AfterSelection: TArray<Integer>);
begin
  inherited Create;
  FDocument := ADocument;
  FIndex := Index;
  FData := Data;
  FBeforeSelection := Copy(BeforeSelection);
  FAfterSelection := Copy(AfterSelection);
end;

procedure TVectArtInsertRectangleCommand.Execute;
begin
  if FDocument = nil then
    Exit;
  FIndex := FDocument.InsertRectangle(FIndex, FData);
  FDocument.SetSelectedLayers(FAfterSelection);
end;

procedure TVectArtInsertRectangleCommand.Undo;
var
  RemovedData: TVectArtRectangleData;
begin
  if FDocument = nil then
    Exit;
  FDocument.RemoveRectangle(FIndex, RemovedData);
  FDocument.SetSelectedLayers(FBeforeSelection);
end;

{ TVectArtDeleteRectangleCommand }

constructor TVectArtDeleteRectangleCommand.Create(
  ADocument: TVectArtDocument; Index: Integer;
  const Data: TVectArtRectangleData; const BeforeSelection,
  AfterSelection: TArray<Integer>);
begin
  inherited Create;
  FDocument := ADocument;
  FIndex := Index;
  FData := Data;
  FBeforeSelection := Copy(BeforeSelection);
  FAfterSelection := Copy(AfterSelection);
end;

procedure TVectArtDeleteRectangleCommand.Execute;
var
  RemovedData: TVectArtRectangleData;
begin
  if FDocument = nil then
    Exit;
  FDocument.RemoveRectangle(FIndex, RemovedData);
  FDocument.SetSelectedLayers(FAfterSelection);
end;

procedure TVectArtDeleteRectangleCommand.Undo;
begin
  if FDocument = nil then
    Exit;
  FIndex := FDocument.InsertRectangle(FIndex, FData);
  FDocument.SetSelectedLayers(FBeforeSelection);
end;

{ TVectArtMoveLayerCommand }

constructor TVectArtMoveLayerCommand.Create(ADocument: TVectArtDocument;
  OldIndex, NewIndex: Integer; const BeforeSelection,
  AfterSelection: TArray<Integer>);
begin
  inherited Create;
  FDocument := ADocument;
  FOldIndex := OldIndex;
  FNewIndex := NewIndex;
  FBeforeSelection := Copy(BeforeSelection);
  FAfterSelection := Copy(AfterSelection);
end;

procedure TVectArtMoveLayerCommand.Execute;
begin
  if FDocument = nil then
    Exit;
  FDocument.MoveLayer(FOldIndex, FNewIndex);
  FDocument.SetSelectedLayers(FAfterSelection);
end;

procedure TVectArtMoveLayerCommand.Undo;
begin
  if FDocument = nil then
    Exit;
  FDocument.MoveLayer(FNewIndex, FOldIndex);
  FDocument.SetSelectedLayers(FBeforeSelection);
end;

end.
