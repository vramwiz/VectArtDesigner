// 図形の塗り・線・文字のペイント設定を独立したUndo操作として適用する。
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
  // 線色とグラデーションを同時に更新し、線幅・線種・内側の塗りは維持する。
  TVectArtStrokePaintCommand = class(TVectArtEditCommand)
  private
    FDocument: TVectArtDocument;
    FIndex: Integer;
    FBefore, FAfter: TVectArtFillStyle;
    FBeforeColor, FAfterColor: TColor;
    procedure Apply(Color: TColor; const Style: TVectArtFillStyle);
  public
    constructor Create(Document: TVectArtDocument; Index: Integer;
      Color: TColor; const Style: TVectArtFillStyle);
    procedure Execute; override;
    procedure Undo; override;
  end;
implementation
constructor TVectArtStrokePaintCommand.Create(Document: TVectArtDocument; Index: Integer;
  Color: TColor; const Style: TVectArtFillStyle);
begin
  inherited Create;
  FDocument := Document; FIndex := Index; FAfter := Style; FAfterColor := Color;
  FBefore := Document[Index].StrokePaint;
  if Document[Index] is TVectArtRectangleLayer then FBeforeColor := TVectArtRectangleLayer(Document[Index]).StrokeColor
  else if Document[Index] is TVectArtLineLayer then FBeforeColor := TVectArtLineLayer(Document[Index]).StrokeColor
  else FBeforeColor := TVectArtPathLayer(Document[Index]).StrokeColor;
end;
procedure TVectArtStrokePaintCommand.Apply(Color: TColor; const Style: TVectArtFillStyle);
begin
  FDocument[FIndex].StrokePaint := Style;
  if FDocument[FIndex] is TVectArtRectangleLayer then TVectArtRectangleLayer(FDocument[FIndex]).StrokeColor := Color
  else if FDocument[FIndex] is TVectArtLineLayer then TVectArtLineLayer(FDocument[FIndex]).StrokeColor := Color
  else TVectArtPathLayer(FDocument[FIndex]).StrokeColor := Color;
  FDocument.ChangedLayer(FIndex);
end;
procedure TVectArtStrokePaintCommand.Execute;
begin Apply(FAfterColor,FAfter); end;
procedure TVectArtStrokePaintCommand.Undo;
begin Apply(FBeforeColor,FBefore); end;

constructor TVectArtFillCommand.Create(Document: TVectArtDocument; Index: Integer;
  Color: TColor; const Fill: TVectArtFillStyle);
begin
  inherited Create;
  FDocument := Document; FIndex := Index; FAfter := Fill; FAfterColor := Color;
  if Document[Index] is TVectArtRectangleLayer then
    with TVectArtRectangleLayer(Document[Index]) do
    begin FBefore := FillStyle; FBeforeColor := FillColor; FBeforeFilled := Filled; end
  else if Document[Index] is TVectArtTextLayer then
    with TVectArtTextLayer(Document[Index]) do
    begin FBefore := FillStyle; FBeforeColor := TextColor; FBeforeFilled := True; end
  else with TVectArtPathLayer(Document[Index]) do
    begin FBefore := FillStyle; FBeforeColor := FillColor; FBeforeFilled := Filled; end;
end;
procedure TVectArtFillCommand.Apply(Color: TColor; const Fill: TVectArtFillStyle; IsFilled: Boolean);
begin
  if FDocument[FIndex] is TVectArtRectangleLayer then
    with TVectArtRectangleLayer(FDocument[FIndex]) do
    begin FillStyle := Fill; FillColor := Color; Filled := IsFilled; end
  else if FDocument[FIndex] is TVectArtTextLayer then
    with TVectArtTextLayer(FDocument[FIndex]) do
    begin FillStyle := Fill; TextColor := Color; end
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