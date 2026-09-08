// レイヤー一覧の描画方式切替、クリック判定、Document接続を担当する。
unit VectArtDesignerLayerList;

interface

uses
  System.Classes, Vcl.Controls, Vcl.Direct2D, VectArtDesignerDocument,
  VectArtDesignerEditCommands, VectArtDesignerEditHistory,
  VectArtDesignerLayerRenderer, VectArtDesignerObjectContextMenu;

type
  TVectArtLayerListControl = class(TCustomControl)
  private
    FDirect2DEnabled: Boolean;
    FDocument: TVectArtDocument;
    FEditHistory: TVectArtEditHistory;
    FObjectPopup: TVectArtObjectContextMenu;
    FRenderer: TVectArtLayerRenderer;
    FSelectionAnchorIndex: Integer;
    function GetThumbnailBackground: TVectArtLayerThumbnailBackground;
    procedure ApplyGroupBoolean(GroupId: TVectArtGroupId;
      PropertyKind: TVectArtLayerBooleanProperty);
    procedure PaintDirect2D;
    procedure PaintGDI;
    procedure ObjectMenuExecuted(Sender: TObject);
    procedure SetDocument(const Value: TVectArtDocument);
    procedure SetThumbnailBackground(
      const Value: TVectArtLayerThumbnailBackground);
  protected
    function PrepareObjectContextSelection(Index: Integer): Boolean;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function IsGroupExpanded(GroupId: TVectArtGroupId): Boolean;
    function VisibleRowCount: Integer;
    property Document: TVectArtDocument read FDocument write SetDocument;
    property EditHistory: TVectArtEditHistory read FEditHistory
      write FEditHistory;
    property ThumbnailBackground: TVectArtLayerThumbnailBackground
      read GetThumbnailBackground write SetThumbnailBackground;
  end;

implementation

uses
  System.Types, Vcl.Graphics;

const
  COLOR_LIST_BACKGROUND = TColor($001A1A1A);

constructor TVectArtLayerListControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Color := COLOR_LIST_BACKGROUND;
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  TabStop := True;
  FDirect2DEnabled := TDirect2DCanvas.Supported;
  FRenderer := TVectArtLayerRenderer.Create;
  FObjectPopup := TVectArtObjectContextMenu.Create(Self);
  FObjectPopup.OnExecuted := ObjectMenuExecuted;
  FSelectionAnchorIndex := -1;
end;

destructor TVectArtLayerListControl.Destroy;
begin
  FRenderer.Free;
  inherited Destroy;
end;

function TVectArtLayerListControl.GetThumbnailBackground:
  TVectArtLayerThumbnailBackground;
begin
  Result := FRenderer.ThumbnailBackground;
end;

procedure TVectArtLayerListControl.ApplyGroupBoolean(
  GroupId: TVectArtGroupId; PropertyKind: TVectArtLayerBooleanProperty);
var
  AllEnabled: Boolean;
  Command: TVectArtCompoundCommand;
  Index: Integer;
  NewValue: Boolean;
  OldValue: Boolean;
begin
  if (FDocument = nil) or (GroupId = VECTART_NO_GROUP) then
    Exit;
  AllEnabled := True;
  for Index in FDocument.GetGroupLayerIndices(GroupId) do
    if ((PropertyKind = vlbpVisible) and not FDocument[Index].Visible) or
      ((PropertyKind = vlbpLocked) and not FDocument[Index].Locked) then
      AllEnabled := False;
  NewValue := not AllEnabled;
  Command := TVectArtCompoundCommand.Create;
  try
    for Index in FDocument.GetGroupLayerIndices(GroupId) do
    begin
      if PropertyKind = vlbpVisible then
        OldValue := FDocument[Index].Visible
      else
        OldValue := FDocument[Index].Locked;
      if OldValue <> NewValue then
        Command.Add(TVectArtLayerBooleanCommand.Create(FDocument, Index,
          PropertyKind, OldValue, NewValue));
    end;
    if Command.Count = 0 then
      Exit;
    FDocument.BeginUpdate;
    try
      Command.Execute;
    finally
      FDocument.EndUpdate;
    end;
    if FEditHistory <> nil then
    begin
      FEditHistory.AddApplied(Command);
      Command := nil;
    end;
  finally
    Command.Free;
  end;
  Invalidate;
end;

procedure TVectArtLayerListControl.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Entry: TVectArtLayerDisplayEntry;
  Index: Integer;
  ItemRect: TRect;
  Layer: TVectArtLayer;
  NewValue: Boolean;
  ScreenPoint: TPoint;
  SourceIndex: Integer;
begin
  if (Button in [mbLeft, mbRight]) and (FDocument <> nil) then
  begin
    if CanFocus then
      SetFocus;
    Index := FRenderer.LayerIndexAt(ClientRect, Y);
    if Index >= 0 then
    begin
      Entry := FRenderer.EntryAt(Index);
      SourceIndex := Entry.LayerIndex;
      if SourceIndex <= 0 then
        Exit;
      if Button = mbRight then
      begin
        if not PrepareObjectContextSelection(SourceIndex) then
          Exit;
        FObjectPopup.Document := FDocument;
        FObjectPopup.EditHistory := FEditHistory;
        ScreenPoint := ClientToScreen(Point(X, Y));
        FObjectPopup.Popup(ScreenPoint.X, ScreenPoint.Y);
        Exit;
      end;
      ItemRect := FRenderer.LayerItemRect(ClientRect, Index);
      Layer := FDocument[SourceIndex];
      if Entry.IsGroupHeader and
        PtInRect(FRenderer.ExpandButtonRect(ItemRect), Point(X, Y)) then
      begin
        // ダブルクリック時は1回目のMouseDownですでに切り替わるため、
        // ssDouble側では重ねて反転しない。
        if not (ssDouble in Shift) then
          FRenderer.ToggleGroupExpanded(Entry.GroupId);
        FSelectionAnchorIndex := -1;
        Invalidate;
        Exit;
      end;
      if (ssDouble in Shift) and Entry.IsGroupHeader then
      begin
        FRenderer.ToggleGroupExpanded(Entry.GroupId);
        FSelectionAnchorIndex := -1;
        Invalidate;
        Exit;
      end;
      if PtInRect(FRenderer.VisibilityButtonRect(ItemRect), Point(X, Y)) then
      begin
        if Entry.IsGroupHeader then
        begin
          ApplyGroupBoolean(Entry.GroupId, vlbpVisible);
          Exit;
        end;
        NewValue := not Layer.Visible;
        FDocument.SetLayerVisible(SourceIndex, NewValue);
        if FEditHistory <> nil then
          FEditHistory.AddApplied(TVectArtLayerBooleanCommand.Create(
            FDocument, SourceIndex, vlbpVisible, not NewValue, NewValue));
        Exit;
      end;
      if PtInRect(FRenderer.LockButtonRect(ItemRect), Point(X, Y)) then
      begin
        if Entry.IsGroupHeader then
        begin
          ApplyGroupBoolean(Entry.GroupId, vlbpLocked);
          Exit;
        end;
        NewValue := not Layer.Locked;
        FDocument.SetLayerLocked(SourceIndex, NewValue);
        if FEditHistory <> nil then
          FEditHistory.AddApplied(TVectArtLayerBooleanCommand.Create(
            FDocument, SourceIndex, vlbpLocked, not NewValue, NewValue));
        Exit;
      end;
      if ssShift in Shift then
      begin
        if FSelectionAnchorIndex <= 0 then
          if FDocument.SelectedIndex > 0 then
            FSelectionAnchorIndex := FDocument.SelectedIndex
          else
            FSelectionAnchorIndex := SourceIndex;
        FDocument.SelectLayerRange(FSelectionAnchorIndex, SourceIndex,
          ssCtrl in Shift);
      end
      else if ssCtrl in Shift then
      begin
        FDocument.ToggleSelectedLayer(SourceIndex);
        FSelectionAnchorIndex := SourceIndex;
      end
      else
      begin
        FDocument.SelectedIndex := SourceIndex;
        FSelectionAnchorIndex := SourceIndex;
      end;
      Exit;
    end;
  end;
  inherited MouseDown(Button, Shift, X, Y);
end;

function TVectArtLayerListControl.PrepareObjectContextSelection(
  Index: Integer): Boolean;
begin
  Result := (FDocument <> nil) and (Index > 0) and
    (Index < FDocument.LayerCount);
  if not Result then
    Exit;
  // 選択済み行では複数選択を保ち、未選択行だけを右クリック対象へ切り替える。
  if not FDocument.IsLayerSelected(Index) then
    FDocument.SelectedIndex := Index;
  FSelectionAnchorIndex := Index;
end;

procedure TVectArtLayerListControl.ObjectMenuExecuted(Sender: TObject);
begin
  Invalidate;
end;

function TVectArtLayerListControl.IsGroupExpanded(
  GroupId: TVectArtGroupId): Boolean;
begin
  Result := FRenderer.GroupExpanded(GroupId);
end;

function TVectArtLayerListControl.VisibleRowCount: Integer;
begin
  Result := FRenderer.DisplayRowCount;
end;

procedure TVectArtLayerListControl.Paint;
begin
  if FDirect2DEnabled then
    try
      PaintDirect2D;
      Exit;
    except
      FDirect2DEnabled := False;
    end;
  PaintGDI;
end;

procedure TVectArtLayerListControl.PaintDirect2D;
var
  Direct2DCanvas: TDirect2DCanvas;
begin
  Direct2DCanvas := TDirect2DCanvas.Create(Canvas, ClientRect);
  try
    Direct2DCanvas.BeginDraw;
    try
      FRenderer.DrawLayers(Direct2DCanvas, ClientRect);
    finally
      Direct2DCanvas.EndDraw;
    end;
  finally
    Direct2DCanvas.Free;
  end;
end;

procedure TVectArtLayerListControl.PaintGDI;
begin
  FRenderer.DrawLayers(Canvas, ClientRect);
end;

procedure TVectArtLayerListControl.SetDocument(
  const Value: TVectArtDocument);
begin
  if FDocument = Value then
    Exit;
  FDocument := Value;
  FSelectionAnchorIndex := -1;
  FRenderer.Document := Value;
  Invalidate;
end;

procedure TVectArtLayerListControl.SetThumbnailBackground(
  const Value: TVectArtLayerThumbnailBackground);
begin
  if FRenderer.ThumbnailBackground = Value then
    Exit;
  FRenderer.ThumbnailBackground := Value;
  Invalidate;
end;

end.
