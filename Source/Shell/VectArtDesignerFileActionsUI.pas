// SVG／MIFファイルを開く、保存する、別名保存するメニューと標準ファイルダイアログを提供する。
// 実際の読込・保存処理は持たず、選択されたファイル名をホストへ通知する。
unit VectArtDesignerFileActionsUI;

interface

uses
  System.Classes, Vcl.Dialogs, Vcl.Menus;

type
  TVectArtFileNameEvent = procedure(Sender: TObject;
    const FileName: string) of object;

  TVectArtFileActionsUI = class(TComponent)
  private
    FCanSave: Boolean;
    FCurrentFileName: string;
    FMenu: TMenuItem;
    FOnOpenFile: TVectArtFileNameEvent;
    FOnSaveFile: TVectArtFileNameEvent;
    FOpenDialog: TOpenDialog;
    FSaveDialog: TSaveDialog;
    FSaveAsItem: TMenuItem;
    FSaveItem: TMenuItem;
    function NewMenuItem(const Caption: string; AShortCut: TShortCut;
      ClickHandler: TNotifyEvent): TMenuItem;
    procedure OpenClick(Sender: TObject);
    procedure SaveAsClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure SaveTypeChange(Sender: TObject);
    procedure SetCanSave(const Value: Boolean);
  public
    constructor CreateForMenu(AOwner: TComponent; ARootItem: TMenuItem);
    procedure ExecuteOpen;
    procedure ExecuteSave;
    procedure ExecuteSaveAs;
    property CanSave: Boolean read FCanSave write SetCanSave;
    property CurrentFileName: string read FCurrentFileName
      write FCurrentFileName;
    property Menu: TMenuItem read FMenu;
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
  NewMenuItem('開く...', ShortCut(Ord('O'), [ssCtrl]), OpenClick);
  FSaveItem := NewMenuItem('上書き保存', ShortCut(Ord('S'), [ssCtrl]),
    SaveClick);
  FSaveAsItem := NewMenuItem('名前を付けて保存...',
    ShortCut(Ord('S'), [ssCtrl, ssShift]), SaveAsClick);

  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.DefaultExt := '';
  FOpenDialog.Filter := '対応ファイル (*.mif;*.svg)|*.mif;*.svg|' +
    'MIFファイル (*.mif)|*.mif|SVGファイル (*.svg)|*.svg|' +
    'すべてのファイル (*.*)|*.*';
  FOpenDialog.Options := FOpenDialog.Options + [ofFileMustExist, ofPathMustExist];
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

function TVectArtFileActionsUI.NewMenuItem(const Caption: string;
  AShortCut: TShortCut; ClickHandler: TNotifyEvent): TMenuItem;
begin
  Result := TMenuItem.Create(Self);
  Result.Caption := Caption;
  Result.ShortCut := AShortCut;
  Result.OnClick := ClickHandler;
  FMenu.Add(Result);
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
