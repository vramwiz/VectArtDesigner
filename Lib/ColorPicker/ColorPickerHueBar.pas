// 色相の選択と表示を担当する。背景をキャッシュし、カーソル周辺だけを更新する。
unit ColorPickerHueBar;



interface

uses
  System.Classes, Vcl.Controls, Vcl.ExtCtrls, Vcl.Graphics, System.Types;

type
  TColorPickerHueBar = class(TCustomControl)
  private
    FBackground: TBitmap;
    FColor    : TColor;        // 現在選択されている色（色相を含む）
    FOnChange : TNotifyEvent;  // 色が変更された際に通知されるイベント
    procedure PaintGradient(const RectAll: TRect);
    procedure PaintCursor(const RectAll: TRect);
    function CursorRect: TRect;
    procedure SetColor(const Value: TColor);
  protected
    procedure DoChange; virtual;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Color: TColor read FColor write SetColor;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;


implementation

uses
  ColorPickerColorMath,
  System.Math,
  Winapi.Windows;

{ TColorPickerHueBar }

constructor TColorPickerHueBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True; ParentDoubleBuffered := False;
  FBackground := Vcl.Graphics.TBitmap.Create;
  Cursor := crHandPoint;

  FColor := clRed;
end;

destructor TColorPickerHueBar.Destroy;
begin
  FBackground.Free;
  inherited;
end;

function TColorPickerHueBar.CursorRect: TRect;
var Y: Integer;
begin
  Y := Round(ColorHue(FColor)/360*Max(0,Height-1));
  Result := Rect(0,Y-5,Width,Y+6);
end;

procedure TColorPickerHueBar.SetColor(const Value: TColor);
var OldRect,NewRect: TRect;
begin
  if FColor = ColorToRGB(Value) then Exit;
  OldRect := CursorRect;
  FColor := ColorToRGB(Value);
  NewRect := CursorRect;
  if HandleAllocated then
  begin
    InvalidateRect(Handle,@OldRect,False);
    InvalidateRect(Handle,@NewRect,False);
  end;
end;
procedure TColorPickerHueBar.DoChange;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TColorPickerHueBar.Paint;
var
  RectAll: TRect;
begin
  RectAll := ClientRect;

  PaintGradient(RectAll);
  PaintCursor(RectAll);
end;

procedure TColorPickerHueBar.PaintCursor(const RectAll: TRect);
var
  CurHue: Double;
  Y: Integer;
begin
  CurHue := ColorHue(FColor);
  Y := RectAll.Top + Round(CurHue / 360 * (RectAll.Height - 1));
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := clBlack;
  Canvas.Rectangle(RectAll.Left, Y - 3, RectAll.Right, Y + 3);
  Canvas.Pen.Color := clWhite;
  Canvas.Rectangle(RectAll.Left + 1, Y - 2,
    RectAll.Right - 1, Y + 2);
end;


procedure TColorPickerHueBar.PaintGradient(const RectAll: TRect);
var Y: Integer;
begin
  if (Width <= 0) or (Height <= 0) then Exit;
  // 色相帯は選択色に依存しないため、サイズが変わるまで再生成しない。
  if (FBackground.Width <> Width) or (FBackground.Height <> Height) then
  begin
    FBackground.SetSize(Width,Height);
    for Y := 0 to Height-1 do
    begin
      FBackground.Canvas.Pen.Color := HsvToColor(360*Y/Max(1,Height-1),1,1);
      FBackground.Canvas.MoveTo(0,Y); FBackground.Canvas.LineTo(Width,Y);
    end;
  end;
  Canvas.Draw(0,0,FBackground);
end;
procedure TColorPickerHueBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button = mbLeft then
    MouseMove(Shift + [ssLeft], X, Y);
end;

procedure TColorPickerHueBar.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  H: Double;
begin
  if not (ssLeft in Shift) or (ClientHeight <= 0) then
    Exit;
  Y := EnsureRange(Y, 0, ClientHeight - 1);
  H := 360 * Y / Max(1, ClientHeight - 1);
  SetColor(HsvToColor(H, 1, 1));
  DoChange;
end;

end.

