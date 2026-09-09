// 図形の影設定をDocumentと履歴へ接続する。文字効果や作成初期値は扱わない。
unit VectArtDesignerShadowSettings;
interface
uses System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.Graphics,
  VectArtDesignerDocument, VectArtDesignerEditHistory, VectArtDesignerColorSwatch;
type TVectArtShadowSettings = class(TScrollBox)
private
  FDocument: TVectArtDocument;
  FHistory: TVectArtEditHistory;
  FUpdating: Boolean;
  FIndex, FPopupIndex: Integer;
  FEnabled: TCheckBox;
  FColor: TVectArtColorSwatch;
  FBlur, FX, FY: TEdit;
  procedure Change(Sender: TObject);
  procedure OpenColor(Sender: TObject);
  procedure ColorChanged(Sender: TObject; Color: TColor);
  procedure Apply(const Value: TVectArtShadow);
public
  constructor Create(AOwner: TComponent); override;
  destructor Destroy; override;
  procedure Configure(Document: TVectArtDocument; History: TVectArtEditHistory);
end;
implementation
uses System.SysUtils, System.Math, VectArtDesignerPaintPopup, VectArtDesignerShadowCommand;
type TShadowControlAccess = class(TControl);
constructor TVectArtShadowSettings.Create(AOwner: TComponent);
  procedure UsePageFont(Control: TControl);
  begin
    TShadowControlAccess(Control).ParentFont := True;
    Control.StyleElements := Control.StyleElements - [seFont];
  end;
  procedure LabelAt(const Caption: string; Y: Integer);
  var L: TStaticText;
  begin
    // 通常ページと同じ独立ウィンドウにし、親背景の転送でラベルが消えるのを防ぐ。
    L:=TStaticText.Create(Self); L.Parent:=Self; L.AutoSize:=False;
    L.ParentColor:=False; L.Color:=Color; UsePageFont(L);
    L.Caption:=Caption; L.SetBounds(12,Y,210,22);
  end;
  function EditAt(const AName: string; Y: Integer): TEdit;
  begin
    Result:=TEdit.Create(Self); Result.Parent:=Self; Result.Name:=AName; UsePageFont(Result);
    Result.SetBounds(12,Y,210,26); Result.Anchors:=[akLeft,akTop,akRight]; Result.OnExit:=Change;
  end;
begin
  inherited;
  // Page／TabSheetと同じ描画方針にそろえ、ネイティブ入力欄の上から背景を転送しない。
  ParentDoubleBuffered:=False; DoubleBuffered:=False; ParentBackground:=False;
  ParentColor:=False; Color:=TColor($00212121); Font.Color:=TColor($00EEEEEE);
  Width:=234; BorderStyle:=bsNone; FIndex:=-1; FPopupIndex:=-1;
  FEnabled:=TCheckBox.Create(Self); FEnabled.Parent:=Self; FEnabled.Name:='ShadowEnabled';
  UsePageFont(FEnabled);
  FEnabled.Caption:='影を付ける'; FEnabled.SetBounds(12,12,210,26); FEnabled.OnClick:=Change;
  LabelAt('影の色',52); FColor:=TVectArtColorSwatch.Create(Self); FColor.Parent:=Self;
  UsePageFont(FColor);
  FColor.Name:='ShadowColor'; FColor.SetBounds(12,76,210,36); FColor.Anchors:=[akLeft,akTop,akRight]; FColor.OnClick:=OpenColor;
  LabelAt('ぼかしの強さ',128); FBlur:=EditAt('ShadowBlur',152);
  LabelAt('横方向位置 (px)',194); FX:=EditAt('ShadowOffsetX',218);
  LabelAt('縦方向位置 (px)',260); FY:=EditAt('ShadowOffsetY',284);
end;
destructor TVectArtShadowSettings.Destroy;
begin CloseVectArtColorPopup(Self); inherited; end;
procedure TVectArtShadowSettings.Configure(Document: TVectArtDocument; History: TVectArtEditHistory);
var V: TVectArtShadow; NewIndex: Integer; L: TVectArtLayer;
begin
  NewIndex:=-1;
  if (Document<>nil) and (Document.SelectionCount=1) then
  begin
    L:=Document[Document.SelectedIndex];
    if not L.Locked and ((L is TVectArtRectangleLayer) or
      ((L is TVectArtPathLayer) and TVectArtPathLayer(L).Closed)) then NewIndex:=Document.SelectedIndex;
  end;
  if (FDocument<>Document) or (FIndex<>NewIndex) then CloseVectArtColorPopup(Self);
  FDocument:=Document; FHistory:=History; FIndex:=NewIndex;
  FUpdating:=True;
  try
    Enabled:=FIndex>=0; V:=Default(TVectArtShadow);
    if Enabled then V:=Document[FIndex].Shadow;
    FEnabled.Checked:=V.Enabled; FColor.Value:=V.Color;
    FBlur.Text:=IntToStr(V.Blur); FX.Text:=IntToStr(V.OffsetX); FY.Text:=IntToStr(V.OffsetY);
    FColor.Enabled:=Enabled; FBlur.Enabled:=Enabled; FX.Enabled:=Enabled; FY.Enabled:=Enabled;
  finally FUpdating:=False; end;
end;
procedure TVectArtShadowSettings.Apply(const Value: TVectArtShadow);
var Command: TVectArtShadowCommand; Before: TVectArtShadow;
begin
  if FUpdating or (FDocument=nil) or (FIndex<0) or FDocument[FIndex].Locked then Exit;
  Before:=FDocument[FIndex].Shadow;
  if (Before.Enabled=Value.Enabled) and (Before.Color=Value.Color) and
    (Before.Blur=Value.Blur) and (Before.OffsetX=Value.OffsetX) and (Before.OffsetY=Value.OffsetY) then Exit;
  Command:=TVectArtShadowCommand.Create(FDocument,FIndex,Value);
  Command.Execute;
  if FHistory<>nil then FHistory.AddApplied(Command) else Command.Free;
end;
procedure TVectArtShadowSettings.Change(Sender: TObject);
var V: TVectArtShadow; B,X,Y: Integer;
begin
  if FUpdating or (FIndex<0) then Exit;
  if not TryStrToInt(FBlur.Text,B) or not TryStrToInt(FX.Text,X) or not TryStrToInt(FY.Text,Y) then
  begin Configure(FDocument,FHistory); Exit; end;
  V:=FDocument[FIndex].Shadow; V.Enabled:=FEnabled.Checked; V.Color:=FColor.Value;
  V.Blur:=EnsureRange(B,0,100); V.OffsetX:=EnsureRange(X,-10000,10000); V.OffsetY:=EnsureRange(Y,-10000,10000);
  if (Sender=FEnabled) and V.Enabled and (V.Blur=0) and (V.OffsetX=0) and (V.OffsetY=0) then
  begin V.Blur:=1; V.OffsetX:=1; V.OffsetY:=1; end;
  Apply(V); Configure(FDocument,FHistory);
end;
procedure TVectArtShadowSettings.OpenColor(Sender: TObject);
begin
  if FIndex<0 then Exit;
  FPopupIndex:=FIndex;
  ShowVectArtColorPopup(Self,'影の色',FColor.Value,[clBlack,clWhite,clRed],ColorChanged);
end;
procedure TVectArtShadowSettings.ColorChanged(Sender: TObject; Color: TColor);
var V: TVectArtShadow;
begin
  if (FIndex<0) or (FIndex<>FPopupIndex) then Exit;
  V:=FDocument[FIndex].Shadow; V.Color:=Color; Apply(V); FColor.Value:=Color;
end;
end.
