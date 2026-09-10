// Document状態を所有せず、キャンバス解像度と背景を1つのダイアログで編集する。
unit VectArtDesignerCanvasSettingsDialog;

interface

uses
  System.Classes, Vcl.Graphics;

// ユーザーが確定した場合にだけ、入力されたキャンバス設定を返す。
function ExecuteCanvasSettingsDialog(AOwner: TComponent;
  CurrentWidth, CurrentHeight: Integer; CurrentBackgroundColor: TColor;
  CurrentTransparent: Boolean; out SelectedWidth, SelectedHeight: Integer;
  out SelectedBackgroundColor: TColor;
  out SelectedTransparent: Boolean): Boolean;

implementation

uses
  System.SysUtils, Winapi.Windows, Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms,
  Vcl.StdCtrls, ColorPickerHueBar, ColorPickerSVArea,
  VectArtDesignerColorSwatch;

type
  TCanvasResolution = record
    Width: Integer;
    Height: Integer;
  end;

  TCanvasSettingsForm = class(TForm)
  private
    FBackgroundColor: TColor;
    FBlackRadio: TRadioButton;
    FCancelButton: TButton;
    FColorLabel: TLabel;
    FColorPreview: TVectArtColorSwatch;
    FCustomRadio: TRadioButton;
    FHeightEdit: TEdit;
    FHuePicker: TColorPickerHueBar;
    FOkButton: TButton;
    FResolutionCombo: TComboBox;
    FResolutions: TArray<TCanvasResolution>;
    FSVPicker: TColorPickerSVArea;
    FTransparentRadio: TRadioButton;
    FUpdatingColor: Boolean;
    FUpdatingInputs: Boolean;
    FWhiteRadio: TRadioButton;
    FWidthEdit: TEdit;
    procedure AddResolution(const AName: string; AWidth, AHeight: Integer);
    procedure BackgroundChoiceChanged(Sender: TObject);
    procedure InputChanged(Sender: TObject);
    function InputsAreValid(out AWidth, AHeight: Integer): Boolean;
    procedure PickerChanged(Sender: TObject);
    procedure ResolutionComboChange(Sender: TObject);
    procedure SetPickerColor(AColor: TColor);
    procedure UpdateBackgroundControls;
  public
    constructor CreateForSettings(AOwner: TComponent;
      CurrentWidth, CurrentHeight: Integer; CurrentBackgroundColor: TColor;
      CurrentTransparent: Boolean);
    function SelectedSettings(out AWidth, AHeight: Integer;
      out ABackgroundColor: TColor; out ATransparent: Boolean): Boolean;
  end;

procedure TCanvasSettingsForm.AddResolution(const AName: string;
  AWidth, AHeight: Integer);
var
  Index: Integer;
begin
  Index := Length(FResolutions);
  SetLength(FResolutions, Index + 1);
  FResolutions[Index].Width := AWidth;
  FResolutions[Index].Height := AHeight;
  FResolutionCombo.Items.Add(Format('%s  (%d x %d)',
    [AName, AWidth, AHeight]));
end;

procedure TCanvasSettingsForm.BackgroundChoiceChanged(Sender: TObject);
begin
  if FUpdatingColor then
    Exit;
  if FWhiteRadio.Checked then
    SetPickerColor(clWhite)
  else if FBlackRadio.Checked then
    SetPickerColor(clBlack);
  UpdateBackgroundControls;
end;

constructor TCanvasSettingsForm.CreateForSettings(AOwner: TComponent;
  CurrentWidth, CurrentHeight: Integer; CurrentBackgroundColor: TColor;
  CurrentTransparent: Boolean);
const
  PRESET_NAMES: array[0..11] of string = (
    '小型ワイド', 'SDワイド', 'HD', 'フルHD', 'WQHD', '4K UHD',
    '縦長 HD', '縦長 フルHD', '縦長 WQHD', '縦長 4K',
    '正方形', '正方形（大）');
  COMMON_RESOLUTIONS: array[0..11] of TCanvasResolution = (
    (Width: 640; Height: 360), (Width: 854; Height: 480),
    (Width: 1280; Height: 720), (Width: 1920; Height: 1080),
    (Width: 2560; Height: 1440), (Width: 3840; Height: 2160),
    (Width: 720; Height: 1280), (Width: 1080; Height: 1920),
    (Width: 1440; Height: 2560), (Width: 2160; Height: 3840),
    (Width: 1080; Height: 1080), (Width: 2160; Height: 2160));
var
  BackgroundLabel: TLabel;
  HeightLabel: TLabel;
  I: Integer;
  PixelLabel: TLabel;
  PresetLabel: TLabel;
  WidthLabel: TLabel;
begin
  inherited CreateNew(AOwner);
  Caption := 'キャンバスの設定';
  BorderStyle := bsDialog;
  Font.Name := 'Segoe UI';
  Font.Height := -13;
  ClientWidth := 390;
  ClientHeight := 440;
  Position := poOwnerFormCenter;

  WidthLabel := TLabel.Create(Self);
  WidthLabel.Parent := Self;
  WidthLabel.SetBounds(16, 14, 140, 20);
  WidthLabel.Caption := '幅';

  FWidthEdit := TEdit.Create(Self);
  FWidthEdit.Parent := Self;
  FWidthEdit.SetBounds(16, 36, 130, 25);
  FWidthEdit.NumbersOnly := True;
  FWidthEdit.MaxLength := 7;
  FWidthEdit.Text := IntToStr(CurrentWidth);

  PixelLabel := TLabel.Create(Self);
  PixelLabel.Parent := Self;
  PixelLabel.SetBounds(151, 40, 28, 20);
  PixelLabel.Caption := 'px';

  HeightLabel := TLabel.Create(Self);
  HeightLabel.Parent := Self;
  HeightLabel.SetBounds(205, 14, 140, 20);
  HeightLabel.Caption := '高さ';

  FHeightEdit := TEdit.Create(Self);
  FHeightEdit.Parent := Self;
  FHeightEdit.SetBounds(205, 36, 130, 25);
  FHeightEdit.NumbersOnly := True;
  FHeightEdit.MaxLength := 7;
  FHeightEdit.Text := IntToStr(CurrentHeight);

  PixelLabel := TLabel.Create(Self);
  PixelLabel.Parent := Self;
  PixelLabel.SetBounds(340, 40, 28, 20);
  PixelLabel.Caption := 'px';

  PresetLabel := TLabel.Create(Self);
  PresetLabel.Parent := Self;
  PresetLabel.SetBounds(16, 76, 200, 20);
  PresetLabel.Caption := 'サイズのプリセット';

  FResolutionCombo := TComboBox.Create(Self);
  FResolutionCombo.Parent := Self;
  FResolutionCombo.SetBounds(16, 98, 358, 27);
  FResolutionCombo.Style := csDropDownList;
  FResolutionCombo.DropDownCount := 12;
  FResolutionCombo.OnChange := ResolutionComboChange;

  for I := Low(COMMON_RESOLUTIONS) to High(COMMON_RESOLUTIONS) do
  begin
    AddResolution(PRESET_NAMES[I], COMMON_RESOLUTIONS[I].Width,
      COMMON_RESOLUTIONS[I].Height);
    if (CurrentWidth = COMMON_RESOLUTIONS[I].Width) and
      (CurrentHeight = COMMON_RESOLUTIONS[I].Height) then
      FResolutionCombo.ItemIndex := I;
  end;

  BackgroundLabel := TLabel.Create(Self);
  BackgroundLabel.Parent := Self;
  BackgroundLabel.SetBounds(16, 142, 200, 20);
  BackgroundLabel.Caption := '背景';

  FWhiteRadio := TRadioButton.Create(Self);
  FWhiteRadio.Parent := Self;
  FWhiteRadio.SetBounds(16, 164, 58, 22);
  FWhiteRadio.Caption := '白';
  FWhiteRadio.OnClick := BackgroundChoiceChanged;

  FBlackRadio := TRadioButton.Create(Self);
  FBlackRadio.Parent := Self;
  FBlackRadio.SetBounds(78, 164, 58, 22);
  FBlackRadio.Caption := '黒';
  FBlackRadio.OnClick := BackgroundChoiceChanged;

  FTransparentRadio := TRadioButton.Create(Self);
  FTransparentRadio.Parent := Self;
  FTransparentRadio.SetBounds(140, 164, 72, 22);
  FTransparentRadio.Caption := '透明';
  FTransparentRadio.OnClick := BackgroundChoiceChanged;

  FCustomRadio := TRadioButton.Create(Self);
  FCustomRadio.Parent := Self;
  FCustomRadio.SetBounds(216, 164, 104, 22);
  FCustomRadio.Caption := 'その他の色';
  FCustomRadio.OnClick := BackgroundChoiceChanged;

  FSVPicker := TColorPickerSVArea.Create(Self);
  FSVPicker.Parent := Self;
  FSVPicker.SetBounds(16, 194, 320, 150);
  FSVPicker.OnChange := PickerChanged;

  FHuePicker := TColorPickerHueBar.Create(Self);
  FHuePicker.Parent := Self;
  FHuePicker.SetBounds(348, 194, 26, 150);
  FHuePicker.OnChange := PickerChanged;

  FColorPreview := TVectArtColorSwatch.Create(Self);
  FColorPreview.Parent := Self;
  FColorPreview.SetBounds(16, 356, 54, 26);
  FColorPreview.Compact := True;
  FColorPreview.Cursor := crDefault;
  FColorPreview.TabStop := False;

  FColorLabel := TLabel.Create(Self);
  FColorLabel.Parent := Self;
  FColorLabel.SetBounds(82, 360, 210, 20);

  FOkButton := TButton.Create(Self);
  FOkButton.Parent := Self;
  FOkButton.SetBounds(218, 400, 75, 28);
  FOkButton.Caption := 'OK';
  FOkButton.Default := True;
  FOkButton.ModalResult := mrOk;

  FCancelButton := TButton.Create(Self);
  FCancelButton.Parent := Self;
  FCancelButton.SetBounds(299, 400, 75, 28);
  FCancelButton.Caption := 'キャンセル';
  FCancelButton.Cancel := True;
  FCancelButton.ModalResult := mrCancel;

  FWidthEdit.OnChange := InputChanged;
  FHeightEdit.OnChange := InputChanged;
  SetPickerColor(CurrentBackgroundColor);
  FUpdatingColor := True;
  try
    if CurrentTransparent then
      FTransparentRadio.Checked := True
    else if ColorToRGB(CurrentBackgroundColor) = ColorToRGB(clWhite) then
      FWhiteRadio.Checked := True
    else if ColorToRGB(CurrentBackgroundColor) = ColorToRGB(clBlack) then
      FBlackRadio.Checked := True
    else
      FCustomRadio.Checked := True;
  finally
    FUpdatingColor := False;
  end;
  UpdateBackgroundControls;
  InputChanged(nil);
end;

procedure TCanvasSettingsForm.InputChanged(Sender: TObject);
var
  Height: Integer;
  I: Integer;
  Width: Integer;
begin
  FOkButton.Enabled := InputsAreValid(Width, Height);
  if FUpdatingInputs then
    Exit;

  FResolutionCombo.ItemIndex := -1;
  if not FOkButton.Enabled then
    Exit;
  for I := 0 to High(FResolutions) do
    if (FResolutions[I].Width = Width) and
      (FResolutions[I].Height = Height) then
    begin
      FResolutionCombo.ItemIndex := I;
      Break;
    end;
end;

function TCanvasSettingsForm.InputsAreValid(out AWidth,
  AHeight: Integer): Boolean;
begin
  Result := TryStrToInt(Trim(FWidthEdit.Text), AWidth) and
    TryStrToInt(Trim(FHeightEdit.Text), AHeight) and
    (AWidth > 0) and (AHeight > 0);
end;

procedure TCanvasSettingsForm.PickerChanged(Sender: TObject);
begin
  if FUpdatingColor or FTransparentRadio.Checked then
    Exit;
  FUpdatingColor := True;
  try
    if Sender = FHuePicker then
    begin
      FSVPicker.BaseColor := FHuePicker.Color;
      FSVPicker.Color := FHuePicker.Color;
    end;
    FBackgroundColor := ColorToRGB(FSVPicker.Color);
    FCustomRadio.Checked := True;
    FColorPreview.Value := FBackgroundColor;
    FColorLabel.Caption := Format('RGB  #%2.2x%2.2x%2.2x',
      [GetRValue(FBackgroundColor), GetGValue(FBackgroundColor),
       GetBValue(FBackgroundColor)]);
  finally
    FUpdatingColor := False;
  end;
end;

procedure TCanvasSettingsForm.ResolutionComboChange(Sender: TObject);
var
  Index: Integer;
begin
  Index := FResolutionCombo.ItemIndex;
  if (Index < 0) or (Index >= Length(FResolutions)) then
    Exit;

  FUpdatingInputs := True;
  try
    FWidthEdit.Text := IntToStr(FResolutions[Index].Width);
    FHeightEdit.Text := IntToStr(FResolutions[Index].Height);
  finally
    FUpdatingInputs := False;
  end;
  InputChanged(nil);
end;

function TCanvasSettingsForm.SelectedSettings(out AWidth,
  AHeight: Integer; out ABackgroundColor: TColor;
  out ATransparent: Boolean): Boolean;
begin
  Result := InputsAreValid(AWidth, AHeight);
  ABackgroundColor := FBackgroundColor;
  ATransparent := FTransparentRadio.Checked;
end;

procedure TCanvasSettingsForm.SetPickerColor(AColor: TColor);
begin
  FUpdatingColor := True;
  try
    FBackgroundColor := ColorToRGB(AColor);
    FHuePicker.Color := FBackgroundColor;
    FSVPicker.BaseColor := FBackgroundColor;
    FSVPicker.Color := FBackgroundColor;
    FColorPreview.Value := FBackgroundColor;
    FColorLabel.Caption := Format('RGB  #%2.2x%2.2x%2.2x',
      [GetRValue(FBackgroundColor), GetGValue(FBackgroundColor),
       GetBValue(FBackgroundColor)]);
  finally
    FUpdatingColor := False;
  end;
end;

procedure TCanvasSettingsForm.UpdateBackgroundControls;
var
  PickerEnabled: Boolean;
begin
  PickerEnabled := not FTransparentRadio.Checked;
  FSVPicker.Enabled := PickerEnabled;
  FHuePicker.Enabled := PickerEnabled;
  FColorPreview.Enabled := PickerEnabled;
  if PickerEnabled then
  begin
    FColorLabel.Font.Color := clWindowText;
    SetPickerColor(FBackgroundColor);
  end
  else
  begin
    FColorLabel.Font.Color := clGrayText;
    FColorLabel.Caption := '透明時は色設定を使用しません';
  end;
end;

function ExecuteCanvasSettingsDialog(AOwner: TComponent;
  CurrentWidth, CurrentHeight: Integer; CurrentBackgroundColor: TColor;
  CurrentTransparent: Boolean; out SelectedWidth, SelectedHeight: Integer;
  out SelectedBackgroundColor: TColor;
  out SelectedTransparent: Boolean): Boolean;
var
  Dialog: TCanvasSettingsForm;
begin
  Dialog := TCanvasSettingsForm.CreateForSettings(AOwner, CurrentWidth,
    CurrentHeight, CurrentBackgroundColor, CurrentTransparent);
  try
    Result := (Dialog.ShowModal = mrOk) and Dialog.SelectedSettings(
      SelectedWidth, SelectedHeight, SelectedBackgroundColor,
      SelectedTransparent);
  finally
    Dialog.Free;
  end;
end;

end.
