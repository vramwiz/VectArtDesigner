// キャンバスとレイヤー一覧で共有するオブジェクト操作メニューを構築する。
// 選択と履歴は所有せず、呼出元が渡す現在Contextへ編集・画像出力を適用する。
unit VectArtDesignerObjectContextMenu;

interface

uses
  System.Classes, Vcl.Dialogs, Vcl.Menus, VectArtDesignerDocument,
  VectArtDesignerEditHistory;

type
  TVectArtObjectContextMenu = class(TPopupMenu)
  private
    FAlignItems: array[0..6] of TMenuItem;
    FAlignMenu: TMenuItem;
    FAttributePasteItems: array[0..5] of TMenuItem;
    FAttributePasteMenu: TMenuItem;
    FCopyItem: TMenuItem;
    FCutItem: TMenuItem;
    FDeleteItem: TMenuItem;
    FDocument: TVectArtDocument;
    FDuplicateItem: TMenuItem;
    FEditHistory: TVectArtEditHistory;
    FFlipHorizontalItem: TMenuItem;
    FFlipVerticalItem: TMenuItem;
    FGroupItem: TMenuItem;
    FGroupMenu: TMenuItem;
    FHideItem: TMenuItem;
    FMoveBackwardItem: TMenuItem;
    FMoveForwardItem: TMenuItem;
    FMoveToBackItem: TMenuItem;
    FMoveToFrontItem: TMenuItem;
    FOnExecuted: TNotifyEvent;
    FOutputDialog: TSaveDialog;
    FOutputMenu: TMenuItem;
    FPasteItem: TMenuItem;
    FRotate180Item: TMenuItem;
    FRotateLeftItem: TMenuItem;
    FRotateRightItem: TMenuItem;
    FUngroupItem: TMenuItem;
    procedure AlignClick(Sender: TObject);
    procedure AttributePasteClick(Sender: TObject);
    procedure CopyClick(Sender: TObject);
    procedure CutClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure DuplicateClick(Sender: TObject);
    procedure FlipHorizontalClick(Sender: TObject);
    procedure FlipVerticalClick(Sender: TObject);
    procedure GroupClick(Sender: TObject);
    procedure HideClick(Sender: TObject);
    procedure MenuPopup(Sender: TObject);
    procedure OutputClipboardClick(Sender: TObject);
    procedure OutputFileClick(Sender: TObject);
    procedure OutputTypeChange(Sender: TObject);
    procedure PasteClick(Sender: TObject);
    procedure RotateClick(Sender: TObject);
    procedure StackClick(Sender: TObject);
    procedure UngroupClick(Sender: TObject);
    procedure NotifyExecuted;
  public
    constructor Create(AOwner: TComponent); override;
    procedure RefreshState;
    property Document: TVectArtDocument read FDocument write FDocument;
    property EditHistory: TVectArtEditHistory read FEditHistory
      write FEditHistory;
    property OnExecuted: TNotifyEvent read FOnExecuted write FOnExecuted;
  end;

implementation

uses
  System.SysUtils, System.UITypes, Winapi.Windows,
  VectArtDesignerClipboardOperations,
  VectArtDesignerAttributePasteOperations,
  VectArtDesignerLayerAlignmentOperations,
  VectArtDesignerLayerFlipOperations,
  VectArtDesignerLayerGroupOperations,
  VectArtDesignerLayerOperations,
  VectArtDesignerLayerRotationOperations,
  VectArtDesignerLayerVisibilityOperations,
  VectArtDesignerPngOutput;

constructor TVectArtObjectContextMenu.Create(AOwner: TComponent);
const
  ALIGNMENT_CAPTIONS: array[0..6] of string = ('左揃え(&L)',
    '左右中央揃え(&H)', '右揃え(&R)', '上揃え(&T)',
    '上下中央揃え(&V)', '下揃え(&B)', '中央揃え(&C)');
  ATTRIBUTE_PASTE_CAPTIONS: array[0..5] of string = ('色(&C)',
    'サイズ(&S)', '文字(&T)', 'フォント名(&F)', '縁取り(&O)', '効果(&E)');
var
  AttributeIndex: Integer;
  FlipMenu: TMenuItem;
  I: Integer;
  OutputItem: TMenuItem;
  RotationMenu: TMenuItem;
  StackMenu: TMenuItem;
begin
  inherited Create(AOwner);
  OnPopup := MenuPopup;

  FCutItem := TMenuItem.Create(Self);
  FCutItem.Caption := '切り取り(&T)';
  FCutItem.ShortCut := ShortCut(Ord('X'), [ssCtrl]);
  FCutItem.OnClick := CutClick;
  Items.Add(FCutItem);
  FCopyItem := TMenuItem.Create(Self);
  FCopyItem.Caption := 'コピー(&C)';
  FCopyItem.ShortCut := ShortCut(Ord('C'), [ssCtrl]);
  FCopyItem.OnClick := CopyClick;
  Items.Add(FCopyItem);
  FPasteItem := TMenuItem.Create(Self);
  FPasteItem.Caption := '貼り付け(&P)';
  FPasteItem.ShortCut := ShortCut(Ord('V'), [ssCtrl]);
  FPasteItem.OnClick := PasteClick;
  Items.Add(FPasteItem);
  FAttributePasteMenu := TMenuItem.Create(Self);
  FAttributePasteMenu.Caption := 'オブジェクト属性の貼り付け(&B)';
  Items.Add(FAttributePasteMenu);
  for AttributeIndex := Low(FAttributePasteItems) to
    High(FAttributePasteItems) do
  begin
    if AttributeIndex = 2 then
      FAttributePasteMenu.Add(NewLine);
    FAttributePasteItems[AttributeIndex] := TMenuItem.Create(Self);
    FAttributePasteItems[AttributeIndex].Caption :=
      ATTRIBUTE_PASTE_CAPTIONS[AttributeIndex];
    FAttributePasteItems[AttributeIndex].Tag := AttributeIndex;
    if AttributeIndex <= Ord(High(TVectArtAttributePasteKind)) then
      FAttributePasteItems[AttributeIndex].OnClick := AttributePasteClick;
    FAttributePasteItems[AttributeIndex].Enabled := False;
    FAttributePasteMenu.Add(FAttributePasteItems[AttributeIndex]);
  end;
  FDeleteItem := TMenuItem.Create(Self);
  FDeleteItem.Caption := '削除(&D)';
  FDeleteItem.ShortCut := ShortCut(VK_DELETE, []);
  FDeleteItem.OnClick := DeleteClick;
  Items.Add(FDeleteItem);
  FDuplicateItem := TMenuItem.Create(Self);
  FDuplicateItem.Caption := '複製(&L)';
  FDuplicateItem.ShortCut := ShortCut(Ord('D'), [ssCtrl]);
  FDuplicateItem.OnClick := DuplicateClick;
  Items.Add(FDuplicateItem);

  FOutputMenu := TMenuItem.Create(Self);
  FOutputMenu.Caption := '出力(&E)';
  OutputItem := TMenuItem.Create(Self);
  OutputItem.Caption := 'ファイル...(&F)';
  OutputItem.OnClick := OutputFileClick;
  FOutputMenu.Add(OutputItem);
  OutputItem := TMenuItem.Create(Self);
  OutputItem.Caption := 'クリップボード(&C)';
  OutputItem.OnClick := OutputClipboardClick;
  FOutputMenu.Add(OutputItem);

  FOutputDialog := TSaveDialog.Create(Self);
  FOutputDialog.DefaultExt := 'png';
  FOutputDialog.Filter := 'PNG画像 (*.png)|*.png|' +
    'GIF画像 (*.gif)|*.gif|JPEG画像 (*.jpg;*.jpeg)|*.jpg;*.jpeg';
  FOutputDialog.Options := FOutputDialog.Options +
    [ofOverwritePrompt, ofPathMustExist];
  FOutputDialog.Title := '選択オブジェクトを画像として出力';
  FOutputDialog.OnTypeChange := OutputTypeChange;
  Items.Add(NewLine);

  FHideItem := TMenuItem.Create(Self);
  FHideItem.Caption := '非表示(&H)';
  FHideItem.OnClick := HideClick;
  Items.Add(FHideItem);

  FGroupMenu := TMenuItem.Create(Self);
  FGroupMenu.Caption := 'グループ(&G)';
  Items.Add(FGroupMenu);
  FGroupItem := TMenuItem.Create(Self);
  FGroupItem.Caption := 'グループ化(&G)';
  FGroupItem.ShortCut := ShortCut(Ord('G'), [ssCtrl]);
  FGroupItem.OnClick := GroupClick;
  FGroupMenu.Add(FGroupItem);
  FUngroupItem := TMenuItem.Create(Self);
  FUngroupItem.Caption := 'グループ解除(&U)';
  FUngroupItem.ShortCut := ShortCut(Ord('G'), [ssCtrl, ssShift]);
  FUngroupItem.OnClick := UngroupClick;
  FGroupMenu.Add(FUngroupItem);

  StackMenu := TMenuItem.Create(Self);
  StackMenu.Caption := '重なり(&A)';
  Items.Add(StackMenu);
  FMoveToFrontItem := TMenuItem.Create(Self);
  FMoveToFrontItem.Caption := '最前面に移動(&T)';
  FMoveToFrontItem.Tag := Ord(vlaMoveToFront);
  FMoveToFrontItem.OnClick := StackClick;
  StackMenu.Add(FMoveToFrontItem);
  FMoveToBackItem := TMenuItem.Create(Self);
  FMoveToBackItem.Caption := '最背面に移動(&B)';
  FMoveToBackItem.Tag := Ord(vlaMoveToBack);
  FMoveToBackItem.OnClick := StackClick;
  StackMenu.Add(FMoveToBackItem);
  FMoveForwardItem := TMenuItem.Create(Self);
  FMoveForwardItem.Caption := '前面に移動(&U)';
  FMoveForwardItem.Tag := Ord(vlaMoveForward);
  FMoveForwardItem.OnClick := StackClick;
  StackMenu.Add(FMoveForwardItem);
  FMoveBackwardItem := TMenuItem.Create(Self);
  FMoveBackwardItem.Caption := '背面に移動(&D)';
  FMoveBackwardItem.Tag := Ord(vlaMoveBackward);
  FMoveBackwardItem.OnClick := StackClick;
  StackMenu.Add(FMoveBackwardItem);

  FlipMenu := TMenuItem.Create(Self);
  FlipMenu.Caption := '反転(&F)';
  Items.Add(FlipMenu);
  FFlipVerticalItem := TMenuItem.Create(Self);
  FFlipVerticalItem.Caption := '上下反転(&V)';
  FFlipVerticalItem.OnClick := FlipVerticalClick;
  FlipMenu.Add(FFlipVerticalItem);
  FFlipHorizontalItem := TMenuItem.Create(Self);
  FFlipHorizontalItem.Caption := '左右反転(&H)';
  FFlipHorizontalItem.OnClick := FlipHorizontalClick;
  FlipMenu.Add(FFlipHorizontalItem);

  RotationMenu := TMenuItem.Create(Self);
  RotationMenu.Caption := '回転(&R)';
  Items.Add(RotationMenu);
  FRotateLeftItem := TMenuItem.Create(Self);
  FRotateLeftItem.Caption := '左へ90度(&L)';
  FRotateLeftItem.Tag := -90;
  FRotateLeftItem.OnClick := RotateClick;
  RotationMenu.Add(FRotateLeftItem);
  FRotateRightItem := TMenuItem.Create(Self);
  FRotateRightItem.Caption := '右へ90度(&R)';
  FRotateRightItem.Tag := 90;
  FRotateRightItem.OnClick := RotateClick;
  RotationMenu.Add(FRotateRightItem);
  FRotate180Item := TMenuItem.Create(Self);
  FRotate180Item.Caption := '180度(&I)';
  FRotate180Item.Tag := 180;
  FRotate180Item.OnClick := RotateClick;
  RotationMenu.Add(FRotate180Item);

  FAlignMenu := TMenuItem.Create(Self);
  FAlignMenu.Caption := '整列(&I)';
  Items.Add(FAlignMenu);
  for I := Low(FAlignItems) to High(FAlignItems) do
  begin
    FAlignItems[I] := TMenuItem.Create(Self);
    FAlignItems[I].Caption := ALIGNMENT_CAPTIONS[I];
    FAlignItems[I].Tag := I;
    FAlignItems[I].OnClick := AlignClick;
    FAlignMenu.Add(FAlignItems[I]);
  end;
  Items.Add(NewLine);
  Items.Add(FOutputMenu);
end;

procedure TVectArtObjectContextMenu.AttributePasteClick(Sender: TObject);
begin
  if (Sender is TMenuItem) and PasteVectArtAttribute(FDocument,
    FEditHistory, TVectArtAttributePasteKind(TMenuItem(Sender).Tag)) then
    NotifyExecuted;
end;

procedure TVectArtObjectContextMenu.AlignClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    AlignVectArtSelection(FDocument, FEditHistory,
      TVectArtAlignment(TMenuItem(Sender).Tag));
  NotifyExecuted;
end;

procedure TVectArtObjectContextMenu.CopyClick(Sender: TObject);
begin
  CopyVectArtSelectionToClipboard(FDocument);
end;

procedure TVectArtObjectContextMenu.CutClick(Sender: TObject);
begin
  CutVectArtSelectionToClipboard(FDocument, FEditHistory);
  NotifyExecuted;
end;

procedure TVectArtObjectContextMenu.DeleteClick(Sender: TObject);
begin
  DeleteVectArtSelection(FDocument, FEditHistory);
  NotifyExecuted;
end;

procedure TVectArtObjectContextMenu.DuplicateClick(Sender: TObject);
var
  Operations: TVectArtLayerOperations;
begin
  Operations := TVectArtLayerOperations.Create;
  try
    Operations.Document := FDocument;
    Operations.EditHistory := FEditHistory;
    Operations.Execute(vlaDuplicate);
  finally
    Operations.Free;
  end;
  NotifyExecuted;
end;

procedure TVectArtObjectContextMenu.FlipHorizontalClick(Sender: TObject);
begin
  FlipVectArtSelection(FDocument, FEditHistory, vfdHorizontal);
  NotifyExecuted;
end;

procedure TVectArtObjectContextMenu.FlipVerticalClick(Sender: TObject);
begin
  FlipVectArtSelection(FDocument, FEditHistory, vfdVertical);
  NotifyExecuted;
end;

procedure TVectArtObjectContextMenu.HideClick(Sender: TObject);
begin
  ToggleVectArtSelectionHidden(FDocument, FEditHistory);
  NotifyExecuted;
end;

procedure TVectArtObjectContextMenu.GroupClick(Sender: TObject);
begin
  GroupVectArtSelection(FDocument, FEditHistory);
  NotifyExecuted;
end;

procedure TVectArtObjectContextMenu.MenuPopup(Sender: TObject);
begin
  RefreshState;
end;

procedure TVectArtObjectContextMenu.RefreshState;
var
  AttributePastes: TVectArtAttributePasteKinds;
  Enabled: Boolean;
  I: Integer;
  Operations: TVectArtLayerOperations;
begin
  FCopyItem.Enabled := CanCopyVectArtSelection(FDocument);
  FCutItem.Enabled := CanCutVectArtSelection(FDocument);
  FDeleteItem.Enabled := FCutItem.Enabled;
  FPasteItem.Enabled := CanPasteVectArtClipboard;
  AttributePastes := AvailableVectArtAttributePastes(FDocument);
  for I := 0 to Ord(High(TVectArtAttributePasteKind)) do
    FAttributePasteItems[I].Enabled :=
      TVectArtAttributePasteKind(I) in AttributePastes;
  for I := Ord(High(TVectArtAttributePasteKind)) + 1 to
    High(FAttributePasteItems) do
    FAttributePasteItems[I].Enabled := False;
  FAttributePasteMenu.Enabled := AttributePastes <> [];
  FHideItem.Enabled := (FDocument <> nil) and
    (FDocument.SelectionCount > 0);
  FHideItem.Checked := IsVectArtSelectionHidden(FDocument);
  FGroupItem.Enabled := CanGroupVectArtSelection(FDocument);
  FUngroupItem.Enabled := CanUngroupVectArtSelection(FDocument);
  FGroupMenu.Enabled := FGroupItem.Enabled or FUngroupItem.Enabled;
  Enabled := CanFlipVectArtSelection(FDocument);
  FFlipHorizontalItem.Enabled := Enabled;
  FFlipVerticalItem.Enabled := Enabled;
  Enabled := CanRotateVectArtSelection(FDocument);
  FRotateLeftItem.Enabled := Enabled;
  FRotateRightItem.Enabled := Enabled;
  FRotate180Item.Enabled := Enabled;
  Enabled := CanAlignVectArtSelection(FDocument);
  FAlignMenu.Enabled := Enabled;
  for I := Low(FAlignItems) to High(FAlignItems) do
    FAlignItems[I].Enabled := Enabled;
  Operations := TVectArtLayerOperations.Create;
  try
    Operations.Document := FDocument;
    Operations.EditHistory := FEditHistory;
    FDuplicateItem.Enabled := Operations.CanExecute(vlaDuplicate);
    FMoveToFrontItem.Enabled := Operations.CanExecute(vlaMoveToFront);
    FMoveToBackItem.Enabled := Operations.CanExecute(vlaMoveToBack);
    FMoveForwardItem.Enabled := Operations.CanExecute(vlaMoveForward);
    FMoveBackwardItem.Enabled := Operations.CanExecute(vlaMoveBackward);
  finally
    Operations.Free;
  end;
  FOutputMenu.Enabled := CanOutputVectArtPng(FDocument,
    vposSelectedObjects);
end;

procedure TVectArtObjectContextMenu.OutputClipboardClick(Sender: TObject);
var
  ErrorMessage: string;
begin
  if not TryCopyVectArtPngToClipboard(FDocument, vposSelectedObjects,
    ErrorMessage) then
    MessageDlg(ErrorMessage, mtError, [mbOK], 0);
end;

procedure TVectArtObjectContextMenu.OutputFileClick(Sender: TObject);
var
  ErrorMessage: string;
begin
  FOutputDialog.FilterIndex := 1;
  FOutputDialog.FileName := '';
  OutputTypeChange(FOutputDialog);
  if FOutputDialog.Execute and
    not TrySaveVectArtImage(FDocument, vposSelectedObjects,
      FOutputDialog.FileName, ErrorMessage) then
    MessageDlg(ErrorMessage, mtError, [mbOK], 0);
end;

procedure TVectArtObjectContextMenu.OutputTypeChange(Sender: TObject);
var
  Extension: string;
begin
  case FOutputDialog.FilterIndex of
    2: Extension := '.gif';
    3: Extension := '.jpg';
  else
    Extension := '.png';
  end;
  FOutputDialog.DefaultExt := Copy(Extension, 2, MaxInt);
  if FOutputDialog.FileName <> '' then
    FOutputDialog.FileName := ChangeFileExt(FOutputDialog.FileName,
      Extension);
end;

procedure TVectArtObjectContextMenu.PasteClick(Sender: TObject);
begin
  PasteVectArtClipboard(FDocument, FEditHistory);
  NotifyExecuted;
end;

procedure TVectArtObjectContextMenu.NotifyExecuted;
begin
  if Assigned(FOnExecuted) then
    FOnExecuted(Self);
end;

procedure TVectArtObjectContextMenu.RotateClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    RotateVectArtSelection(FDocument, FEditHistory,
      TMenuItem(Sender).Tag);
  NotifyExecuted;
end;

procedure TVectArtObjectContextMenu.StackClick(Sender: TObject);
var
  Operations: TVectArtLayerOperations;
begin
  if not (Sender is TMenuItem) then
    Exit;
  Operations := TVectArtLayerOperations.Create;
  try
    Operations.Document := FDocument;
    Operations.EditHistory := FEditHistory;
    Operations.Execute(TVectArtLayerAction(TMenuItem(Sender).Tag));
  finally
    Operations.Free;
  end;
  NotifyExecuted;
end;

procedure TVectArtObjectContextMenu.UngroupClick(Sender: TObject);
begin
  UngroupVectArtSelection(FDocument, FEditHistory);
  NotifyExecuted;
end;

end.
