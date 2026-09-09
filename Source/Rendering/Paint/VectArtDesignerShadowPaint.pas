// 図形の合成済みアルファから影を作り、塗りと枠の重なりによる二重の影を防ぐ。
unit VectArtDesignerShadowPaint;
interface
uses System.Skia, System.Types, VectArtDesignerDocument;
function ShadowPaint(const Shadow: TVectArtShadow): ISkPaint;
function ShadowBounds(const Bounds: TRectF; const Shadow: TVectArtShadow): TRectF;
implementation
uses System.Math, System.UITypes, Vcl.Graphics, Winapi.Windows;
function ShadowPaint(const Shadow: TVectArtShadow): ISkPaint;
var C: Cardinal;
begin
  Result := TSkPaint.Create;
  C := ColorToRGB(Shadow.Color);
  // levelはぼかし強度としてsigmaへ対応付ける。輪郭の画素は元アプリと完全一致ではない。
  Result.ImageFilter := TSkImageFilter.MakeDropShadow(Shadow.OffsetX,Shadow.OffsetY,
    Max(Shadow.Blur,0),Max(Shadow.Blur,0),TAlphaColor($FF000000 or
    (Cardinal(GetRValue(C)) shl 16) or (Cardinal(GetGValue(C)) shl 8) or GetBValue(C)));
end;
function ShadowBounds(const Bounds: TRectF; const Shadow: TVectArtShadow): TRectF;
var R: TRectF;
begin
  Result := Bounds;
  if not Shadow.Enabled then Exit;
  R := Bounds; R.Offset(Shadow.OffsetX,Shadow.OffsetY);
  // ガウスぼかしの裾まで含め、PNGとサムネイルの端で影が切れないようにする。
  R.Inflate(3*Max(Shadow.Blur,0)+1,3*Max(Shadow.Blur,0)+1);
  Result := RectF(Min(Bounds.Left,R.Left),Min(Bounds.Top,R.Top),
    Max(Bounds.Right,R.Right),Max(Bounds.Bottom,R.Bottom));
end;
end.
