// Document状態を所有せず、一般的なプリセットからキャンバス解像度を選択する。
unit VectArtDesignerCanvasSettingsDialog;

interface

uses
  System.Classes;

// Returns the selected resolution only when the user confirms the dialog.
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
    FOkButton: TButton;
    FResolutionList: TListBox;
    FResolutions: TArray<TCanvasResolution>;
    procedure AddResolution(AWidth, AHeight: Integer);
    procedure ResolutionListDblClick(Sender: TObject);
  public
    constructor CreateForResolution(AOwner: TComponent;
      CurrentWidth, CurrentHeight: Integer);
    function SelectedResolution(out AWidth, AHeight: Integer): Boolean;
  end;

procedure TCanvasSettingsForm.AddResolution(AWidth, AHeight: Integer);
var
  Index: Integer;
begin
  Index := Length(FResolutions);
  SetLength(FResolutions, Index + 1);
  FResolutions[Index].Width := AWidth;
  FResolutions[Index].Height := AHeight;
  FResolutionList.Items.Add(Format('%d x %d', [AWidth, AHeight]));
end;

constructor TCanvasSettingsForm.CreateForResolution(AOwner: TComponent;
  CurrentWidth, CurrentHeight: Integer);
const
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
  I: Integer;
begin
  inherited CreateNew(AOwner);
  Caption := 'Canvas Settings';
  BorderStyle := bsDialog;
  Font.Name := 'Segoe UI';
  ClientWidth := 300;
  ClientHeight := 290;
  Position := poOwnerFormCenter;

  FResolutionList := TListBox.Create(Self);
  FResolutionList.Parent := Self;
  FResolutionList.SetBounds(12, 12, 276, 226);
  FResolutionList.Font.Name := 'Segoe UI';
  FResolutionList.Font.Height := -13;
  FResolutionList.OnDblClick := ResolutionListDblClick;

  for I := Low(COMMON_RESOLUTIONS) to High(COMMON_RESOLUTIONS) do
  begin
    AddResolution(COMMON_RESOLUTIONS[I].Width,
      COMMON_RESOLUTIONS[I].Height);
    if (CurrentWidth = COMMON_RESOLUTIONS[I].Width) and
      (CurrentHeight = COMMON_RESOLUTIONS[I].Height) then
      FResolutionList.ItemIndex := I;
  end;
  if FResolutionList.ItemIndex < 0 then
  begin
    AddResolution(CurrentWidth, CurrentHeight);
    FResolutionList.ItemIndex := FResolutionList.Items.Count - 1;
  end;

  FOkButton := TButton.Create(Self);
  FOkButton.Parent := Self;
  FOkButton.SetBounds(132, 250, 75, 28);
  FOkButton.Caption := 'OK';
  FOkButton.Default := True;
  FOkButton.ModalResult := mrOk;

  FCancelButton := TButton.Create(Self);
  FCancelButton.Parent := Self;
  FCancelButton.SetBounds(213, 250, 75, 28);
  FCancelButton.Caption := 'Cancel';
  FCancelButton.Cancel := True;
  FCancelButton.ModalResult := mrCancel;
end;

procedure TCanvasSettingsForm.ResolutionListDblClick(Sender: TObject);
begin
  if FResolutionList.ItemIndex >= 0 then
    ModalResult := mrOk;
end;

function TCanvasSettingsForm.SelectedResolution(out AWidth,
  AHeight: Integer): Boolean;
begin
  Result := (FResolutionList.ItemIndex >= 0) and
    (FResolutionList.ItemIndex < Length(FResolutions));
  if Result then
  begin
    AWidth := FResolutions[FResolutionList.ItemIndex].Width;
    AHeight := FResolutions[FResolutionList.ItemIndex].Height;
  end;
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
