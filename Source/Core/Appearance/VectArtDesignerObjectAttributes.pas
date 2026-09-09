// 見た目の属性を形状・配置・所属から分離し、作成と将来の属性貼付けで共有する。
// Documentの変更通知とUndoは呼出側が担当し、このユニットは値の取得・適用だけを行う。
unit VectArtDesignerObjectAttributes;
interface
uses Vcl.Graphics, VectArtDesignerDocument;
type
  TVectArtAttributeCategory = (vacNone, vacLine, vacShape, vacText);
  TVectArtObjectAttributes = record
    Shadow: TVectArtShadow;
    Category: TVectArtAttributeCategory;
    HasLineDetails: Boolean;
    Opacity: Single;
    StrokeColor: TColor;
    StrokeWidth: Single;
    StrokeStyle: TVectArtStrokeStyle;
    StrokePaint: TVectArtFillStyle;
    Filled: Boolean;
    FillColor: TColor;
    FillStyle: TVectArtFillStyle;
    LineCap: TVectArtLineCap;
    LineJoin: TVectArtLineJoin;
    AntiAlias: Boolean;
    StartMarker: TVectArtLineMarker;
    EndMarker: TVectArtLineMarker;
    StartMarkerSize: Single;
    EndMarkerSize: Single;
    FontFamily: string;
    FontSize: Single;
    FontStyle: TFontStyles;
    LetterSpacingRatio: Single;
    LineSpacingRatio: Single;
    TextColor: TColor;
    Vertical: Boolean;
  end;
function CaptureVectArtObjectAttributes(Source: TVectArtLayer): TVectArtObjectAttributes;
// 複数選択や非対応のレイヤーからは属性を取得せず、呼出側の初期値を維持する。
function CaptureVectArtSelectedAttributes(Document: TVectArtDocument): TVectArtObjectAttributes;
procedure ApplyVectArtObjectAttributes(const Attributes: TVectArtObjectAttributes;
  var Target: TVectArtRectangleData); overload;
procedure ApplyVectArtObjectAttributes(const Attributes: TVectArtObjectAttributes;
  var Target: TVectArtLineData); overload;
procedure ApplyVectArtObjectAttributes(const Attributes: TVectArtObjectAttributes;
  var Target: TVectArtPathData); overload;
procedure ApplyVectArtObjectAttributes(const Attributes: TVectArtObjectAttributes;
  var Target: TVectArtTextData); overload;
implementation
function ClonePaint(const Value: TVectArtFillStyle): TVectArtFillStyle;
begin
  Result := Value;
  // 画像バイトの書換えが取得元や他の貼付け先へ波及しないよう所有を分ける。
  Result.TexturePng := Copy(Value.TexturePng);
end;
function CaptureVectArtObjectAttributes(Source: TVectArtLayer): TVectArtObjectAttributes;
begin
  Result := Default(TVectArtObjectAttributes);
  if Source = nil then Exit;
  if Source is TVectArtRectangleLayer then
  begin
    Result.Shadow := Source.Shadow;
    Result.Category := vacShape;
    Result.Opacity := TVectArtRectangleLayer(Source).Opacity;
    Result.StrokeColor := TVectArtRectangleLayer(Source).StrokeColor;
    Result.StrokeWidth := TVectArtRectangleLayer(Source).StrokeWidth;
    Result.StrokeStyle := TVectArtRectangleLayer(Source).StrokeStyle;
    Result.StrokePaint := ClonePaint(TVectArtRectangleLayer(Source).StrokePaint);
    Result.Filled := TVectArtRectangleLayer(Source).Filled;
    Result.FillColor := TVectArtRectangleLayer(Source).FillColor;
    Result.FillStyle := ClonePaint(TVectArtRectangleLayer(Source).FillStyle);
    Exit;
  end;
  if Source is TVectArtLineLayer then
  begin
    Result.Category := vacLine;
    Result.HasLineDetails := True;
    Result.Opacity := TVectArtLineLayer(Source).Opacity;
    Result.StrokeColor := TVectArtLineLayer(Source).StrokeColor;
    Result.StrokeWidth := TVectArtLineLayer(Source).StrokeWidth;
    Result.StrokeStyle := TVectArtLineLayer(Source).StrokeStyle;
    Result.StrokePaint := ClonePaint(TVectArtLineLayer(Source).StrokePaint);
    Result.LineCap := TVectArtLineLayer(Source).LineCap;
    Result.LineJoin := TVectArtLineLayer(Source).LineJoin;
    Result.AntiAlias := TVectArtLineLayer(Source).AntiAlias;
    Result.StartMarker := TVectArtLineLayer(Source).StartMarker;
    Result.EndMarker := TVectArtLineLayer(Source).EndMarker;
    Result.StartMarkerSize := TVectArtLineLayer(Source).StartMarkerSize;
    Result.EndMarkerSize := TVectArtLineLayer(Source).EndMarkerSize;
    Exit;
  end;
  if Source is TVectArtPathLayer then
  begin
    Result.Category := vacLine;
    if TVectArtPathLayer(Source).Closed then
    begin
      Result.Category := vacShape;
      Result.Shadow := Source.Shadow;
    end;
    Result.HasLineDetails := True;
    Result.Opacity := TVectArtPathLayer(Source).Opacity;
    Result.StrokeColor := TVectArtPathLayer(Source).StrokeColor;
    Result.StrokeWidth := TVectArtPathLayer(Source).StrokeWidth;
    Result.StrokeStyle := TVectArtPathLayer(Source).StrokeStyle;
    Result.StrokePaint := ClonePaint(TVectArtPathLayer(Source).StrokePaint);
    Result.Filled := TVectArtPathLayer(Source).Filled;
    Result.FillColor := TVectArtPathLayer(Source).FillColor;
    Result.FillStyle := ClonePaint(TVectArtPathLayer(Source).FillStyle);
    Result.LineCap := TVectArtPathLayer(Source).LineCap;
    Result.LineJoin := TVectArtPathLayer(Source).LineJoin;
    Result.AntiAlias := TVectArtPathLayer(Source).AntiAlias;
    Result.StartMarker := TVectArtPathLayer(Source).StartMarker;
    Result.EndMarker := TVectArtPathLayer(Source).EndMarker;
    Result.StartMarkerSize := TVectArtPathLayer(Source).StartMarkerSize;
    Result.EndMarkerSize := TVectArtPathLayer(Source).EndMarkerSize;
    Exit;
  end;
  if Source is TVectArtTextLayer then
  begin
    Result.Category := vacText;
    Result.Opacity := TVectArtTextLayer(Source).Opacity;
    Result.FillStyle := ClonePaint(TVectArtTextLayer(Source).FillStyle);
    Result.FontFamily := TVectArtTextLayer(Source).FontFamily;
    Result.FontSize := TVectArtTextLayer(Source).FontSize;
    Result.FontStyle := TVectArtTextLayer(Source).FontStyle;
    Result.LetterSpacingRatio := TVectArtTextLayer(Source).LetterSpacingRatio;
    Result.LineSpacingRatio := TVectArtTextLayer(Source).LineSpacingRatio;
    Result.TextColor := TVectArtTextLayer(Source).TextColor;
    Result.Vertical := TVectArtTextLayer(Source).Vertical;
    Exit;
  end;
end;
function CaptureVectArtSelectedAttributes(Document: TVectArtDocument): TVectArtObjectAttributes;
var Selection: TArray<Integer>;
begin
  Result := Default(TVectArtObjectAttributes);
  if Document = nil then Exit;
  Selection := Document.GetSelectedLayerIndices;
  if Length(Selection) = 1 then
    Result := CaptureVectArtObjectAttributes(Document[Selection[0]]);
end;
procedure ApplyVectArtObjectAttributes(const Attributes: TVectArtObjectAttributes;
  var Target: TVectArtRectangleData);
begin
  if Attributes.Category <> vacShape then Exit;
  Target.Shadow := Attributes.Shadow;
  Target.Opacity := Attributes.Opacity;
  Target.StrokeColor := Attributes.StrokeColor;
  Target.StrokeWidth := Attributes.StrokeWidth;
  Target.StrokeStyle := Attributes.StrokeStyle;
  Target.StrokePaint := ClonePaint(Attributes.StrokePaint);
  Target.Filled := Attributes.Filled;
  Target.FillColor := Attributes.FillColor;
  Target.FillStyle := ClonePaint(Attributes.FillStyle);
end;
procedure ApplyVectArtObjectAttributes(const Attributes: TVectArtObjectAttributes;
  var Target: TVectArtLineData);
begin
  if Attributes.Category <> vacLine then Exit;
  Target.Opacity := Attributes.Opacity;
  Target.StrokeColor := Attributes.StrokeColor;
  Target.StrokeWidth := Attributes.StrokeWidth;
  Target.StrokeStyle := Attributes.StrokeStyle;
  Target.StrokePaint := ClonePaint(Attributes.StrokePaint);
  // 取得元が持たない属性をゼロ値で上書きしない。
  if Attributes.HasLineDetails then
  begin
    Target.LineCap := Attributes.LineCap;
    Target.LineJoin := Attributes.LineJoin;
    Target.AntiAlias := Attributes.AntiAlias;
    Target.StartMarker := Attributes.StartMarker;
    Target.EndMarker := Attributes.EndMarker;
    Target.StartMarkerSize := Attributes.StartMarkerSize;
    Target.EndMarkerSize := Attributes.EndMarkerSize;
  end;
end;
procedure ApplyVectArtObjectAttributes(const Attributes: TVectArtObjectAttributes;
  var Target: TVectArtPathData);
begin
  if Target.Closed then
  begin
    if Attributes.Category <> vacShape then Exit;
  end
  else if Attributes.Category <> vacLine then Exit;
  Target.Opacity := Attributes.Opacity;
  Target.StrokeColor := Attributes.StrokeColor;
  Target.StrokeWidth := Attributes.StrokeWidth;
  Target.StrokeStyle := Attributes.StrokeStyle;
  Target.StrokePaint := ClonePaint(Attributes.StrokePaint);
  if Target.Closed then
  begin
    Target.Shadow := Attributes.Shadow;
    Target.Filled := Attributes.Filled;
    Target.FillColor := Attributes.FillColor;
    Target.FillStyle := ClonePaint(Attributes.FillStyle);
  end;
  // 四角に存在しない線端・品質は、貼付け先の値を維持する。
  if Attributes.HasLineDetails then
  begin
    Target.LineCap := Attributes.LineCap;
    Target.LineJoin := Attributes.LineJoin;
    Target.AntiAlias := Attributes.AntiAlias;
    Target.StartMarker := Attributes.StartMarker;
    Target.EndMarker := Attributes.EndMarker;
    Target.StartMarkerSize := Attributes.StartMarkerSize;
    Target.EndMarkerSize := Attributes.EndMarkerSize;
  end;
end;
procedure ApplyVectArtObjectAttributes(const Attributes: TVectArtObjectAttributes;
  var Target: TVectArtTextData);
begin
  if Attributes.Category <> vacText then Exit;
  Target.Opacity := Attributes.Opacity;
  Target.FillStyle := ClonePaint(Attributes.FillStyle);
  Target.FontFamily := Attributes.FontFamily;
  Target.FontSize := Attributes.FontSize;
  Target.FontStyle := Attributes.FontStyle;
  Target.LetterSpacingRatio := Attributes.LetterSpacingRatio;
  Target.LineSpacingRatio := Attributes.LineSpacingRatio;
  Target.TextColor := Attributes.TextColor;
  Target.Vertical := Attributes.Vertical;
end;
end.
