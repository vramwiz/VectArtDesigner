// 角形・波状の手続き的な色場を構築する。コンパイル済み効果だけを共有し、色と寸法は呼出しごとに設定する。
unit VectArtDesignerGradientShaders;

interface

uses System.Types, System.UITypes, System.Skia;
function WaveShader(A,B: TAlphaColor; const Bounds: TRectF; Count: Integer): ISkShader;
function SquareShader(A,B: TAlphaColor; const Bounds: TRectF; TextPaint: Boolean = False): ISkShader;

implementation

uses System.SysUtils, System.Math;

var SquareEffect, WaveEffect: ISkRuntimeEffect;

function WaveShader(A,B: TAlphaColor; const Bounds: TRectF; Count: Integer): ISkShader;
var Builder: ISkRuntimeShaderBuilder; ErrorText: string;
begin
  // 元MIFは対角半径を周期数で分割し、cosで2色を滑らかに往復する。
  if WaveEffect = nil then
    WaveEffect := TSkRuntimeEffect.MakeForShader(
      'uniform float2 center; uniform float frequency; uniform shader ramp; '+
      'half4 main(float2 p) { float t = (1-cos(length(p-center)*frequency))*0.5; '+
      'return ramp.eval(float2(t,0)); }',ErrorText);
  if WaveEffect = nil then raise EInvalidOp.Create('Cannot create wave gradient: '+ErrorText);
  Builder := TSkRuntimeShaderBuilder.Create(WaveEffect);
  Builder.SetUniform('center',PointF((Bounds.Left+Bounds.Right)*0.5+0.5,
    (Bounds.Top+Bounds.Bottom)*0.5+0.5));
  Builder.SetUniform('frequency',Single(4*Pi*Count/Hypot(Bounds.Width,Bounds.Height)));
  Builder.SetChild('ramp',TSkShader.MakeGradientLinear(PointF(0,0),PointF(1,0),A,B));
  Result := Builder.MakeShader;
end;

function SquareShader(A,B: TAlphaColor; const Bounds: TRectF; TextPaint: Boolean = False): ISkShader;
var Builder: ISkRuntimeShaderBuilder; ErrorText: string;
begin
  // 図形の幅・高さで正規化した距離の大きい方を使うと、等色線が角形になる。
  // 色変更ではコンパイル済み効果を再利用し、2色と配置だけを差し替える。
  if SquareEffect = nil then
    SquareEffect := TSkRuntimeEffect.MakeForShader(
      'uniform float2 center; uniform float2 halfSize; uniform float2 gap; uniform shader ramp; '+
      'half4 main(float2 p) { float2 d = max(abs(p-center)-gap,float2(0))/halfSize; '+
      'return ramp.eval(float2(max(d.x,d.y),0)); }',ErrorText);
  if SquareEffect = nil then raise EInvalidOp.Create('Cannot create square gradient: '+ErrorText);
  Builder := TSkRuntimeShaderBuilder.Create(SquareEffect);
  Builder.SetUniform('center',PointF((Bounds.Left+Bounds.Right)*0.5+0.5,
    (Bounds.Top+Bounds.Bottom)*0.5+0.5));
  Builder.SetUniform('halfSize',PointF(Bounds.Width*0.5,Bounds.Height*0.5));
  Builder.SetUniform('gap',PointF(0,0));
  if TextPaint then
  begin
    // 奇数寸法の文字画像では中央の2画素を同色にし、両側を整数半寸法で補間する。
    Builder.SetUniform('gap',PointF((Bounds.Width-2*Floor(Bounds.Width*0.5))*0.5,
      (Bounds.Height-2*Floor(Bounds.Height*0.5))*0.5));
    Builder.SetUniform('halfSize',PointF(Max(1,Floor(Bounds.Width*0.5)),Max(1,Floor(Bounds.Height*0.5))));
  end;
  Builder.SetChild('ramp',TSkShader.MakeGradientLinear(PointF(0,0),PointF(1,0),A,B));
  Result := Builder.MakeShader;
end;


end.
