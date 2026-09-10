// Document状態を所有せず、一般的なプリセットからキャンバス解像度を選択する。
unit VectArtDesignerCanvasSettingsDialog;

interface

uses
  System.Classes;

// ユーザーが確定した場合にだけ、入力されたキャンバスサイズを返す。
function ExecuteCanvasSettingsDialog(AOwner: TComponent;
  CurrentWidth, CurrentHeight: Integer;
  out SelectedWidth, SelectedHeight: Integer): Boolean;

implementation

uses
  System.SysUtils, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls;

type
  TCanvasResolution = record
    Width: Integer;
    Height: Integer;
  end;

  TCanvasSettingsForm = class(TForm)
  private
    FCancelButton: TButton;
    FHeightEdit: TEdit;
    FOkButton: TButton;
    FResolutionList: TListBox;
    FResolutions: TArray<TCanvasResolution>;
    FUpdatingInputs: Boolean;
    FWidthEdit: TEdit;
    procedure AddResolution(const AName: string; AWidth, AHeight: Integer);
    procedure InputChanged(Sender: TObject);
    function InputsAreValid(out AWidth, AHeight: Integer): Boolean;
    procedure ResolutionListClick(Sender: TObject);
  public
    constructor CreateForResolution(AOwner: TComponent;
      CurrentWidth, CurrentHeight: Integer);
    function SelectedResolution(out AWidth, AHeight: Integer): Boolean;
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
  FResolutionList.Items.Add(Format('%s  (%d x %d)',
    [AName, AWidth, AHeight]));
end;

constructor TCanvasSettingsForm.CreateForResolution(AOwner: TComponent;
  CurrentWidth, CurrentHeight: Integer);
const
  PRESET_NAMES: array[0..11] of string = (
    '小型ワイド',
    'SDワイド',
    'HD',
    'フルHD',
    'WQHD',
    '4K UHD',
    '縦長 HD',
    '縦長 フルHD',
    '縦長 WQHD',
    '縦長 4K',
    '正方形',
    '正方形（大）');
  COMMON_RESOLUTIONS: array[0..11] of TCanvasResolution = (
    (Width: 640; Height: 360),
    (Width: 854; Height: 480),
    (Width: 1280; Height: 720),
    (Width: 1920; Height: 1080),
    (Width: 2560; Height: 1440),
    (Width: 3840; Height: 2160),
    (Width: 720; Height: 1280),
    (Width: 1080; Height: 1920),
    (Width: 1440; Height: 2560),
    (Width: 2160; Height: 3840),
    (Width: 1080; Height: 1080),
    (Width: 2160; Height: 2160));
var
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
  ClientWidth := 360;
  ClientHeight := 382;
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
  HeightLabel.SetBounds(190, 14, 140, 20);
  HeightLabel.Caption := '高さ';

  FHeightEdit := TEdit.Create(Self);
  FHeightEdit.Parent := Self;
  FHeightEdit.SetBounds(190, 36, 130, 25);
  FHeightEdit.NumbersOnly := True;
  FHeightEdit.MaxLength := 7;
  FHeightEdit.Text := IntToStr(CurrentHeight);

  PixelLabel := TLabel.Create(Self);
  PixelLabel.Parent := Self;
  PixelLabel.SetBounds(325, 40, 28, 20);
  PixelLabel.Caption := 'px';

  PresetLabel := TLabel.Create(Self);
  PresetLabel.Parent := Self;
  PresetLabel.SetBounds(16, 78, 200, 20);
  PresetLabel.Caption := 'プリセット';

  FResolutionList := TListBox.Create(Self);
  FResolutionList.Parent := Self;
  FResolutionList.SetBounds(16, 100, 328, 226);
  FResolutionList.Font.Name := 'Segoe UI';
  FResolutionList.Font.Height := -13;
  FResolutionList.OnClick := ResolutionListClick;

  for I := Low(COMMON_RESOLUTIONS) to High(COMMON_RESOLUTIONS) do
  begin
    AddResolution(PRESET_NAMES[I], COMMON_RESOLUTIONS[I].Width,
      COMMON_RESOLUTIONS[I].Height);
    if (CurrentWidth = COMMON_RESOLUTIONS[I].Width) and
      (CurrentHeight = COMMON_RESOLUTIONS[I].Height) then
      FResolutionList.ItemIndex := I;
  end;

  FOkButton := TButton.Create(Self);
  FOkButton.Parent := Self;
  FOkButton.SetBounds(188, 342, 75, 28);
  FOkButton.Caption := 'OK';
  FOkButton.Default := True;
  FOkButton.ModalResult := mrOk;

  FCancelButton := TButton.Create(Self);
  FCancelButton.Parent := Self;
  FCancelButton.SetBounds(269, 342, 75, 28);
  FCancelButton.Caption := 'キャンセル';
  FCancelButton.Cancel := True;
  FCancelButton.ModalResult := mrCancel;

  FWidthEdit.OnChange := InputChanged;
  FHeightEdit.OnChange := InputChanged;
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

  FResolutionList.ItemIndex := -1;
  if not FOkButton.Enabled then
    Exit;
  for I := 0 to High(FResolutions) do
    if (FResolutions[I].Width = Width) and
      (FResolutions[I].Height = Height) then
    begin
      FResolutionList.ItemIndex := I;
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

procedure TCanvasSettingsForm.ResolutionListClick(Sender: TObject);
var
  Index: Integer;
begin
  Index := FResolutionList.ItemIndex;
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

function TCanvasSettingsForm.SelectedResolution(out AWidth,
  AHeight: Integer): Boolean;
begin
  Result := InputsAreValid(AWidth, AHeight);
end;

function ExecuteCanvasSettingsDialog(AOwner: TComponent;
  CurrentWidth, CurrentHeight: Integer;
  out SelectedWidth, SelectedHeight: Integer): Boolean;
var
  Dialog: TCanvasSettingsForm;
begin
  Dialog := TCanvasSettingsForm.CreateForResolution(AOwner,
    CurrentWidth, CurrentHeight);
  try
    Result := (Dialog.ShowModal = mrOk) and
      Dialog.SelectedResolution(SelectedWidth, SelectedHeight);
  finally
    Dialog.Free;
  end;
end;

end.
