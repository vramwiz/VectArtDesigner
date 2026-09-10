// 新規作成用の2色を表示・編集する。既存オブジェクトやUndo履歴には接続しない。
// 共通の単色ポップアップだけを使い、グラデーションと画像を作成初期値へ持ち込まない。
unit VectArtDesignerCreationColors;
interface
uses System.Classes, Vcl.Controls, Vcl.Buttons, Vcl.Graphics,
  VectArtDesignerEditorState, VectArtDesignerColorHistory,
  VectArtDesignerColorSwatch;
type
  TVectArtCreationColors = class(TCustomControl)
  private
    FState: TVectArtEditorState;
    FColorHistory: TVectArtColorHistory;
    FColor1, FColor2: TVectArtColorSwatch;
    FSwap: TSpeedButton;
    FEditingFirst: Boolean;
    procedure SwapColors(Sender: TObject);
    procedure OpenColor(Sender: TObject);
    procedure ColorChanged(Sender: TObject; Color: TColor);
    procedure SetState(Value: TVectArtEditorState);
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure RefreshColors;
    property EditorState: TVectArtEditorState read FState write SetState;
    property ColorHistory: TVectArtColorHistory read FColorHistory
      write FColorHistory;
  end;
implementation
uses VectArtDesignerPaintPopup;
constructor TVectArtCreationColors.Create(AOwner: TComponent);
begin
  inherited;
  Height := 62; Color := TColor($00252525); DoubleBuffered := True;
  FColor1 := TVectArtColorSwatch.Create(Self); FColor1.Parent := Self;
  FColor1.Compact := True; FColor1.Circular := True; FColor1.Name := 'CreationColor1'; FColor1.OnClick := OpenColor;
  FColor1.Hint := '色1：線・枠・文字'; FColor1.ShowHint := True;
  FColor2 := TVectArtColorSwatch.Create(Self); FColor2.Parent := Self;
  FColor2.Compact := True; FColor2.Circular := True; FColor2.Name := 'CreationColor2'; FColor2.OnClick := OpenColor;
  FColor2.Hint := '色2：図形の塗り'; FColor2.ShowHint := True;
  FSwap := TSpeedButton.Create(Self); FSwap.Parent := Self;
  FSwap.Name := 'SwapCreationColors'; FSwap.Flat := True;
  FSwap.Caption := '⇄'; FSwap.Font.Name := 'Segoe UI Symbol'; FSwap.Font.Height := -19;
  FSwap.Hint := '線・文字の色と塗り色を入れ替え'; FSwap.ShowHint := True;
  FSwap.OnClick := SwapColors;
  RefreshColors; Resize;
end;
procedure TVectArtCreationColors.Resize;
var Left: Integer;
begin
  inherited;
  if FSwap = nil then Exit;
  Left := (Width-46) div 2;
  FColor1.SetBounds(Left,0,28,28);
  FColor2.SetBounds(Left+18,28,28,28);
  FSwap.SetBounds(Left+26,0,20,26);
end;
procedure TVectArtCreationColors.SetState(Value: TVectArtEditorState);
begin
  if FState <> Value then CloseVectArtColorPopup(Self);
  FState := Value; RefreshColors;
end;
procedure TVectArtCreationColors.RefreshColors;
begin
  FSwap.Enabled := FState <> nil;
  FColor1.Enabled := FState <> nil; FColor2.Enabled := FState <> nil;
  if FState = nil then begin FColor1.Value := clBlack; FColor2.Value := clWhite; end
  else begin FColor1.Value := FState.Color1; FColor2.Value := FState.Color2; end;
end;
procedure TVectArtCreationColors.SwapColors(Sender: TObject);
begin
  if FState = nil then Exit;
  // 開いているピッカーが交換前の色を再適用しないように閉じる。
  CloseVectArtColorPopup(Self);
  FState.SwapColors;
  RefreshColors;
end;
procedure TVectArtCreationColors.OpenColor(Sender: TObject);
begin
  if FState = nil then Exit;
  FEditingFirst := Sender = FColor1;
  if FEditingFirst then
    ShowVectArtColorPopup(Self,'色1（線・文字）',FState.Color1,nil,
      ColorChanged,FColorHistory)
  else
    ShowVectArtColorPopup(Self,'色2（塗り）',FState.Color2,nil,
      ColorChanged,FColorHistory);
end;
procedure TVectArtCreationColors.ColorChanged(Sender: TObject; Color: TColor);
begin
  if FState = nil then Exit;
  if FEditingFirst then FState.Color1 := Color else FState.Color2 := Color;
  RefreshColors;
end;
end.
