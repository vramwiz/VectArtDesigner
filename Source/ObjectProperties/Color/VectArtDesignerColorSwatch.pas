// 塗り設定の見本とキーボード操作可能な編集入口を表示する。
// 塗り画像は変更時だけ再生成し、再描画のたびにSkia処理を繰り返さない。
unit VectArtDesignerColorSwatch;

interface

uses System.Classes, Vcl.Controls, Vcl.Graphics, VectArtDesignerDocument;

type
  TVectArtColorSwatch = class(TCustomControl)
  private
    FValue: TColor;
    FCompact: Boolean;
    FCircular: Boolean;
    FEmpty: Boolean;
    FFillStyle: TVectArtFillStyle;
    FSwatchBitmap: Vcl.Graphics.TBitmap;
    FSwatchDirty: Boolean;
    procedure SetFillStyle(const Value: TVectArtFillStyle);
    procedure SetValue(Value: TColor);
  protected
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property FillStyle: TVectArtFillStyle read FFillStyle write SetFillStyle;
    property Value: TColor read FValue write SetValue;
    property Empty: Boolean read FEmpty write FEmpty;
    // 狭い作成色欄では単色面だけを表示し、役割は外側のラベルで示す。
    property Circular: Boolean read FCircular write FCircular;
    property Compact: Boolean read FCompact write FCompact;
    property OnClick;
  end;

function HexColor(Color: TColor): string;

implementation

uses System.SysUtils, System.Types, System.Math,
  System.UITypes, System.Skia, Winapi.Windows, Vcl.Imaging.pngimage,
  VectArtDesignerFillPaint;

function HexColor(Color: TColor): string;
begin
  Color := ColorToRGB(Color);
  Result := Format('#%.2x%.2x%.2x', [GetRValue(Color), GetGValue(Color), GetBValue(Color)]);
end;

constructor TVectArtColorSwatch.Create(AOwner: TComponent);
begin
  inherited;
  DoubleBuffered := True;
  ParentDoubleBuffered := False;
  ControlStyle := ControlStyle + [csOpaque];
  FSwatchBitmap := Vcl.Graphics.TBitmap.Create;
  FSwatchBitmap.PixelFormat := pf32bit;
  FSwatchDirty := True;
  Height := 36;
  Width := 240;
  Cursor := crHandPoint;
  TabStop := True;
end;

procedure TVectArtColorSwatch.SetValue(Value: TColor);
begin
  if FValue = Value then Exit;
  FValue := Value;
  FSwatchDirty := True;
  Invalidate;
end;

destructor TVectArtColorSwatch.Destroy;
begin
  FSwatchBitmap.Free;
  inherited;
end;
procedure TVectArtColorSwatch.SetFillStyle(const Value: TVectArtFillStyle);
begin
  if (FFillStyle.Kind = Value.Kind) and (FFillStyle.Color2 = Value.Color2) and
    (FFillStyle.Angle = Value.Angle) and
    (FFillStyle.WaveCount = Value.WaveCount) and
    (Length(FFillStyle.TexturePng) = Length(Value.TexturePng)) then
    if (Length(Value.TexturePng) = 0) or
      CompareMem(@FFillStyle.TexturePng[0],@Value.TexturePng[0],Length(Value.TexturePng)) then Exit;
  FFillStyle := Value;
  FSwatchDirty := True;
  Invalidate;
end;
procedure TVectArtColorSwatch.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;
  if (Key = VK_RETURN) or (Key = VK_SPACE) then begin Click; Key := 0; end;
end;

procedure TVectArtColorSwatch.Paint;
var
  Caption: string;
  H: Integer;
  Paint: ISkPaint;
  Png: TPngImage;
  Stream: TBytesStream;
  Surface: ISkSurface;
begin
  if FCircular then Canvas.Brush.Color := TColor($00252525)
  else Canvas.Brush.Color := TColor($00353535);
  Canvas.FillRect(ClientRect);
  Canvas.Brush.Color := FValue;
  if FCompact then
  begin
    if FCircular then
    begin
      Canvas.Pen.Color := clSilver; Canvas.Pen.Width := 1;
      Canvas.Ellipse(2,2,Width-2,Height-2);
    end
    else Canvas.FillRect(Rect(4,4,Width-4,Height-4));
    Exit;
  end;
  Canvas.FillRect(Rect(6, 6, 44, Height - 6));
  if not FEmpty and (FFillStyle.Kind <> vfkSolid) then
  begin
    H := Max(1,Height-12);
    if (FSwatchBitmap.Width <> 38) or (FSwatchBitmap.Height <> H) then
    begin FSwatchBitmap.SetSize(38,H); FSwatchDirty := True; end;
    if FSwatchDirty then
    begin
      if FFillStyle.Kind = vfkTexture then
      begin
        FSwatchBitmap.Canvas.Brush.Color := clWhite;
        FSwatchBitmap.Canvas.FillRect(Rect(0,0,38,H));
        Stream := TBytesStream.Create(FFillStyle.TexturePng);
        Png := TPngImage.Create;
        try
          Png.LoadFromStream(Stream);
          // 小型見本では実寸の左上だけでなく、画像全体を縮小して内容を示す。
          FSwatchBitmap.Canvas.StretchDraw(Rect(0,0,38,H),Png);
        finally
          Png.Free;
          Stream.Free;
        end;
      end
      else
      begin
        Surface := TSkSurface.MakeRasterDirect(
          TSkImageInfo.Create(38,H,TSkColorType.BGRA8888,TSkAlphaType.Premul),
          FSwatchBitmap.ScanLine[H-1],38*4);
        Surface.Canvas.Clear(TAlphaColorRec.White);
        Surface.Canvas.Translate(0,H); Surface.Canvas.Scale(1,-1);
        Paint := TSkPaint.Create;
        SetFillPaint(Paint,FValue,FFillStyle,RectF(0,0,38,H),1);
        Surface.Canvas.DrawPaint(Paint); Surface := nil;
      end;
      FSwatchDirty := False;
    end;
    Canvas.Draw(6,6,FSwatchBitmap);
  end;
  Canvas.Font.Assign(Font);
  Canvas.Font.Color := clWhite;
  if not Enabled then Canvas.Font.Color := clGrayText;
  Canvas.Brush.Style := bsClear;
  if FEmpty then
    Canvas.TextOut(54, 10, '複数の色 / 色を選択')
  else
  begin
    Caption := HexColor(FValue);
    if FFillStyle.Kind in [vfkLinearHorizontal,vfkLinearVertical,vfkRadial,vfkCircle,vfkSquare,vfkWave,vfkSpectrum] then Caption := 'グラデーション';
    if FFillStyle.Kind = vfkTexture then Caption := 'テクスチャ';
    Canvas.TextOut(54,10,Caption + '  編集…');
  end;
  Canvas.Brush.Style := bsSolid;
end;

end.
