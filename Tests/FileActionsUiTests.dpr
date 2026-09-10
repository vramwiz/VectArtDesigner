program FileActionsUiTests;

{$APPTYPE CONSOLE}

uses
  System.Classes, System.IniFiles, System.IOUtils, System.SysUtils,
  System.Types, Vcl.Forms, Vcl.Graphics, Vcl.Menus,
  VectArtDesignerDocument, VectArtDesignerFileActionsUI;

type
  TRequestRecorder = class
  public
    NewCount: Integer;
    OpenedFileName: string;
    WizardCount: Integer;
    procedure NewRequest(Sender: TObject);
    procedure OpenRequest(Sender: TObject; const FileName: string);
    procedure WizardRequest(Sender: TObject);
  end;

procedure TRequestRecorder.NewRequest(Sender: TObject);
begin
  Inc(NewCount);
end;

procedure TRequestRecorder.OpenRequest(Sender: TObject;
  const FileName: string);
begin
  OpenedFileName := FileName;
end;

procedure TRequestRecorder.WizardRequest(Sender: TObject);
begin
  Inc(WizardCount);
end;

procedure Require(Value: Boolean; const MessageText: string);
begin
  if not Value then
    raise Exception.Create(MessageText);
end;

var
  Document: TVectArtDocument;
  FileActions: TVectArtFileActionsUI;
  I: Integer;
  Ini: TMemIniFile;
  IniFileName: string;
  MainMenu: TMainMenu;
  Owner: TComponent;
  Recorder: TRequestRecorder;
  RectangleData: TVectArtRectangleData;
  ReloadedActions: TVectArtFileActionsUI;
  ReloadedMenu: TMainMenu;
  ReloadedRoot: TMenuItem;
  Root: TMenuItem;
begin
  Application.Initialize;
  Owner := TComponent.Create(nil);
  Recorder := TRequestRecorder.Create;
  Document := TVectArtDocument.Create;
  IniFileName := TPath.Combine(TPath.GetTempPath,
    'VectArtDesignerFileActionsUiTests.ini');
  try
    MainMenu := TMainMenu.Create(Owner);
    Root := TMenuItem.Create(MainMenu);
    Root.Caption := 'ファイル';
    MainMenu.Items.Add(Root);
    FileActions := TVectArtFileActionsUI.CreateForMenu(Owner, Root);
    FileActions.OnNewFile := Recorder.NewRequest;
    FileActions.OnNewWizard := Recorder.WizardRequest;
    FileActions.OnOpenFile := Recorder.OpenRequest;

    Require((Root.Count = 8) and (Root.Items[0].Caption = '新規キャンバス') and
      (Root.Items[1].Caption = 'ウィザードで新規作成...') and
      (Root.Items[4].Caption = '上書き保存') and
      (Root.Items[7] = FileActions.HistoryMenu), 'File menu structure');
    FileActions.ExecuteNew;
    FileActions.ExecuteNewWizard;
    Require((Recorder.NewCount = 1) and (Recorder.WizardCount = 1),
      'New document requests');

    for I := 0 to 11 do
      FileActions.AddRecentFile(Format('C:\Temp\design-%d.mif', [I]));
    Require((FileActions.RecentFileCount = 10) and
      SameText(FileActions.RecentFileName(0),
        ExpandFileName('C:\Temp\design-11.mif')), 'Recent file limit/order');
    FileActions.AddRecentFile('C:\Temp\design-5.mif');
    Require((FileActions.RecentFileCount = 10) and
      SameText(FileActions.RecentFileName(0),
        ExpandFileName('C:\Temp\design-5.mif')), 'Recent duplicate promotion');
    FileActions.HistoryMenu.Items[0].Click;
    Require(SameText(Recorder.OpenedFileName,
      ExpandFileName('C:\Temp\design-5.mif')), 'Recent file click');

    Ini := TMemIniFile.Create(IniFileName, TEncoding.UTF8);
    try
      FileActions.SaveHistory(Ini);
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
    ReloadedMenu := TMainMenu.Create(Owner);
    ReloadedRoot := TMenuItem.Create(ReloadedMenu);
    ReloadedMenu.Items.Add(ReloadedRoot);
    ReloadedActions := TVectArtFileActionsUI.CreateForMenu(Owner,
      ReloadedRoot);
    Ini := TMemIniFile.Create(IniFileName, TEncoding.UTF8);
    try
      ReloadedActions.LoadHistory(Ini);
    finally
      Ini.Free;
    end;
    Require((ReloadedActions.RecentFileCount = 10) and
      SameText(ReloadedActions.RecentFileName(0),
        FileActions.RecentFileName(0)), 'Recent file persistence');

    RectangleData := Default(TVectArtRectangleData);
    RectangleData.Name := 'Rectangle';
    RectangleData.Bounds := RectF(10, 10, 100, 100);
    RectangleData.Visible := True;
    RectangleData.Filled := True;
    RectangleData.FillColor := clRed;
    RectangleData.Opacity := 1;
    Document.InsertRectangle(1, RectangleData);
    Document.SelectedIndex := 1;
    Document.Reset(800, 600);
    Require((Document.LayerCount = 1) and (Document.SelectionCount = 0) and
      (Document.CanvasLayer.Width = 800) and
      (Document.CanvasLayer.Height = 600) and
      (Document.CanvasLayer.BackgroundColor = clWhite),
      'New document reset');

    Writeln('PASS file menu, new document reset and recent file history');
  finally
    if TFile.Exists(IniFileName) then
      TFile.Delete(IniFileName);
    Document.Free;
    Recorder.Free;
    Owner.Free;
  end;
end.
