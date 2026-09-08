// Documentから標準SVG属性と編集用補助属性を生成する。
// 読込みやファイル置換を扱わず、文字列生成の失敗は呼び出し側へ返す。
unit VectArtDesignerSvgWriter;

interface

uses VectArtDesignerDocument;

function TryWriteVectArtSvg(Document: TVectArtDocument; out SvgText,
  ErrorMessage: string): Boolean;

implementation

uses VectArtDesignerFillPaint, System.SysUtils, System.Classes,
  System.Types, System.Math, System.NetEncoding,
  Vcl.Graphics, Winapi.Windows, VectArtDesignerSvgPrimitives, VectArtDesignerSvgPaintWriter,
  VectArtDesignerBezierGeometry, VectArtDesignerGeometry;

function XmlEscape(const Value: string): string;
begin
  Result := StringReplace(Value, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&apos;', [rfReplaceAll]);
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

procedure AppendSvgStroke(Builder: TStringBuilder; Color: TColor;
  Width: Single; Style: TVectArtStrokeStyle; const PaintRef: string);
var
  DashIndex: Integer;
  DashIntervals: TArray<Single>;
begin
  if Width <= 0 then
  begin
    Builder.Append(' stroke="none"');
    Exit;
  end;
  Builder.Append(' stroke="').Append(PaintRef)
    .Append('" stroke-width="').Append(SvgNumber(Width))
    .Append('" vad:stroke-color="').Append(Integer(Color))
    .Append('" vad:stroke-style="').Append(Ord(Style)).Append('"');
  DashIntervals := VectArtStrokeDashIntervals(Style, Width);
  if Length(DashIntervals) = 0 then
    Exit;
  Builder.Append(' stroke-dasharray="');
  for DashIndex := 0 to High(DashIntervals) do
  begin
    if DashIndex > 0 then
      Builder.Append(' ');
    Builder.Append(SvgNumber(DashIntervals[DashIndex]));
  end;
  Builder.Append('"');
end;

function TryWriteVectArtSvg(Document: TVectArtDocument; out SvgText,
  ErrorMessage: string): Boolean;
var
  A: Single;
  B: Single;
  Builder: TStringBuilder;
  C: Single;
  Canvas: TVectArtCanvasLayer;
  Cosine: Extended;
  D: Single;
  E: Single;
  F: Single;
  FlipX: Single;
  FlipY: Single;
  I: Integer;
  Image: TVectArtImageLayer;
  Layer: TVectArtLayer;
  Line: TVectArtLineLayer;
  Path: TVectArtPathLayer;
  PathDisplayPoints: TArray<TPointF>;
  PointIndex: Integer;
  Rectangle: TVectArtRectangleLayer;
  Radians: Extended;
  Sine: Extended;
  TextLayer: TVectArtTextLayer;
  TextLines: TArray<string>;
  TextLineIndex: Integer;
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
        end
        else if Document[I] is TVectArtPathLayer then
        begin
          Path := TVectArtPathLayer(Document[I]);
          if not Path.Closed and (Path.EndMarker <> vlmNone) then
            Builder.Append('    <marker id="vad-end-marker-').Append(I)
              .Append('" markerWidth="').Append(SvgNumber(Path.EndMarkerSize))
              .Append('" markerHeight="').Append(SvgNumber(Path.EndMarkerSize))
              .Append('" refX="4" refY="2" viewBox="-1 -1 6 6" orient="auto" markerUnits="strokeWidth">')
              .Append(SvgMarkerBody(Path.EndMarker, Path.EndMarkerSize))
              .AppendLine('</marker>');
          if not Path.Closed and (Path.StartMarker <> vlmNone) then
            Builder.Append('    <marker id="vad-start-marker-').Append(I)
              .Append('" markerWidth="').Append(SvgNumber(Path.StartMarkerSize))
              .Append('" markerHeight="').Append(SvgNumber(Path.StartMarkerSize))
              .Append('" refX="4" refY="2" viewBox="-1 -1 6 6" orient="auto-start-reverse" markerUnits="strokeWidth">')
              .Append(SvgMarkerBody(Path.StartMarker, Path.StartMarkerSize))
              .AppendLine('</marker>');
        end;
      for I := 1 to Document.LayerCount-1 do
        if Document[I] is TVectArtRectangleLayer then
        begin
          Rectangle := TVectArtRectangleLayer(Document[I]);
          Builder.AppendLine(FillDefinition(Rectangle.FillColor,Rectangle.FillStyle,I,Rectangle.Bounds));
        end
        else if Document[I] is TVectArtPathLayer then
        begin
          Path := TVectArtPathLayer(Document[I]);
          Builder.AppendLine(FillDefinition(Path.FillColor,Path.FillStyle,I,PointsBounds(BuildPathDisplayPolyline(Path.Points,Path.Bezier,Path.Closed,16))));
        end;
      for I := 1 to Document.LayerCount-1 do
      begin
        Layer := Document[I];
        if Layer is TVectArtRectangleLayer then
        begin
          Rectangle := TVectArtRectangleLayer(Layer);
          Builder.AppendLine(FillDefinition(Rectangle.StrokeColor,Rectangle.StrokePaint,-I,
            StrokePaintBounds(Rectangle.Bounds,Rectangle.StrokeWidth,Rectangle.StrokePaint.Kind),Rectangle.StrokeWidth*0.5));
        end
        else if Layer is TVectArtPathLayer then
        begin
          Path := TVectArtPathLayer(Layer);
          Builder.AppendLine(FillDefinition(Path.StrokeColor,Path.StrokePaint,-I,
            StrokePaintBounds(PointsBounds(BuildPathDisplayPolyline(Path.Points,Path.Bezier,Path.Closed,16)),Path.StrokeWidth,Path.StrokePaint.Kind),
            Max(Path.StrokeWidth,Max(Path.StartMarkerSize,Path.EndMarkerSize)*Path.StrokeWidth)));
        end
        else if Layer is TVectArtLineLayer then
        begin
          Line := TVectArtLineLayer(Layer);
          Builder.AppendLine(FillDefinition(Line.StrokeColor,Line.StrokePaint,-I,
            StrokePaintBounds(PointsBounds([Line.StartPoint,Line.EndPoint]),Line.StrokeWidth,Line.StrokePaint.Kind),
            Max(Line.StrokeWidth,Max(Line.StartMarkerSize,Line.EndMarkerSize)*Line.StrokeWidth)));
        end;
      end;
      for I := 1 to Document.LayerCount-1 do
        if Document[I] is TVectArtTextLayer then
        begin
          TextLayer := TVectArtTextLayer(Document[I]);
          Builder.AppendLine(FillDefinition(TextLayer.TextColor,TextLayer.FillStyle,-I,
            TextLayer.Bounds,0,True));
        end;
      Builder.AppendLine('  </defs>');
      for I := 1 to Document.LayerCount - 1 do
      begin
        Layer := Document[I];
        if Layer is TVectArtTextLayer then
        begin
          TextLayer := TVectArtTextLayer(Layer);
          Builder.Append('  <text x="').Append(SvgNumber(TextLayer.Bounds.Left))
            .Append('" y="').Append(SvgNumber(TextLayer.Bounds.Top +
              TextLayer.FontSize)).Append('" fill="')
            .Append(FillReference(TextLayer.TextColor,TextLayer.FillStyle,-I)).Append('" font-family="')
            .Append(XmlEscape(TextLayer.FontFamily)).Append('" font-size="')
            .Append(SvgNumber(TextLayer.FontSize)).Append('" letter-spacing="')
            .Append(SvgNumber(TextLayer.FontSize *
              TextLayer.LetterSpacingRatio)).Append('" opacity="')
            .Append(SvgNumber(TextLayer.Opacity)).Append('" vad:name="')
            .Append(XmlEscape(TextLayer.Name)).Append('" vad:locked="')
            .Append(BooleanText(TextLayer.Locked)).Append('" vad:width="')
            .Append(SvgNumber(TextLayer.Bounds.Width))
            .Append('" vad:height="')
            .Append(SvgNumber(TextLayer.Bounds.Height)).Append('"');
          Builder.Append(' vad:letter-spacing-ratio="')
            .Append(SvgNumber(TextLayer.LetterSpacingRatio))
            .Append('" vad:line-spacing-ratio="')
            .Append(SvgNumber(TextLayer.LineSpacingRatio)).Append('"');
          if fsBold in TextLayer.FontStyle then
            Builder.Append(' font-weight="bold"');
          if fsItalic in TextLayer.FontStyle then
            Builder.Append(' font-style="italic"');
          if TextLayer.Vertical then
            Builder.Append(' writing-mode="vertical-rl"');
          if TextLayer.FlipHorizontal or TextLayer.FlipVertical then
          begin
            Radians := DegToRad(TextLayer.RotationDegrees);
            SinCos(Radians, Sine, Cosine);
            if TextLayer.FlipHorizontal then FlipX := -1 else FlipX := 1;
            if TextLayer.FlipVertical then FlipY := -1 else FlipY := 1;
            A := Cosine * FlipX;
            B := Sine * FlipX;
            C := -Sine * FlipY;
            D := Cosine * FlipY;
            E := TextLayer.Bounds.CenterPoint.X -
              A * TextLayer.Bounds.CenterPoint.X -
              C * TextLayer.Bounds.CenterPoint.Y;
            F := TextLayer.Bounds.CenterPoint.Y -
              B * TextLayer.Bounds.CenterPoint.X -
              D * TextLayer.Bounds.CenterPoint.Y;
            Builder.Append(' transform="matrix(').Append(SvgNumber(A))
              .Append(' ').Append(SvgNumber(B)).Append(' ')
              .Append(SvgNumber(C)).Append(' ').Append(SvgNumber(D))
              .Append(' ').Append(SvgNumber(E)).Append(' ')
              .Append(SvgNumber(F)).Append(')"');
          end
          else if not SameValue(TextLayer.RotationDegrees, 0.0) then
            Builder.Append(' transform="rotate(')
              .Append(SvgNumber(TextLayer.RotationDegrees)).Append(' ')
              .Append(SvgNumber(TextLayer.Bounds.CenterPoint.X)).Append(' ')
              .Append(SvgNumber(TextLayer.Bounds.CenterPoint.Y)).Append(')"');
          if not TextLayer.Visible then
            Builder.Append(' display="none"');
          Builder.AppendLine('>');
          TextLines := StringReplace(TextLayer.Text, #13#10, #10,
            [rfReplaceAll]).Split([#10], TStringSplitOptions.None);
          for TextLineIndex := 0 to High(TextLines) do
            Builder.Append('    <tspan x="')
              .Append(SvgNumber(TextLayer.Bounds.Left)).Append('" dy="')
              .Append(SvgNumber(IfThen(TextLineIndex = 0, 0.0,
                TextLayer.FontSize * 1.2))).Append('">')
              .Append(XmlEscape(TextLines[TextLineIndex]))
              .AppendLine('</tspan>');
          Builder.Append('    <title>').Append(XmlEscape(TextLayer.Name))
            .AppendLine('</title>');
          Builder.AppendLine('  </text>');
          Continue;
        end;
        if Layer is TVectArtImageLayer then
        begin
          Image := TVectArtImageLayer(Layer);
          if not IsDecodablePng(Image.PngData) then
            raise EConvertError.CreateFmt(
              'Image layer "%s" does not contain a valid PNG',
              [Image.Name]);
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
          if Image.SourceFileName <> '' then
            Builder.Append(' vad:source-file="')
              .Append(XmlEscape(Image.SourceFileName)).Append('"');
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
            .Append('" fill="none"');
          AppendSvgStroke(Builder, Line.StrokeColor, Line.StrokeWidth,
            Line.StrokeStyle,FillReference(Line.StrokeColor,Line.StrokePaint,-I));
          Builder.Append(' opacity="').Append(SvgNumber(Line.Opacity))
            .Append('" stroke-linecap="')
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
          if not Line.Visible then
            Builder.Append(' display="none"');
          Builder.Append('><title>').Append(XmlEscape(Line.Name))
            .AppendLine('</title></line>');
          Continue;
        end;
        if Layer is TVectArtPathLayer then
        begin
          Path := TVectArtPathLayer(Layer);
          PathDisplayPoints := BuildPathDisplayPolyline(Path.Points,
            Path.Bezier, Path.Closed, 16);
          if Path.Closed then
            Builder.Append('  <polygon points="')
          else
            Builder.Append('  <polyline points="');
          for PointIndex := 0 to High(PathDisplayPoints) do
          begin
            if PointIndex > 0 then
              Builder.Append(' ');
            Builder.Append(SvgNumber(PathDisplayPoints[PointIndex].X))
              .Append(',').Append(SvgNumber(
              PathDisplayPoints[PointIndex].Y));
          end;
          Builder.Append('" fill="');
          if Path.Filled and Path.Closed then
            Builder.Append(FillReference(Path.FillColor,Path.FillStyle,I))
          else
            Builder.Append('none');
          Builder.Append('"');
          AppendSvgStroke(Builder, Path.StrokeColor, Path.StrokeWidth,
            Path.StrokeStyle,FillReference(Path.StrokeColor,Path.StrokePaint,-I));
          Builder.Append(' stroke-linecap="').Append(SvgLineCap(Path.LineCap))
            .Append('" stroke-linejoin="').Append(SvgLineJoin(Path.LineJoin))
            .Append('"');
          if not Path.AntiAlias then
            Builder.Append(' shape-rendering="crispEdges"');
          if not Path.Closed and (Path.EndMarker <> vlmNone) then
            Builder.Append(' marker-end="url(#vad-end-marker-').Append(I)
              .Append(')" vad:end-marker="')
              .Append(LineMarkerName(Path.EndMarker))
              .Append('" vad:end-marker-size="')
              .Append(SvgNumber(Path.EndMarkerSize)).Append('"');
          if not Path.Closed and (Path.StartMarker <> vlmNone) then
            Builder.Append(' marker-start="url(#vad-start-marker-').Append(I)
              .Append(')" vad:start-marker="')
              .Append(LineMarkerName(Path.StartMarker))
              .Append('" vad:start-marker-size="')
              .Append(SvgNumber(Path.StartMarkerSize)).Append('"');
          Builder.Append(' opacity="').Append(SvgNumber(Path.Opacity))
            .Append('" vad:fill-color="').Append(Integer(Path.FillColor))
            .Append('" vad:name="').Append(XmlEscape(Path.Name))
            .Append('" vad:locked="').Append(BooleanText(Path.Locked))
            .Append('" vad:bounds-editing="')
            .Append(BooleanText(Path.BoundsEditing))
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
        if Rectangle.Shape = vpsEllipse then
          Builder.Append('  <ellipse cx="').Append(SvgNumber(
            (Rectangle.Bounds.Left + Rectangle.Bounds.Right) * 0.5))
            .Append('" cy="').Append(SvgNumber(
            (Rectangle.Bounds.Top + Rectangle.Bounds.Bottom) * 0.5))
            .Append('" rx="').Append(SvgNumber(Abs(Rectangle.Bounds.Width) *
            0.5)).Append('" ry="').Append(SvgNumber(
            Abs(Rectangle.Bounds.Height) * 0.5)).Append('" fill="')
        else
          Builder.Append('  <rect x="').Append(SvgNumber(Rectangle.Bounds.Left))
            .Append('" y="').Append(SvgNumber(Rectangle.Bounds.Top))
            .Append('" width="').Append(SvgNumber(Rectangle.Bounds.Width))
            .Append('" height="').Append(SvgNumber(Rectangle.Bounds.Height))
            .Append('" fill="');
        if Rectangle.Filled then
          Builder.Append(FillReference(Rectangle.FillColor,Rectangle.FillStyle,I))
        else
          Builder.Append('none');
        Builder
          .Append('" opacity="').Append(SvgNumber(Rectangle.Opacity))
          .Append('" vad:fill-color="')
          .Append(Integer(Rectangle.FillColor))
          .Append('"');
        AppendSvgStroke(Builder, Rectangle.StrokeColor,
          Rectangle.StrokeWidth, Rectangle.StrokeStyle,
          FillReference(Rectangle.StrokeColor,Rectangle.StrokePaint,-I));
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
        Builder.Append('><title>').Append(XmlEscape(Rectangle.Name));
        if Rectangle.Shape = vpsEllipse then
          Builder.AppendLine('</title></ellipse>')
        else
          Builder.AppendLine('</title></rect>');
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

end.
