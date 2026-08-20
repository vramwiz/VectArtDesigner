// 複数Rectangleの一括挿入を1回のUndo／Redoとして管理する。
unit VectArtDesignerLayerBatchCommands;

interface

uses
  VectArtDesignerDocument, VectArtDesignerEditCommands;

type
  TVectArtInsertRectanglesCommand = class(TVectArtEditCommand)
  private
    FAfterSelection: TArray<Integer>;
    FBeforeSelection: TArray<Integer>;
    FData: TArray<TVectArtRectangleData>;
    FDocument: TVectArtDocument;
    FStartIndex: Integer;
  public
    constructor Create(ADocument: TVectArtDocument; StartIndex: Integer;
      const Data: TArray<TVectArtRectangleData>; const BeforeSelection,
      AfterSelection: TArray<Integer>);
    procedure Execute; override;
    procedure Undo; override;
  end;

implementation

constructor TVectArtInsertRectanglesCommand.Create(
  ADocument: TVectArtDocument; StartIndex: Integer;
  const Data: TArray<TVectArtRectangleData>; const BeforeSelection,
  AfterSelection: TArray<Integer>);
begin
  inherited Create;
  FDocument := ADocument;
  FStartIndex := StartIndex;
  FData := Copy(Data);
  FBeforeSelection := Copy(BeforeSelection);
  FAfterSelection := Copy(AfterSelection);
end;

procedure TVectArtInsertRectanglesCommand.Execute;
var
  I: Integer;
begin
  if FDocument = nil then
    Exit;
  for I := 0 to High(FData) do
    FDocument.InsertRectangle(FStartIndex + I, FData[I]);
  FDocument.SetSelectedLayers(FAfterSelection);
end;

procedure TVectArtInsertRectanglesCommand.Undo;
var
  I: Integer;
  RemovedData: TVectArtRectangleData;
begin
  if FDocument = nil then
    Exit;
  for I := High(FData) downto 0 do
    FDocument.RemoveRectangle(FStartIndex + I, RemovedData);
  FDocument.SetSelectedLayers(FBeforeSelection);
end;

end.
