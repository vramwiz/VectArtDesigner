// 標準テンプレートは正規化した輪郭だけを提供し、配置後は通常の閉じたPathになる。
unit VectArtDesignerTemplateGeometry;

interface

uses System.Types;

const VECTART_TEMPLATE_COUNT = 30;

function VectArtTemplateName(Index: Integer): string;
function VectArtTemplateCategory(Index: Integer): Integer;
function VectArtTemplatePoints(Index: Integer; const Bounds: TRectF): TArray<TPointF>;

implementation

uses System.Math;

const
  Names: array[0..29] of string = ('三角形', '直角三角形', '五角形', '六角形', '八角形',
    '台形', 'ひし形', '平行四辺形', '右矢印', '左矢印', '上矢印', '下矢印',
    '左右矢印', 'シェブロン', '四角吹き出し', '右向き吹き出し', '5角星', '8角星',
    'バースト', '判断', '入出力', '書類', 'リボン', 'タグ', '角折れカード',
    '半円', '扇形', 'ハート', '十字', 'ジグザグ区切り');
  Categories: array[0..29] of Integer = (0,0,0,0,0,0,0,0,1,1,1,1,1,1,2,2,3,3,3,4,4,4,5,5,5,6,6,7,7,8);

function VectArtTemplateName(Index: Integer): string;
begin Result := Names[EnsureRange(Index, 0, High(Names))]; end;

function VectArtTemplateCategory(Index: Integer): Integer;
begin Result := Categories[EnsureRange(Index, 0, High(Names))]; end;

function VectArtTemplatePoints(Index: Integer; const Bounds: TRectF): TArray<TPointF>;
var
  I, N: Integer;
  Angle, Radius, X, Y: Single;
  P: TPointF;
  procedure Polygon(Count: Integer; Inner: Single = 1);
  var J: Integer;
  begin
    SetLength(Result, Count);
    for J := 0 to Count - 1 do
    begin
      Radius := 0.5;
      if Odd(J) then Radius := Radius * Inner;
      Angle := J * 2 * Pi / Count - Pi / 2;
      Result[J] := PointF(0.5 + Cos(Angle) * Radius, 0.5 + Sin(Angle) * Radius);
    end;
  end;
begin
  case Index of
    0: Result := [PointF(0.5,0), PointF(1,1), PointF(0,1)];
    1: Result := [PointF(0,0), PointF(1,1), PointF(0,1)];
    2: Polygon(5); 3: Polygon(6); 4: Polygon(8);
    5: Result := [PointF(0.2,0),PointF(0.8,0),PointF(1,1),PointF(0,1)];
    6, 19: Result := [PointF(0.5,0),PointF(1,0.5),PointF(0.5,1),PointF(0,0.5)];
    7, 20: Result := [PointF(0.25,0),PointF(1,0),PointF(0.75,1),PointF(0,1)];
    8..11: begin
      Result := [PointF(0,0.3),PointF(0.6,0.3),PointF(0.6,0),PointF(1,0.5),
        PointF(0.6,1),PointF(0.6,0.7),PointF(0,0.7)];
      for I := 0 to High(Result) do
      begin
        P := Result[I];
        case Index of
          9: Result[I] := PointF(1-P.X,P.Y);
          10: Result[I] := PointF(P.Y,1-P.X);
          11: Result[I] := PointF(P.Y,P.X);
        end;
      end;
    end;
    12: Result := [PointF(0,0.5),PointF(0.3,0),PointF(0.3,0.3),PointF(0.7,0.3),
      PointF(0.7,0),PointF(1,0.5),PointF(0.7,1),PointF(0.7,0.7),PointF(0.3,0.7),PointF(0.3,1)];
    13: Result := [PointF(0,0),PointF(0.6,0),PointF(1,0.5),PointF(0.6,1),PointF(0,1),PointF(0.4,0.5)];
    14,15: begin
      Result := [PointF(0,0),PointF(1,0),PointF(1,0.75),PointF(0.6,0.75),
        PointF(0.25,1),PointF(0.35,0.75),PointF(0,0.75)];
      if Index = 15 then for I := 0 to High(Result) do Result[I].X := 1-Result[I].X;
    end;
    16: Polygon(10,0.45); 17: Polygon(16,0.48); 18: Polygon(32,0.7);
    21: begin
      Result := [PointF(0,0), PointF(1,0), PointF(1,0.8)];
      for I := 1 to 24 do
      begin X := 1-I/24; Result := Result + [PointF(X,0.8+0.12*Sin(X*2*Pi))]; end;
    end;
    22: Result := [PointF(0,0),PointF(1,0),PointF(0.85,0.5),PointF(1,1),PointF(0,1),PointF(0.15,0.5)];
    23: Result := [PointF(0,0),PointF(0.7,0),PointF(1,0.5),PointF(0.7,1),PointF(0,1)];
    24: Result := [PointF(0,0),PointF(0.7,0),PointF(1,0.3),PointF(1,1),PointF(0,1)];
    25,26: begin
      N := 32;
      SetLength(Result,N+2);
      Result[0] := PointF(0.5,1);
      for I := 0 to N do
      begin Angle := Pi + Pi*I/N; Result[I+1] := PointF(0.5+0.5*Cos(Angle),1+Sin(Angle)); end;
      if Index = 26 then
        for I := 0 to High(Result) do Result[I].X := 0.5+(Result[I].X-0.5)*0.8;
    end;
    27: begin
      SetLength(Result,64);
      for I := 0 to High(Result) do
      begin
        Angle := I*2*Pi/Length(Result);
        X := 16*Power(Sin(Angle),3);
        Y := 13*Cos(Angle)-5*Cos(2*Angle)-2*Cos(3*Angle)-Cos(4*Angle);
        Result[I] := PointF((X+16)/32, (12-Y)/29);
      end;
    end;
    28: Result := [PointF(0.35,0),PointF(0.65,0),PointF(0.65,0.35),PointF(1,0.35),
      PointF(1,0.65),PointF(0.65,0.65),PointF(0.65,1),PointF(0.35,1),
      PointF(0.35,0.65),PointF(0,0.65),PointF(0,0.35),PointF(0.35,0.35)];
    29: begin
      Result := [PointF(0,0),PointF(1,0),PointF(1,0.6)];
      for I := 1 to 12 do Result := Result + [PointF(1-I/12,0.6+0.4*Ord(Odd(I)))];
    end;
  else Result := [PointF(0,0),PointF(1,0),PointF(1,1),PointF(0,1)];
  end;
  for I := 0 to High(Result) do
    Result[I] := PointF(Bounds.Left+Result[I].X*Bounds.Width, Bounds.Top+Result[I].Y*Bounds.Height);
end;

end.
