// 色の編集窓を全呼び出し元で共有し、単色適用と未接続の塗りプレビューを区別する。
unit VectArtDesignerPaintPopup;

interface

uses
  System.Classes, System.Types, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Graphics, Vcl.Grids;

type
  TVectArtColorChanged = procedure(Sender: TObject; Color: TColor) of object;
  TVectArtColorSwatch = class(TCustomControl)
  private
    FValue: TColor;
    FEmpty: Boolean;
    procedure SetValue(Value: TColor);
  protected
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    property Value: TColor read FValue write SetValue;
    property Empty: Boolean read FEmpty write FEmpty;
    property OnClick;
  end;

procedure ShowVectArtColorPopup(Target: TComponent; const Title: string;
  Color: TColor; const UsedColors: TArray<TColor>; AllowPaint: Boolean;
  OnChanged: TVectArtColorChanged);
procedure CloseVectArtColorPopup(Target: TComponent);

implementation

uses
  System.SysUtils, System.Math, System.UITypes, Winapi.Windows, Vcl.Dialogs,
  Vcl.Imaging.pngimage, Vcl.Imaging.jpeg;

type
  TVectArtPaintPopup = class(TForm)
  private
    FTarget: TComponent;
    FChanged: TVectArtColorChanged;
    FMode, FGradient: TComboBox;
    FSlot: TRadioGroup;
    FHex, FRGB: TEdit;
    FPreview: TPaintBox;
    FPalette: TDrawGrid;
    FRecent: TComboBox;
    FNotice: TLabel;
    FTextureButton: TButton;
    FTexture: TPicture;
    FColors: TArray<TColor>;
    FColor1, FColor2: TColor;
    FUpdating: Boolean;
    procedure Changed(Sender: TObject);
    procedure EditColor(Sender: TObject);
    procedure ColorKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure DrawPreview(Sender: TObject);
    procedure DrawColor(Sender: TObject; ACol, ARow: Longint;
      Rect: TRect; State: TGridDrawState);
    procedure PickColor(Sender: TObject; ACol, ARow: Longint; var CanSelect: Boolean);
    procedure PickRecent(Sender: TObject);
    procedure LoadTexture(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure ApplyColor(Color: TColor);
    procedure Sync;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  Popup: TVectArtPaintPopup;
  RecentColors: TArray<TColor>;

function HexColor(Color: TColor): string;
begin
  Color := ColorToRGB(Color);
  Result := Format('#%.2x%.2x%.2x', [GetRValue(Color), GetGValue(Color), GetBValue(Color)]);
end;

constructor TVectArtColorSwatch.Create(AOwner: TComponent);
begin
  inherited;
  Height := 36;
  Width := 240;
  Cursor := crHandPoint;
  TabStop := True;
end;

procedure TVectArtColorSwatch.SetValue(Value: TColor);
begin
  FValue := Value;
  Invalidate;
end;

procedure TVectArtColorSwatch.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;
  if (Key = VK_RETURN) or (Key = VK_SPACE) then begin Click; Key := 0; end;
end;

procedure TVectArtColorSwatch.Paint;
begin
  Canvas.Brush.Color := TColor($00353535);
  Canvas.FillRect(ClientRect);
  Canvas.Brush.Color := FValue;
  Canvas.FillRect(Rect(6, 6, 44, Height - 6));
  Canvas.Font.Color := clWhite;
  if not Enabled then Canvas.Font.Color := clGrayText;
  Canvas.Brush.Style := bsClear;
  if FEmpty then
    Canvas.TextOut(54, 10, '複数の色 / 色を選択')
  else
    Canvas.TextOut(54, 10, HexColor(FValue) + '  編集…');
  Canvas.Brush.Style := bsSolid;
end;

constructor TVectArtPaintPopup.Create(AOwner: TComponent);
var
  L: TLabel;
  B: TButton;
  I: Integer;
  procedure LabelAt(const Text: string; Y: Integer);
  begin
    L := TLabel.Create(Self);
    L.Parent := Self;
    L.Caption := Text;
    L.SetBounds(16, Y, 340, 20);
  end;
begin
  inherited CreateNew(AOwner);
  BorderStyle := bsToolWindow;
  Position := poScreenCenter;
  ClientWidth := 370;
  ClientHeight := 630;
  Font.Name := 'Yu Gothic UI';
  Font.Size := 9;
  FTexture := TPicture.Create;
  FMode := TComboBox.Create(Self);
  FMode.Parent := Self;
  FMode.Style := csDropDownList;
  FMode.Items.AddStrings(['ベタ', 'グラデーション（プレビュー）', 'テクスチャ（プレビュー）']);
  FMode.SetBounds(16, 16, 338, 28);
  FMode.ItemIndex := 0;
  FMode.OnChange := Changed;
  FPreview := TPaintBox.Create(Self);
  FPreview.Parent := Self;
  FPreview.SetBounds(16, 54, 338, 68);
  FPreview.OnPaint := DrawPreview;
  FGradient := TComboBox.Create(Self);
  FGradient.Parent := Self;
  FGradient.Style := csDropDownList;
  FGradient.Items.AddStrings(['線形・横', '線形・縦', '放射']);
  FGradient.ItemIndex := 0;
  FGradient.SetBounds(16, 132, 338, 28);
  FGradient.OnChange := Changed;
  FTextureButton := TButton.Create(Self);
  FTextureButton.Parent := Self;
  FTextureButton.Caption := 'テクスチャ画像を選択…';
  FTextureButton.SetBounds(16, 132, 338, 28);
  FTextureButton.OnClick := LoadTexture;
  FSlot := TRadioGroup.Create(Self);
  FSlot.Parent := Self;
  FSlot.Items.AddStrings(['色1', '色2']);
  FSlot.Columns := 2;
  FSlot.ItemIndex := 0;
  FSlot.SetBounds(16, 166, 338, 48);
  FSlot.OnClick := Changed;
  LabelAt('16進カラー値', 228);
  FHex := TEdit.Create(Self);
  FHex.Parent := Self;
  FHex.SetBounds(16, 250, 338, 26);
  FHex.OnExit := EditColor;
  FHex.OnKeyDown := ColorKey;
  LabelAt('RGB（0～255、カンマ区切り）', 286);
  FRGB := TEdit.Create(Self);
  FRGB.Parent := Self;
  FRGB.SetBounds(16, 308, 338, 26);
  FRGB.OnExit := EditColor;
  FRGB.OnKeyDown := ColorKey;
  LabelAt('使用された色 / プリセット', 344);
  FPalette := TDrawGrid.Create(Self);
  FPalette.Parent := Self;
  FPalette.SetBounds(16, 366, 338, 108);
  FPalette.FixedCols := 0;
  FPalette.FixedRows := 0;
  FPalette.ColCount := 10;
  FPalette.RowCount := 3;
  FPalette.DefaultColWidth := 31;
  FPalette.DefaultRowHeight := 31;
  FPalette.OnDrawCell := DrawColor;
  FPalette.OnSelectCell := PickColor;
  LabelAt('最近使った塗り（適用済みのベタ）', 482);
  FRecent := TComboBox.Create(Self);
  FRecent.Parent := Self;
  FRecent.Style := csDropDownList;
  FRecent.SetBounds(16, 504, 338, 26);
  FRecent.OnChange := PickRecent;
  FNotice := TLabel.Create(Self);
  FNotice.Parent := Self;
  FNotice.AutoSize := False;
  FNotice.WordWrap := True;
  FNotice.SetBounds(16, 542, 338, 42);
  B := TButton.Create(Self);
  B.Parent := Self;
  B.Caption := '閉じる';
  B.SetBounds(252, 592, 102, 28);
  B.OnClick := CloseClick;
  for I := 0 to ControlCount-1 do Controls[I].Tag := Controls[I].Top;
end;

destructor TVectArtPaintPopup.Destroy;
begin
  FTexture.Free;
  inherited;
end;

procedure TVectArtPaintPopup.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FTarget) then
  begin
    FTarget := nil;
    FChanged := nil;
    Hide;
  end;
end;

procedure TVectArtPaintPopup.Sync;
var
  C: TColor;
  I, Offset: Integer;
begin
  FUpdating := True;
  try
    C := FColor1;
    if (FMode.ItemIndex = 1) and (FSlot.ItemIndex = 1) then C := FColor2;
    C := ColorToRGB(C);
    FHex.Text := HexColor(C);
    FRGB.Text := Format('%d, %d, %d', [GetRValue(C), GetGValue(C), GetBValue(C)]);
    Offset := 0;
    if FMode.ItemIndex = 0 then Offset := 96;
    for I := 0 to ControlCount-1 do
      if Controls[I].Tag >= 228 then Controls[I].Top := Controls[I].Tag - Offset;
    ClientHeight := 630 - Offset;
    FGradient.Visible := FMode.ItemIndex = 1;
    FSlot.Visible := FMode.ItemIndex = 1;
    FTextureButton.Visible := FMode.ItemIndex = 2;
    FHex.Enabled := FMode.ItemIndex <> 2;
    FRGB.Enabled := FHex.Enabled;
    FPalette.Enabled := FHex.Enabled;
    if FMode.ItemIndex = 0 then
      FNotice.Caption := '単色の変更は選択対象へ即時反映されます。'
    else
      FNotice.Caption := 'この方式はプレビューのみです。図形への適用・保存は今後対応します。';
    FPreview.Invalidate;
    FPalette.Invalidate;
  finally
    FUpdating := False;
  end;
end;

procedure TVectArtPaintPopup.Changed(Sender: TObject);
begin
  if not FUpdating then Sync;
end;

procedure TVectArtPaintPopup.ApplyColor(Color: TColor);
var
  C: TColor;
  Found: Boolean;
begin
  if (FMode.ItemIndex = 1) and (FSlot.ItemIndex = 1) then FColor2 := Color
  else FColor1 := Color;
  if (FMode.ItemIndex = 0) and Assigned(FChanged) then
  begin
    FChanged(Self, Color);
    Found := False;
    for C in RecentColors do Found := Found or (C = Color);
    if not Found then
    begin
      RecentColors := [Color] + RecentColors;
      if Length(RecentColors) > 20 then SetLength(RecentColors, 20);
    end;
    FRecent.Items.Clear;
    for C in RecentColors do FRecent.Items.Add(HexColor(C));
  end;
  Sync;
end;

procedure TVectArtPaintPopup.EditColor(Sender: TObject);
var
  N, R, G, B: Integer;
  Parts: TArray<string>;
  S: string;
begin
  if FUpdating or not Visible then Exit;
  if Sender = FHex then
  begin
    S := Trim(FHex.Text);
    S := S.Replace('#', '');
    if (Length(S) <> 6) or not TryStrToInt('$' + S, N) then begin Sync; Exit; end;
    ApplyColor(RGB((N shr 16) and 255, (N shr 8) and 255, N and 255));
  end
  else
  begin
    S := FRGB.Text;
    Parts := S.Split([',']);
    if (Length(Parts) <> 3) or not TryStrToInt(Trim(Parts[0]), R) or
      not TryStrToInt(Trim(Parts[1]), G) or not TryStrToInt(Trim(Parts[2]), B) then
    begin Sync; Exit; end;
    if (R < 0) or (R > 255) or (G < 0) or (G > 255) or (B < 0) or (B > 255) then
    begin Sync; Exit; end;
    ApplyColor(RGB(R, G, B));
  end;
end;

procedure TVectArtPaintPopup.ColorKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then begin EditColor(Sender); Key := 0; end;
  if Key = VK_ESCAPE then begin Sync; Key := 0; end;
end;

procedure TVectArtPaintPopup.DrawPreview(Sender: TObject);
var
  X, Y: Integer;
  T: Single;
  A, B: TColor;
begin
  if (FMode.ItemIndex = 2) and (FTexture.Graphic <> nil) then
  begin FPreview.Canvas.StretchDraw(FPreview.ClientRect, FTexture.Graphic); Exit; end;
  A := ColorToRGB(FColor1);
  B := ColorToRGB(FColor2);
  for Y := 0 to FPreview.Height - 1 do
    for X := 0 to FPreview.Width - 1 do
    begin
      T := 0;
      if FMode.ItemIndex = 1 then
        case FGradient.ItemIndex of
          0: T := X / Max(1, FPreview.Width - 1);
          1: T := Y / Max(1, FPreview.Height - 1);
          2: T := Min(1.0, Hypot((X / FPreview.Width - 0.5) * 2,
            (Y / FPreview.Height - 0.5) * 2));
        end;
      FPreview.Canvas.Pixels[X, Y] := RGB(Round(GetRValue(A) * (1-T) + GetRValue(B) * T),
        Round(GetGValue(A) * (1-T) + GetGValue(B) * T), Round(GetBValue(A) * (1-T) + GetBValue(B) * T));
    end;
end;

procedure TVectArtPaintPopup.DrawColor(Sender: TObject; ACol, ARow: Longint;
  Rect: TRect; State: TGridDrawState);
var I: Integer;
begin
  I := ARow * 10 + ACol;
  FPalette.Canvas.Brush.Color := clBtnFace;
  if I < Length(FColors) then FPalette.Canvas.Brush.Color := FColors[I];
  InflateRect(Rect, -3, -3);
  FPalette.Canvas.FillRect(Rect);
end;

procedure TVectArtPaintPopup.PickColor(Sender: TObject; ACol, ARow: Longint; var CanSelect: Boolean);
var I: Integer;
begin
  I := ARow * 10 + ACol;
  if (I < Length(FColors)) and not FUpdating then ApplyColor(FColors[I]);
end;

procedure TVectArtPaintPopup.PickRecent(Sender: TObject);
begin
  if (FRecent.ItemIndex >= 0) and (FRecent.ItemIndex < Length(RecentColors)) then
    ApplyColor(RecentColors[FRecent.ItemIndex]);
end;

procedure TVectArtPaintPopup.LoadTexture(Sender: TObject);
var D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := '画像|*.png;*.jpg;*.jpeg;*.bmp';
    if D.Execute then
      try FTexture.LoadFromFile(D.FileName); FPreview.Invalidate;
      except on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0); end;
  finally D.Free; end;
end;

procedure TVectArtPaintPopup.CloseClick(Sender: TObject);
begin Hide; end;

procedure ShowVectArtColorPopup(Target: TComponent; const Title: string;
  Color: TColor; const UsedColors: TArray<TColor>; AllowPaint: Boolean;
  OnChanged: TVectArtColorChanged);
var C: TColor;
begin
  if Popup = nil then Popup := TVectArtPaintPopup.Create(Application);
  if Popup.FTarget <> nil then Popup.FTarget.RemoveFreeNotification(Popup);
  Popup.FTarget := Target;
  Target.FreeNotification(Popup);
  Popup.FChanged := OnChanged;
  Popup.Caption := Title;
  Popup.FColor1 := Color;
  Popup.FColor2 := clWhite;
  Popup.FMode.ItemIndex := 0;
  Popup.FMode.Visible := AllowPaint;
  Popup.FColors := UsedColors + RecentColors + [clBlack, clWhite, clRed, clYellow,
    clLime, clAqua, clBlue, clFuchsia, clGray, clSilver, clMaroon, clOlive, clGreen, clTeal, clNavy, clPurple];
  Popup.FPalette.RowCount := Max(3, (Length(Popup.FColors) + 9) div 10);
  Popup.FRecent.Items.Clear;
  for C in RecentColors do Popup.FRecent.Items.Add(HexColor(C));
  Popup.Sync;
  Popup.Show;
end;

procedure CloseVectArtColorPopup(Target: TComponent);
begin
  if (Popup <> nil) and (Popup.FTarget = Target) then
  begin Popup.FChanged := nil; Popup.Hide; end;
end;

end.
