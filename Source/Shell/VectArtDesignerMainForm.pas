// VectArtDesignerのメイン画面と標準メニューを構築する。
// 個別編集UIはFrameへ委譲し、ここではDocument、履歴、ショートカットとの接続を担当する。
unit VectArtDesignerMainForm;

interface

uses
  System.Classes, System.SysUtils, Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms,
  Vcl.Menus, Vcl.StdCtrls, Winapi.Windows,
  ShortcutAction, VectArtDesignerContext,
  VectArtDesignerDockManager,
  VectArtDesignerDocumentSession,
  VectArtDesignerDocument,
  VectArtDesignerEditHistory, VectArtDesignerEditorState,
  VectArtDesignerEditorWorkspaceFrame, VectArtDesignerLayerPanelFrame,
  VectArtDesignerLineToolbar,
  VectArtDesignerLayerOperations,
  VectArtDesignerEditActionsUI, VectArtDesignerFileActionsUI,
  VectArtDesignerDocumentFileController,
  VectArtDesignerObjectPropertiesFrame, VectArtDesignerToolFrames,
  VectArtDesignerTemplatePanelFrame, VectArtDesignerToolPaletteFrame;

type
  TMainForm = class(TForm)
    pnlShortcutBar: TPanel;
    lblShortcutItems: TLabel;
    pnlStatusBar: TPanel;
    lblStatus: TLabel;
    pnlWorkspace: TPanel;
    pnlLeftDockArea: TPanel;
    splLeftRegion: TSplitter;
    pnlRightDockArea: TPanel;
    splRightRegion: TSplitter;
    pnlEditorHost: TPanel;
    pnlLeftDropTarget: TPanel;
    pnlRightDropTarget: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormResize(Sender: TObject);
  private
    FDockManager: TVectDockManager;
    FDesignerContext: IVectArtDesignerContext;
    FDocument: TVectArtDocument;
    FDocumentSession: TVectArtDocumentSession;
    FLastSaveSucceeded: Boolean;
    FEditorFrame: TEditorWorkspaceFrame;
    FEditorState: TVectArtEditorState;
    FEditActionsUI: TVectArtEditActionsUI;
    FEditHistory: TVectArtEditHistory;
    FFileActionsUI: TVectArtFileActionsUI;
    FLayerFrame: TLayerPanelFrame;
    FLineToolbar: TVectArtLineToolbarControl;
    FObjectPropertiesFrame: TObjectPropertiesFrame;
    FDocumentRefreshPending: Boolean;
    FDocumentRefreshTimer: TTimer;
    FSkiaAcquired: Boolean;
    FShortcuts: TShortcutAction;
    FTemplateFrame: TTemplatePanelFrame;
    FToolPaletteFrame: TToolPaletteFrame;
    FMainMenu: TMainMenu;
    FViewMenu: TMenuItem;
    FLayoutEditing: Boolean;
    FLayoutFileName: string;
    FLayoutEditMenuItem: TMenuItem;
    FLayerMenuItem: TMenuItem;
    FObjectPropertiesMenuItem: TMenuItem;
    FTemplateMenuItem: TMenuItem;
    FToolPaletteMenuItem: TMenuItem;
    FDocumentFileController: TVectArtDocumentFileController;
    FMifAnalysisDetail: string;
    FMifAnalysisRevision: Int64;
    FMifAnalysisStatus: string;
    procedure AttachFrame(AFrame: TFrame; AHost: TWinControl);
    procedure CanvasSettingsRequest(Sender: TObject);
    function ConfirmSaveChanges: Boolean;
    procedure CreateStandardMenus;
    function CreateViewMenuItem(const Caption: string): TMenuItem;
    procedure DocumentChanged(Sender: TObject);
    procedure DocumentSessionChanged(Sender: TObject);
    procedure DocumentRefreshTimer(Sender: TObject);
    procedure FinalizeSkiaRuntime;
    procedure HistoryChanged(Sender: TObject);
    procedure EditorStateChanged(Sender: TObject);
    procedure FileOpenRequest(Sender: TObject; const FileName: string);
    procedure FileOpenShortcut(Sender: TObject);
    procedure FileSaveRequest(Sender: TObject; const FileName: string);
    procedure FileSaveShortcut(Sender: TObject);
    procedure InitializeSkiaRuntime;
    function IsContinuousSliderInput: Boolean;
    procedure RefreshDocumentPanels;
    procedure ScheduleDocumentPanelRefresh;
    function SaveDocumentForContinuation: Boolean;
    procedure InitializeShortcuts;
    function CanUseToolShortcut: Boolean;
    function IsEditingSurfaceFocused: Boolean;
    function IsTextInputFocused: Boolean;
    function MifConstraintStatusText: string;
    procedure LoadLayoutSettings;
    procedure NewCanvasRequest(Sender: TObject);
    procedure NewCanvasWizardRequest(Sender: TObject);
    procedure ResetToNewDocument(AWidth, AHeight: Integer);
    procedure SaveLayoutSettings;
    procedure SelectAllLayers;
    procedure SetLayoutEditing(const Value: Boolean);
    procedure LayoutEditMenuItemClick(Sender: TObject);
    procedure ToolMenuItemClick(Sender: TObject);
    procedure ToolVisibilityChanged(Sender: TToolPlaceholderFrame);
    procedure UpdateLayoutEditMenu;
    procedure UpdateToolMenuItems;
  public
    // 外部ホストが編集メニュー内のキャンバス設定項目を表示するか切り替える。
    procedure SetCanvasSettingsVisible(const Value: Boolean);
    // 単独アプリ専用のファイルメニューを表示し、非表示時は残りのメニューを左詰めする。
    procedure SetFileMenuVisible(const Value: Boolean);
    // プラグインホストが編集中だけ表示する参照背景を設定する。
    procedure SetReferenceBackgroundRgba(const Pixels: TBytes;
      Width, Height: Integer);
    // プラグインなど外部ホストが、同じ編集UIへDocumentを受け渡すための接続口。
    property Document: TVectArtDocument read FDocument;
  end;

var
  MainForm: TMainForm;

implementation

uses
  System.IniFiles, System.IOUtils, System.Math,
  {$IFDEF DEBUG} VectArtDesignerMifDebugLog, {$ENDIF}
  HorizontalTrackBarControl,
  TextRendererSkiaBootstrap, TextRendererSkiaRuntime,
  VectArtDesignerCanvasSettingsDialog,
  VectArtDesignerClipboardOperations, VectArtDesignerKeyboardMovement,
  VectArtDesignerLayerGroupOperations, VectArtDesignerMifDocument;

{$R *.dfm}

function ConstrainToMonitor(const Bounds: TRect): TRect;
var
  Monitor: TMonitor;
  WorkArea: TRect;
begin
  Result := Bounds;
  Monitor := Screen.MonitorFromRect(Result, mdNearest);
  WorkArea := Monitor.WorkareaRect;
  if Result.Width > WorkArea.Width then
    Result.Right := Result.Left + WorkArea.Width;
  if Result.Height > WorkArea.Height then
    Result.Bottom := Result.Top + WorkArea.Height;
  if Result.Left < WorkArea.Left then
    OffsetRect(Result, WorkArea.Left - Result.Left, 0);
  if Result.Top < WorkArea.Top then
    OffsetRect(Result, 0, WorkArea.Top - Result.Top);
  if Result.Right > WorkArea.Right then
    OffsetRect(Result, WorkArea.Right - Result.Right, 0);
  if Result.Bottom > WorkArea.Bottom then
    OffsetRect(Result, 0, WorkArea.Bottom - Result.Bottom);
end;

procedure TMainForm.AttachFrame(AFrame: TFrame; AHost: TWinControl);
begin
  AFrame.Parent := AHost;
  AFrame.Align := alClient;
  AFrame.Visible := True;
end;

procedure TMainForm.CreateStandardMenus;
var
  EditMenu: TMenuItem;
  FileMenu: TMenuItem;
begin
  FMainMenu := TMainMenu.Create(Self);
  Menu := FMainMenu;

  FileMenu := TMenuItem.Create(FMainMenu);
  FileMenu.Caption := 'ファイル(&F)';
  FMainMenu.Items.Add(FileMenu);
  FFileActionsUI := TVectArtFileActionsUI.CreateForMenu(Self, FileMenu);

  EditMenu := TMenuItem.Create(FMainMenu);
  EditMenu.Caption := '編集(&E)';
  FMainMenu.Items.Add(EditMenu);
  FEditActionsUI := TVectArtEditActionsUI.CreateForMenu(Self, EditMenu,
    pnlShortcutBar);

  FViewMenu := TMenuItem.Create(FMainMenu);
  FViewMenu.Caption := '表示(&V)';
  FMainMenu.Items.Add(FViewMenu);
end;

function TMainForm.CreateViewMenuItem(const Caption: string): TMenuItem;
begin
  Result := TMenuItem.Create(Self);
  Result.Caption := Caption;
  Result.OnClick := ToolMenuItemClick;
  FViewMenu.Add(Result);
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  LayoutFolder: string;
begin
  InitializeSkiaRuntime;

  FDocument := TVectArtDocument.Create;
  FDocumentSession := TVectArtDocumentSession.Create(FDocument);
  FDocumentSession.OnChanged := DocumentSessionChanged;
  DocumentSessionChanged(FDocumentSession);
  OnCloseQuery := FormCloseQuery;
  FMifAnalysisRevision := -1;
  FDocument.OnChanged := DocumentChanged;
  FEditorState := TVectArtEditorState.Create;
  FEditorState.OnChanged := EditorStateChanged;
  FEditHistory := TVectArtEditHistory.Create;
  FEditHistory.OnChanged := HistoryChanged;
  FDesignerContext := TVectArtDesignerContext.Create(FDocument, FEditHistory,
    FEditorState);
  FDocumentFileController := TVectArtDocumentFileController.Create(FDocument,
    FEditHistory);
  lblShortcutItems.Visible := False;
  CreateStandardMenus;
  FFileActionsUI.OnNewFile := NewCanvasRequest;
  FFileActionsUI.OnNewWizard := NewCanvasWizardRequest;
  FFileActionsUI.OnOpenFile := FileOpenRequest;
  FFileActionsUI.OnSaveFile := FileSaveRequest;
  FFileActionsUI.CanSave := True;
  FEditActionsUI.History := FEditHistory;
  FEditActionsUI.OnCanvasSettingsRequest := CanvasSettingsRequest;
  FEditActionsUI.OnNewRequest := NewCanvasRequest;
  FEditActionsUI.OnOpenRequest := FileOpenShortcut;
  FEditActionsUI.OnSaveRequest := FileSaveShortcut;
  FLineToolbar := TVectArtLineToolbarControl.CreateForHost(Self,
    pnlShortcutBar);
  FLineToolbar.Document := FDocument;
  FLineToolbar.EditHistory := FEditHistory;
  FLineToolbar.EditorState := FEditorState;
  FLineToolbar.BringToFront;
  FEditorFrame := TEditorWorkspaceFrame.Create(Self);
  FEditorFrame.Context := FDesignerContext;
  AttachFrame(FEditorFrame, pnlEditorHost);
  FDocumentRefreshTimer := TTimer.Create(Self);
  FDocumentRefreshTimer.Enabled := False;
  FDocumentRefreshTimer.Interval := 200;
  FDocumentRefreshTimer.OnTimer := DocumentRefreshTimer;

  FDockManager := TVectDockManager.Create(Self, pnlWorkspace,
    pnlLeftDockArea, pnlRightDockArea, pnlLeftDropTarget,
    pnlRightDropTarget, splLeftRegion, splRightRegion);
  FLayerFrame := TLayerPanelFrame.Create(Self);
  FLayerFrame.Context := FDesignerContext;
  FToolPaletteFrame := TToolPaletteFrame.Create(Self);
  FToolPaletteFrame.Context := FDesignerContext;
  FTemplateFrame := TTemplatePanelFrame.Create(Self);
  FTemplateFrame.Context := FDesignerContext;
  FObjectPropertiesFrame := TObjectPropertiesFrame.Create(Self);
  FObjectPropertiesFrame.Context := FDesignerContext;
  FDockManager.RegisterTool(FLayerFrame, vdsLeft);
  FDockManager.RegisterTool(FToolPaletteFrame, vdsLeft);
  FDockManager.RegisterTool(FTemplateFrame, vdsLeft);
  FDockManager.RegisterTool(FObjectPropertiesFrame, vdsRight);
  FDockManager.OnToolVisibilityChanged := ToolVisibilityChanged;

  FLayoutEditMenuItem := TMenuItem.Create(Self);
  FLayoutEditMenuItem.Caption := 'レイアウト編集';
  FLayoutEditMenuItem.OnClick := LayoutEditMenuItemClick;
  FViewMenu.Add(FLayoutEditMenuItem);
  FViewMenu.Add(NewLine);
  FObjectPropertiesMenuItem := CreateViewMenuItem('Object Properties');
  FToolPaletteMenuItem := CreateViewMenuItem('Tools');
  FTemplateMenuItem := CreateViewMenuItem('テンプレ図形');
  FLayerMenuItem := CreateViewMenuItem('Layers');

  LayoutFolder := TPath.Combine(TPath.GetDocumentsPath, 'VectArtDesigner');
  FLayoutFileName := TPath.Combine(LayoutFolder, 'MainForm.ini');
  try
    TDirectory.CreateDirectory(LayoutFolder);
  except
    on E: Exception do
      lblStatus.Caption := 'Layout folder error: ' + E.Message;
  end;

  FLayoutEditing := False;
  UpdateLayoutEditMenu;
  UpdateToolMenuItems;
  LoadLayoutSettings;
  InitializeShortcuts;
  HistoryChanged(FEditHistory);
  EditorStateChanged(FEditorState);
end;

procedure TMainForm.CanvasSettingsRequest(Sender: TObject);
var
  CanvasHeight: Integer;
  CanvasWidth: Integer;
begin
  if (FDocument = nil) or (FDocument.CanvasLayer = nil) then
    Exit;
  if ExecuteCanvasSettingsDialog(Self, FDocument.CanvasLayer.Width,
    FDocument.CanvasLayer.Height, CanvasWidth, CanvasHeight) then
  begin
    FDocument.SetCanvasSize(CanvasWidth, CanvasHeight);
    EditorStateChanged(FEditorState);
  end;
end;

function TMainForm.ConfirmSaveChanges: Boolean;
begin
  Result := (FDocumentSession = nil) or
    FDocumentSession.ConfirmSave(Handle, SaveDocumentForContinuation);
end;

procedure TMainForm.NewCanvasRequest(Sender: TObject);
begin
  if not ConfirmSaveChanges then
    Exit;
  ResetToNewDocument(DEFAULT_CANVAS_WIDTH, DEFAULT_CANVAS_HEIGHT);
end;

procedure TMainForm.NewCanvasWizardRequest(Sender: TObject);
var
  CanvasHeight: Integer;
  CanvasWidth: Integer;
begin
  if not ConfirmSaveChanges then
    Exit;
  if ExecuteCanvasSettingsDialog(Self, DEFAULT_CANVAS_WIDTH,
    DEFAULT_CANVAS_HEIGHT, CanvasWidth, CanvasHeight) then
    ResetToNewDocument(CanvasWidth, CanvasHeight);
end;

procedure TMainForm.ResetToNewDocument(AWidth, AHeight: Integer);
begin
  if FDocument = nil then
    Exit;
  if (FEditorFrame <> nil) and (FEditorFrame.CanvasControl <> nil) then
    FEditorFrame.CanvasControl.CancelCutoutSelection;
  FDocument.Reset(AWidth, AHeight);
  if FEditHistory <> nil then
    FEditHistory.Clear;
  if FDocumentFileController <> nil then
    FDocumentFileController.Reset;
  FMifAnalysisRevision := -1;
  FFileActionsUI.CurrentFileName := '';
  FFileActionsUI.CanSave := True;
  FEditActionsUI.OnSaveRequest := FileSaveShortcut;
  FDocumentSession.MarkClean('新規キャンバス');
  lblStatus.Caption := Format('新規キャンバス: %d x %d',
    [AWidth, AHeight]);
end;

procedure TMainForm.FileOpenRequest(Sender: TObject; const FileName: string);
var
  StatusText: string;
begin
  if not ConfirmSaveChanges then
    Exit;
  StatusText := 'Open error: file controller unavailable';
  if (FDocumentFileController = nil) or
    not FDocumentFileController.OpenFile(Handle, FileName, StatusText) then
  begin
    lblStatus.Caption := StatusText;
    Exit;
  end;
  DocumentChanged(FDocument);
  FFileActionsUI.CurrentFileName := FileName;
  FFileActionsUI.CanSave := True;
  FFileActionsUI.AddRecentFile(FileName);
  FEditActionsUI.OnSaveRequest := FileSaveShortcut;
  FDocumentSession.MarkClean(ExtractFileName(FileName));
  lblStatus.Caption := StatusText;
end;

procedure TMainForm.FileOpenShortcut(Sender: TObject);
begin
  if FFileActionsUI <> nil then
    FFileActionsUI.ExecuteOpen;
end;

procedure TMainForm.FileSaveRequest(Sender: TObject; const FileName: string);
var
  StatusText: string;
begin
  FLastSaveSucceeded := False;
  StatusText := 'Save error: file controller unavailable';
  if (FDocumentFileController = nil) or
    not FDocumentFileController.SaveFile(Handle, FileName, StatusText) then
  begin
    lblStatus.Caption := StatusText;
    Exit;
  end;
  FFileActionsUI.CurrentFileName := FileName;
  FFileActionsUI.CanSave := True;
  FFileActionsUI.AddRecentFile(FileName);
  FEditActionsUI.OnSaveRequest := FileSaveShortcut;
  FDocumentSession.MarkClean(ExtractFileName(FileName));
  FLastSaveSucceeded := True;
  lblStatus.Caption := StatusText;
end;

procedure TMainForm.FileSaveShortcut(Sender: TObject);
begin
  if FFileActionsUI <> nil then
    FFileActionsUI.ExecuteSave;
end;

procedure TMainForm.DocumentChanged(Sender: TObject);
begin
  if FDocumentSession <> nil then
    FDocumentSession.ObserveDocumentChange;
  if FEditorFrame <> nil then
    FEditorFrame.CanvasControl.Invalidate;
  if (FDocument <> nil) and FDocument.IsInteractiveUpdate then
    Exit;
  // 連続入力中もキャンバスは上で即時更新する。設定欄などのネイティブUIだけを
  // 入力停止後へ集約し、値の再設定と背景消去によるちらつき・操作遅延を避ける。
  if ((FEditorFrame <> nil) and FEditorFrame.CanvasControl.TextEditing) or
    IsContinuousSliderInput then
  begin
    ScheduleDocumentPanelRefresh;
    Exit;
  end;
  if FDocumentRefreshTimer <> nil then
    FDocumentRefreshTimer.Enabled := False;
  FDocumentRefreshPending := False;
  RefreshDocumentPanels;
end;

procedure TMainForm.DocumentSessionChanged(Sender: TObject);
begin
  if FDocumentSession <> nil then
    Caption := FDocumentSession.Caption;
end;

function TMainForm.IsContinuousSliderInput: Boolean;
var
  FocusedControl: TWinControl;
  FocusedHandle: HWND;
begin
  FocusedHandle := GetFocus;
  if FocusedHandle = 0 then
    Exit(False);
  FocusedControl := FindControl(FocusedHandle);
  Result := FocusedControl is THorizontalTrackBarControl;
end;

procedure TMainForm.DocumentRefreshTimer(Sender: TObject);
begin
  FDocumentRefreshTimer.Enabled := False;
  if not FDocumentRefreshPending then
    Exit;
  FDocumentRefreshPending := False;
  RefreshDocumentPanels;
end;

procedure TMainForm.RefreshDocumentPanels;
begin
  if FEditActionsUI <> nil then
    FEditActionsUI.RefreshState;
  if FLayerFrame <> nil then
    FLayerFrame.RefreshFromDocument;
  if FObjectPropertiesFrame <> nil then
    FObjectPropertiesFrame.RefreshFromDocument;
  if FLineToolbar <> nil then
    FLineToolbar.RefreshState;
  EditorStateChanged(FEditorState);
end;

procedure TMainForm.ScheduleDocumentPanelRefresh;
begin
  FDocumentRefreshPending := True;
  if FDocumentRefreshTimer = nil then
    Exit;
  FDocumentRefreshTimer.Enabled := False;
  FDocumentRefreshTimer.Enabled := True;
end;

function TMainForm.SaveDocumentForContinuation: Boolean;
begin
  FLastSaveSucceeded := False;
  if FFileActionsUI <> nil then
    FFileActionsUI.ExecuteSave;
  Result := FLastSaveSucceeded;
end;

procedure TMainForm.SetReferenceBackgroundRgba(const Pixels: TBytes;
  Width, Height: Integer);
begin
  if (FEditorFrame <> nil) and (FEditorFrame.CanvasControl <> nil) then
    FEditorFrame.CanvasControl.SetReferenceBackgroundRgba(Pixels,
      Width, Height);
end;

procedure TMainForm.SetCanvasSettingsVisible(const Value: Boolean);
begin
  if FEditActionsUI <> nil then
    FEditActionsUI.CanvasSettingsVisible := Value;
end;

procedure TMainForm.SetFileMenuVisible(const Value: Boolean);
begin
  if (FFileActionsUI = nil) or (FEditActionsUI = nil) then
    Exit;
  FFileActionsUI.Menu.Visible := Value;
end;

function TMainForm.MifConstraintStatusText: string;
var
  ErrorMessage: string;
  Report: TMifExportReport;
begin
  Result := '';
  if FDocument = nil then
    Exit;
  if FMifAnalysisRevision <> FDocument.Revision then
  begin
    FMifAnalysisRevision := FDocument.Revision;
    FMifAnalysisDetail := '';
    if not TryAnalyzeVectArtMifExport(FDocument, Report, ErrorMessage) then
    begin
      FMifAnalysisStatus := 'MIF: analysis error';
      FMifAnalysisDetail := ErrorMessage;
    end
    else
    begin
      FMifAnalysisDetail := Report.ToDisplayText;
      case Report.Compatibility of
        mecExact:
          FMifAnalysisStatus := 'MIF: exact';
        mecNeedsConfirmation:
          FMifAnalysisStatus := Format('MIF: %d conversion notice(s)',
            [Length(Report.Issues)]);
        mecUnsupported:
          FMifAnalysisStatus := Format('MIF: unsupported (%d issue(s))',
            [Length(Report.Issues)]);
      end;
    end;
  end;
  lblStatus.ShowHint := FMifAnalysisDetail <> '';
  lblStatus.Hint := FMifAnalysisDetail;
  Result := FMifAnalysisStatus;
end;

procedure TMainForm.EditorStateChanged(Sender: TObject);
var
  CanvasSize: string;
  ConstraintStatus: string;
begin
  if FEditorFrame <> nil then
    FEditorFrame.CanvasControl.Invalidate;
  if FToolPaletteFrame <> nil then
    FToolPaletteFrame.RefreshState;
  if FTemplateFrame <> nil then
    FTemplateFrame.RefreshState;
  if FLineToolbar <> nil then
    FLineToolbar.RefreshState;
  if (FDocument <> nil) and (FDocument.CanvasLayer <> nil) then
    CanvasSize := Format('%d x %d', [FDocument.CanvasLayer.Width,
      FDocument.CanvasLayer.Height])
  else
    CanvasSize := '-';
  ConstraintStatus := MifConstraintStatusText;
  if (FEditorState <> nil) and
    (FEditorState.CurrentTool = vetRectangle) then
    lblStatus.Caption := 'Ready   Tool: Rectangle   Canvas: ' + CanvasSize
  else if (FEditorState <> nil) and
    (FEditorState.CurrentTool = vetEllipse) then
    lblStatus.Caption := 'Ready   Tool: Ellipse   Canvas: ' + CanvasSize
  else if (FEditorState <> nil) and
    (FEditorState.CurrentTool = vetRoundedRectangle) then
    lblStatus.Caption := 'Ready   Tool: Rounded Rectangle   Canvas: ' +
      CanvasSize
  else if (FEditorState <> nil) and
    (FEditorState.CurrentTool = vetClosedPath) then
    lblStatus.Caption := 'Closed path: click vertices, click first point, ' +
      'double-click, or right-click to close   Canvas: ' + CanvasSize
  else if (FEditorState <> nil) and
    (FEditorState.CurrentTool = vetClosedBezier) then
    lblStatus.Caption := 'Closed Bezier: click anchors, click first point, ' +
      'double-click, or right-click to close   Canvas: ' + CanvasSize
  else if (FEditorState <> nil) and
    (FEditorState.CurrentTool = vetLine) then
    lblStatus.Caption := 'Ready   Tool: Line   Canvas: ' + CanvasSize
  else if (FEditorState <> nil) and
    (FEditorState.CurrentTool = vetPath) then
    lblStatus.Caption := 'Path: click vertices, click first point to close, ' +
      'double-click/right-click to finish   Canvas: ' + CanvasSize
  else if (FEditorState <> nil) and
    (FEditorState.CurrentTool = vetBezier) then
    lblStatus.Caption := 'Bezier: click anchors, double-click/right-click ' +
      'to finish   Canvas: ' + CanvasSize
  else if (FEditorState <> nil) and
    (FEditorState.CurrentTool = vetFreehandLine) then
    lblStatus.Caption := 'Freehand polyline: drag to draw, release to ' +
      'finish   Canvas: ' + CanvasSize
  else if (FEditorState <> nil) and
    (FEditorState.CurrentTool = vetFreehandBezier) then
    lblStatus.Caption := 'Freehand Bezier: drag to draw, release to smooth ' +
      'and finish   Canvas: ' + CanvasSize
  else if (FEditorState <> nil) and
    (FEditorState.CurrentTool = vetText) then
    lblStatus.Caption := 'Text: click the input position, Enter inserts a ' +
      'line break   Canvas: ' + CanvasSize
  else if (FEditorState <> nil) and
    (FEditorState.CurrentTool = vetCutout) then
    case FEditorState.CutoutMode of
      vcmRectangle:
        lblStatus.Caption := 'Cutout rectangle: drag a copy region   Canvas: ' +
          CanvasSize;
      vcmEllipse:
        lblStatus.Caption := 'Cutout ellipse: drag a copy region   Canvas: ' +
          CanvasSize;
      vcmPolygon:
        lblStatus.Caption := 'Cutout polygon: click vertices, then double-click ' +
          'or right-click   Canvas: ' + CanvasSize;
      vcmFreehand:
        lblStatus.Caption := 'Cutout freehand: drag a closed copy region   Canvas: ' +
          CanvasSize;
    end
  else
    lblStatus.Caption := 'Ready   Tool: Select   Canvas: ' + CanvasSize;
  if ConstraintStatus <> '' then
    lblStatus.Caption := lblStatus.Caption + '   ' + ConstraintStatus;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (FShortcuts <> nil) and FShortcuts.KeyDown(Key, Shift) then
    Exit;
  if (FEditorFrame <> nil) and
    (GetFocus = FEditorFrame.CanvasControl.Handle) and
    HandleSelectionNudge(FDocument, FEditHistory, Key, Shift) then
    Key := 0;
end;

procedure TMainForm.HistoryChanged(Sender: TObject);
begin
  if FEditActionsUI <> nil then
    FEditActionsUI.RefreshState;
end;

procedure TMainForm.ToolMenuItemClick(Sender: TObject);
begin
  if Sender = FLayerMenuItem then
    FDockManager.SetToolVisible(FLayerFrame,
      not FDockManager.ToolVisible(FLayerFrame))
  else if Sender = FToolPaletteMenuItem then
    FDockManager.SetToolVisible(FToolPaletteFrame,
      not FDockManager.ToolVisible(FToolPaletteFrame))
  else if Sender = FTemplateMenuItem then
    FDockManager.SetToolVisible(FTemplateFrame,
      not FDockManager.ToolVisible(FTemplateFrame))
  else if Sender = FObjectPropertiesMenuItem then
    FDockManager.SetToolVisible(FObjectPropertiesFrame,
      not FDockManager.ToolVisible(FObjectPropertiesFrame));
end;

procedure TMainForm.ToolVisibilityChanged(Sender: TToolPlaceholderFrame);
begin
  UpdateToolMenuItems;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := ConfirmSaveChanges;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  SaveLayoutSettings;
  if FDocumentRefreshTimer <> nil then
  begin
    FDocumentRefreshTimer.Enabled := False;
    FDocumentRefreshTimer.OnTimer := nil;
  end;
  FreeAndNil(FShortcuts);
  FreeAndNil(FLineToolbar);
  OnResize := nil;
  FreeAndNil(FDockManager);
  if FDocument <> nil then
    FDocument.OnChanged := nil;
  if FEditorFrame <> nil then
    FEditorFrame.Context := nil;
  if FLayerFrame <> nil then
    FLayerFrame.Context := nil;
  if FObjectPropertiesFrame <> nil then
    FObjectPropertiesFrame.Context := nil;
  if FToolPaletteFrame <> nil then
    FToolPaletteFrame.Context := nil;
  if FTemplateFrame <> nil then
    FTemplateFrame.Context := nil;
  FDesignerContext := nil;
  if FEditorState <> nil then
    FEditorState.OnChanged := nil;
  if FEditHistory <> nil then
    FEditHistory.OnChanged := nil;
  FreeAndNil(FDocumentFileController);
  FreeAndNil(FFileActionsUI);
  FreeAndNil(FEditActionsUI);
  FreeAndNil(FEditHistory);
  FreeAndNil(FEditorState);
  FreeAndNil(FDocumentSession);
  FreeAndNil(FDocument);
  FinalizeSkiaRuntime;
end;

procedure TMainForm.InitializeShortcuts;
begin
  FShortcuts := TShortcutAction.Create;
  FShortcuts.Add(Ord('N'), [ssCtrl],
    procedure
    begin
      FFileActionsUI.ExecuteNew;
    end);
  FShortcuts.Add(Ord('N'), [ssCtrl, ssShift],
    procedure
    begin
      FFileActionsUI.ExecuteNewWizard;
    end);
  FShortcuts.Add(Ord('O'), [ssCtrl],
    procedure
    begin
      FFileActionsUI.ExecuteOpen;
    end);
  FShortcuts.Add(Ord('S'), [ssCtrl],
    procedure
    begin
      FFileActionsUI.ExecuteSave;
    end);
  FShortcuts.Add(Ord('S'), [ssCtrl, ssShift],
    procedure
    begin
      FFileActionsUI.ExecuteSaveAs;
    end);
  FShortcuts.Add(Ord('Z'), [ssCtrl],
    procedure
    begin
      FEditHistory.Undo;
    end,
    function: Boolean
    begin
      Result := (FEditHistory <> nil) and not IsTextInputFocused;
    end);
  FShortcuts.Add(Ord('Z'), [ssCtrl, ssShift],
    procedure
    begin
      FEditHistory.Redo;
    end,
    function: Boolean
    begin
      Result := (FEditHistory <> nil) and not IsTextInputFocused;
    end);
  FShortcuts.Add(Ord('Y'), [ssCtrl],
    procedure
    begin
      FEditHistory.Redo;
    end,
    function: Boolean
    begin
      Result := (FEditHistory <> nil) and not IsTextInputFocused;
    end);
  FShortcuts.Add(Ord('A'), [ssCtrl],
    procedure
    begin
      SelectAllLayers;
    end,
    function: Boolean
    begin
      Result := IsEditingSurfaceFocused and (FDocument <> nil) and
        (FDocument.LayerCount > 1);
    end);
  FShortcuts.Add(Ord('C'), [ssCtrl],
    procedure
    begin
      FEditorFrame.CanvasControl.CopyToClipboard;
    end,
    function: Boolean
    begin
      Result := IsEditingSurfaceFocused and (FEditorFrame <> nil) and
        FEditorFrame.CanvasControl.CanCopyToClipboard;
    end);
  FShortcuts.Add(Ord('X'), [ssCtrl],
    procedure
    begin
      CutVectArtSelectionToClipboard(FDocument, FEditHistory);
    end,
    function: Boolean
    begin
      Result := IsEditingSurfaceFocused and
        CanCutVectArtSelection(FDocument);
    end);
  FShortcuts.Add(Ord('V'), [ssCtrl],
    procedure
    begin
      PasteVectArtClipboard(FDocument, FEditHistory);
    end,
    function: Boolean
    begin
      Result := IsEditingSurfaceFocused and CanPasteVectArtClipboard;
    end);
  FShortcuts.Add(Ord('D'), [ssCtrl],
    procedure
    begin
      FLayerFrame.RunLayerAction(vlaDuplicate);
    end,
    function: Boolean
    begin
      Result := IsEditingSurfaceFocused and (FLayerFrame <> nil) and
        FLayerFrame.CanRunLayerAction(vlaDuplicate);
    end);
  FShortcuts.Add(Ord('G'), [ssCtrl],
    procedure
    begin
      GroupVectArtSelection(FDocument, FEditHistory);
    end,
    function: Boolean
    begin
      Result := IsEditingSurfaceFocused and
        CanGroupVectArtSelection(FDocument);
    end);
  FShortcuts.Add(Ord('G'), [ssCtrl, ssShift],
    procedure
    begin
      UngroupVectArtSelection(FDocument, FEditHistory);
    end,
    function: Boolean
    begin
      Result := IsEditingSurfaceFocused and
        CanUngroupVectArtSelection(FDocument);
    end);
  FShortcuts.Add(Ord('S'), [],
    procedure
    begin
      FEditorState.CurrentTool := vetSelect;
    end,
    function: Boolean
    begin
      Result := CanUseToolShortcut;
    end);
  FShortcuts.Add(Ord('L'), [],
    procedure
    begin
      FEditorState.CurrentTool := vetLine;
    end,
    function: Boolean
    begin
      Result := CanUseToolShortcut;
    end);
  FShortcuts.Add(Ord('P'), [],
    procedure
    begin
      FEditorState.SelectPathToolGroup;
    end,
    function: Boolean
    begin
      Result := CanUseToolShortcut;
    end);
  FShortcuts.Add(Ord('B'), [],
    procedure
    begin
      FEditorState.SelectFreehandToolGroup;
    end,
    function: Boolean
    begin
      Result := CanUseToolShortcut;
    end);
  FShortcuts.Add(Ord('R'), [],
    procedure
    begin
      FEditorState.SelectRectangleToolGroup;
    end,
    function: Boolean
    begin
      Result := CanUseToolShortcut;
    end);
  FShortcuts.Add(Ord('E'), [],
    procedure
    begin
      FEditorState.SelectEllipseToolGroup;
    end,
    function: Boolean
    begin
      Result := CanUseToolShortcut;
    end);
  FShortcuts.Add(Ord('U'), [],
    procedure
    begin
      FEditorState.SelectRoundedRectangleToolGroup;
    end,
    function: Boolean
    begin
      Result := CanUseToolShortcut;
    end);
  FShortcuts.Add(Ord('C'), [],
    procedure
    begin
      FEditorState.SelectClosedPathToolGroup;
    end,
    function: Boolean
    begin
      Result := CanUseToolShortcut;
    end);
  FShortcuts.Add(Ord('G'), [],
    procedure
    begin
      FEditorState.SelectClosedBezierToolGroup;
    end,
    function: Boolean
    begin
      Result := CanUseToolShortcut;
    end);
  FShortcuts.Add(Ord('T'), [],
    procedure
    begin
      FEditorState.CurrentTool := vetText;
    end,
    function: Boolean
    begin
      Result := CanUseToolShortcut;
    end);
  FShortcuts.Add(Ord('K'), [],
    procedure
    begin
      FEditorState.SelectCutoutToolGroup;
    end,
    function: Boolean
    begin
      Result := CanUseToolShortcut;
    end);
  FShortcuts.Add(VK_DELETE, [],
    procedure
    begin
      FLayerFrame.RunLayerAction(vlaDelete);
    end,
    function: Boolean
    begin
      Result := IsEditingSurfaceFocused and (FLayerFrame <> nil) and
        FLayerFrame.CanRunLayerAction(vlaDelete);
    end);
  FShortcuts.Add(VK_ESCAPE, [],
    procedure
    begin
      if not FEditorFrame.CanvasControl.CancelCutoutSelection then
        FDocument.SetSelectedLayers([]);
    end,
    function: Boolean
    begin
      Result := IsEditingSurfaceFocused and (FDocument <> nil) and
        (FEditorFrame <> nil) and
        ((FEditorState.CurrentTool = vetCutout) or
          (FDocument.SelectionCount > 0));
    end);
end;

function TMainForm.CanUseToolShortcut: Boolean;
begin
  Result := (FEditorState <> nil) and IsEditingSurfaceFocused and
    not IsTextInputFocused;
end;

function TMainForm.IsEditingSurfaceFocused: Boolean;
begin
  Result := ((FEditorFrame <> nil) and
    (GetFocus = FEditorFrame.CanvasControl.Handle)) or
    ((FLayerFrame <> nil) and
    (GetFocus = FLayerFrame.LayerList.Handle));
end;

function TMainForm.IsTextInputFocused: Boolean;
var
  FocusedControl: TWinControl;
begin
  FocusedControl := FindControl(GetFocus);
  Result := (FocusedControl is TCustomEdit) or
    (FocusedControl is TCustomComboBox);
end;

procedure TMainForm.SelectAllLayers;
var
  I: Integer;
  Indices: TArray<Integer>;
begin
  if (FDocument = nil) or (FDocument.LayerCount <= 1) then
    Exit;
  SetLength(Indices, FDocument.LayerCount - 1);
  for I := 1 to FDocument.LayerCount - 1 do
    Indices[I - 1] := I;
  FDocument.SetSelectedLayers(Indices);
end;

procedure TMainForm.FinalizeSkiaRuntime;
begin
  if not FSkiaAcquired then
    Exit;
  TTextRendererSkiaRuntime.Release;
  FSkiaAcquired := False;
end;

procedure TMainForm.InitializeSkiaRuntime;
begin
  try
    TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
    FSkiaAcquired := True;
  except
    on E: Exception do
      lblStatus.Caption := 'Skia runtime error: ' + E.Message;
  end;
end;

procedure TMainForm.LoadLayoutSettings;
var
  Bounds: TRect;
  Ini: TMemIniFile;
  SavedHeight: Integer;
  SavedWidth: Integer;
begin
  if (FLayoutFileName = '') or not TFile.Exists(FLayoutFileName) then
    Exit;
  Ini := nil;
  try
    try
      Ini := TMemIniFile.Create(FLayoutFileName, TEncoding.UTF8);
      if Ini.ReadInteger('File', 'Version', 0) <> 1 then
        Exit;
      if FFileActionsUI <> nil then
        FFileActionsUI.LoadHistory(Ini);
      SavedWidth := Max(Ini.ReadInteger('MainForm', 'Width', Width),
        Constraints.MinWidth);
      SavedHeight := Max(Ini.ReadInteger('MainForm', 'Height', Height),
        Constraints.MinHeight);
      Bounds := Rect(
        Ini.ReadInteger('MainForm', 'Left', Left),
        Ini.ReadInteger('MainForm', 'Top', Top), 0, 0);
      Bounds.Right := Bounds.Left + SavedWidth;
      Bounds.Bottom := Bounds.Top + SavedHeight;
      Bounds := ConstrainToMonitor(Bounds);
      SetBounds(Bounds.Left, Bounds.Top, Bounds.Width, Bounds.Height);
      FDockManager.LoadLayout(Ini);
      if SameText(Ini.ReadString('MainForm', 'WindowState', 'Normal'),
        'Maximized') then
        WindowState := wsMaximized
      else
        WindowState := wsNormal;
      UpdateToolMenuItems;
    except
      on E: Exception do
        lblStatus.Caption := 'Layout load error: ' + E.Message;
    end;
  finally
    Ini.Free;
  end;
end;

procedure TMainForm.SaveLayoutSettings;
var
  Ini: TMemIniFile;
  Placement: TWindowPlacement;
  SavedBounds: TRect;
begin
  if (FLayoutFileName = '') or (FDockManager = nil) then
    Exit;
  Ini := nil;
  try
    try
      Ini := TMemIniFile.Create(FLayoutFileName, TEncoding.UTF8);
      Placement.Length := SizeOf(Placement);
      if GetWindowPlacement(Handle, @Placement) then
        SavedBounds := Placement.rcNormalPosition
      else
        SavedBounds := BoundsRect;
      Ini.WriteInteger('File', 'Version', 1);
      Ini.WriteInteger('MainForm', 'Left', SavedBounds.Left);
      Ini.WriteInteger('MainForm', 'Top', SavedBounds.Top);
      Ini.WriteInteger('MainForm', 'Width', SavedBounds.Width);
      Ini.WriteInteger('MainForm', 'Height', SavedBounds.Height);
      if WindowState = wsMaximized then
        Ini.WriteString('MainForm', 'WindowState', 'Maximized')
      else
        Ini.WriteString('MainForm', 'WindowState', 'Normal');
      FDockManager.SaveLayout(Ini);
      if FFileActionsUI <> nil then
        FFileActionsUI.SaveHistory(Ini);
      Ini.UpdateFile;
    except
      on E: Exception do
        lblStatus.Caption := 'Layout save error: ' + E.Message;
    end;
  finally
    Ini.Free;
  end;
end;

procedure TMainForm.UpdateToolMenuItems;
begin
  FLayerMenuItem.Checked := FDockManager.ToolVisible(FLayerFrame);
  FToolPaletteMenuItem.Checked := FDockManager.ToolVisible(FToolPaletteFrame);
  FTemplateMenuItem.Checked := FDockManager.ToolVisible(FTemplateFrame);
  FObjectPropertiesMenuItem.Checked :=
    FDockManager.ToolVisible(FObjectPropertiesFrame);
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  if (FDockManager <> nil) and not (csDestroying in ComponentState) then
    FDockManager.Resize;
end;

procedure TMainForm.LayoutEditMenuItemClick(Sender: TObject);
begin
  SetLayoutEditing(not FLayoutEditing);
end;

procedure TMainForm.SetLayoutEditing(const Value: Boolean);
begin
  if FLayoutEditing = Value then
    Exit;
  FLayoutEditing := Value;
  FDockManager.LayoutEditing := Value;
  UpdateLayoutEditMenu;
end;

procedure TMainForm.UpdateLayoutEditMenu;
begin
  FLayoutEditMenuItem.Checked := FLayoutEditing;
end;

end.
