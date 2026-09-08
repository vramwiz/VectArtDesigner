// 実パスを現在の色・枠設定で一覧表示し、キャンバスのドラッグ配置ツールへ接続する。
unit VectArtDesignerTemplatePicker;

interface

uses System.Classes, System.Types, Vcl.Graphics, Vcl.Forms, Vcl.StdCtrls, Vcl.Grids, Vcl.Controls,
  VectArtDesignerDocument, VectArtDesignerEditorState, VectArtDesignerColorSwatch, VectArtDesignerPaintPopup;

type
  TVectArtTemplatePicker = class(TForm)
  private
    FState: TVectArtEditorState;
    FCategory: TComboBox;
    FMode: TComboBox;
    FGrid: TDrawGrid;
    FFill, FStroke: TVectArtColorSwatch;
    FItems: TArray<Integer>;
    FNotice: TLabel;
    FStrokeEditing: Boolean;
    procedure Filter(Sender: TObject);
    procedure DrawCell(Sender: TObject; ACol, ARow: Longint; Rect: TRect; State: TGridDrawState);
    procedure Choose(Sender: TObject; ACol, ARow: Longint; var CanSelect: Boolean);
    procedure ModeChanged(Sender: TObject);
    procedure OpenColor(Sender: TObject);
    procedure ColorChanged(Sender: TObject; Color: TColor);
    procedure FillChanged(Sender: TObject; Color: TColor; const Fill: TVectArtFillStyle);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Open(State: TVectArtEditorState);
    procedure Refresh;
  end;

implementation

uses System.Math, System.Skia, VectArtDesignerFillPaint, VectArtDesignerTemplateGeometry;

constructor TVectArtTemplatePicker.Create(AOwner: TComponent);
var L: TLabel;
begin
  inherited CreateNew(AOwner);
  Caption := 'テンプレ図形';
  Position := poScreenCenter;
  BorderStyle := bsToolWindow;
  ClientWidth := 468;
  ClientHeight := 570;
  Font.Name := 'Yu Gothic UI'; Font.Size := 9;
  FCategory := TComboBox.Create(Self);
  FCategory.Parent := Self;
  FCategory.Style := csDropDownList;
  FCategory.Items.AddStrings(['すべて', '基本', '矢印', '吹き出し', '星・強調', 'フロー', 'UI・資料', '図解', '記号', '装飾']);
  FCategory.ItemIndex := 0;
  FCategory.SetBounds(12,12,444,28);
  FCategory.OnChange := Filter;
  FGrid := TDrawGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.FixedCols := 0; FGrid.FixedRows := 0;
  FGrid.ColCount := 3; FGrid.DefaultColWidth := 137; FGrid.DefaultRowHeight := 94;
  FGrid.SetBounds(12,50,444,324);
  FGrid.OnDrawCell := DrawCell;
  FGrid.OnSelectCell := Choose;
  L := TLabel.Create(Self); L.Parent := Self; L.Caption := '枠色'; L.SetBounds(12,386,200,20);
  L := TLabel.Create(Self); L.Parent := Self; L.Caption := '塗り色'; L.SetBounds(240,386,200,20);
  FStroke := TVectArtColorSwatch.Create(Self); FStroke.Parent := Self;
  FStroke.SetBounds(12,410,216,36); FStroke.OnClick := OpenColor;
  FFill := TVectArtColorSwatch.Create(Self); FFill.Parent := Self;
  FFill.SetBounds(240,410,216,36); FFill.OnClick := OpenColor;
  FMode := TComboBox.Create(Self); FMode.Parent := Self; FMode.Style := csDropDownList;
  FMode.Items.AddStrings(['枠のみ', '塗りのみ', '枠＋塗り']);
  FMode.SetBounds(12,460,444,28); FMode.OnChange := ModeChanged;
  FNotice := TLabel.Create(Self); FNotice.Parent := Self;
  FNotice.WordWrap := True; FNotice.AutoSize := False;
  FNotice.SetBounds(12,502,444,56);
  FNotice.Caption := '図形を選択し、キャンバス上でドラッグして配置します。配置後は通常の閉じたPathとして編集できます。';
end;

procedure TVectArtTemplatePicker.Open(State: TVectArtEditorState);
begin FState := State; Filter(nil); Refresh; Show; end;

procedure TVectArtTemplatePicker.Refresh;
begin
  if FState = nil then Exit;
  FFill.Value := FState.RectangleFillColor;
  FFill.FillStyle := FState.RectangleFillStyle;
  FStroke.Value := FState.RectangleStrokeColor;
  FMode.ItemIndex := Ord(FState.RectangleMode);
  FGrid.Invalidate;
end;

procedure TVectArtTemplatePicker.Filter(Sender: TObject);
var I: Integer;
begin
  FItems := nil;
  for I := 0 to VECTART_TEMPLATE_COUNT - 1 do
    if (FCategory.ItemIndex = 0) or (VectArtTemplateCategory(I) = FCategory.ItemIndex - 1) then
      FItems := FItems + [I];
  FGrid.RowCount := Max(1,(Length(FItems)+2) div 3);
  FGrid.Invalidate;
end;

procedure TVectArtTemplatePicker.DrawCell(Sender: TObject; ACol, ARow: Longint;
  Rect: TRect; State: TGridDrawState);
var I,J: Integer; P: TArray<TPointF>; ScreenPoints: TArray<TPoint>; Bounds: TRectF;
  Bitmap: TBitmap; Surface: ISkSurface; Paint: ISkPaint; Builder: ISkPathBuilder; Path: ISkPath;
begin
  FGrid.Canvas.Brush.Color := TColor($00333333); FGrid.Canvas.FillRect(Rect);
  I := ARow*3+ACol;
  if (I >= Length(FItems)) or (FState = nil) then Exit;
  Bounds := RectF(Rect.Left+26,Rect.Top+8,Rect.Right-26,Rect.Bottom-30);
  P := VectArtTemplatePoints(FItems[I],Bounds); SetLength(ScreenPoints,Length(P));
  for J := 0 to High(P) do ScreenPoints[J] := Point(Round(P[J].X),Round(P[J].Y));
  FGrid.Canvas.Brush.Color := FState.RectangleFillColor;
  if not VectArtRectangleModeHasFill(FState.RectangleMode) then FGrid.Canvas.Brush.Style := bsClear;
  FGrid.Canvas.Pen.Color := FState.RectangleStrokeColor;
  FGrid.Canvas.Pen.Width := EnsureRange(Round(FState.RectangleStrokeWidth),1,5);
  if not VectArtRectangleModeHasStroke(FState.RectangleMode) then FGrid.Canvas.Pen.Style := psClear;
  if VectArtRectangleModeHasFill(FState.RectangleMode) and
    (FState.RectangleFillStyle.Kind <> vfkSolid) then
  begin
    Bitmap := TBitmap.Create;
    try
      Bitmap.PixelFormat := pf32bit; Bitmap.SetSize(Rect.Width,Rect.Height);
      Surface := TSkSurface.MakeRasterDirect(
        TSkImageInfo.Create(Bitmap.Width,Bitmap.Height,TSkColorType.BGRA8888,TSkAlphaType.Premul),
        Bitmap.ScanLine[Bitmap.Height-1],Bitmap.Width*4);
      Surface.Canvas.Clear($FF333333);
      Surface.Canvas.Translate(0,Bitmap.Height); Surface.Canvas.Scale(1,-1);
      Surface.Canvas.Translate(-Rect.Left,-Rect.Top);
      Builder := TSkPathBuilder.Create; Builder.MoveTo(P[0]);
      for J := 1 to High(P) do Builder.LineTo(P[J]);
      Builder.Close; Path := Builder.Detach;
      Paint := TSkPaint.Create; Paint.AntiAlias := True;
      SetFillPaint(Paint,FState.RectangleFillColor,FState.RectangleFillStyle,Bounds,1);
      Surface.Canvas.DrawPath(Path,Paint); Surface := nil;
      FGrid.Canvas.Draw(Rect.Left,Rect.Top,Bitmap);
    finally Bitmap.Free; end;
    FGrid.Canvas.Brush.Style := bsClear;
  end;
  FGrid.Canvas.Polygon(ScreenPoints);
  FGrid.Canvas.Pen.Style := psSolid; FGrid.Canvas.Pen.Width := 1;
  FGrid.Canvas.Brush.Style := bsClear; FGrid.Canvas.Font.Color := clWhite;
  FGrid.Canvas.TextOut(Rect.Left+8,Rect.Bottom-24,VectArtTemplateName(FItems[I]));
  if (FState.CurrentTool = vetTemplate) and (FState.TemplateIndex = FItems[I]) then
  begin FGrid.Canvas.Pen.Color := clHighlight; FGrid.Canvas.Rectangle(Rect); end;
  FGrid.Canvas.Brush.Style := bsSolid;
end;

procedure TVectArtTemplatePicker.Choose(Sender: TObject; ACol, ARow: Longint; var CanSelect: Boolean);
var I: Integer;
begin
  I := ARow*3+ACol;
  if (I >= Length(FItems)) or (FState = nil) then Exit;
  FState.TemplateIndex := FItems[I]; FState.CurrentTool := vetTemplate;
  FNotice.Caption := VectArtTemplateName(FItems[I]) + '：キャンバスをドラッグして配置。Shiftで縦横比1:1、Altで中心基準。';
  FGrid.Invalidate;
end;

procedure TVectArtTemplatePicker.ModeChanged(Sender: TObject);
begin if FState <> nil then begin FState.RectangleMode := TVectArtRectangleMode(FMode.ItemIndex); Refresh; end; end;

procedure TVectArtTemplatePicker.OpenColor(Sender: TObject);
begin
  FStrokeEditing := Sender = FStroke;
  if FState = nil then Exit;
  if FStrokeEditing then
    ShowVectArtColorPopup(Self,'テンプレ図形の線色',FStroke.Value,nil,ColorChanged)
  else ShowVectArtFillPopup(Self,FFill.Value,FState.RectangleFillStyle,nil,FillChanged);
end;

procedure TVectArtTemplatePicker.FillChanged(Sender: TObject; Color: TColor;
  const Fill: TVectArtFillStyle);
begin
  if FState = nil then Exit;
  FState.SetRectangleFill(Color,Fill);
  if FState.RectangleMode = vrmOutline then FState.RectangleMode := vrmFillAndOutline;
  Refresh;
end;
procedure TVectArtTemplatePicker.ColorChanged(Sender: TObject; Color: TColor);
begin
  if FState = nil then Exit;
  if FStrokeEditing then FState.RectangleStrokeColor := Color else FState.RectangleFillColor := Color;
  Refresh;
end;

end.
