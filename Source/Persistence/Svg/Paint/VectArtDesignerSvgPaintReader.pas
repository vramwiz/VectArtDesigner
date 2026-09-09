// SVGの単色・グラデーション・埋込画像をMIF互換のペイント設定へ変換する。
// 図形の生成やDocument更新を行わず、書出し側と対になる定義の解釈だけを担当する。
unit VectArtDesignerSvgPaintReader;

interface

uses Xml.XMLIntf, Vcl.Graphics, VectArtDesignerDocument;
function TryParseSvgColor(const Text: string; out Value: TColor): Boolean;
function TryParseFill(const Node: IXMLNode; const Text: string;
  out Color: TColor; out Fill: TVectArtFillStyle): Boolean;

implementation

uses System.SysUtils, System.Math, System.NetEncoding, Winapi.Windows,
  VectArtDesignerSvgPrimitives;

function TryParseHexByte(const Text: string; out Value: Byte): Boolean;
var
  IntegerValue: Integer;
begin
  Result := TryStrToInt('$' + Text, IntegerValue) and
    InRange(IntegerValue, 0, 255);
  if Result then
    Value := Byte(IntegerValue)
  else
    Value := 0;
end;

function TryParseSvgColor(const Text: string; out Value: TColor): Boolean;
var
  B: Byte;
  ColorText: string;
  G: Byte;
  R: Byte;
begin
  ColorText := Trim(Text);
  if SameText(ColorText, 'black') then
  begin
    Value := clBlack;
    Exit(True);
  end;
  if SameText(ColorText, 'white') then
  begin
    Value := clWhite;
    Exit(True);
  end;
  if SameText(ColorText, 'red') then
  begin
    Value := clRed;
    Exit(True);
  end;
  if SameText(ColorText, 'green') then
  begin
    Value := clGreen;
    Exit(True);
  end;
  if SameText(ColorText, 'blue') then
  begin
    Value := clBlue;
    Exit(True);
  end;
  if (Length(ColorText) = 4) and (ColorText[1] = '#') then
    ColorText := '#' + ColorText[2] + ColorText[2] + ColorText[3] +
      ColorText[3] + ColorText[4] + ColorText[4];
  Result := (Length(ColorText) = 7) and (ColorText[1] = '#') and
    TryParseHexByte(Copy(ColorText, 2, 2), R) and
    TryParseHexByte(Copy(ColorText, 4, 2), G) and
    TryParseHexByte(Copy(ColorText, 6, 2), B);
  if Result then
    Value := TColor(RGB(R, G, B))
  else
    Value := clBlack;
end;

function FindPaintNode(const Node: IXMLNode; const Id: string): IXMLNode;
var J: Integer; S: string;
begin
  Result := nil;
  if TryGetAttribute(Node,'id',S) and (S = Id) then Exit(Node);
  for J := 0 to Node.ChildNodes.Count-1 do
  begin
    Result := FindPaintNode(Node.ChildNodes[J],Id);
    if Result <> nil then Exit;
  end;
end;
function TryParseFill(const Node: IXMLNode; const Text: string;
  out Color: TColor; out Fill: TVectArtFillStyle): Boolean;
var PaintNode, Child: IXMLNode; S, Kind, X, Y: string; J, Count: Integer; X1,Y1,X2,Y2: Single;
begin
  Fill := Default(TVectArtFillStyle);
  if TryParseSvgColor(Text,Color) then Exit(True);
  Result := False;
  S := Trim(Text);
  if not S.StartsWith('url(#') or not S.EndsWith(')') then Exit;
  PaintNode := FindPaintNode(Node.OwnerDocument.DocumentElement,Copy(S,6,Length(S)-6));
  if PaintNode = nil then Exit;
  Kind := LocalNodeName(PaintNode);
  if Kind = 'pattern' then
  begin
    // 表示用PNGへ変換した円形・角形・波状塗りも、編集時はMIF互換の2色設定へ戻す。
    if TryGetAttribute(PaintNode,'data-vad-fill',S) and ((S = 'circle') or (S = 'square') or (S = 'wave')) then
    begin
      Fill.Kind := vfkCircle;
      if S = 'square' then Fill.Kind := vfkSquare;
      if S = 'wave' then
      begin
        Fill.Kind := vfkWave;
        if not TryGetAttribute(PaintNode,'data-vad-wave-count',S) or
          not TryStrToInt(S,Fill.WaveCount) then Exit;
      end;
      if not TryGetAttribute(PaintNode,'data-vad-color1',S) or
        not TryParseSvgColor(S,Color) then Exit;
      if not TryGetAttribute(PaintNode,'data-vad-color2',S) or
        not TryParseSvgColor(S,Fill.Color2) then Exit;
      Exit(True);
    end;
    // 現在の編集モデルは実寸画像を保持する。任意のpatternTransformは復元対象に含めない。
    for J := 0 to PaintNode.ChildNodes.Count-1 do
    begin
      Child := PaintNode.ChildNodes[J];
      if (LocalNodeName(Child) = 'image') and TryGetAttribute(Child,'href',S) and
        S.StartsWith('data:image/png;base64,') then
      begin
        Fill.Kind := vfkTexture;
        Fill.TexturePng := TNetEncoding.Base64.DecodeStringToBytes(Copy(S,23,MaxInt));
        Exit(Length(Fill.TexturePng) > 0);
      end;
    end;
    Exit;
  end;
  if Kind = 'linearGradient' then
  begin
    // 多ストップの標準SVG表示を保ちつつ、再編集時は開始色と角度へ戻す。
    if TryGetAttribute(PaintNode,'data-vad-fill',S) and (S = 'spectrum') then
    begin
      if not TryGetAttribute(PaintNode,'data-vad-color1',S) or
        not TryParseSvgColor(S,Color) then Exit;
      if not TryGetAttribute(PaintNode,'data-vad-angle',S) or
        not TryStrToInt(S,Fill.Angle) then Exit;
      Fill.Kind := vfkSpectrum;
      Exit(True);
    end;
    X := '1'; Y := '0';
    TryGetAttribute(PaintNode,'x2',X); TryGetAttribute(PaintNode,'y2',Y);
    if (X = '0') and (Y = '1') then Fill.Kind := vfkLinearVertical
    else Fill.Kind := vfkLinearHorizontal;
    if not TryParseSvgNumber(X,X2) or not TryParseSvgNumber(Y,Y2) then Exit;
    X := '0'; Y := '0';
    TryGetAttribute(PaintNode,'x1',X); TryGetAttribute(PaintNode,'y1',Y);
    if not TryParseSvgNumber(X,X1) or not TryParseSvgNumber(Y,Y1) then Exit;
    if SameValue(X1,X2) and SameValue(Y1,Y2) then Exit;
    Fill.Angle := (Round(RadToDeg(ArcTan2(Y2-Y1,X2-X1)))+360) mod 360;
    if Fill.Angle = 90 then Fill.Kind := vfkLinearVertical
    else Fill.Kind := vfkLinearHorizontal;
  end
  else if Kind = 'radialGradient' then Fill.Kind := vfkRadial else Exit;
  Count := 0;
  for J := 0 to PaintNode.ChildNodes.Count-1 do
  begin
    Child := PaintNode.ChildNodes[J];
    if LocalNodeName(Child) <> 'stop' then Continue;
    if not TryGetAttribute(Child,'stop-color',S) then Exit;
    if Count = 0 then begin if not TryParseSvgColor(S,Color) then Exit; end
    else if Count = 1 then begin if not TryParseSvgColor(S,Fill.Color2) then Exit; end
    else Exit;
    Inc(Count);
  end;
  Result := Count = 2;
end;
end.
