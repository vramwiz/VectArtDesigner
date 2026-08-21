// MIFファイルを開く、保存する、別名保存するメニューと標準ファイルダイアログを提供する。
// 実際の読込・保存処理は持たず、選択されたファイル名をホストへ通知する。
unit VectArtDesignerFileActionsUI;

interface

uses
  System.Classes, Vcl.Controls, Vcl.Dialogs, Vcl.ExtCtrls;

type
  TVectArtFileNameEvent = procedure(Sender: TObject;
    const FileName: string) of object;

  TVectArtFileActionsUI = class(TComponent)
  private
    FCanSave: Boolean;
    FCurrentFileName: string;
    FFileButton: TPanel;
    FMainForm: TWinControl;
    FOnOpenFile: TVectArtFileNameEvent;
    FOnSaveFile: TVectArtFileNameEvent;
    FOpenDialog: TOpenDialog;
    FPopup: TPanel;
    FSaveDialog: TSaveDialog;
    FSaveAsItem: TPanel;
    FSaveItem: TPanel;
    procedure FileButtonClick(Sender: TObject);
    function NewMenuItem(const Caption: string; Top: Integer;
      ClickHandler: TNotifyEvent): TPanel;
    procedure OpenClick(Sender: TObject);
    procedure SaveAsClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure SetCanSave(const Value: Boolean);
  public
    constructor CreateForHosts(AOwner: TComponent; AMainForm,
      AMenuBar: TWinControl);
    procedure ExecuteOpen;
    procedure ExecuteSave;
    procedure ExecuteSaveAs;
    property CanSave: Boolean read FCanSave write SetCanSave;
    property CurrentFileName: string read FCurrentFileName
      write FCurrentFileName;
    property OnOpenFile: TVectArtFileNameEvent read FOnOpenFile
      write FOnOpenFile;
    property OnSaveFile: TVectArtFileNameEvent read FOnSaveFile
      write FOnSaveFile;
  end;

implementation

uses
  System.Types, Vcl.Graphics;

const
  COLOR_BACKGROUND = TColor($00222222);
  COLOR_DISABLED = TColor($00757575);
  COLOR_POPUP = TColor($00303030);
  COLOR_TEXT = TColor($00E6E6E6);

constructor TVectArtFileActionsUI.CreateForHosts(AOwner: TComponent;
  AMainForm, AMenuBar: TWinControl);
begin
  inherited Create(AOwner);
  FMainForm := AMainForm;
  FFileButton := TPanel.Create(Self);
  FFileButton.Parent := AMenuBar;
  FFileButton.SetBounds(0, 0, 36, AMenuBar.Height);
  FFileButton.BevelOuter := bvNone;
  FFileButton.Caption := 'File';
  FFileButton.Color := COLOR_BACKGROUND;
  FFileButton.Font.Name := 'Segoe UI';
  FFileButton.Font.Height := -12;
  FFileButton.Font.Color := COLOR_TEXT;
  FFileButton.ParentBackground := False;
  FFileButton.OnClick := FileButtonClick;

  FPopup := TPanel.Create(Self);
  FPopup.Parent := AMainForm;
  FPopup.SetBounds(0, AMenuBar.Height, 220, 96);
  FPopup.BevelOuter := bvNone;
  FPopup.Color := COLOR_POPUP;
  FPopup.ParentBackground := False;
  FPopup.Visible := False;
  NewMenuItem('Open...    Ctrl+O', 0, OpenClick);
  FSaveItem := NewMenuItem('Save       Ctrl+S', 32, SaveClick);
  FSaveAsItem := NewMenuItem('Save As... Ctrl+Shift+S', 64, SaveAsClick);

  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.DefaultExt := 'mif';
  FOpenDialog.Filter := 'IBM WebArt Designer (*.mif)|*.mif|All files (*.*)|*.*';
  FOpenDialog.Options := FOpenDialog.Options + [ofFileMustExist, ofPathMustExist];
  FOpenDialog.Title := 'Open MIF';

  FSaveDialog := TSaveDialog.Create(Self);
  FSaveDialog.DefaultExt := 'mif';
  FSaveDialog.Filter := FOpenDialog.Filter;
  FSaveDialog.Options := FSaveDialog.Options +
    [ofOverwritePrompt, ofPathMustExist];
  FSaveDialog.Title := 'Save MIF';
  SetCanSave(False);
end;

procedure TVectArtFileActionsUI.ExecuteOpen;
begin
  FPopup.Visible := False;
  if FOpenDialog.Execute and Assigned(FOnOpenFile) then
    FOnOpenFile(Self, FOpenDialog.FileName);
end;

procedure TVectArtFileActionsUI.ExecuteSave;
begin
  FPopup.Visible := False;
  if not FCanSave then
    Exit;
  if FCurrentFileName = '' then
    ExecuteSaveAs
  else if Assigned(FOnSaveFile) then
    FOnSaveFile(Self, FCurrentFileName);
end;

procedure TVectArtFileActionsUI.ExecuteSaveAs;
begin
  FPopup.Visible := False;
  if not FCanSave then
    Exit;
  FSaveDialog.FileName := FCurrentFileName;
  if FSaveDialog.Execute and Assigned(FOnSaveFile) then
    FOnSaveFile(Self, FSaveDialog.FileName);
end;

procedure TVectArtFileActionsUI.FileButtonClick(Sender: TObject);
var
  Origin: TPoint;
begin
  Origin := FMainForm.ScreenToClient(FFileButton.ClientToScreen(Point(0,
    FFileButton.Height)));
  FPopup.Left := Origin.X;
  FPopup.Top := Origin.Y;
  FPopup.Visible := not FPopup.Visible;
  if FPopup.Visible then
    FPopup.BringToFront;
end;

function TVectArtFileActionsUI.NewMenuItem(const Caption: string; Top: Integer;
  ClickHandler: TNotifyEvent): TPanel;
begin
  Result := TPanel.Create(Self);
  Result.Parent := FPopup;
  Result.SetBounds(0, Top, FPopup.Width, 32);
  Result.BevelOuter := bvNone;
  Result.Caption := Caption;
  Result.Color := COLOR_POPUP;
  Result.Font.Name := 'Segoe UI';
  Result.Font.Height := -12;
  Result.Font.Color := COLOR_TEXT;
  Result.ParentBackground := False;
  Result.OnClick := ClickHandler;
end;

procedure TVectArtFileActionsUI.OpenClick(Sender: TObject);
begin
  ExecuteOpen;
end;

procedure TVectArtFileActionsUI.SaveAsClick(Sender: TObject);
begin
  ExecuteSaveAs;
end;

procedure TVectArtFileActionsUI.SaveClick(Sender: TObject);
begin
  ExecuteSave;
end;

procedure TVectArtFileActionsUI.SetCanSave(const Value: Boolean);
begin
  FCanSave := Value;
  FSaveItem.Enabled := Value;
  FSaveAsItem.Enabled := Value;
  if Value then
  begin
    FSaveItem.Font.Color := COLOR_TEXT;
    FSaveAsItem.Font.Color := COLOR_TEXT;
  end
  else
  begin
    FSaveItem.Font.Color := COLOR_DISABLED;
    FSaveAsItem.Font.Color := COLOR_DISABLED;
  end;
end;

end.
