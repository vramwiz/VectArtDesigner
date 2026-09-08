// 単色・グラデーション・画像の塗りをSkiaのPaintへ変換する。
// プレビューと本描画で色、座標、透明度の扱いを共有し、UI状態には依存しない。
unit VectArtDesignerFillPaint;

interface

uses System.Types, System.UITypes, System.Skia, Vcl.Graphics, VectArtDesignerDocument;

function VclColorToAlphaColor(Color: TColor; Opacity: Single): TAlphaColor;
procedure SetFillPaint(const Paint: ISkPaint; Color: TColor;
  const Fill: TVectArtFillStyle; const Bounds: TRectF; Opacity: Single);

implementation

uses VectArtDesignerGradientGeometry, System.Math, System.Math.Vectors, Winapi.Windows;

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
var A,B: TAlphaColor; M: TMatrix; Image: ISkImage; StartPoint,EndPoint: TPointF;
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
    vfkRadial: Paint.Shader := TSkShader.MakeGradientRadial(PointF(0.5,0.5),0.5,A,B,M);
    vfkTexture:
      begin
        Image := TSkImage.MakeFromEncoded(Fill.TexturePng);
        if Image = nil then Exit;
        M := TMatrix.CreateScaling(Bounds.Width/Image.Width,Bounds.Height/Image.Height) *
          TMatrix.CreateTranslation(Bounds.Left,Bounds.Top);
        Paint.Shader := Image.MakeShader(M,TSkSamplingOptions.Medium);
      end;
  end;
  // Shaderの色を保ち、Paint側ではレイヤーの透明度だけを乗算する。
  Paint.Color := VclColorToAlphaColor(clWhite,Opacity);
end;
end.
