// 新規作成、SVG／MIFファイルの入出力、最近使ったファイルのメニューを提供する。
// 実際のDocument操作と読込・保存処理は持たず、要求をホストへ通知する。
unit VectArtDesignerFileActionsUI;

interface

uses
  System.Classes, System.IniFiles, Vcl.Dialogs, Vcl.Menus,
  VectArtDesignerRecentFiles;

type
  TVectArtFileNameEvent = procedure(Sender: TObject;
    const FileName: string) of object;

  TVectArtFileActionsUI = class(TComponent)
  private
    FCanSave: Boolean;
    FCurrentFileName: string;
    FHistoryMenu: TMenuItem;
    FMenu: TMenuItem;
    FOnNewFile: TNotifyEvent;
    FOnNewWizard: TNotifyEvent;
    FOnOpenFile: TVectArtFileNameEvent;
    FOnSaveFile: TVectArtFileNameEvent;
    FOpenDialog: TOpenDialog;
    FRecentFiles: TVectArtRecentFiles;
    FSaveDialog: TSaveDialog;
    FSaveAsItem: TMenuItem;
    FSaveItem: TMenuItem;
    procedure ClearHistoryClick(Sender: TObject);
    procedure NewClick(Sender: TObject);
    procedure NewWizardClick(Sender: TObject);
    function NewMenuItem(const Caption: string; AShortCut: TShortCut;
      ClickHandler: TNotifyEvent): TMenuItem;
    procedure OpenClick(Sender: TObject);
    procedure RecentFileClick(Sender: TObject);
    procedure RefreshHistoryMenu;
    procedure SaveAsClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure SaveTypeChange(Sender: TObject);
    procedure SetCanSave(const Value: Boolean);
  public
    constructor CreateForMenu(AOwner: TComponent; ARootItem: TMenuItem);
    destructor Destroy; override;
    procedure AddRecentFile(const FileName: string);
    procedure ExecuteNew;
    procedure ExecuteNewWizard;
    procedure ExecuteOpen;
    procedure ExecuteSave;
    procedure ExecuteSaveAs;
    procedure LoadHistory(Ini: TCustomIniFile);
    function RecentFileCount: Integer;
    function RecentFileName(Index: Integer): string;
    procedure SaveHistory(Ini: TCustomIniFile);
    property CanSave: Boolean read FCanSave write SetCanSave;
    property CurrentFileName: string read FCurrentFileName
      write FCurrentFileName;
    property HistoryMenu: TMenuItem read FHistoryMenu;
    property Menu: TMenuItem read FMenu;
    property OnNewFile: TNotifyEvent read FOnNewFile write FOnNewFile;
    property OnNewWizard: TNotifyEvent read FOnNewWizard write FOnNewWizard;
    property OnOpenFile: TVectArtFileNameEvent read FOnOpenFile
      write FOnOpenFile;
    property OnSaveFile: TVectArtFileNameEvent read FOnSaveFile
      write FOnSaveFile;
  end;

implementation

uses
  System.SysUtils;

constructor TVectArtFileActionsUI.CreateForMenu(AOwner: TComponent;
  ARootItem: TMenuItem);
begin
  inherited Create(AOwner);
  FMenu := ARootItem;
  FRecentFiles := TVectArtRecentFiles.Create;

  NewMenuItem('新規キャンバス', ShortCut(Ord('N'), [ssCtrl]), NewClick);
  NewMenuItem('ウィザードで新規作成...',
    ShortCut(Ord('N'), [ssCtrl, ssShift]), NewWizardClick);
  NewMenuItem('-', 0, nil);
  NewMenuItem('開く...', ShortCut(Ord('O'), [ssCtrl]), OpenClick);
  FSaveItem := NewMenuItem('上書き保存', ShortCut(Ord('S'), [ssCtrl]),
    SaveClick);
  FSaveAsItem := NewMenuItem('名前を付けて保存...',
    ShortCut(Ord('S'), [ssCtrl, ssShift]), SaveAsClick);
  NewMenuItem('-', 0, nil);
  FHistoryMenu := NewMenuItem('履歴', 0, nil);
  RefreshHistoryMenu;

  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.DefaultExt := '';
  FOpenDialog.Filter := '対応ファイル (*.mif;*.svg)|*.mif;*.svg|' +
    'MIFファイル (*.mif)|*.mif|SVGファイル (*.svg)|*.svg|' +
    'すべてのファイル (*.*)|*.*';
  FOpenDialog.Options := FOpenDialog.Options +
    [ofFileMustExist, ofPathMustExist];
  FOpenDialog.Title := 'デザインファイルを開く';

  FSaveDialog := TSaveDialog.Create(Self);
  FSaveDialog.DefaultExt := 'mif';
  FSaveDialog.Filter := 'MIFファイル (*.mif)|*.mif|' +
    'SVGファイル (*.svg)|*.svg|すべてのファイル (*.*)|*.*';
  FSaveDialog.Options := FSaveDialog.Options +
    [ofOverwritePrompt, ofPathMustExist];
  FSaveDialog.Title := 'デザインファイルを保存';
  FSaveDialog.OnTypeChange := SaveTypeChange;
  SetCanSave(False);
  FSaveAsItem.Enabled := True;
end;

destructor TVectArtFileActionsUI.Destroy;
begin
  FRecentFiles.Free;
  inherited Destroy;
end;

procedure TVectArtFileActionsUI.AddRecentFile(const FileName: string);
begin
  FRecentFiles.Add(FileName);
  RefreshHistoryMenu;
end;

procedure TVectArtFileActionsUI.ClearHistoryClick(Sender: TObject);
begin
  FRecentFiles.Clear;
  RefreshHistoryMenu;
end;

procedure TVectArtFileActionsUI.ExecuteNew;
begin
  if Assigned(FOnNewFile) then
    FOnNewFile(Self);
end;

procedure TVectArtFileActionsUI.ExecuteNewWizard;
begin
  if Assigned(FOnNewWizard) then
    FOnNewWizard(Self);
end;

procedure TVectArtFileActionsUI.ExecuteOpen;
begin
  if FOpenDialog.Execute and Assigned(FOnOpenFile) then
    FOnOpenFile(Self, FOpenDialog.FileName);
end;

procedure TVectArtFileActionsUI.ExecuteSave;
begin
  if not FCanSave then
    Exit;
  if FCurrentFileName = '' then
    ExecuteSaveAs
  else if Assigned(FOnSaveFile) then
    FOnSaveFile(Self, FCurrentFileName);
end;

procedure TVectArtFileActionsUI.ExecuteSaveAs;
begin
  FSaveDialog.FileName := FCurrentFileName;
  if SameText(ExtractFileExt(FCurrentFileName), '.svg') then
    FSaveDialog.FilterIndex := 2
  else
    FSaveDialog.FilterIndex := 1;
  SaveTypeChange(FSaveDialog);
  if FSaveDialog.Execute and Assigned(FOnSaveFile) then
    FOnSaveFile(Self, FSaveDialog.FileName);
end;

procedure TVectArtFileActionsUI.LoadHistory(Ini: TCustomIniFile);
begin
  FRecentFiles.LoadFrom(Ini);
  RefreshHistoryMenu;
end;

function TVectArtFileActionsUI.NewMenuItem(const Caption: string;
  AShortCut: TShortCut; ClickHandler: TNotifyEvent): TMenuItem;
begin
  Result := TMenuItem.Create(Self);
  Result.Caption := Caption;
  Result.ShortCut := AShortCut;
  Result.OnClick := ClickHandler;
  FMenu.Add(Result);
end;

procedure TVectArtFileActionsUI.NewClick(Sender: TObject);
begin
  ExecuteNew;
end;

procedure TVectArtFileActionsUI.NewWizardClick(Sender: TObject);
begin
  ExecuteNewWizard;
end;

procedure TVectArtFileActionsUI.OpenClick(Sender: TObject);
begin
  ExecuteOpen;
end;

procedure TVectArtFileActionsUI.RecentFileClick(Sender: TObject);
var
  FileName: string;
begin
  if not (Sender is TMenuItem) then
    Exit;
  FileName := TMenuItem(Sender).Hint;
  if (FileName <> '') and Assigned(FOnOpenFile) then
    FOnOpenFile(Self, FileName);
end;

function TVectArtFileActionsUI.RecentFileCount: Integer;
begin
  Result := FRecentFiles.Count;
end;

function TVectArtFileActionsUI.RecentFileName(Index: Integer): string;
begin
  if (Index < 0) or (Index >= FRecentFiles.Count) then
    Exit('');
  Result := FRecentFiles[Index];
end;

procedure TVectArtFileActionsUI.RefreshHistoryMenu;
var
  ClearItem: TMenuItem;
  EmptyItem: TMenuItem;
  I: Integer;
  RecentItem: TMenuItem;
  Separator: TMenuItem;
begin
  if FHistoryMenu = nil then
    Exit;
  FHistoryMenu.Clear;
  if FRecentFiles.Count = 0 then
  begin
    EmptyItem := TMenuItem.Create(Self);
    EmptyItem.Caption := '（履歴はありません）';
    EmptyItem.Enabled := False;
    FHistoryMenu.Add(EmptyItem);
    Exit;
  end;
  for I := 0 to FRecentFiles.Count - 1 do
  begin
    RecentItem := TMenuItem.Create(Self);
    if I < 9 then
      RecentItem.Caption := Format('&%d  %s', [I + 1,
        StringReplace(FRecentFiles[I], '&', '&&', [rfReplaceAll])])
    else
      RecentItem.Caption := StringReplace(FRecentFiles[I], '&', '&&',
        [rfReplaceAll]);
    RecentItem.Hint := FRecentFiles[I];
    RecentItem.OnClick := RecentFileClick;
    FHistoryMenu.Add(RecentItem);
  end;
  Separator := TMenuItem.Create(Self);
  Separator.Caption := '-';
  FHistoryMenu.Add(Separator);
  ClearItem := TMenuItem.Create(Self);
  ClearItem.Caption := '履歴を消去';
  ClearItem.OnClick := ClearHistoryClick;
  FHistoryMenu.Add(ClearItem);
end;

procedure TVectArtFileActionsUI.SaveAsClick(Sender: TObject);
begin
  ExecuteSaveAs;
end;

procedure TVectArtFileActionsUI.SaveClick(Sender: TObject);
begin
  ExecuteSave;
end;

procedure TVectArtFileActionsUI.SaveHistory(Ini: TCustomIniFile);
begin
  FRecentFiles.SaveTo(Ini);
end;

procedure TVectArtFileActionsUI.SaveTypeChange(Sender: TObject);
begin
  if FSaveDialog.FilterIndex = 2 then
    FSaveDialog.DefaultExt := 'svg'
  else
    FSaveDialog.DefaultExt := 'mif';
end;

procedure TVectArtFileActionsUI.SetCanSave(const Value: Boolean);
begin
  FCanSave := Value;
  FSaveItem.Enabled := Value;
end;

end.
