// 図形の影設定をDocumentと履歴へ接続する。文字効果や作成初期値は扱わない。
unit VectArtDesignerShadowSettings;
interface
uses VectArtDesignerNumericSlider, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.Graphics,
  VectArtDesignerDocument, VectArtDesignerColorHistory,
  VectArtDesignerEditHistory, VectArtDesignerColorSwatch;
type TVectArtShadowSettings = class(TScrollBox)
private
  FDocument: TVectArtDocument;
  FHistory: TVectArtEditHistory;
  FColorHistory: TVectArtColorHistory;
  FUpdating: Boolean;
  FIndex, FPopupIndex: Integer;
  FEnabled: TCheckBox;
  FColor: TVectArtColorSwatch;
  FBlur, FX, FY: TVectArtNumericSlider;
  procedure Change(Sender: TObject);
  procedure OpenColor(Sender: TObject);
  procedure ColorChanged(Sender: TObject; Color: TColor);
  procedure Apply(const Value: TVectArtShadow);
public
  constructor CreateForParent(AOwner: TComponent; AParent: TWinControl);
  destructor Destroy; override;
  procedure Configure(Document: TVectArtDocument; History: TVectArtEditHistory;
    ColorHistory: TVectArtColorHistory);
end;
implementation
uses VectArtDesignerSettingsFont, System.SysUtils, System.Math, VectArtDesignerPaintPopup, VectArtDesignerShadowCommand;
type TShadowControlAccess = class(TControl);
constructor TVectArtShadowSettings.CreateForParent(AOwner: TComponent; AParent: TWinControl);
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
    L.Caption:=Caption+'：'; L.SetBounds(8,Y+4,96,30);
  end;
  function SliderAt(const AName: string; Y, Minimum, Maximum: Integer): TVectArtNumericSlider;
  begin
    Result:=TVectArtNumericSlider.CreateForParent(Self,Self); Result.Name:=AName;
    Result.Configure(Minimum,Maximum,1,0);
    if Minimum<0 then Result.SetSliderRange(-100,100);
    Result.SetBounds(108,Y,114,34); Result.Anchors:=[akLeft,akTop,akRight];
    Result.OnChange:=Change;
  end;
begin
  inherited Create(AOwner);
  Parent := AParent;
  // 設定パネルと同じ描画方針にそろえ、ネイティブ入力欄の上から背景を転送しない。
  ParentDoubleBuffered:=False; DoubleBuffered:=False; ParentBackground:=False;
  ParentColor:=False; Color:=TColor($00212121); Font.Color:=TColor($00EEEEEE);
  ApplyVectArtSettingsFont(Self);
  Width:=234; BorderStyle:=bsNone; FIndex:=-1; FPopupIndex:=-1;
  FEnabled:=TCheckBox.Create(Self); FEnabled.Parent:=Self; FEnabled.Name:='ShadowEnabled';
  UsePageFont(FEnabled);
  FEnabled.Caption:='影を付ける'; FEnabled.SetBounds(12,12,210,26); FEnabled.OnClick:=Change;
  LabelAt('影の色',48); FColor:=TVectArtColorSwatch.Create(Self); FColor.Parent:=Self;
  UsePageFont(FColor);
  FColor.Name:='ShadowColor'; FColor.SetBounds(108,48,114,34); FColor.Anchors:=[akLeft,akTop,akRight]; FColor.OnClick:=OpenColor;
  LabelAt('ぼかしの強さ',88); FBlur:=SliderAt('ShadowBlur',88,0,100);
  LabelAt('位置 横 (px)',128); FX:=SliderAt('ShadowOffsetX',128,-10000,10000);
  LabelAt('位置 縦 (px)',168); FY:=SliderAt('ShadowOffsetY',168,-10000,10000);
end;
destructor TVectArtShadowSettings.Destroy;
begin CloseVectArtColorPopup(Self); inherited; end;
procedure TVectArtShadowSettings.Configure(Document: TVectArtDocument;
  History: TVectArtEditHistory; ColorHistory: TVectArtColorHistory);
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
  FDocument:=Document; FHistory:=History; FColorHistory:=ColorHistory;
  FIndex:=NewIndex;
  FUpdating:=True;
  try
    Enabled:=FIndex>=0; V:=Default(TVectArtShadow);
    if Enabled then V:=Document[FIndex].Shadow;
    FEnabled.Checked:=V.Enabled; FColor.Value:=V.Color;
    FBlur.SetDisplay(V.Blur); FX.SetDisplay(V.OffsetX); FY.SetDisplay(V.OffsetY);
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
var V: TVectArtShadow;
begin
  if FUpdating or (FIndex<0) then Exit;
  V:=FDocument[FIndex].Shadow; V.Enabled:=FEnabled.Checked; V.Color:=FColor.Value;
  V.Blur:=Round(FBlur.Value); V.OffsetX:=Round(FX.Value); V.OffsetY:=Round(FY.Value);
  if (Sender=FEnabled) and V.Enabled and (V.Blur=0) and (V.OffsetX=0) and (V.OffsetY=0) then
  begin V.Blur:=1; V.OffsetX:=1; V.OffsetY:=1; end;
  Apply(V); Configure(FDocument,FHistory,FColorHistory);
end;
procedure TVectArtShadowSettings.OpenColor(Sender: TObject);
begin
  if FIndex<0 then Exit;
  FPopupIndex:=FIndex;
  ShowVectArtColorPopup(Self,'影の色',FColor.Value,nil,ColorChanged,
    FColorHistory);
end;
procedure TVectArtShadowSettings.ColorChanged(Sender: TObject; Color: TColor);
var V: TVectArtShadow;
begin
  if (FIndex<0) or (FIndex<>FPopupIndex) then Exit;
  V:=FDocument[FIndex].Shadow; V.Color:=Color; Apply(V); FColor.Value:=Color;
end;
end.
