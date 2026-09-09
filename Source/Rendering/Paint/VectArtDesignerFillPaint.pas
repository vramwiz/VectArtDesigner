// 単色・グラデーション・画像の塗りをSkiaのPaintへ変換する。
// プレビューと本描画で色、座標、透明度の扱いを共有し、UI状態には依存しない。
unit VectArtDesignerFillPaint;

interface

uses System.Types, System.UITypes, System.Skia, Vcl.Graphics, VectArtDesignerDocument;

function VclColorToAlphaColor(Color: TColor; Opacity: Single): TAlphaColor;
procedure SetFillPaint(const Paint: ISkPaint; Color: TColor;
  const Fill: TVectArtFillStyle; const Bounds: TRectF; Opacity: Single);

procedure SpectrumColors(Color: TColor; out Colors: TArray<TAlphaColor>;
  out Positions: TArray<Single>);

function StrokePaintBounds(const Bounds: TRectF; Width: Single; Kind: TVectArtFillKind = vfkSolid): TRectF;
procedure SetStrokePaint(const Paint: ISkPaint; Color: TColor;
  const Style: TVectArtFillStyle; const Bounds: TRectF; Width,Opacity: Single);

// 文字全体の色場をレイアウト座標へ戻し、文字の拡縮で角度が変わらないようにする。
procedure SetTextPaint(const Paint: ISkPaint; Color: TColor;
  const Style: TVectArtFillStyle; Width,Height,LayoutWidth,LayoutHeight,Opacity: Single);

implementation

uses VectArtDesignerGradientShaders, ColorPickerColorMath, System.SysUtils, VectArtDesignerGradientGeometry, System.Math, System.Math.Vectors, Winapi.Windows;

// 色相の各折れ点をRGBの線形ストップへ展開し、SkiaとSVGで共有する。
procedure SpectrumColors(Color: TColor; out Colors: TArray<TAlphaColor>;
  out Positions: TArray<Single>);
var Hue,Sat,Value,Offset: Double; N: Integer;
begin
  ColorToHsv(Color,Hue,Sat,Value);
  SetLength(Colors,8); SetLength(Positions,8);
  Colors[0] := VclColorToAlphaColor(Color,1); Positions[0] := 0; N := 1;
  Offset := (Floor(Hue/60)+1)*60-Hue;
  while Offset < 359.99999 do
  begin
    Colors[N] := VclColorToAlphaColor(HsvToColor(Hue+Offset,Sat,Value),1);
    Positions[N] := Offset/360; Inc(N); Offset := Offset+60;
  end;
  Colors[N] := Colors[0]; Positions[N] := 1; Inc(N);
  SetLength(Colors,N); SetLength(Positions,N);
end;

function StrokePaintBounds(const Bounds: TRectF; Width: Single; Kind: TVectArtFillKind = vfkSolid): TRectF;
begin
  Result := Bounds;
  // 水平・垂直のLineでもグラデーションに面積を与える。
  if Result.Width <= 0 then Result.Inflate(Max(Width,1)*0.5,0);
  if Result.Height <= 0 then Result.Inflate(0,Max(Width,1)*0.5);
  // WebArtの線テクスチャは奇数寸法でも整数の半幅・半高さを基準にする。
  if Kind in [vfkLinearHorizontal,vfkLinearVertical,vfkRadial,vfkCircle,vfkWave,vfkSpectrum] then
  begin
    Result.Right := Result.Left+Max(1,2*Floor(Result.Width*0.5));
    Result.Bottom := Result.Top+Max(1,2*Floor(Result.Height*0.5));
  end;
end;
procedure SetStrokePaint(const Paint: ISkPaint; Color: TColor;
  const Style: TVectArtFillStyle; const Bounds: TRectF; Width,Opacity: Single);
var Area: TRectF; StartPoint,EndPoint: TPointF; Angle: Integer;
begin
  Area := StrokePaintBounds(Bounds,Width,Style.Kind);
  SetFillPaint(Paint,Color,Style,Area,Opacity);
  if Style.Kind = vfkRadial then
    Paint.Shader := TSkShader.MakeGradientRadial(
      PointF(Area.CenterPoint.X+0.5,Area.CenterPoint.Y+0.5),Hypot(Area.Width,Area.Height)*0.5,
      VclColorToAlphaColor(Color,1),VclColorToAlphaColor(Style.Color2,1));
  // 線は経路長ではなく、図形全体の実座標を全セグメントで共有する。
  if Style.Kind in [vfkLinearHorizontal,vfkLinearVertical] then
  begin
    Angle := Style.Angle;
    if Style.Kind = vfkLinearVertical then Angle := 90;
    SpectrumGradientEndpoints(Angle,Area,StartPoint,EndPoint);
    Paint.Shader := TSkShader.MakeGradientLinear(StartPoint,EndPoint,
      VclColorToAlphaColor(Color,1),VclColorToAlphaColor(Style.Color2,1));
  end;
end;

procedure SetTextPaint(const Paint: ISkPaint; Color: TColor;
  const Style: TVectArtFillStyle; Width,Height,LayoutWidth,LayoutHeight,Opacity: Single);
begin
  SetStrokePaint(Paint,Color,Style,RectF(0,0,Width,Height),0,Opacity);
  if Style.Kind = vfkSquare then
    Paint.Shader := SquareShader(VclColorToAlphaColor(Color,1),
      VclColorToAlphaColor(Style.Color2,1),RectF(0,0,Width,Height),True);
  if (Paint.Shader <> nil) and (Width > 0) and (Height > 0) then
    Paint.Shader := Paint.Shader.MakeWithLocalMatrix(
      TMatrix.CreateScaling(Max(LayoutWidth,1)/Width,Max(LayoutHeight,1)/Height));
end;

function VclColorToAlphaColor(Color: TColor; Opacity: Single): TAlphaColor;
var
  RGBColor: TColor;
begin
  RGBColor := ColorToRGB(Color);
  Result := TAlphaColor(
    (Cardinal(EnsureRange(Round(Opacity * 255), 0, 255)) shl 24) or
    (Cardinal(GetRValue(RGBColor)) shl 16) or
    (Cardinal(GetGValue(RGBColor)) shl 8) or
    Cardinal(GetBValue(RGBColor)));
end;

procedure SetFillPaint(const Paint: ISkPaint; Color: TColor;
  const Fill: TVectArtFillStyle; const Bounds: TRectF; Opacity: Single);
var Colors: TArray<TAlphaColor>; Positions: TArray<Single>;
    A,B: TAlphaColor; M: TMatrix; Image: ISkImage; StartPoint,EndPoint: TPointF;
begin
  // Paintを再利用しても前のグラデーションが単色描画へ残らないようにする。
  Paint.Shader := nil;
  Paint.Color := VclColorToAlphaColor(Color,Opacity);
  if (Fill.Kind = vfkSolid) or (Bounds.Width <= 0) or (Bounds.Height <= 0) then Exit;
  A := VclColorToAlphaColor(Color,1); B := VclColorToAlphaColor(Fill.Color2,1);
  M := TMatrix.CreateScaling(Bounds.Width,Bounds.Height) *
    TMatrix.CreateTranslation(Bounds.Left,Bounds.Top);
  case Fill.Kind of
    vfkLinearHorizontal:
      begin
        LinearGradientEndpoints(Fill.Angle,StartPoint,EndPoint);
        Paint.Shader := TSkShader.MakeGradientLinear(StartPoint,EndPoint,A,B,M);
      end;
    vfkLinearVertical: Paint.Shader := TSkShader.MakeGradientLinear(PointF(0,0),PointF(0,1),A,B,M);
    vfkRadial:
      // WebArtは対角線の半分を半径とし、長方形でも等距離を同じ色にする。
      Paint.Shader := TSkShader.MakeGradientRadial(
        PointF((Bounds.Left+Bounds.Right)*0.5,(Bounds.Top+Bounds.Bottom)*0.5),
        Hypot(Bounds.Width,Bounds.Height)*0.5,A,B);
    vfkCircle:
      // WebArtの円形は距離ではなく実座標の偏角で補間する。左が色1、右が色2。
      // 元画像の整数中心画素をSkiaの画素中心へ合わせ、中心の色飛びを避ける。
      Paint.Shader := TSkShader.MakeGradientSweep(
        PointF((Bounds.Left+Bounds.Right)*0.5+0.5,(Bounds.Top+Bounds.Bottom)*0.5+0.5),
        TArray<TAlphaColor>.Create(B,A,B));
    vfkSpectrum:
      begin
        SpectrumGradientEndpoints(Fill.Angle,Bounds,StartPoint,EndPoint);
        SpectrumColors(Color,Colors,Positions);
        Paint.Shader := TSkShader.MakeGradientLinear(StartPoint,EndPoint,Colors,Positions);
      end;
    vfkWave: Paint.Shader := WaveShader(A,B,Bounds,Fill.WaveCount);
    vfkSquare: Paint.Shader := SquareShader(A,B,Bounds);
    vfkTexture:
      begin
        Image := TSkImage.MakeFromEncoded(Fill.TexturePng);
        if Image = nil then Exit;
        // 元アプリの画像塗りは実寸で左上を合わせる。図形全体で同じタイル座標を共有する。
        M := TMatrix.CreateTranslation(Bounds.Left,Bounds.Top);
        Paint.Shader := Image.MakeShader(M,TSkSamplingOptions.Medium,
          TSkTileMode.Repeat,TSkTileMode.Repeat);
      end;
  end;
  // Shaderの色を保ち、Paint側ではレイヤーの透明度だけを乗算する。
  Paint.Color := VclColorToAlphaColor(clWhite,Opacity);
end;
end.
