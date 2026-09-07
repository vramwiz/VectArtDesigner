// 選択・図形作成ツールをコード描画アイコンで選択するControlを提供する。
// 類似ツールは1ボタンへまとめ、選択中の再クリックでペア内を切り替える。
unit VectArtDesignerToolPalette;

interface

uses
  System.Classes, System.Types, Vcl.Controls, VectArtDesignerEditorState;

type
  TVectArtToolPaletteControl = class(TCustomControl)
  private
    FEditorState: TVectArtEditorState;
    procedure ActivateButton(Index: Integer);
    function ButtonRect(Index: Integer): TRect;
    function ButtonSelected(Index: Integer): Boolean;
    procedure DrawButton(Index: Integer);
    procedure SetEditorState(const Value: TVectArtEditorState);
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure RefreshState;
    property EditorState: TVectArtEditorState read FEditorState
      write SetEditorState;
  end;

implementation

uses
  Vcl.Graphics;

const
  BUTTON_SIZE = 46;
  BUTTON_COUNT = 5;
  COLOR_BACKGROUND = TColor($00252525);
  COLOR_BUTTON = TColor($002D2D2D);
  COLOR_SELECTED = TColor($0046382B);
  COLOR_ICON = TColor($00E0E0E0);

function TVectArtToolPaletteControl.ButtonRect(Index: Integer): TRect;
begin
  Result := Rect(6, 6 + Index * (BUTTON_SIZE + 6),
    ClientWidth - 6, 6 + Index * (BUTTON_SIZE + 6) + BUTTON_SIZE);
end;

procedure TVectArtToolPaletteControl.ActivateButton(Index: Integer);
begin
  if FEditorState = nil then
    Exit;
  case Index of
    0: FEditorState.CurrentTool := vetSelect;
    1: FEditorState.CurrentTool := vetLine;
    2: FEditorState.SelectPathToolGroup;
    3: FEditorState.SelectFreehandToolGroup;
    4: FEditorState.CurrentTool := vetRectangle;
  end;
end;

function TVectArtToolPaletteControl.ButtonSelected(Index: Integer): Boolean;
begin
  Result := FEditorState <> nil;
  if not Result then
    Exit;
  case Index of
    0: Result := FEditorState.CurrentTool = vetSelect;
    1: Result := FEditorState.CurrentTool = vetLine;
    2: Result := FEditorState.CurrentTool in [vetPath, vetBezier];
    3: Result := FEditorState.CurrentTool in
      [vetFreehandLine, vetFreehandBezier];
    4: Result := FEditorState.CurrentTool = vetRectangle;
  else
    Result := False;
  end;
end;

constructor TVectArtToolPaletteControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Color := COLOR_BACKGROUND;
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
end;

procedure TVectArtToolPaletteControl.DrawButton(Index: Integer);
var
  Bounds: TRect;
  CenterX: Integer;
  CenterY: Integer;
  Selected: Boolean;
begin
  Bounds := ButtonRect(Index);
  CenterX := (Bounds.Left + Bounds.Right) div 2;
  CenterY := (Bounds.Top + Bounds.Bottom) div 2;
  Selected := ButtonSelected(Index);
  if Selected then
    Canvas.Brush.Color := COLOR_SELECTED
  else
    Canvas.Brush.Color := COLOR_BUTTON;
  Canvas.FillRect(Bounds);
  Canvas.Pen.Color := COLOR_ICON;
  Canvas.Pen.Width := 1;
  Canvas.Brush.Style := bsClear;
  if Index = 0 then
  begin
    Canvas.MoveTo(CenterX - 8, CenterY - 11);
    Canvas.LineTo(CenterX + 7, CenterY + 2);
    Canvas.LineTo(CenterX, CenterY + 4);
    Canvas.LineTo(CenterX + 4, CenterY + 12);
    Canvas.LineTo(CenterX, CenterY + 14);
    Canvas.LineTo(CenterX - 4, CenterY + 6);
    Canvas.LineTo(CenterX - 9, CenterY + 10);
    Canvas.LineTo(CenterX - 8, CenterY - 11);
  end
  else if Index = 1 then
  begin
    Canvas.MoveTo(CenterX - 10, CenterY + 9);
    Canvas.LineTo(CenterX + 10, CenterY - 9);
  end
  else if Index = 2 then
  begin
    if (FEditorState <> nil) and
      (FEditorState.CurrentTool = vetBezier) then
    begin
      Canvas.PolyBezier([
        Point(CenterX - 11, CenterY + 7),
        Point(CenterX - 9, CenterY - 9),
        Point(CenterX - 4, CenterY - 9),
        Point(CenterX - 2, CenterY),
        Point(CenterX, CenterY + 9),
        Point(CenterX + 7, CenterY + 9),
        Point(CenterX + 11, CenterY - 7)]);
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := COLOR_ICON;
      Canvas.Rectangle(CenterX - 13, CenterY + 5, CenterX - 9,
        CenterY + 9);
      Canvas.Rectangle(CenterX - 4, CenterY - 2, CenterX,
        CenterY + 2);
      Canvas.Rectangle(CenterX + 9, CenterY - 9, CenterX + 13,
        CenterY - 5);
    end
    else
    begin
      Canvas.MoveTo(CenterX - 12, CenterY + 8);
      Canvas.LineTo(CenterX - 8, CenterY - 7);
      Canvas.LineTo(CenterX - 2, CenterY + 4);
      Canvas.LineTo(CenterX + 4, CenterY - 8);
      Canvas.LineTo(CenterX + 7, CenterY + 5);
      Canvas.LineTo(CenterX + 12, CenterY + 1);
    end;
  end
  else if Index = 3 then
  begin
    if (FEditorState <> nil) and
      (FEditorState.CurrentTool = vetFreehandBezier) then
      Canvas.PolyBezier([
        Point(CenterX - 13, CenterY + 7),
        Point(CenterX - 11, CenterY - 5),
        Point(CenterX - 5, CenterY - 8),
        Point(CenterX - 1, CenterY + 2),
        Point(CenterX + 1, CenterY + 5),
        Point(CenterX + 3, CenterY + 6),
        Point(CenterX + 5, CenterY + 4)])
    else
      Canvas.Polyline([
        Point(CenterX - 13, CenterY + 7),
        Point(CenterX - 10, CenterY - 5),
        Point(CenterX - 5, CenterY - 8),
        Point(CenterX - 1, CenterY + 3),
        Point(CenterX + 4, CenterY + 5)]);
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := COLOR_ICON;
    Canvas.Polygon([
      Point(CenterX + 3, CenterY + 5),
      Point(CenterX + 5, CenterY),
      Point(CenterX + 10, CenterY - 9),
      Point(CenterX + 14, CenterY - 5),
      Point(CenterX + 5, CenterY + 2)]);
    Canvas.Pen.Color := COLOR_BACKGROUND;
    Canvas.MoveTo(CenterX + 9, CenterY - 7);
    Canvas.LineTo(CenterX + 12, CenterY - 4);
  end
  else
  begin
    Canvas.Rectangle(CenterX - 10, CenterY - 8, CenterX + 10,
      CenterY + 8);
  end;
end;

procedure TVectArtToolPaletteControl.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  if (Button = mbLeft) and (FEditorState <> nil) then
    for I := 0 to BUTTON_COUNT - 1 do
      if PtInRect(ButtonRect(I), Point(X, Y)) then
      begin
        ActivateButton(I);
        Break;
      end;
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TVectArtToolPaletteControl.Paint;
var
  I: Integer;
begin
  Canvas.Brush.Color := COLOR_BACKGROUND;
  Canvas.FillRect(ClientRect);
  for I := 0 to BUTTON_COUNT - 1 do
    DrawButton(I);
end;

procedure TVectArtToolPaletteControl.RefreshState;
begin
  Invalidate;
end;

procedure TVectArtToolPaletteControl.SetEditorState(
  const Value: TVectArtEditorState);
begin
  FEditorState := Value;
  RefreshState;
end;

end.
