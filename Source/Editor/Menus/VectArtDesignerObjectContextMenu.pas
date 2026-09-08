// Shared object context menu used by the canvas and layer list.
// 選択と履歴は保持せず、呼出元が渡す現在Contextへ同じ操作定義を適用する。
unit VectArtDesignerObjectContextMenu;

interface

uses
  System.Classes, Vcl.Menus, VectArtDesignerDocument,
  VectArtDesignerEditHistory;

type
  TVectArtObjectContextMenu = class(TPopupMenu)
  private
    FDocument: TVectArtDocument;
    FEditHistory: TVectArtEditHistory;
    FFlipHorizontalItem: TMenuItem;
    FFlipVerticalItem: TMenuItem;
    FGroupItem: TMenuItem;
    FGroupMenu: TMenuItem;
    FHideItem: TMenuItem;
    FOnExecuted: TNotifyEvent;
    FRotate180Item: TMenuItem;
    FRotateLeftItem: TMenuItem;
    FRotateRightItem: TMenuItem;
    FUngroupItem: TMenuItem;
    procedure FlipHorizontalClick(Sender: TObject);
    procedure FlipVerticalClick(Sender: TObject);
    procedure GroupClick(Sender: TObject);
    procedure HideClick(Sender: TObject);
    procedure MenuPopup(Sender: TObject);
    procedure RotateClick(Sender: TObject);
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
  VectArtDesignerLayerFlipOperations,
  VectArtDesignerLayerGroupOperations,
  VectArtDesignerLayerRotationOperations,
  VectArtDesignerLayerVisibilityOperations;

constructor TVectArtObjectContextMenu.Create(AOwner: TComponent);
var
  FlipMenu: TMenuItem;
  RotationMenu: TMenuItem;
begin
  inherited Create(AOwner);
  OnPopup := MenuPopup;

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
  Enabled: Boolean;
begin
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

procedure TVectArtObjectContextMenu.UngroupClick(Sender: TObject);
begin
  UngroupVectArtSelection(FDocument, FEditHistory);
  NotifyExecuted;
end;

end.
