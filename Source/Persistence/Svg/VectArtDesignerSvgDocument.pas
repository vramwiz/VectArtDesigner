// Rectangle Documentを標準SVGへ可逆保存し、対応するSVGのキャンバスと四角形を復元する。
// 標準属性を描画情報の正本とし、SVGに表現できない編集情報だけをvad名前空間へ保持する。
unit VectArtDesignerSvgDocument;

interface

uses
  VectArtDesignerDocument;

// DocumentをUTF-8で保存可能なSVG文字列へ変換する。Documentを所有しない。
function TryCreateVectArtSvg(Document: TVectArtDocument; out SvgText,
  ErrorMessage: string): Boolean;
// SVG文字列から対応するキャンバスとRectangleをDocumentへ適用する。Documentを所有しない。
function TryLoadVectArtDocumentFromSvg(const SvgText: string;
  Document: TVectArtDocument; out ErrorMessage: string): Boolean;
// SVGファイルを読み、対応内容をDocumentへ適用する。例外を呼び出し側へ漏らさない。
function TryLoadVectArtDocumentFromSvgFile(const FileName: string;
  Document: TVectArtDocument; out ErrorMessage: string): Boolean;
// DocumentをUTF-8 BOMなしのSVGファイルへ保存する。例外を呼び出し側へ漏らさない。
function TrySaveVectArtDocumentToSvgFile(Document: TVectArtDocument;
  const FileName: string; out ErrorMessage: string): Boolean;

implementation

uses
  System.Classes, System.Generics.Collections, System.IOUtils, System.Math,
  System.NetEncoding, System.SysUtils, System.Types, System.Variants,
  Vcl.Graphics, Winapi.Windows,
  VectArtDesignerGeometry, Xml.omnixmldom, Xml.XMLDoc, Xml.XMLIntf,
  Xml.xmldom;

const
  SVG_NAMESPACE = 'http://www.w3.org/2000/svg';
  VAD_NAMESPACE = 'urn:vectartdesigner:document:1';
  VAD_FORMAT_VERSION = 1;

function XmlEscape(const Value: string): string;
begin
  Result := StringReplace(Value, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&apos;', [rfReplaceAll]);
end;

function SvgNumber(Value: Single): string;
var
  FormatSettings: TFormatSettings;
begin
  FormatSettings := TFormatSettings.Create;
  FormatSettings.DecimalSeparator := '.';
  FormatSettings.ThousandSeparator := #0;
  Result := FloatToStrF(Value, ffGeneral, 9, 0, FormatSettings);
end;

function SvgColor(Value: TColor): string;
var
  RgbColor: TColor;
begin
  RgbColor := ColorToRGB(Value);
  Result := Format('#%.2x%.2x%.2x', [GetRValue(RgbColor),
    GetGValue(RgbColor), GetBValue(RgbColor)]);
end;

function BooleanText(Value: Boolean): string;
begin
  if Value then
    Result := 'true'
  else
    Result := 'false';
end;

function SvgLineCap(Value: TVectArtLineCap): string;
begin
  case Value of
    vlcSquare: Result := 'square';
    vlcRound: Result := 'round';
  else
    Result := 'butt';
  end;
end;

function SvgLineJoin(Value: TVectArtLineJoin): string;
begin
  case Value of
    vljBevel: Result := 'bevel';
    vljRound: Result := 'round';
  else
    Result := 'miter';
  end;
end;

function LineMarkerName(Value: TVectArtLineMarker): string;
begin
  case Value of
    vlmArrow: Result := 'arrow';
    vlmOpenArrow: Result := 'open-arrow';
    vlmWideArrow: Result := 'wide-arrow';
    vlmCircle: Result := 'circle';
    vlmDiamond: Result := 'diamond';
    vlmConcaveArrow: Result := 'concave-arrow';
    vlmSmallArrow: Result := 'small-arrow';
    vlmSlash: Result := 'slash';
    vlmStar: Result := 'star';
  else
    Result := 'none';
  end;
end;

function TryParseLineMarkerName(const Value: string;
  out Marker: TVectArtLineMarker): Boolean;
var
  Candidate: TVectArtLineMarker;
begin
  for Candidate := Low(TVectArtLineMarker) to High(TVectArtLineMarker) do
    if SameText(Trim(Value), LineMarkerName(Candidate)) then
    begin
      Marker := Candidate;
      Exit(True);
    end;
  Result := False;
end;

function SvgMarkerBody(Value: TVectArtLineMarker; MarkerSize: Single): string;
var
  OutlineWidth: string;
begin
  OutlineWidth := SvgNumber(6.0 / Max(MarkerSize, 1.0));
  case Value of
    vlmOpenArrow:
      Result := '<path d="M 0 0 L 4 2 L 0 4" fill="none" stroke="context-stroke" stroke-width="' +
        OutlineWidth + '"/>';
    vlmArrow:
      Result := '<path d="M 0 0 L 4 2 L 0 4 z" fill="context-stroke"/>';
    vlmWideArrow:
      Result := '<path d="M 0 -0.5 L 4 2 L 0 4.5 z" fill="context-stroke"/>';
    vlmCircle:
      Result := '<circle cx="2" cy="2" r="2" fill="context-stroke"/>';
    vlmDiamond:
      Result := '<path d="M 0 2 L 2 0 L 4 2 L 2 4 z" fill="context-stroke"/>';
    vlmConcaveArrow:
      Result := '<path d="M 0 0 L 4 2 L 0 4 L 1.4 2 z" fill="context-stroke"/>';
    vlmSmallArrow:
      Result := '<path d="M 1 1 L 4 2 L 1 3 z" fill="context-stroke"/>';
    vlmSlash:
      Result := '<path d="M 2 0 L 2 4" fill="none" stroke="context-stroke" stroke-width="' +
        OutlineWidth + '"/>';
    vlmStar:
      Result := '<path d="M 4 2 L 2.65 2.47 L 2.62 3.9 L 1.75 2.76 L 0.38 3.18 L 1.2 2 L 0.38 0.82 L 1.75 1.24 L 2.62 0.1 L 2.65 1.53 z" fill="context-stroke"/>';
  else
    Result := '';
  end;
end;

function TryCreateVectArtSvg(Document: TVectArtDocument; out SvgText,
  ErrorMessage: string): Boolean;
var
  Builder: TStringBuilder;
  Canvas: TVectArtCanvasLayer;
  DashIndex: Integer;
  DashIntervals: TArray<Single>;
  I: Integer;
  Image: TVectArtImageLayer;
  Layer: TVectArtLayer;
  Line: TVectArtLineLayer;
  Path: TVectArtPathLayer;
  PointIndex: Integer;
  Rectangle: TVectArtRectangleLayer;
begin
  Result := False;
  SvgText := '';
  ErrorMessage := '';
  Builder := nil;
  try
    try
      if Document = nil then
        raise EArgumentNilException.Create('Document');
      Canvas := Document.CanvasLayer;
      if Canvas = nil then
        raise EInvalidOp.Create('Document canvas is missing');
      Builder := TStringBuilder.Create;
      Builder.AppendLine('<?xml version="1.0" encoding="UTF-8"?>');
      Builder.Append('<svg xmlns="').Append(SVG_NAMESPACE)
        .Append('" xmlns:vad="').Append(VAD_NAMESPACE).Append('"')
        .Append(' width="').Append(Canvas.Width).Append('"')
        .Append(' height="').Append(Canvas.Height).Append('"')
        .Append(' viewBox="0 0 ').Append(Canvas.Width).Append(' ')
        .Append(Canvas.Height).Append('"')
        .Append(' vad:version="').Append(VAD_FORMAT_VERSION).Append('"')
        .Append(' vad:background-color="')
        .Append(Integer(Canvas.BackgroundColor)).Append('"')
        .Append(' vad:transparent="').Append(BooleanText(Canvas.Transparent))
        .Append('" vad:selected-index="').Append(Document.SelectedIndex)
        .Append('"');
      if not Canvas.Transparent then
        Builder.Append(' style="background-color:')
          .Append(SvgColor(Canvas.BackgroundColor)).Append('"');
      Builder.AppendLine('>');
      Builder.AppendLine('  <defs>');
      for I := 1 to Document.LayerCount - 1 do
        if Document[I] is TVectArtLineLayer then
        begin
          Line := TVectArtLineLayer(Document[I]);
          if Line.EndMarker <> vlmNone then
            Builder.Append('    <marker id="vad-end-marker-').Append(I)
              .Append('" markerWidth="').Append(SvgNumber(Line.EndMarkerSize))
              .Append('" markerHeight="').Append(SvgNumber(Line.EndMarkerSize))
              .Append('" refX="4" refY="2" viewBox="-1 -1 6 6" orient="auto" markerUnits="strokeWidth">')
              .Append(SvgMarkerBody(Line.EndMarker, Line.EndMarkerSize))
              .AppendLine('</marker>');
          if Line.StartMarker <> vlmNone then
            Builder.Append('    <marker id="vad-start-marker-').Append(I)
              .Append('" markerWidth="').Append(SvgNumber(Line.StartMarkerSize))
              .Append('" markerHeight="').Append(SvgNumber(Line.StartMarkerSize))
              .Append('" refX="4" refY="2" viewBox="-1 -1 6 6" orient="auto-start-reverse" markerUnits="strokeWidth">')
              .Append(SvgMarkerBody(Line.StartMarker, Line.StartMarkerSize))
              .AppendLine('</marker>');
        end;
      Builder.AppendLine('  </defs>');
      for I := 1 to Document.LayerCount - 1 do
      begin
        Layer := Document[I];
        if Layer is TVectArtImageLayer then
        begin
          Image := TVectArtImageLayer(Layer);
          Builder.Append('  <image x="0" y="0" width="1" height="1"')
            .Append(' preserveAspectRatio="none" href="data:image/png;base64,')
            .Append(TNetEncoding.Base64.EncodeBytesToString(Image.PngData))
            .Append('" transform="matrix(')
            .Append(SvgNumber(Image.Points[1].X - Image.Points[0].X))
            .Append(' ')
            .Append(SvgNumber(Image.Points[1].Y - Image.Points[0].Y))
            .Append(' ')
            .Append(SvgNumber(Image.Points[3].X - Image.Points[0].X))
            .Append(' ')
            .Append(SvgNumber(Image.Points[3].Y - Image.Points[0].Y))
            .Append(' ').Append(SvgNumber(Image.Points[0].X))
            .Append(' ').Append(SvgNumber(Image.Points[0].Y))
            .Append(')" opacity="').Append(SvgNumber(Image.Opacity))
            .Append('" vad:name="').Append(XmlEscape(Image.Name))
            .Append('" vad:locked="').Append(BooleanText(Image.Locked))
            .Append('" vad:source-kind="');
          if Image.SourceKind = visLogo then
            Builder.Append('logo')
          else
            Builder.Append('image');
          Builder.Append('"');
          if not Image.Visible then
            Builder.Append(' display="none"');
          Builder.Append('><title>').Append(XmlEscape(Image.Name))
            .AppendLine('</title></image>');
          Continue;
        end;
        if Layer is TVectArtLineLayer then
        begin
          Line := TVectArtLineLayer(Layer);
          Builder.Append('  <line x1="').Append(SvgNumber(Line.StartPoint.X))
            .Append('" y1="').Append(SvgNumber(Line.StartPoint.Y))
            .Append('" x2="').Append(SvgNumber(Line.EndPoint.X))
            .Append('" y2="').Append(SvgNumber(Line.EndPoint.Y))
            .Append('" fill="none" stroke="')
            .Append(SvgColor(Line.StrokeColor)).Append('" stroke-width="')
            .Append(SvgNumber(Line.StrokeWidth)).Append('" opacity="')
            .Append(SvgNumber(Line.Opacity)).Append('" vad:stroke-color="')
            .Append(Integer(Line.StrokeColor)).Append('" vad:stroke-style="')
            .Append(Ord(Line.StrokeStyle)).Append('" stroke-linecap="')
            .Append(SvgLineCap(Line.LineCap)).Append('" stroke-linejoin="')
            .Append(SvgLineJoin(Line.LineJoin)).Append('" vad:name="')
            .Append(XmlEscape(Line.Name)).Append('" vad:locked="')
            .Append(BooleanText(Line.Locked)).Append('"');
          if not Line.AntiAlias then
            Builder.Append(' shape-rendering="crispEdges"');
          if Line.EndMarker <> vlmNone then
            Builder.Append(' marker-end="url(#vad-end-marker-').Append(I)
              .Append(')" vad:end-marker="').Append(LineMarkerName(Line.EndMarker))
              .Append('" vad:end-marker-size="')
              .Append(SvgNumber(Line.EndMarkerSize)).Append('"');
          if Line.StartMarker <> vlmNone then
            Builder.Append(' marker-start="url(#vad-start-marker-').Append(I)
              .Append(')" vad:start-marker="').Append(LineMarkerName(Line.StartMarker))
              .Append('" vad:start-marker-size="')
              .Append(SvgNumber(Line.StartMarkerSize)).Append('"');
          DashIntervals := VectArtStrokeDashIntervals(Line.StrokeStyle,
            Line.StrokeWidth);
          if Length(DashIntervals) > 0 then
          begin
            Builder.Append(' stroke-dasharray="');
            for DashIndex := 0 to High(DashIntervals) do
            begin
              if DashIndex > 0 then
                Builder.Append(' ');
              Builder.Append(SvgNumber(DashIntervals[DashIndex]));
            end;
            Builder.Append('"');
          end;
          if not Line.Visible then
            Builder.Append(' display="none"');
          Builder.Append('><title>').Append(XmlEscape(Line.Name))
            .AppendLine('</title></line>');
          Continue;
        end;
        if Layer is TVectArtPathLayer then
        begin
          Path := TVectArtPathLayer(Layer);
          if Path.Closed then
            Builder.Append('  <polygon points="')
          else
            Builder.Append('  <polyline points="');
          for PointIndex := 0 to High(Path.Points) do
          begin
            if PointIndex > 0 then
              Builder.Append(' ');
            Builder.Append(SvgNumber(Path.Points[PointIndex].X)).Append(',')
              .Append(SvgNumber(Path.Points[PointIndex].Y));
          end;
          Builder.Append('" fill="');
          if Path.Filled and Path.Closed then
            Builder.Append(SvgColor(Path.FillColor))
          else
            Builder.Append('none');
          Builder.Append('"');
          if Path.StrokeWidth > 0 then
          begin
            Builder.Append(' stroke="').Append(SvgColor(Path.StrokeColor))
              .Append('" stroke-width="').Append(SvgNumber(Path.StrokeWidth))
              .Append('" vad:stroke-color="')
              .Append(Integer(Path.StrokeColor))
              .Append('" vad:stroke-style="')
              .Append(Ord(Path.StrokeStyle)).Append('"');
            DashIntervals := VectArtStrokeDashIntervals(Path.StrokeStyle,
              Path.StrokeWidth);
            if Length(DashIntervals) > 0 then
            begin
              Builder.Append(' stroke-dasharray="');
              for DashIndex := 0 to High(DashIntervals) do
              begin
                if DashIndex > 0 then
                  Builder.Append(' ');
                Builder.Append(SvgNumber(DashIntervals[DashIndex]));
              end;
              Builder.Append('"');
            end;
          end
          else
            Builder.Append(' stroke="none"');
          Builder.Append(' opacity="').Append(SvgNumber(Path.Opacity))
            .Append('" vad:fill-color="').Append(Integer(Path.FillColor))
            .Append('" vad:name="').Append(XmlEscape(Path.Name))
            .Append('" vad:locked="').Append(BooleanText(Path.Locked))
            .Append('"');
          if not Path.Visible then
            Builder.Append(' display="none"');
          if Path.Closed then
            Builder.Append('><title>').Append(XmlEscape(Path.Name))
              .AppendLine('</title></polygon>')
          else
            Builder.Append('><title>').Append(XmlEscape(Path.Name))
              .AppendLine('</title></polyline>');
          Continue;
        end;
        if not (Layer is TVectArtRectangleLayer) then
          Continue;
        Rectangle := TVectArtRectangleLayer(Layer);
        Builder.Append('  <rect x="').Append(SvgNumber(Rectangle.Bounds.Left))
          .Append('" y="').Append(SvgNumber(Rectangle.Bounds.Top))
          .Append('" width="').Append(SvgNumber(Rectangle.Bounds.Width))
          .Append('" height="').Append(SvgNumber(Rectangle.Bounds.Height))
          .Append('" fill="').Append(SvgColor(Rectangle.FillColor))
          .Append('" opacity="').Append(SvgNumber(Rectangle.Opacity))
          .Append('" vad:fill-color="')
          .Append(Integer(Rectangle.FillColor))
          .Append('"');
        if Rectangle.StrokeWidth > 0 then
        begin
          Builder.Append(' stroke="').Append(SvgColor(Rectangle.StrokeColor))
            .Append('" stroke-width="').Append(SvgNumber(Rectangle.StrokeWidth))
            .Append('" vad:stroke-color="')
            .Append(Integer(Rectangle.StrokeColor))
            .Append('" vad:stroke-style="')
            .Append(Ord(Rectangle.StrokeStyle)).Append('"');
          DashIntervals := VectArtStrokeDashIntervals(
            Rectangle.StrokeStyle, Rectangle.StrokeWidth);
          if Length(DashIntervals) > 0 then
          begin
            Builder.Append(' stroke-dasharray="');
            for DashIndex := 0 to High(DashIntervals) do
            begin
              if DashIndex > 0 then
                Builder.Append(' ');
              Builder.Append(SvgNumber(DashIntervals[DashIndex]));
            end;
            Builder.Append('"');
          end;
        end
        else
          Builder.Append(' stroke="none"');
        Builder
          .Append(' vad:name="').Append(XmlEscape(Rectangle.Name))
          .Append('" vad:locked="').Append(BooleanText(Rectangle.Locked))
          .Append('"');
        if not SameValue(Rectangle.RotationDegrees, 0.0) then
          Builder.Append(' transform="rotate(')
            .Append(SvgNumber(Rectangle.RotationDegrees)).Append(' ')
            .Append(SvgNumber((Rectangle.Bounds.Left +
              Rectangle.Bounds.Right) * 0.5)).Append(' ')
            .Append(SvgNumber((Rectangle.Bounds.Top +
              Rectangle.Bounds.Bottom) * 0.5)).Append(')"');
        if not Rectangle.Visible then
          Builder.Append(' display="none"');
        Builder.Append('><title>').Append(XmlEscape(Rectangle.Name))
          .AppendLine('</title></rect>');
      end;
      Builder.AppendLine('</svg>');
      SvgText := Builder.ToString;
      Result := True;
    except
      on E: Exception do
        ErrorMessage := E.Message;
    end;
  finally
    Builder.Free;
  end;
end;

function LocalNodeName(const Node: IXMLNode): string;
var
  SeparatorIndex: Integer;
begin
  Result := Node.NodeName;
  SeparatorIndex := Result.IndexOf(':');
  if SeparatorIndex >= 0 then
    Result := Result.Substring(SeparatorIndex + 1);
end;

function TryGetAttribute(const Node: IXMLNode; const Name: string;
  out Value: string): Boolean;
begin
  Result := (Node <> nil) and Node.HasAttribute(Name);
  if Result then
    Value := VarToStr(Node.Attributes[Name])
  else
    Value := '';
end;

function TryGetStyleValue(const Node: IXMLNode; const RequiredName: string;
  out Value: string): Boolean;
var
  I: Integer;
  Name: string;
  Pair: string;
  SeparatorIndex: Integer;
  Style: string;
  Values: TStringList;
begin
  Result := False;
  Value := '';
  if not TryGetAttribute(Node, 'style', Style) then
    Exit;
  Values := TStringList.Create;
  try
    Values.StrictDelimiter := True;
    Values.Delimiter := ';';
    Values.DelimitedText := Style;
    for I := 0 to Values.Count - 1 do
    begin
      Pair := Values[I];
      SeparatorIndex := Pair.IndexOf(':');
      if SeparatorIndex < 0 then
        Continue;
      Name := Trim(Pair.Substring(0, SeparatorIndex));
      if SameText(Name, RequiredName) then
      begin
        Value := Trim(Pair.Substring(SeparatorIndex + 1));
        Exit(True);
      end;
    end;
  finally
    Values.Free;
  end;
end;

function TryGetPresentationValue(const Node: IXMLNode; const Name: string;
  out Value: string): Boolean;
begin
  Result := TryGetStyleValue(Node, Name, Value);
  if not Result then
    Result := TryGetAttribute(Node, Name, Value);
end;

function TryParseSvgNumber(const Text: string; out Value: Single): Boolean;
var
  FormatSettings: TFormatSettings;
  NumberText: string;
begin
  NumberText := Trim(Text);
  if NumberText.EndsWith('px', True) then
    Delete(NumberText, Length(NumberText) - 1, 2);
  FormatSettings := TFormatSettings.Create;
  FormatSettings.DecimalSeparator := '.';
  FormatSettings.ThousandSeparator := #0;
  Result := TryStrToFloat(Trim(NumberText), Value, FormatSettings) and
    not IsNan(Value) and not IsInfinite(Value);
end;

function TryParseBoolean(const Text: string; out Value: Boolean): Boolean;
begin
  Result := SameText(Trim(Text), 'true') or (Trim(Text) = '1') or
    SameText(Trim(Text), 'false') or (Trim(Text) = '0');
  if Result then
    Value := SameText(Trim(Text), 'true') or (Trim(Text) = '1')
  else
    Value := False;
end;

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

function RectangleName(const Node: IXMLNode; Index: Integer): string;
var
  Child: IXMLNode;
  I: Integer;
begin
  for I := 0 to Node.ChildNodes.Count - 1 do
  begin
    Child := Node.ChildNodes[I];
    if SameText(LocalNodeName(Child), 'title') and (Trim(Child.Text) <> '') then
      Exit(Child.Text);
  end;
  if TryGetAttribute(Node, 'vad:name', Result) and (Result <> '') then
    Exit;
  if TryGetAttribute(Node, 'id', Result) and (Result <> '') then
    Exit;
  Result := Format('Rectangle %d', [Index]);
end;

function ImageName(const Node: IXMLNode; Index: Integer): string;
var
  Child: IXMLNode;
  I: Integer;
begin
  for I := 0 to Node.ChildNodes.Count - 1 do
  begin
    Child := Node.ChildNodes[I];
    if SameText(LocalNodeName(Child), 'title') and (Trim(Child.Text) <> '') then
      Exit(Child.Text);
  end;
  if TryGetAttribute(Node, 'vad:name', Result) and (Result <> '') then
    Exit;
  if TryGetAttribute(Node, 'id', Result) and (Result <> '') then
    Exit;
  Result := Format('Image %d', [Index]);
end;

function TryParseSvgMatrix(const Text: string; out A, B, C, D, E,
  F: Single): Boolean;
var
  CloseIndex: Integer;
  I: Integer;
  OpenIndex: Integer;
  Parts: TStringList;
  ValueText: string;
begin
  Result := False;
  ValueText := Trim(Text);
  OpenIndex := ValueText.IndexOf('(');
  CloseIndex := ValueText.LastIndexOf(')');
  if (OpenIndex < 0) or (CloseIndex <= OpenIndex) or
    (Trim(ValueText.Substring(CloseIndex + 1)) <> '') or
    not SameText(Trim(ValueText.Substring(0, OpenIndex)), 'matrix') then
    Exit;
  ValueText := ValueText.Substring(OpenIndex + 1,
    CloseIndex - OpenIndex - 1).Replace(',', ' ');
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ' ';
    Parts.DelimitedText := ValueText;
    for I := Parts.Count - 1 downto 0 do
      if Trim(Parts[I]) = '' then
        Parts.Delete(I);
    Result := (Parts.Count = 6) and
      TryParseSvgNumber(Parts[0], A) and
      TryParseSvgNumber(Parts[1], B) and
      TryParseSvgNumber(Parts[2], C) and
      TryParseSvgNumber(Parts[3], D) and
      TryParseSvgNumber(Parts[4], E) and
      TryParseSvgNumber(Parts[5], F);
  finally
    Parts.Free;
  end;
end;

function TransformSvgPoint(const Point: TPointF; A, B, C, D, E,
  F: Single): TPointF;
begin
  Result := TPointF.Create(A * Point.X + C * Point.Y + E,
    B * Point.X + D * Point.Y + F);
end;

function TryParseImage(const Node: IXMLNode; Index: Integer;
  out Data: TVectArtImageData): Boolean;
const
  PNG_DATA_PREFIX = 'data:image/png;base64,';
var
  A: Single;
  B: Single;
  C: Single;
  D: Single;
  DisplayValue: string;
  E: Single;
  F: Single;
  Height: Single;
  Href: string;
  LockedText: string;
  OpacityText: string;
  SourceKindText: string;
  TransformText: string;
  ValueText: string;
  VisibilityValue: string;
  Width: Single;
  X: Single;
  Y: Single;
begin
  Result := False;
  if not TryGetAttribute(Node, 'href', Href) then
    if not TryGetAttribute(Node, 'xlink:href', Href) then
      Exit;
  if not SameText(Copy(Href, 1, Length(PNG_DATA_PREFIX)), PNG_DATA_PREFIX) then
    Exit;
  Data.PngData := TNetEncoding.Base64.DecodeStringToBytes(
    Copy(Href, Length(PNG_DATA_PREFIX) + 1, MaxInt));
  if Length(Data.PngData) = 0 then
    Exit;
  if not TryGetAttribute(Node, 'x', ValueText) then
    ValueText := '0';
  if not TryParseSvgNumber(ValueText, X) then
    Exit;
  if not TryGetAttribute(Node, 'y', ValueText) then
    ValueText := '0';
  if not TryParseSvgNumber(ValueText, Y) then
    Exit;
  if not TryGetAttribute(Node, 'width', ValueText) or
    not TryParseSvgNumber(ValueText, Width) or (Width <= 0) then
    Exit;
  if not TryGetAttribute(Node, 'height', ValueText) or
    not TryParseSvgNumber(ValueText, Height) or (Height <= 0) then
    Exit;
  A := 1;
  B := 0;
  C := 0;
  D := 1;
  E := 0;
  F := 0;
  if TryGetAttribute(Node, 'transform', TransformText) and
    not TryParseSvgMatrix(TransformText, A, B, C, D, E, F) then
    Exit;
  Data.Points[0] := TransformSvgPoint(PointF(X, Y), A, B, C, D, E, F);
  Data.Points[1] := TransformSvgPoint(PointF(X + Width, Y),
    A, B, C, D, E, F);
  Data.Points[2] := TransformSvgPoint(PointF(X + Width, Y + Height),
    A, B, C, D, E, F);
  Data.Points[3] := TransformSvgPoint(PointF(X, Y + Height),
    A, B, C, D, E, F);
  Data.Name := ImageName(Node, Index);
  Data.SourceKind := visImage;
  if TryGetAttribute(Node, 'vad:source-kind', SourceKindText) and
    SameText(Trim(SourceKindText), 'logo') then
    Data.SourceKind := visLogo;
  Data.Opacity := 1.0;
  if TryGetPresentationValue(Node, 'opacity', OpacityText) and
    not TryParseSvgNumber(OpacityText, Data.Opacity) then
    Exit;
  Data.Opacity := EnsureRange(Data.Opacity, 0.0, 1.0);
  Data.Visible := True;
  if TryGetPresentationValue(Node, 'display', DisplayValue) then
    Data.Visible := not SameText(Trim(DisplayValue), 'none');
  if TryGetPresentationValue(Node, 'visibility', VisibilityValue) then
    Data.Visible := Data.Visible and
      not SameText(Trim(VisibilityValue), 'hidden') and
      not SameText(Trim(VisibilityValue), 'collapse');
  Data.Locked := False;
  if TryGetAttribute(Node, 'vad:locked', LockedText) then
    TryParseBoolean(LockedText, Data.Locked);
  Result := True;
end;

function TryParseRotation(const Node: IXMLNode; var Bounds: TRectF;
  out Angle: Single): Boolean;
var
  CloseIndex: Integer;
  Center: TPointF;
  I: Integer;
  NewCenter: TPointF;
  OpenIndex: Integer;
  Parts: TStringList;
  Pivot: TPointF;
  TransformText: string;
begin
  Angle := 0.0;
  if not TryGetAttribute(Node, 'transform', TransformText) then
    Exit(True);
  TransformText := Trim(TransformText);
  OpenIndex := TransformText.IndexOf('(');
  CloseIndex := TransformText.LastIndexOf(')');
  if (OpenIndex < 0) or (CloseIndex <= OpenIndex) or
    not SameText(Trim(TransformText.Substring(0, OpenIndex)), 'rotate') then
    Exit(False);
  TransformText := TransformText.Substring(OpenIndex + 1,
    CloseIndex - OpenIndex - 1).Replace(',', ' ');
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ' ';
    Parts.DelimitedText := TransformText;
    for I := Parts.Count - 1 downto 0 do
      if Parts[I] = '' then
        Parts.Delete(I);
    Result := (Parts.Count in [1, 3]) and
      TryParseSvgNumber(Parts[0], Angle);
    if not Result then
      Exit;
    Pivot := TPointF.Create(0, 0);
    if Parts.Count = 3 then
      Result := TryParseSvgNumber(Parts[1], Pivot.X) and
        TryParseSvgNumber(Parts[2], Pivot.Y);
    if Result then
    begin
      Center := TPointF.Create((Bounds.Left + Bounds.Right) * 0.5,
        (Bounds.Top + Bounds.Bottom) * 0.5);
      NewCenter := RotatePointAround(Center, Pivot, Angle);
      Bounds.Offset(NewCenter.X - Center.X, NewCenter.Y - Center.Y);
    end;
  finally
    Parts.Free;
  end;
end;

function TryParseRectangle(const Node: IXMLNode; Index: Integer;
  out Data: TVectArtRectangleData): Boolean;
var
  DisplayValue: string;
  FillOpacity: Single;
  FillInteger: Integer;
  FillText: string;
  Height: Single;
  LockedText: string;
  Opacity: Single;
  OpacityText: string;
  StrokeInteger: Integer;
  StrokeStyleInteger: Integer;
  StrokeText: string;
  StrokeWidth: Single;
  ValueText: string;
  VisibilityValue: string;
  Width: Single;
  X: Single;
  Y: Single;
begin
  Result := False;
  if not TryGetAttribute(Node, 'x', ValueText) then
    ValueText := '0';
  if not TryParseSvgNumber(ValueText, X) then
    Exit;
  if not TryGetAttribute(Node, 'y', ValueText) then
    ValueText := '0';
  if not TryParseSvgNumber(ValueText, Y) then
    Exit;
  if not TryGetAttribute(Node, 'width', ValueText) or
    not TryParseSvgNumber(ValueText, Width) or (Width < 0) then
    Exit;
  if not TryGetAttribute(Node, 'height', ValueText) or
    not TryParseSvgNumber(ValueText, Height) or (Height < 0) then
    Exit;
  FillText := 'black';
  TryGetPresentationValue(Node, 'fill', FillText);
  if SameText(Trim(FillText), 'none') or
    not TryParseSvgColor(FillText, Data.FillColor) then
    Exit;
  if TryGetAttribute(Node, 'vad:fill-color', ValueText) and
    TryStrToInt(ValueText, FillInteger) and
    (ColorToRGB(TColor(FillInteger)) = ColorToRGB(Data.FillColor)) then
    Data.FillColor := TColor(FillInteger);
  Data.StrokeColor := clBlack;
  Data.StrokeStyle := vssSolid;
  Data.StrokeWidth := 0.0;
  StrokeText := 'none';
  if TryGetPresentationValue(Node, 'stroke', StrokeText) and
    not SameText(Trim(StrokeText), 'none') then
  begin
    if not TryParseSvgColor(StrokeText, Data.StrokeColor) then
      Exit;
    if TryGetAttribute(Node, 'vad:stroke-color', ValueText) and
      TryStrToInt(ValueText, StrokeInteger) and
      (ColorToRGB(TColor(StrokeInteger)) =
       ColorToRGB(Data.StrokeColor)) then
      Data.StrokeColor := TColor(StrokeInteger);
    StrokeWidth := 1.0;
    if TryGetPresentationValue(Node, 'stroke-width', ValueText) and
      (not TryParseSvgNumber(ValueText, StrokeWidth) or (StrokeWidth < 0)) then
      Exit;
    Data.StrokeWidth := StrokeWidth;
    if TryGetAttribute(Node, 'vad:stroke-style', ValueText) and
      TryStrToInt(ValueText, StrokeStyleInteger) and
      InRange(StrokeStyleInteger, Ord(Low(TVectArtStrokeStyle)),
        Ord(High(TVectArtStrokeStyle))) then
      Data.StrokeStyle := TVectArtStrokeStyle(StrokeStyleInteger)
    else if TryGetPresentationValue(Node, 'stroke-dasharray', ValueText) and
      (Trim(ValueText) <> '') and not SameText(Trim(ValueText), 'none') then
      Data.StrokeStyle := vssDashed;
  end;
  Opacity := 1.0;
  if TryGetPresentationValue(Node, 'opacity', OpacityText) and
    not TryParseSvgNumber(OpacityText, Opacity) then
    Exit;
  FillOpacity := 1.0;
  if TryGetPresentationValue(Node, 'fill-opacity', OpacityText) and
    not TryParseSvgNumber(OpacityText, FillOpacity) then
    Exit;
  Data.Bounds := TRectF.Create(X, Y, X + Width, Y + Height);
  Data.Name := RectangleName(Node, Index);
  Data.Opacity := EnsureRange(Opacity * FillOpacity, 0.0, 1.0);
  if not TryParseRotation(Node, Data.Bounds, Data.RotationDegrees) then
    Exit;
  Data.Visible := True;
  if TryGetPresentationValue(Node, 'display', DisplayValue) then
    Data.Visible := not SameText(Trim(DisplayValue), 'none');
  if TryGetPresentationValue(Node, 'visibility', VisibilityValue) then
    Data.Visible := Data.Visible and
      not SameText(Trim(VisibilityValue), 'hidden') and
      not SameText(Trim(VisibilityValue), 'collapse');
  Data.Locked := False;
  if TryGetAttribute(Node, 'vad:locked', LockedText) then
    TryParseBoolean(LockedText, Data.Locked);
  Result := True;
end;

function TryParseLine(const Node: IXMLNode; Index: Integer;
  out Data: TVectArtLineData): Boolean;
var
  DisplayValue: string;
  LineCapText: string;
  LineJoinText: string;
  LockedText: string;
  OpacityText: string;
  StrokeInteger: Integer;
  StrokeStyleInteger: Integer;
  StrokeText: string;
  ValueText: string;
  VisibilityValue: string;
begin
  Result := TryGetAttribute(Node, 'x1', ValueText) and
    TryParseSvgNumber(ValueText, Data.StartPoint.X) and
    TryGetAttribute(Node, 'y1', ValueText) and
    TryParseSvgNumber(ValueText, Data.StartPoint.Y) and
    TryGetAttribute(Node, 'x2', ValueText) and
    TryParseSvgNumber(ValueText, Data.EndPoint.X) and
    TryGetAttribute(Node, 'y2', ValueText) and
    TryParseSvgNumber(ValueText, Data.EndPoint.Y);
  if not Result then
    Exit;
  StrokeText := 'black';
  TryGetPresentationValue(Node, 'stroke', StrokeText);
  if SameText(Trim(StrokeText), 'none') or
    not TryParseSvgColor(StrokeText, Data.StrokeColor) then
    Exit(False);
  if TryGetAttribute(Node, 'vad:stroke-color', ValueText) and
    TryStrToInt(ValueText, StrokeInteger) and
    (ColorToRGB(TColor(StrokeInteger)) =
     ColorToRGB(Data.StrokeColor)) then
    Data.StrokeColor := TColor(StrokeInteger);
  Data.StrokeWidth := 1.0;
  if TryGetPresentationValue(Node, 'stroke-width', ValueText) and
    (not TryParseSvgNumber(ValueText, Data.StrokeWidth) or
     (Data.StrokeWidth <= 0)) then
    Exit(False);
  Data.StrokeStyle := vssSolid;
  if TryGetAttribute(Node, 'vad:stroke-style', ValueText) and
    TryStrToInt(ValueText, StrokeStyleInteger) and
    InRange(StrokeStyleInteger, Ord(Low(TVectArtStrokeStyle)),
      Ord(High(TVectArtStrokeStyle))) then
    Data.StrokeStyle := TVectArtStrokeStyle(StrokeStyleInteger)
  else if TryGetPresentationValue(Node, 'stroke-dasharray', ValueText) and
    (Trim(ValueText) <> '') and not SameText(Trim(ValueText), 'none') then
    Data.StrokeStyle := vssDashed;
  Data.LineCap := vlcButt;
  if TryGetPresentationValue(Node, 'stroke-linecap', LineCapText) then
    if SameText(Trim(LineCapText), 'square') then
      Data.LineCap := vlcSquare
    else if SameText(Trim(LineCapText), 'round') then
      Data.LineCap := vlcRound;
  Data.LineJoin := vljMiter;
  if TryGetPresentationValue(Node, 'stroke-linejoin', LineJoinText) then
    if SameText(Trim(LineJoinText), 'bevel') then
      Data.LineJoin := vljBevel
    else if SameText(Trim(LineJoinText), 'round') then
      Data.LineJoin := vljRound;
  Data.AntiAlias := True;
  if TryGetPresentationValue(Node, 'shape-rendering', ValueText) and
    SameText(Trim(ValueText), 'crispEdges') then
    Data.AntiAlias := False;
  Data.EndMarker := vlmNone;
  Data.EndMarkerSize := 4.0;
  if TryGetAttribute(Node, 'vad:end-marker', ValueText) then
    TryParseLineMarkerName(ValueText, Data.EndMarker);
  if TryGetAttribute(Node, 'vad:end-marker-size', ValueText) then
    if not TryParseSvgNumber(ValueText, Data.EndMarkerSize) or
      (Data.EndMarkerSize < 1.0) then Data.EndMarkerSize := 4.0;
  Data.StartMarker := vlmNone;
  Data.StartMarkerSize := 4.0;
  if TryGetAttribute(Node, 'vad:start-marker', ValueText) then
    TryParseLineMarkerName(ValueText, Data.StartMarker);
  if TryGetAttribute(Node, 'vad:start-marker-size', ValueText) then
    if not TryParseSvgNumber(ValueText, Data.StartMarkerSize) or
      (Data.StartMarkerSize < 1.0) then Data.StartMarkerSize := 4.0;
  Data.Opacity := 1.0;
  if TryGetPresentationValue(Node, 'opacity', OpacityText) and
    not TryParseSvgNumber(OpacityText, Data.Opacity) then
    Exit(False);
  Data.Opacity := EnsureRange(Data.Opacity, 0.0, 1.0);
  Data.Name := RectangleName(Node, Index);
  Data.Visible := True;
  if TryGetPresentationValue(Node, 'display', DisplayValue) then
    Data.Visible := not SameText(Trim(DisplayValue), 'none');
  if TryGetPresentationValue(Node, 'visibility', VisibilityValue) then
    Data.Visible := Data.Visible and
      not SameText(Trim(VisibilityValue), 'hidden') and
      not SameText(Trim(VisibilityValue), 'collapse');
  Data.Locked := False;
  if TryGetAttribute(Node, 'vad:locked', LockedText) then
    TryParseBoolean(LockedText, Data.Locked);
  Result := True;
end;

function TryParsePath(const Node: IXMLNode; Index: Integer; Closed: Boolean;
  out Data: TVectArtPathData): Boolean;
var
  ColorInteger: Integer;
  DisplayValue: string;
  I: Integer;
  LockedText: string;
  OpacityText: string;
  Parts: TStringList;
  PointsText: string;
  StrokeStyleInteger: Integer;
  ValueText: string;
  VisibilityValue: string;
begin
  Result := False;
  if not TryGetAttribute(Node, 'points', PointsText) then
    Exit;
  PointsText := StringReplace(Trim(PointsText), ',', ' ', [rfReplaceAll]);
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ' ';
    Parts.DelimitedText := PointsText;
    for I := Parts.Count - 1 downto 0 do
      if Trim(Parts[I]) = '' then
        Parts.Delete(I);
    if (Parts.Count < 4) or Odd(Parts.Count) then
      Exit;
    SetLength(Data.Points, Parts.Count div 2);
    for I := 0 to High(Data.Points) do
      if not TryParseSvgNumber(Parts[I * 2], Data.Points[I].X) or
        not TryParseSvgNumber(Parts[I * 2 + 1], Data.Points[I].Y) then
        Exit;
  finally
    Parts.Free;
  end;
  Data.Closed := Closed;
  ValueText := 'none';
  TryGetPresentationValue(Node, 'fill', ValueText);
  Data.Filled := Closed and not SameText(Trim(ValueText), 'none');
  Data.FillColor := clWhite;
  if Data.Filled and not TryParseSvgColor(ValueText, Data.FillColor) then
    Exit;
  if TryGetAttribute(Node, 'vad:fill-color', ValueText) and
    TryStrToInt(ValueText, ColorInteger) and
    (not Data.Filled or (ColorToRGB(TColor(ColorInteger)) =
    ColorToRGB(Data.FillColor))) then
    Data.FillColor := TColor(ColorInteger);
  ValueText := 'none';
  TryGetPresentationValue(Node, 'stroke', ValueText);
  Data.StrokeWidth := 0.0;
  Data.StrokeColor := clBlack;
  if not SameText(Trim(ValueText), 'none') then
  begin
    if not TryParseSvgColor(ValueText, Data.StrokeColor) then
      Exit;
    Data.StrokeWidth := 1.0;
    if TryGetPresentationValue(Node, 'stroke-width', ValueText) and
      (not TryParseSvgNumber(ValueText, Data.StrokeWidth) or
      (Data.StrokeWidth < 0)) then
      Exit;
  end;
  if TryGetAttribute(Node, 'vad:stroke-color', ValueText) and
    TryStrToInt(ValueText, ColorInteger) and
    (ColorToRGB(TColor(ColorInteger)) = ColorToRGB(Data.StrokeColor)) then
    Data.StrokeColor := TColor(ColorInteger);
  Data.StrokeStyle := vssSolid;
  if TryGetAttribute(Node, 'vad:stroke-style', ValueText) and
    TryStrToInt(ValueText, StrokeStyleInteger) and
    InRange(StrokeStyleInteger, Ord(Low(TVectArtStrokeStyle)),
      Ord(High(TVectArtStrokeStyle))) then
    Data.StrokeStyle := TVectArtStrokeStyle(StrokeStyleInteger)
  else if TryGetPresentationValue(Node, 'stroke-dasharray', ValueText) and
    (Trim(ValueText) <> '') and not SameText(Trim(ValueText), 'none') then
    Data.StrokeStyle := vssDashed;
  Data.Opacity := 1.0;
  if TryGetPresentationValue(Node, 'opacity', OpacityText) and
    not TryParseSvgNumber(OpacityText, Data.Opacity) then
    Exit;
  Data.Opacity := EnsureRange(Data.Opacity, 0.0, 1.0);
  Data.Name := RectangleName(Node, Index);
  Data.Visible := True;
  if TryGetPresentationValue(Node, 'display', DisplayValue) then
    Data.Visible := not SameText(Trim(DisplayValue), 'none');
  if TryGetPresentationValue(Node, 'visibility', VisibilityValue) then
    Data.Visible := Data.Visible and
      not SameText(Trim(VisibilityValue), 'hidden') and
      not SameText(Trim(VisibilityValue), 'collapse');
  Data.Locked := False;
  if TryGetAttribute(Node, 'vad:locked', LockedText) then
    TryParseBoolean(LockedText, Data.Locked);
  Result := True;
end;

function TryReadCanvasSize(const Root: IXMLNode; out Width,
  Height: Integer): Boolean;
var
  HeightValue: Single;
  I: Integer;
  Part: string;
  Parts: TStringList;
  ValueText: string;
  ViewBox: string;
  WidthValue: Single;
begin
  Result := TryGetAttribute(Root, 'width', ValueText) and
    TryParseSvgNumber(ValueText, WidthValue) and
    TryGetAttribute(Root, 'height', ValueText) and
    TryParseSvgNumber(ValueText, HeightValue) and
    (WidthValue > 0) and (HeightValue > 0);
  if not Result and TryGetAttribute(Root, 'viewBox', ViewBox) then
  begin
    ViewBox := StringReplace(Trim(ViewBox), ',', ' ', [rfReplaceAll]);
    Parts := TStringList.Create;
    try
      Parts.StrictDelimiter := True;
      Parts.Delimiter := ' ';
      Parts.DelimitedText := ViewBox;
      for I := Parts.Count - 1 downto 0 do
      begin
        Part := Trim(Parts[I]);
        if Part = '' then
          Parts.Delete(I);
      end;
      Result := (Parts.Count = 4) and TryParseSvgNumber(Parts[2], WidthValue)
        and TryParseSvgNumber(Parts[3], HeightValue) and
        (WidthValue > 0) and (HeightValue > 0);
    finally
      Parts.Free;
    end;
  end;
  if Result then
  begin
    Width := Max(Round(WidthValue), 1);
    Height := Max(Round(HeightValue), 1);
  end
  else
  begin
    Width := 0;
    Height := 0;
  end;
end;

function TryLoadVectArtDocumentFromSvg(const SvgText: string;
  Document: TVectArtDocument; out ErrorMessage: string): Boolean;
var
  BackgroundColor: TColor;
  BackgroundInteger: Integer;
  BackgroundText: string;
  Canvas: TVectArtCanvasLayer;
  CanvasHeight: Integer;
  CanvasWidth: Integer;
  Child: IXMLNode;
  Data: TVectArtRectangleData;
  Discarded: TVectArtRectangleData;
  DiscardedImage: TVectArtImageData;
  DiscardedLine: TVectArtLineData;
  DiscardedPath: TVectArtPathData;
  I: Integer;
  ImageData: TVectArtImageData;
  Images: TList<TVectArtImageData>;
  LayerOrder: TList<Integer>;
  LineData: TVectArtLineData;
  Lines: TList<TVectArtLineData>;
  PathData: TVectArtPathData;
  Paths: TList<TVectArtPathData>;
  RectangleData: TList<TVectArtRectangleData>;
  Root: IXMLNode;
  SelectedIndex: Integer;
  StyleBackground: string;
  SvgDocument: IXMLDocument;
  SvgDocumentObject: TXMLDocument;
  Transparent: Boolean;
  TransparentText: string;
begin
  Result := False;
  ErrorMessage := '';
  RectangleData := TList<TVectArtRectangleData>.Create;
  Lines := TList<TVectArtLineData>.Create;
  Paths := TList<TVectArtPathData>.Create;
  Images := TList<TVectArtImageData>.Create;
  LayerOrder := TList<Integer>.Create;
  try
    try
      if Document = nil then
        raise EArgumentNilException.Create('Document');
      SvgDocumentObject := TXMLDocument.Create(nil);
      SvgDocumentObject.DOMVendor := GetDOMVendor(sOmniXmlVendor);
      SvgDocument := SvgDocumentObject;
      SvgDocument.LoadFromXML(SvgText);
      SvgDocument.Active := True;
      Root := SvgDocument.DocumentElement;
      if (Root = nil) or not SameText(LocalNodeName(Root), 'svg') then
        raise EConvertError.Create('SVG root element was not found');
      if not TryReadCanvasSize(Root, CanvasWidth, CanvasHeight) then
        raise EConvertError.Create('SVG canvas size is missing or unsupported');

      BackgroundColor := clWhite;
      if TryGetStyleValue(Root, 'background-color', StyleBackground) then
        TryParseSvgColor(StyleBackground, BackgroundColor);
      if TryGetAttribute(Root, 'vad:background-color', BackgroundText) and
        TryStrToInt(BackgroundText, BackgroundInteger) and
        (not TryGetStyleValue(Root, 'background-color', StyleBackground) or
        (ColorToRGB(TColor(BackgroundInteger)) =
        ColorToRGB(BackgroundColor))) then
        BackgroundColor := TColor(BackgroundInteger);
      Transparent := not TryGetStyleValue(Root, 'background-color',
        StyleBackground);
      if TryGetAttribute(Root, 'vad:transparent', TransparentText) then
        TryParseBoolean(TransparentText, Transparent);
      SelectedIndex := -1;
      if TryGetAttribute(Root, 'vad:selected-index', BackgroundText) then
        TryStrToInt(BackgroundText, SelectedIndex);

      for I := 0 to Root.ChildNodes.Count - 1 do
      begin
        Child := Root.ChildNodes[I];
        if Child.NodeType <> ntElement then
          Continue;
        if SameText(LocalNodeName(Child), 'rect') and
          TryParseRectangle(Child, RectangleData.Count + 1, Data) then
        begin
          RectangleData.Add(Data);
          LayerOrder.Add(RectangleData.Count);
        end
        else if SameText(LocalNodeName(Child), 'line') and
          TryParseLine(Child, Lines.Count + 1, LineData) then
        begin
          Lines.Add(LineData);
          LayerOrder.Add(-Lines.Count);
        end
        else if (SameText(LocalNodeName(Child), 'polyline') or
          SameText(LocalNodeName(Child), 'polygon')) and
          TryParsePath(Child, Paths.Count + 1,
            SameText(LocalNodeName(Child), 'polygon'), PathData) then
        begin
          Paths.Add(PathData);
          LayerOrder.Add(-(1000000 + Paths.Count));
        end
        else if SameText(LocalNodeName(Child), 'image') and
          TryParseImage(Child, Images.Count + 1, ImageData) then
        begin
          Images.Add(ImageData);
          LayerOrder.Add(-(2000000 + Images.Count));
        end;
      end;

      Canvas := Document.CanvasLayer;
      if Canvas = nil then
        raise EInvalidOp.Create('Document canvas is missing');
      while Document.LayerCount > 1 do
        if Document[Document.LayerCount - 1] is TVectArtRectangleLayer then
          Document.RemoveRectangle(Document.LayerCount - 1, Discarded)
        else if Document[Document.LayerCount - 1] is TVectArtLineLayer then
          Document.RemoveLine(Document.LayerCount - 1, DiscardedLine)
        else if Document[Document.LayerCount - 1] is TVectArtPathLayer then
          Document.RemovePath(Document.LayerCount - 1, DiscardedPath)
        else if Document[Document.LayerCount - 1] is TVectArtImageLayer then
          Document.RemoveImage(Document.LayerCount - 1, DiscardedImage)
        else
          raise EInvalidOp.Create('Document contains an unsupported layer');
      Canvas.Width := CanvasWidth;
      Canvas.Height := CanvasHeight;
      Canvas.BackgroundColor := BackgroundColor;
      Canvas.Transparent := Transparent;
      for I in LayerOrder do
        if I > 0 then
          Document.InsertRectangle(Document.LayerCount,
            RectangleData[I - 1])
        else if I <= -2000000 then
          Document.InsertImage(Document.LayerCount,
            Images[-I - 2000001])
        else if I <= -1000000 then
          Document.InsertPath(Document.LayerCount,
            Paths[-I - 1000001])
        else
          Document.InsertLine(Document.LayerCount, Lines[-I - 1]);
      Document.SelectedIndex := SelectedIndex;
      Document.Changed;
      Result := True;
    except
      on E: Exception do
        ErrorMessage := E.Message;
    end;
  finally
    LayerOrder.Free;
    Images.Free;
    Lines.Free;
    Paths.Free;
    RectangleData.Free;
  end;
end;

function TryLoadVectArtDocumentFromSvgFile(const FileName: string;
  Document: TVectArtDocument; out ErrorMessage: string): Boolean;
var
  SvgText: string;
begin
  Result := False;
  ErrorMessage := '';
  try
    SvgText := TFile.ReadAllText(FileName, TEncoding.UTF8);
    Result := TryLoadVectArtDocumentFromSvg(SvgText, Document, ErrorMessage);
  except
    on E: Exception do
      ErrorMessage := E.Message;
  end;
end;

function TrySaveVectArtDocumentToSvgFile(Document: TVectArtDocument;
  const FileName: string; out ErrorMessage: string): Boolean;
var
  Encoding: TUTF8Encoding;
  SvgText: string;
begin
  Result := TryCreateVectArtSvg(Document, SvgText, ErrorMessage);
  if not Result then
    Exit;
  Encoding := TUTF8Encoding.Create(False);
  try
    try
      TFile.WriteAllText(FileName, SvgText, Encoding);
      Result := True;
    except
      on E: Exception do
      begin
        ErrorMessage := E.Message;
        Result := False;
      end;
    end;
  finally
    Encoding.Free;
  end;
end;

end.
