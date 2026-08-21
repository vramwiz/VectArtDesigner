// VectArtDesignerのメイン画面を提供する。
// 個別ツールの内容はFrameへ分離し、このユニットは外枠と初期配置だけを担当する。
unit VectArtDesignerMainForm;

interface

uses
  System.Classes, Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms, Vcl.StdCtrls,
  VectArtDesignerContext, VectArtDesignerDockManager, VectArtDesignerDocument,
  VectArtDesignerEditHistory, VectArtDesignerEditorState,
  VectArtDesignerEditorWorkspaceFrame, VectArtDesignerLayerPanelFrame,
  VectArtDesignerEditActionsUI, VectArtDesignerFileActionsUI,
  VectArtDesignerMifContainer,
  VectArtDesignerObjectPropertiesFrame, VectArtDesignerToolFrames,
  VectArtDesignerToolPaletteFrame;

type
  TMainForm = class(TForm)
    pnlMenuBar: TPanel;
    lblMenuItems: TLabel;
    pnlViewMenuButton: TPanel;
    pnlViewMenuPopup: TPanel;
    pnlLayoutEditMenuItem: TPanel;
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
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormResize(Sender: TObject);
    procedure lblLayoutEditMenuItemClick(Sender: TObject);
    procedure lblViewMenuClick(Sender: TObject);
  private
    FDockManager: TVectDockManager;
    FDesignerContext: IVectArtDesignerContext;
    FDocument: TVectArtDocument;
    FEditorFrame: TEditorWorkspaceFrame;
    FEditorState: TVectArtEditorState;
    FEditActionsUI: TVectArtEditActionsUI;
    FEditHistory: TVectArtEditHistory;
    FFileActionsUI: TVectArtFileActionsUI;
    FLayerFrame: TLayerPanelFrame;
    FObjectPropertiesFrame: TObjectPropertiesFrame;
    FSkiaAcquired: Boolean;
    FToolPaletteFrame: TToolPaletteFrame;
    FLayoutEditing: Boolean;
    FLayoutFileName: string;
    FLayerMenuItem: TPanel;
    FObjectPropertiesMenuItem: TPanel;
    FToolPaletteMenuItem: TPanel;
    FMifContainer: TVectArtMifContainer;
    FMifReader: IVectArtMifContainerReader;
    FMifWriter: IVectArtMifContainerWriter;
    procedure AttachFrame(AFrame: TFrame; AHost: TWinControl);
    function CreateViewMenuItem(const Caption: string): TPanel;
    procedure DocumentChanged(Sender: TObject);
    procedure FinalizeSkiaRuntime;
    procedure HistoryChanged(Sender: TObject);
    procedure EditorStateChanged(Sender: TObject);
    procedure FileOpenRequest(Sender: TObject; const FileName: string);
    procedure FileOpenShortcut(Sender: TObject);
    procedure FileSaveRequest(Sender: TObject; const FileName: string);
    procedure FileSaveShortcut(Sender: TObject);
    procedure InitializeSkiaRuntime;
    procedure LoadLayoutSettings;
    procedure SaveLayoutSettings;
    procedure SetLayoutEditing(const Value: Boolean);
    procedure ToolMenuItemClick(Sender: TObject);
    procedure ToolVisibilityChanged(Sender: TToolPlaceholderFrame);
    procedure UpdateLayoutEditMenu;
    procedure UpdateToolMenuItems;
  public
    // プラグインなど外部ホストが、同じ編集UIへDocumentを受け渡すための接続口。
    property Document: TVectArtDocument read FDocument;
  end;

var
  MainForm: TMainForm;

implementation

uses
  System.IniFiles, System.IOUtils, System.Math, System.SysUtils,
  TextRendererSkiaBootstrap, TextRendererSkiaRuntime,
  VectArtDesignerKeyboardMovement, Winapi.Dwmapi, Winapi.Windows;

{$R *.dfm}

const
  DWMWA_USE_IMMERSIVE_DARK_MODE = 20;

function CheckedMenuCaption(const IsVisible: Boolean;
  const Caption: string): string;
begin
  if IsVisible then
    Result := '✓ ' + Caption
  else
    Result := '□ ' + Caption;
end;

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

function TMainForm.CreateViewMenuItem(const Caption: string): TPanel;
begin
  Result := TPanel.Create(Self);
  Result.Parent := pnlViewMenuPopup;
  Result.Align := alTop;
  Result.BevelOuter := bvNone;
  Result.Caption := Caption;
  Result.Color := pnlViewMenuPopup.Color;
  Result.Font.Assign(pnlLayoutEditMenuItem.Font);
  Result.Height := 32;
  Result.ParentBackground := False;
  Result.OnClick := ToolMenuItemClick;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  DarkModeEnabled: BOOL;
  LayoutFolder: string;
begin
  DarkModeEnabled := True;
  DwmSetWindowAttribute(Handle, DWMWA_USE_IMMERSIVE_DARK_MODE,
    @DarkModeEnabled, SizeOf(DarkModeEnabled));

  InitializeSkiaRuntime;

  FDocument := TVectArtDocument.Create;
  FDocument.OnChanged := DocumentChanged;
  FEditorState := TVectArtEditorState.Create;
  FEditorState.OnChanged := EditorStateChanged;
  FEditHistory := TVectArtEditHistory.Create;
  FEditHistory.OnChanged := HistoryChanged;
  FDesignerContext := TVectArtDesignerContext.Create(FDocument, FEditHistory,
    FEditorState);
  FMifReader := CreateVectArtMifContainerReader;
  FMifWriter := CreateVectArtMifContainerWriter;
  lblShortcutItems.Visible := False;
  FFileActionsUI := TVectArtFileActionsUI.CreateForHosts(Self, Self,
    pnlMenuBar);
  FFileActionsUI.OnOpenFile := FileOpenRequest;
  FFileActionsUI.OnSaveFile := FileSaveRequest;
  FEditActionsUI := TVectArtEditActionsUI.CreateForHosts(Self, Self,
    pnlMenuBar, pnlShortcutBar);
  FEditActionsUI.History := FEditHistory;
  FEditActionsUI.OnOpenRequest := FileOpenShortcut;
  FEditorFrame := TEditorWorkspaceFrame.Create(Self);
  FEditorFrame.Context := FDesignerContext;
  AttachFrame(FEditorFrame, pnlEditorHost);

  FDockManager := TVectDockManager.Create(Self, pnlWorkspace,
    pnlLeftDockArea, pnlRightDockArea, pnlLeftDropTarget,
    pnlRightDropTarget, splLeftRegion, splRightRegion);
  FLayerFrame := TLayerPanelFrame.Create(Self);
  FLayerFrame.Context := FDesignerContext;
  FToolPaletteFrame := TToolPaletteFrame.Create(Self);
  FToolPaletteFrame.Context := FDesignerContext;
  FObjectPropertiesFrame := TObjectPropertiesFrame.Create(Self);
  FObjectPropertiesFrame.Context := FDesignerContext;
  FDockManager.RegisterTool(FLayerFrame, vdsLeft);
  FDockManager.RegisterTool(FToolPaletteFrame, vdsLeft);
  FDockManager.RegisterTool(FObjectPropertiesFrame, vdsRight);
  FDockManager.OnToolVisibilityChanged := ToolVisibilityChanged;

  pnlViewMenuPopup.Height := 128;
  pnlLayoutEditMenuItem.Align := alTop;
  FObjectPropertiesMenuItem := CreateViewMenuItem('Object Properties');
  FToolPaletteMenuItem := CreateViewMenuItem('Tools');
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
  pnlViewMenuPopup.Visible := False;
  UpdateLayoutEditMenu;
  UpdateToolMenuItems;
  LoadLayoutSettings;
  HistoryChanged(FEditHistory);
  EditorStateChanged(FEditorState);
end;

procedure TMainForm.FileOpenRequest(Sender: TObject; const FileName: string);
var
  Container: TVectArtMifContainer;
  ErrorMessage: string;
begin
  ErrorMessage := '';
  if (FMifReader = nil) or
    not FMifReader.TryReadFile(FileName, Container, ErrorMessage) then
  begin
    lblStatus.Caption := 'MIF open error: ' + ErrorMessage;
    Exit;
  end;
  FreeAndNil(FMifContainer);
  FMifContainer := Container;
  FFileActionsUI.CurrentFileName := FileName;
  FFileActionsUI.CanSave := True;
  FEditActionsUI.OnSaveRequest := FileSaveShortcut;
  Caption := 'VectArtDesigner - ' + ExtractFileName(FileName);
  lblStatus.Caption := Format(
    'MIF container loaded: %s   Chunks: %d   Canvas import: pending',
    [ExtractFileName(FileName), FMifContainer.ChunkCount]);
end;

procedure TMainForm.FileOpenShortcut(Sender: TObject);
begin
  if FFileActionsUI <> nil then
    FFileActionsUI.ExecuteOpen;
end;

procedure TMainForm.FileSaveRequest(Sender: TObject; const FileName: string);
var
  ErrorMessage: string;
begin
  ErrorMessage := '';
  if FMifContainer = nil then
  begin
    lblStatus.Caption := 'MIF save error: no MIF container is loaded';
    Exit;
  end;
  if (FMifWriter = nil) or
    not FMifWriter.TryWriteFile(FMifContainer, FileName, ErrorMessage) then
  begin
    lblStatus.Caption := 'MIF save error: ' + ErrorMessage;
    Exit;
  end;
  FFileActionsUI.CurrentFileName := FileName;
  Caption := 'VectArtDesigner - ' + ExtractFileName(FileName);
  lblStatus.Caption := 'MIF container saved: ' + ExtractFileName(FileName);
end;

procedure TMainForm.FileSaveShortcut(Sender: TObject);
begin
  if FFileActionsUI <> nil then
    FFileActionsUI.ExecuteSave;
end;

procedure TMainForm.DocumentChanged(Sender: TObject);
begin
  if FEditorFrame <> nil then
    FEditorFrame.CanvasControl.Invalidate;
  if FLayerFrame <> nil then
    FLayerFrame.RefreshFromDocument;
  if FObjectPropertiesFrame <> nil then
    FObjectPropertiesFrame.RefreshFromDocument;
end;

procedure TMainForm.EditorStateChanged(Sender: TObject);
begin
  if FEditorFrame <> nil then
    FEditorFrame.CanvasControl.Invalidate;
  if FToolPaletteFrame <> nil then
    FToolPaletteFrame.RefreshState;
  if (FEditorState <> nil) and
    (FEditorState.CurrentTool = vetRectangle) then
    lblStatus.Caption := 'Ready   Tool: Rectangle   Canvas: 1920 x 1080'
  else
    lblStatus.Caption := 'Ready   Tool: Select   Canvas: 1920 x 1080';
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if ssCtrl in Shift then
  begin
    if (Key = Ord('O')) and not (ssShift in Shift) then
      FFileActionsUI.ExecuteOpen
    else if (Key = Ord('S')) and (ssShift in Shift) then
      FFileActionsUI.ExecuteSaveAs
    else if Key = Ord('S') then
      FFileActionsUI.ExecuteSave
    else if (Key = Ord('Z')) and (ssShift in Shift) and
      (FEditHistory <> nil) then
      FEditHistory.Redo
    else if (Key = Ord('Z')) and (FEditHistory <> nil) then
      FEditHistory.Undo
    else if (Key = Ord('Y')) and (FEditHistory <> nil) then
      FEditHistory.Redo
    else
      Exit;
    Key := 0;
    Exit;
  end;
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
  else if Sender = FObjectPropertiesMenuItem then
    FDockManager.SetToolVisible(FObjectPropertiesFrame,
      not FDockManager.ToolVisible(FObjectPropertiesFrame));
  pnlViewMenuPopup.Visible := False;
end;

procedure TMainForm.ToolVisibilityChanged(Sender: TToolPlaceholderFrame);
begin
  UpdateToolMenuItems;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  SaveLayoutSettings;
  FDockManager.Free;
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
  FDesignerContext := nil;
  if FEditorState <> nil then
    FEditorState.OnChanged := nil;
  if FEditHistory <> nil then
    FEditHistory.OnChanged := nil;
  FreeAndNil(FMifContainer);
  FMifReader := nil;
  FMifWriter := nil;
  FreeAndNil(FFileActionsUI);
  FreeAndNil(FEditActionsUI);
  FreeAndNil(FEditHistory);
  FreeAndNil(FEditorState);
  FreeAndNil(FDocument);
  FinalizeSkiaRuntime;
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
  FLayerMenuItem.Caption := CheckedMenuCaption(
    FDockManager.ToolVisible(FLayerFrame), 'Layers');
  FToolPaletteMenuItem.Caption := CheckedMenuCaption(
    FDockManager.ToolVisible(FToolPaletteFrame), 'Tools');
  FObjectPropertiesMenuItem.Caption := CheckedMenuCaption(
    FDockManager.ToolVisible(FObjectPropertiesFrame), 'Object Properties');
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  if FDockManager <> nil then
    FDockManager.Resize;
end;

procedure TMainForm.lblLayoutEditMenuItemClick(Sender: TObject);
begin
  SetLayoutEditing(not FLayoutEditing);
  pnlViewMenuPopup.Visible := False;
end;

procedure TMainForm.lblViewMenuClick(Sender: TObject);
begin
  pnlViewMenuPopup.Visible := not pnlViewMenuPopup.Visible;
  if pnlViewMenuPopup.Visible then
    pnlViewMenuPopup.BringToFront;
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
  if FLayoutEditing then
    pnlLayoutEditMenuItem.Caption := '✓ レイアウト編集'
  else
    pnlLayoutEditMenuItem.Caption := '□ レイアウト編集';
end;

end.
