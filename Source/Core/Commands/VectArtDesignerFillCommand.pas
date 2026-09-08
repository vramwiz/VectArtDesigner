// 四角形・閉じたパスの塗り設定を一つのUndo操作として適用する。
// 塗りの有効状態も保存し、取り消し時には輪郭のみの状態まで復元する。
unit VectArtDesignerFillCommand;
interface
uses Vcl.Graphics, VectArtDesignerDocument, VectArtDesignerEditCommands;
type
  TVectArtFillCommand = class(TVectArtEditCommand)
  private
    FDocument: TVectArtDocument;
    FIndex: Integer;
    FBefore, FAfter: TVectArtFillStyle;
    FBeforeColor, FAfterColor: TColor;
    FBeforeFilled: Boolean;
    procedure Apply(Color: TColor; const Fill: TVectArtFillStyle; IsFilled: Boolean);
  public
    constructor Create(Document: TVectArtDocument; Index: Integer;
      Color: TColor; const Fill: TVectArtFillStyle);
    procedure Execute; override;
    procedure Undo; override;
  end;
implementation
constructor TVectArtFillCommand.Create(Document: TVectArtDocument; Index: Integer;
  Color: TColor; const Fill: TVectArtFillStyle);
begin
  inherited Create;
  FDocument := Document; FIndex := Index; FAfter := Fill; FAfterColor := Color;
  if Document[Index] is TVectArtRectangleLayer then
    with TVectArtRectangleLayer(Document[Index]) do
    begin FBefore := FillStyle; FBeforeColor := FillColor; FBeforeFilled := Filled; end
  else with TVectArtPathLayer(Document[Index]) do
    begin FBefore := FillStyle; FBeforeColor := FillColor; FBeforeFilled := Filled; end;
end;
procedure TVectArtFillCommand.Apply(Color: TColor; const Fill: TVectArtFillStyle; IsFilled: Boolean);
begin
  if FDocument[FIndex] is TVectArtRectangleLayer then
    with TVectArtRectangleLayer(FDocument[FIndex]) do
    begin FillStyle := Fill; FillColor := Color; Filled := IsFilled; end
  else with TVectArtPathLayer(FDocument[FIndex]) do
    begin FillStyle := Fill; FillColor := Color; Filled := IsFilled; end;
  // 色と方式を揃えてから通知し、途中状態のプレビュー生成を防ぐ。
  FDocument.ChangedLayer(FIndex);
end;
procedure TVectArtFillCommand.Execute;
begin Apply(FAfterColor,FAfter,True); end;
procedure TVectArtFillCommand.Undo;
begin Apply(FBeforeColor,FBefore,FBeforeFilled); end;
end.