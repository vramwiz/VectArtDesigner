// テンプレ図形を分類表示し、共通作成色と図形モードでキャンバス配置ツールへ接続する。
// 色はツールパレット下部のEditorState.Color1／Color2だけを正本とする。
unit VectArtDesignerTemplatePicker;

interface

uses
  System.Classes, System.Types, Vcl.Controls, Vcl.Graphics, Vcl.Grids,
  Vcl.StdCtrls, VectArtDesignerDocument, VectArtDesignerEditorState;

type
  TVectArtTemplatePicker = class(TCustomControl)
  private
    FState: TVectArtEditorState;
    FCategory: TComboBox;
    FMode: TComboBox;
    FGrid: TDrawGrid;
    FItems: TArray<Integer>;
    FNotice: TLabel;
    procedure BuildControls;
    procedure Filter(Sender: TObject);
    procedure DrawCell(Sender: TObject; ACol, ARow: Longint;
      Rect: TRect; State: TGridDrawState);
    procedure Choose(Sender: TObject; ACol, ARow: Longint;
      var CanSelect: Boolean);
    procedure ModeChanged(Sender: TObject);
  protected
    procedure CreateWnd; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Open(State: TVectArtEditorState);
    procedure Refresh;
  end;

implementation

uses
  System.Math, VectArtDesignerTemplateGeometry;

const
  PICKER_MARGIN = 8;
  PICKER_GAP = 8;
  CATEGORY_HEIGHT = 28;
  MODE_HEIGHT = 28;
  NOTICE_HEIGHT = 48;
  MINIMUM_CELL_WIDTH = 128;
  CELL_HEIGHT = 94;

constructor TVectArtTemplatePicker.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Color := TColor($00252525);
  ParentBackground := False;
  Font.Name := 'Segoe UI';
  Font.Height := -13;
  Width := 320;
  Height := 520;
end;

procedure TVectArtTemplatePicker.BuildControls;
begin
  if FCategory <> nil then
    Exit;

  FCategory := TComboBox.Create(Self);
  FCategory.Parent := Self;
  FCategory.Style := csDropDownList;
  FCategory.Items.AddStrings(['すべて', '基本', '矢印', '吹き出し',
    '星・強調', 'フロー', 'UI・資料', '図解', '記号', '装飾']);
  FCategory.ItemIndex := 0;
  FCategory.OnChange := Filter;

  FMode := TComboBox.Create(Self);
  FMode.Parent := Self;
  FMode.Style := csDropDownList;
  FMode.Items.AddStrings(['枠のみ', '塗りのみ', '枠＋塗り']);
  FMode.OnChange := ModeChanged;

  FGrid := TDrawGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.FixedCols := 0;
  FGrid.FixedRows := 0;
  FGrid.DefaultRowHeight := CELL_HEIGHT;
  FGrid.OnDrawCell := DrawCell;
  FGrid.OnSelectCell := Choose;

  FNotice := TLabel.Create(Self);
  FNotice.Parent := Self;
  FNotice.WordWrap := True;
  FNotice.AutoSize := False;
  FNotice.Caption := '図形を選択し、キャンバス上でドラッグして配置します。色はツール下部の2色を使用します。';
  Resize;
  Refresh;
end;

procedure TVectArtTemplatePicker.CreateWnd;
begin
  inherited;
  BuildControls;
end;

procedure TVectArtTemplatePicker.Open(State: TVectArtEditorState);
begin
  FState := State;
  Filter(nil);
  Refresh;
  Show;
end;

procedure TVectArtTemplatePicker.Refresh;
begin
  if (FState = nil) or (FMode = nil) then
    Exit;
  FMode.ItemIndex := Ord(FState.RectangleMode);
  FGrid.Invalidate;
end;

procedure TVectArtTemplatePicker.Resize;
var
  ColumnCount: Integer;
  GridBottom: Integer;
  GridTop: Integer;
begin
  inherited;
  if FCategory = nil then
    Exit;
  FCategory.SetBounds(PICKER_MARGIN, PICKER_MARGIN,
    Max(1, ClientWidth - 2 * PICKER_MARGIN), CATEGORY_HEIGHT);
  FMode.SetBounds(PICKER_MARGIN,
    FCategory.Top + FCategory.Height + PICKER_GAP,
    Max(1, ClientWidth - 2 * PICKER_MARGIN), MODE_HEIGHT);
  GridTop := FMode.Top + FMode.Height + PICKER_GAP;
  FNotice.SetBounds(PICKER_MARGIN,
    Max(GridTop, ClientHeight - PICKER_MARGIN - NOTICE_HEIGHT),
    Max(1, ClientWidth - 2 * PICKER_MARGIN), NOTICE_HEIGHT);
  GridBottom := Max(GridTop + 1, FNotice.Top - PICKER_GAP);
  FGrid.SetBounds(PICKER_MARGIN, GridTop,
    Max(1, ClientWidth - 2 * PICKER_MARGIN), GridBottom - GridTop);
  ColumnCount := Max(1, FGrid.ClientWidth div MINIMUM_CELL_WIDTH);
  FGrid.ColCount := ColumnCount;
  FGrid.DefaultColWidth := Max(1,
    (FGrid.ClientWidth - 2) div ColumnCount);
  Filter(nil);
end;

procedure TVectArtTemplatePicker.Filter(Sender: TObject);
var
  I: Integer;
begin
  if FGrid = nil then
    Exit;
  FItems := nil;
  for I := 0 to VECTART_TEMPLATE_COUNT - 1 do
    if (FCategory.ItemIndex = 0) or
      (VectArtTemplateCategory(I) = FCategory.ItemIndex - 1) then
      FItems := FItems + [I];
  FGrid.RowCount := Max(1,
    (Length(FItems) + FGrid.ColCount - 1) div FGrid.ColCount);
  FGrid.Invalidate;
end;

procedure TVectArtTemplatePicker.DrawCell(Sender: TObject;
  ACol, ARow: Longint; Rect: TRect; State: TGridDrawState);
var
  Bounds: TRectF;
  I: Integer;
  J: Integer;
  Points: TArray<TPointF>;
  ScreenPoints: TArray<TPoint>;
begin
  FGrid.Canvas.Brush.Color := TColor($00333333);
  FGrid.Canvas.FillRect(Rect);
  I := ARow * FGrid.ColCount + ACol;
  if (I >= Length(FItems)) or (FState = nil) then
    Exit;
  Bounds := RectF(Rect.Left + 26, Rect.Top + 8,
    Rect.Right - 26, Rect.Bottom - 30);
  Points := VectArtTemplatePoints(FItems[I], Bounds);
  SetLength(ScreenPoints, Length(Points));
  for J := 0 to High(Points) do
    ScreenPoints[J] := Point(Round(Points[J].X), Round(Points[J].Y));
  FGrid.Canvas.Brush.Color := FState.Color2;
  if not VectArtRectangleModeHasFill(FState.RectangleMode) then
    FGrid.Canvas.Brush.Style := bsClear;
  FGrid.Canvas.Pen.Color := FState.Color1;
  FGrid.Canvas.Pen.Width := EnsureRange(
    Round(FState.RectangleStrokeWidth), 1, 5);
  if not VectArtRectangleModeHasStroke(FState.RectangleMode) then
    FGrid.Canvas.Pen.Style := psClear;
  FGrid.Canvas.Polygon(ScreenPoints);
  FGrid.Canvas.Pen.Style := psSolid;
  FGrid.Canvas.Pen.Width := 1;
  FGrid.Canvas.Brush.Style := bsClear;
  FGrid.Canvas.Font.Color := clWhite;
  FGrid.Canvas.TextOut(Rect.Left + 8, Rect.Bottom - 24,
    VectArtTemplateName(FItems[I]));
  if (FState.CurrentTool = vetTemplate) and
    (FState.TemplateIndex = FItems[I]) then
  begin
    FGrid.Canvas.Pen.Color := clHighlight;
    FGrid.Canvas.Rectangle(Rect);
  end;
  FGrid.Canvas.Brush.Style := bsSolid;
end;

procedure TVectArtTemplatePicker.Choose(Sender: TObject;
  ACol, ARow: Longint; var CanSelect: Boolean);
var
  I: Integer;
begin
  I := ARow * FGrid.ColCount + ACol;
  if (I >= Length(FItems)) or (FState = nil) then
    Exit;
  FState.TemplateIndex := FItems[I];
  FState.CurrentTool := vetTemplate;
  FNotice.Caption := VectArtTemplateName(FItems[I]) +
    '：キャンバスをドラッグして配置。Shiftで縦横比1:1、Altで中心基準。';
  FGrid.Invalidate;
end;

procedure TVectArtTemplatePicker.ModeChanged(Sender: TObject);
begin
  if (FState <> nil) and (FMode.ItemIndex >= 0) then
  begin
    FState.RectangleMode := TVectArtRectangleMode(FMode.ItemIndex);
    Refresh;
  end;
end;

end.
