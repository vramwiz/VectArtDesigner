// 未対応の文字装飾は設定UIを先行提供し、Documentへ適用しないことを明示する。
unit VectArtDesignerSettingsDrafts;

interface

uses System.Classes, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.Graphics,
  VectArtDesignerColorSwatch, VectArtDesignerPaintPopup;

type
  TVectArtSettingsDraft = class(TScrollBox)
  private
    FKind: Integer;
    FSelector: TComboBox;
    FFields: TScrollBox;
    procedure ChangeKind(Sender: TObject);
    procedure ChooseColor(Sender: TObject);
    procedure ColorChanged(Sender: TObject; Color: TColor);
  protected
    procedure Resize; override;
  public
    constructor CreateKind(AOwner: TComponent; AParent: TWinControl; Kind: Integer);
  end;

implementation

uses System.SysUtils;

constructor TVectArtSettingsDraft.CreateKind(AOwner: TComponent; AParent: TWinControl; Kind: Integer);
var L: TLabel;
begin
  inherited Create(AOwner);
  Parent := AParent;
  FKind := Kind;
  BorderStyle := bsNone;
  L := TLabel.Create(Self);
  L.Parent := Self;
  L.AutoSize := False;
  L.WordWrap := True;
  L.SetBounds(12, 12, 230, 58);
  L.Caption := '設定UIの先行表示です。ここでの変更はオブジェクトへ適用・保存されません。';
  L.Anchors := [akLeft, akTop, akRight];
  FSelector := TComboBox.Create(Self);
  FSelector.Parent := Self;
  FSelector.Style := csDropDownList;
  FSelector.SetBounds(12, 78, 230, 28);
  FSelector.Anchors := [akLeft, akTop, akRight];
  case Kind of
    0: FSelector.Items.AddStrings(['影なし', '影を付ける']);
    1: FSelector.Items.AddStrings(['なし', '通常', '封蝋', '白抜き', '囲み', '反転']);
    2: FSelector.Items.AddStrings(['なし', 'ぼかし', '動き', '影', '切り抜き', 'エンボス', '炎']);
  end;
  FSelector.ItemIndex := 0;
  FSelector.OnChange := ChangeKind;
  FFields := TScrollBox.Create(Self);
  FFields.Parent := Self;
  FFields.BorderStyle := bsNone;
  FFields.SetBounds(0, 118, 254, 420);
  FFields.Anchors := [akLeft, akTop, akRight];
  ChangeKind(nil);
end;

procedure TVectArtSettingsDraft.Resize;
var I: Integer;
begin
  inherited;
  if FSelector = nil then Exit;
  FSelector.SetBounds(12,78,ClientWidth-24,28);
  for I := 0 to ControlCount-1 do
    if Controls[I] is TLabel then Controls[I].Width := ClientWidth-24;
  if FFields <> nil then FFields.SetBounds(0,118,ClientWidth,ClientHeight-118);
end;

procedure TVectArtSettingsDraft.ChangeKind(Sender: TObject);
var
  Y: Integer;
  procedure Field(const Caption, Value: string; ColorField: Boolean = False;
    Directions: Boolean = False);
  var L: TLabel; E: TEdit; C: TComboBox; S: TVectArtColorSwatch;
  begin
    L := TLabel.Create(FFields);
    L.Parent := FFields;
    L.Caption := Caption;
    L.SetBounds(12, Y, 220, 22);
    if ColorField then
    begin
      S := TVectArtColorSwatch.Create(FFields);
      S.Parent := FFields;
      S.SetBounds(12, Y + 24, 220, 36);
      S.Value := clBlack;
      S.OnClick := ChooseColor;
    end
    else if Directions then
    begin
      C := TComboBox.Create(FFields);
      C.Parent := FFields;
      C.Style := csDropDownList;
      C.Items.AddStrings(['上', '右上', '右', '右下', '下', '左下', '左', '左上']);
      C.ItemIndex := 3;
      C.SetBounds(12, Y + 24, 220, 28);
    end
    else
    begin
      E := TEdit.Create(FFields);
      E.Parent := FFields;
      E.Text := Value;
      E.SetBounds(12, Y + 24, 220, 28);
    end;
    Inc(Y, 72);
  end;
begin
  CloseVectArtColorPopup(Self);
  while FFields.ControlCount > 0 do FFields.Controls[0].Free;
  Y := 4;
  if FSelector.ItemIndex = 0 then Exit;
  if FKind = 0 then
  begin
    Field('ぼかしの強さ', '8'); Field('影の色', '', True);
    Field('横方向位置', '8'); Field('縦方向位置', '8');
  end
  else if FKind = 1 then
  begin
    case FSelector.ItemIndex of
      1, 2: begin
        Field('縁の太さ', '2'); Field('縁の色', '', True);
        Field('文字の透明度 (%)', '0');
        if FSelector.ItemIndex = 2 then
        begin Field('縁のふくらみ', '4'); Field('ふくらみ方向（要確認）', '外側'); end;
      end;
      3: Field('白抜きの詳細は調査予定', '');
      4: Field('縁の太さ', '2');
      5: Field('文字と背景側の色関係を反転', '個別パラメータなし');
    end;
  end
  else
    case FSelector.ItemIndex of
      1: Field('ぼかしの強さ', '8');
      2, 5: begin Field('強さ', '8'); Field('方向', '', False, True); end;
      3, 4: begin Field('強さ / ぼかし', '8'); Field('色', '', True);
        Field('横方向位置', '8'); Field('縦方向位置', '8'); end;
      6: begin Field('炎の強さ', '8'); Field('炎の色', '', True); end;
    end;
end;

procedure TVectArtSettingsDraft.ChooseColor(Sender: TObject);
begin
  FFields.Tag := NativeInt(Sender);
  ShowVectArtColorPopup(Self, '装飾色のプレビュー', TVectArtColorSwatch(Sender).Value,
    nil, ColorChanged);
end;

procedure TVectArtSettingsDraft.ColorChanged(Sender: TObject; Color: TColor);
begin
  if FFields.Tag <> 0 then TVectArtColorSwatch(Pointer(FFields.Tag)).Value := Color;
end;

end.
