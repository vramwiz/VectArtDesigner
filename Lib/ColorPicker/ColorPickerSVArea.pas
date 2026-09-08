// 彩度・明度の選択と表示を担当する。色相・サイズ単位の背景キャッシュで再描画を抑える。
unit ColorPickerSVArea;



interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.Math,
  Vcl.Controls, Vcl.ExtCtrls, Vcl.Graphics;

type
  PRGBTripleArray = ^TRGBTripleArray;
  TRGBTripleArray = array[0..MaxInt div SizeOf(TRGBTriple) - 1] of TRGBTriple;

type
  TColorPickerSVArea = class(TCustomControl)
  private
    FCachedHue: Double;
    FCacheValid: Boolean;
    FColor     : TColor;        // 現在選択されている色（RGB）
    FBaseColor : TColor;        // SV グラデーションの基準色（Hue）
    FOnChange  : TNotifyEvent;  // 色が変更された際に通知されるイベント
    FSVBitmap  : TBitmap;       // SV グラデーション描画用の内部ビットマップ
    function CursorRect: TRect;
    procedure SetColor(const Value: TColor);
    procedure SetBaseColor(const Value: TColor);
  protected
    procedure DoChange; virtual;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure PaintSV(const RectAll: TRect);
    procedure PaintCursor(const RectAll: TRect);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property BaseColor: TColor read FBaseColor write SetBaseColor;
    property Color: TColor read FColor write SetColor;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;


implementation

uses
  ColorPickerColorMath;

{ TColorPickerSVArea }

constructor TColorPickerSVArea.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  ParentDoubleBuffered := False;
  Cursor := crCross;
  FColor := clRed;
  FBaseColor := clRed;
  FSVBitmap := TBitmap.Create;
end;

procedure TColorPickerSVArea.SetBaseColor(const Value: TColor);
begin
  if FBaseColor <> Value then
  begin
    FBaseColor := Value;
    Invalidate; // 色相変更時だけ背景キャッシュを更新する。
  end;
end;

function TColorPickerSVArea.CursorRect: TRect;
var H,S,V: Double; X,Y: Integer;
begin
  ColorToHsv(FColor,H,S,V);
  X := Round(S*Max(0,Width-1)); Y := Round((1-V)*Max(0,Height-1));
  Result := Rect(X-6,Y-6,X+7,Y+7);
end;

procedure TColorPickerSVArea.SetColor(const Value: TColor);
var OldRect,NewRect: TRect;
begin
  if FColor = ColorToRGB(Value) then Exit;
  OldRect := CursorRect;
  FColor := ColorToRGB(Value);
  NewRect := CursorRect;
  // 独立HWNDの旧・新カーソル周辺だけを更新し、親の背景消去を発生させない。
  if HandleAllocated then
  begin
    InvalidateRect(Handle,@OldRect,False);
    InvalidateRect(Handle,@NewRect,False);
  end;
end;
destructor TColorPickerSVArea.Destroy;
begin
  FSVBitmap.Free;
  inherited;
end;

procedure TColorPickerSVArea.DoChange;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TColorPickerSVArea.Paint;
begin
  PaintSV(ClientRect);

  if Assigned(FSVBitmap) then
    Canvas.Draw(0, 0, FSVBitmap);

  PaintCursor(ClientRect);
end;

procedure TColorPickerSVArea.PaintSV(const RectAll: TRect);
var
  Color: TColor;
  Hue: Double;
  Row: PRGBTripleArray;
  Saturation: Double;
  Value: Double;
  X: Integer;
  Y: Integer;
begin
  if (RectAll.Width <= 0) or (RectAll.Height <= 0) then
    Exit;

  Hue := ColorHue(FBaseColor);
  if FCacheValid and SameValue(FCachedHue,Hue,0.000001) and
    (FSVBitmap.Width = RectAll.Width) and (FSVBitmap.Height = RectAll.Height) then Exit;
  FCacheValid := True; FCachedHue := Hue;
  FSVBitmap.SetSize(RectAll.Width, RectAll.Height);
  FSVBitmap.PixelFormat := pf24bit;
  Hue := ColorHue(FBaseColor);
  for Y := 0 to FSVBitmap.Height - 1 do
  begin
    Row := PRGBTripleArray(FSVBitmap.ScanLine[Y]);
    Value := 1 - Y / Max(1, FSVBitmap.Height - 1);
    for X := 0 to FSVBitmap.Width - 1 do
    begin
      Saturation := X / Max(1, FSVBitmap.Width - 1);
      Color := ColorToRGB(HsvToColor(Hue, Saturation, Value));
      Row[X].rgbtBlue := GetBValue(Color);
      Row[X].rgbtGreen := GetGValue(Color);
      Row[X].rgbtRed := GetRValue(Color);
    end;
  end;
end;



procedure TColorPickerSVArea.PaintCursor(const RectAll: TRect);
var
  Hue: Double;
  Saturation: Double;
  Value: Double;
  X: Integer;
  Y: Integer;
begin
  ColorToHsv(FColor, Hue, Saturation, Value);
  X := RectAll.Left + Round(Saturation * (RectAll.Width - 1));
  Y := RectAll.Top + Round((1 - Value) * (RectAll.Height - 1));
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := clBlack;
  Canvas.Ellipse(X - 4, Y - 4, X + 4, Y + 4);
  Canvas.Pen.Color := clWhite;
  Canvas.Ellipse(X - 3, Y - 3, X + 3, Y + 3);
end;

procedure TColorPickerSVArea.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button = mbLeft then
    MouseMove(Shift + [ssLeft], X, Y);
end;

procedure TColorPickerSVArea.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Hue: Double;
  Saturation: Double;
  Value: Double;
begin
  if not (ssLeft in Shift) or (ClientWidth <= 0) or
    (ClientHeight <= 0) then
    Exit;
  X := EnsureRange(X, 0, ClientWidth - 1);
  Y := EnsureRange(Y, 0, ClientHeight - 1);
  Saturation := X / Max(1, ClientWidth - 1);
  Value := 1 - Y / Max(1, ClientHeight - 1);
  Hue := ColorHue(FBaseColor);
  SetColor(HsvToColor(Hue, Saturation, Value));
  DoChange;
end;

end.
