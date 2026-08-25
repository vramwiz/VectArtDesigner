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
  System.SysUtils, System.Types, System.Variants, Vcl.Graphics, Winapi.Windows,
  Xml.omnixmldom, Xml.XMLDoc, Xml.XMLIntf, Xml.xmldom;

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

function TryCreateVectArtSvg(Document: TVectArtDocument; out SvgText,
  ErrorMessage: string): Boolean;
var
  Builder: TStringBuilder;
  Canvas: TVectArtCanvasLayer;
  I: Integer;
  Layer: TVectArtLayer;
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
      for I := 1 to Document.LayerCount - 1 do
      begin
        Layer := Document[I];
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
          .Append('" vad:name="').Append(XmlEscape(Rectangle.Name))
          .Append('" vad:locked="').Append(BooleanText(Rectangle.Locked))
          .Append('"');
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
  I: Integer;
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
        if (Child.NodeType = ntElement) and
          SameText(LocalNodeName(Child), 'rect') and
          TryParseRectangle(Child, RectangleData.Count + 1, Data) then
          RectangleData.Add(Data);
      end;

      Canvas := Document.CanvasLayer;
      if Canvas = nil then
        raise EInvalidOp.Create('Document canvas is missing');
      while Document.LayerCount > 1 do
        Document.RemoveRectangle(Document.LayerCount - 1, Discarded);
      Canvas.Width := CanvasWidth;
      Canvas.Height := CanvasHeight;
      Canvas.BackgroundColor := BackgroundColor;
      Canvas.Transparent := Transparent;
      for Data in RectangleData do
        Document.InsertRectangle(Document.LayerCount, Data);
      Document.SelectedIndex := SelectedIndex;
      Document.Changed;
      Result := True;
    except
      on E: Exception do
        ErrorMessage := E.Message;
    end;
  finally
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
