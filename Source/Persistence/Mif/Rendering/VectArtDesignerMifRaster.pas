// MIFへ埋め込む合成画像・文字・図形PNGを描画する。チャンク順序と互換性判定は変換側で管理する。
unit VectArtDesignerMifRaster;

interface

uses System.SysUtils, System.Types, Vcl.Graphics, VectArtDesignerDocument;
function EncodeRgba(const Pixels: Pointer; Width, Height: Integer): TBytes;
function CreateCompositePng(Document: TVectArtDocument): TBytes;
function CreateSolidPng(Width, Height: Integer; Color: TColor): TBytes;
function CreateTextImagePng(TextLayer: TVectArtTextLayer): TBytes;
function CreateRectangleRasterPng(Rectangle: TVectArtRectangleLayer; Width, Height: Integer): TBytes;
function CreateLineRasterPng(Line: TVectArtLineLayer; out PlacementBounds: TRectF): TBytes;
function CreatePathRasterPng(PathLayer: TVectArtPathLayer; out PlacementBounds: TRectF): TBytes;

implementation

uses System.Classes, System.Math, System.Skia, System.UITypes, Winapi.Windows,
  VectArtDesignerMifPngMetadata, VectArtDesignerMifPlacement,
  VectArtDesignerFillPaint, VectArtDesignerRenderer, VectArtDesignerTextGeometry,
  VectArtDesignerGeometry, VectArtDesignerBezierGeometry;

function EncodeRgba(const Pixels: Pointer; Width, Height: Integer): TBytes;
var
  ImageInfo: TSkImageInfo;
begin
  ImageInfo := TSkImageInfo.Create(Width, Height, TSkColorType.RGBA8888,
    TSkAlphaType.Unpremul);
  Result := TSkImageEncoder.Encode(ImageInfo, Pixels,
    NativeUInt(Width) * SizeOf(TVectArtRgbaPixel), TSkEncodedImageFormat.PNG);
  if Length(Result) = 0 then
    raise EWriteError.Create('PNG encoding failed');
  // WebArt製PNGに存在しないSkia固有のsBITは、厳密な読込側との互換性を優先して除去する。
  Result := RemovePngChunk(Result, 'sBIT');
end;

procedure CompositeCanvasBackground(Buffer: TVectArtRenderBuffer;
  Canvas: TVectArtCanvasLayer);
var
  Alpha: Cardinal;
  Background: TColor;
  BackgroundB: Cardinal;
  BackgroundG: Cardinal;
  BackgroundR: Cardinal;
  I: NativeInt;
  Pixel: PVectArtRgbaPixel;
begin
  if (Buffer = nil) or (Canvas = nil) or Canvas.Transparent then
    Exit;
  Background := ColorToRGB(Canvas.BackgroundColor);
  BackgroundR := GetRValue(Background);
  BackgroundG := GetGValue(Background);
  BackgroundB := GetBValue(Background);
  Pixel := Buffer.Data;
  for I := 0 to Buffer.PixelCount - 1 do
  begin
    Alpha := Pixel^.A;
    Pixel^.R := (Cardinal(Pixel^.R) * Alpha +
      BackgroundR * (255 - Alpha) + 127) div 255;
    Pixel^.G := (Cardinal(Pixel^.G) * Alpha +
      BackgroundG * (255 - Alpha) + 127) div 255;
    Pixel^.B := (Cardinal(Pixel^.B) * Alpha +
      BackgroundB * (255 - Alpha) + 127) div 255;
    Pixel^.A := 255;
    Inc(Pixel);
  end;
end;

function CreateCompositePng(Document: TVectArtDocument): TBytes;
var
  Buffer: TVectArtRenderBuffer;
  Canvas: TVectArtCanvasLayer;
begin
  Canvas := Document.CanvasLayer;
  Buffer := TVectArtRenderBuffer.Create;
  try
    RenderVectArtDocument(Document, Buffer, Canvas.Width, Canvas.Height);
    CompositeCanvasBackground(Buffer, Canvas);
    Result := EncodeRgba(Buffer.Data, Buffer.Width, Buffer.Height);
    AddPhysicalDimensions(Result);
    AddText(Result, 'application name', 'WebArt Designer');
    AddWadaInteger(Result, 'application version', 700);
    AddWadaInteger(Result, 'background page index', 0);
  finally
    Buffer.Free;
  end;
end;

function CreateSolidPng(Width, Height: Integer; Color: TColor): TBytes;
var
  ColorValue: TColor;
  I: Integer;
  Pixels: TArray<TVectArtRgbaPixel>;
begin
  Width := EnsureRange(Width, 1, 16384);
  Height := EnsureRange(Height, 1, 16384);
  SetLength(Pixels, Width * Height);
  ColorValue := ColorToRGB(Color);
  for I := 0 to High(Pixels) do
  begin
    Pixels[I].R := GetRValue(ColorValue);
    Pixels[I].G := GetGValue(ColorValue);
    Pixels[I].B := GetBValue(ColorValue);
    Pixels[I].A := 255;
  end;
  Result := EncodeRgba(@Pixels[0], Width, Height);
  AddPhysicalDimensions(Result);
end;

function CreateTextImagePng(TextLayer: TVectArtTextLayer): TBytes;
var
  Canvas: ISkCanvas;
  Font: ISkFont;
  I: Integer;
  ImageInfo: TSkImageInfo;
  Layout: TVectArtTextLayout;
  Paint: ISkPaint;
  Pixels: TArray<TVectArtRgbaPixel>;
  PointValue: TPointF;
  Quad: TVectArtQuad;
  ShiftJis: TEncoding;
  ShiftJisBytes: TBytes;
  Surface: ISkSurface;
  TextScaleX: Single;
  TextScaleY: Single;
  UnicodeBytes: TBytes;
  Width: Integer;
  Height: Integer;
begin
  Width := EnsureRange(Ceil(Max(TextLayer.Bounds.Width, 1.0)), 1, 16384);
  Height := EnsureRange(Ceil(Max(TextLayer.Bounds.Height, 1.0)), 1, 16384);
  SetLength(Pixels, Width * Height);
  ImageInfo := TSkImageInfo.Create(Width, Height, TSkColorType.RGBA8888,
    TSkAlphaType.Unpremul);
  Surface := TSkSurface.MakeRasterDirect(ImageInfo, @Pixels[0],
    NativeUInt(Width) * SizeOf(TVectArtRgbaPixel));
  if Surface = nil then
    raise EWriteError.Create('Cannot create text PNG surface');
  Canvas := Surface.Canvas;
  Canvas.Clear(TAlphaColorRec.Null);
  Font := CreateVectArtTextFont(TextLayer.FontFamily, TextLayer.FontSize,
    TextLayer.FontStyle, TextLayer.Vertical);
  Layout := BuildVectArtTextLayout(TextLayer.Text, TextLayer.FontFamily,
    TextLayer.FontSize, TextLayer.FontStyle, TextLayer.LetterSpacingRatio,
    TextLayer.LineSpacingRatio, TextLayer.Vertical);
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;
  SetTextPaint(Paint,TextLayer.TextColor,TextLayer.FillStyle,
    Width,Height,Layout.Width,Layout.Height,1);
  TextScaleX := Width / Max(Layout.Width, 1.0);
  TextScaleY := Height / Max(Layout.Height, 1.0);
  Canvas.Scale(TextScaleX, TextScaleY);
  if TextLayer.Vertical then
    for I := 0 to High(Layout.Lines) do
      DrawVectArtTextColumn(Canvas, Layout.Lines[I],
        Layout.Width - Layout.BaseLineHeight - I * Layout.LineHeight,
        0, Layout.BaseLineHeight, Layout.Ascent,
        Layout.CharacterAdvance, Font, Paint)
  else
    for I := 0 to High(Layout.Lines) do
      DrawVectArtTextLine(Canvas, Layout.Lines[I], 0,
        Layout.Ascent + I * Layout.LineHeight, Font, Paint,
        TextLayer.FontSize * TextLayer.LetterSpacingRatio);
  Surface.Flush;
  Result := EncodeRgba(@Pixels[0], Width, Height);
  AddPhysicalDimensions(Result);
  AddText(Result, 'object type', 'logo');
  Quad := RectangleCorners(TextLayer.Bounds, TextLayer.RotationDegrees);
  if TextLayer.FlipHorizontal then
  begin
    PointValue := Quad[0]; Quad[0] := Quad[1]; Quad[1] := PointValue;
    PointValue := Quad[3]; Quad[3] := Quad[2]; Quad[2] := PointValue;
  end;
  if TextLayer.FlipVertical then
  begin
    PointValue := Quad[0]; Quad[0] := Quad[3]; Quad[3] := PointValue;
    PointValue := Quad[1]; Quad[1] := Quad[2]; Quad[2] := PointValue;
  end;
  AddImagePlacementMetadata(Result, Quad, MifAlpha(TextLayer.Opacity),
    not TextLayer.Visible);
  AddWadaInteger(Result, 'logo fs auto', 1);
  AddWadaInteger(Result, 'logo smooth', 0);
  AddWadaInteger(Result, 'logo pad x', 2);
  AddWadaInteger(Result, 'logo pad y', 2);
  AddWadaInteger(Result, 'logo margin x', 10);
  AddWadaInteger(Result, 'logo margin y', 10);
  AddWadaInteger(Result, 'logo format', 2);
  UnicodeBytes := TEncoding.Unicode.GetBytes(TextLayer.Text);
  AddWadaBytes(Result, 'logo text unicode', UnicodeBytes);
  ShiftJis := TEncoding.GetEncoding(932);
  try
    ShiftJisBytes := ShiftJis.GetBytes(TextLayer.Text);
  finally
    ShiftJis.Free;
  end;
  AddWadaBytes(Result, 'logo text', ShiftJisBytes);
  AddWadaInteger(Result, 'font height', -Max(Round(TextLayer.FontSize), 1));
  AddWadaInteger(Result, 'font width', Round(Font.MeasureText('0')));
  if fsBold in TextLayer.FontStyle then
    AddWadaInteger(Result, 'font weight', 700)
  else
    AddWadaInteger(Result, 'font weight', 400);
  AddWadaInteger(Result, 'font escapement', 0);
  AddWadaInteger(Result, 'font orientation', 0);
  AddWadaInteger(Result, 'font italic', Ord(fsItalic in TextLayer.FontStyle));
  AddWadaInteger(Result, 'font underline',
    Ord(fsUnderline in TextLayer.FontStyle));
  AddWadaInteger(Result, 'font strikeout',
    Ord(fsStrikeOut in TextLayer.FontStyle));
  AddWadaInteger(Result, 'font charset', 128);
  AddWadaInteger(Result, 'font outprecision', 3);
  AddWadaInteger(Result, 'font clipprecision', 2);
  AddWadaInteger(Result, 'font quality', 1);
  AddWadaInteger(Result, 'font pitchandfamily', 0);
  AddWadaString(Result, 'font facename', TextLayer.FontFamily);
  AddWadaInteger(Result, 'logo writing mode', Ord(TextLayer.Vertical));
  AddWadaString(Result, 'logo outline object type', 'none');
  AddWadaString(Result, 'logo effect object type', 'none');
end;

function CreateRectangleRasterPng(Rectangle: TVectArtRectangleLayer;
  Width, Height: Integer): TBytes;
var
  Canvas: ISkCanvas;
  DashIntervals: TArray<Single>;
  FillPaint: ISkPaint;
  ImageInfo: TSkImageInfo;
  Inset: Single;
  Pixels: TArray<TVectArtRgbaPixel>;
  RGBColor: TColor;
  StrokePaint: ISkPaint;
  Surface: ISkSurface;
begin
  Width := EnsureRange(Width, 1, 16384);
  Height := EnsureRange(Height, 1, 16384);
  SetLength(Pixels, Width * Height);
  ImageInfo := TSkImageInfo.Create(Width, Height, TSkColorType.RGBA8888,
    TSkAlphaType.Unpremul);
  Surface := TSkSurface.MakeRasterDirect(ImageInfo, @Pixels[0],
    NativeUInt(Width) * SizeOf(TVectArtRgbaPixel));
  if Surface = nil then
    raise EWriteError.Create('Cannot create rectangle PNG surface');
  Canvas := Surface.Canvas;
  Canvas.Clear(TAlphaColorRec.Null);
  FillPaint := TSkPaint.Create(TSkPaintStyle.Fill);
  FillPaint.AntiAlias := True;
  RGBColor := ColorToRGB(Rectangle.FillColor);
  FillPaint.Color := TAlphaColor($FF000000 or
    (Cardinal(GetRValue(RGBColor)) shl 16) or
    (Cardinal(GetGValue(RGBColor)) shl 8) or
    Cardinal(GetBValue(RGBColor)));
  if Rectangle.Filled then
  begin
    SetFillPaint(FillPaint,Rectangle.FillColor,Rectangle.FillStyle,RectF(0,0,Width,Height),1);
    if Rectangle.Shape = vpsEllipse then
      Canvas.DrawOval(TRectF.Create(0, 0, Width, Height), FillPaint)
    else
      Canvas.DrawRect(TRectF.Create(0, 0, Width, Height), FillPaint);
  end;
  if Rectangle.StrokeWidth > 0 then
  begin
    StrokePaint := TSkPaint.Create(TSkPaintStyle.Stroke);
    StrokePaint.AntiAlias := True;
    RGBColor := ColorToRGB(Rectangle.StrokeColor);
    StrokePaint.Color := TAlphaColor($FF000000 or
      (Cardinal(GetRValue(RGBColor)) shl 16) or
      (Cardinal(GetGValue(RGBColor)) shl 8) or
      Cardinal(GetBValue(RGBColor)));
    SetStrokePaint(StrokePaint,Rectangle.StrokeColor,Rectangle.StrokePaint,RectF(0,0,Width,Height),Rectangle.StrokeWidth,1);
    StrokePaint.StrokeWidth := Rectangle.StrokeWidth;
    DashIntervals := VectArtStrokeDashIntervals(Rectangle.StrokeStyle,
      Rectangle.StrokeWidth);
    if Length(DashIntervals) > 0 then
      StrokePaint.PathEffect := TSkPathEffect.MakeDash(DashIntervals, 0);
    if VectArtStrokeUsesRoundCaps(Rectangle.StrokeStyle) then
      StrokePaint.StrokeCap := TSkStrokeCap.Round
    else
      StrokePaint.StrokeCap := TSkStrokeCap.Butt;
    Inset := Min(Rectangle.StrokeWidth * 0.5,
      Min(Width, Height) * 0.5);
    if Rectangle.Shape = vpsEllipse then
      Canvas.DrawOval(TRectF.Create(Inset, Inset, Width - Inset,
        Height - Inset), StrokePaint)
    else
      Canvas.DrawRect(TRectF.Create(Inset, Inset, Width - Inset,
        Height - Inset), StrokePaint);
  end;
  Surface.Flush;
  Result := EncodeRgba(@Pixels[0], Width, Height);
  AddPhysicalDimensions(Result);
end;

function CreateLineRasterPng(Line: TVectArtLineLayer;
  out PlacementBounds: TRectF): TBytes;
var
  Canvas: ISkCanvas;
  DashIntervals: TArray<Single>;
  Height: Integer;
  ImageInfo: TSkImageInfo;
  MarkerGeometry: TVectArtMarkerGeometry;
  Padding: Single;
  Paint: ISkPaint;
  Pixels: TArray<TVectArtRgbaPixel>;
  RGBColor: TColor;
  Surface: ISkSurface;
  Width: Integer;

  procedure DrawMarker(Marker: TVectArtLineMarker; const Tip,
    InsidePoint: TPointF; MarkerSize: Single);
  var
    I: Integer;
    MarkerPathBuilder: ISkPathBuilder;
  begin
    MarkerGeometry := BuildLineMarkerGeometry(Ord(Marker), Tip, InsidePoint,
      Line.StrokeWidth, MarkerSize);
    if Length(MarkerGeometry.PrimaryPoints) < 2 then Exit;
    MarkerPathBuilder := TSkPathBuilder.Create;
    MarkerPathBuilder.MoveTo(MarkerGeometry.PrimaryPoints[0].X -
      PlacementBounds.Left, MarkerGeometry.PrimaryPoints[0].Y -
      PlacementBounds.Top);
    for I := 1 to High(MarkerGeometry.PrimaryPoints) do
      MarkerPathBuilder.LineTo(MarkerGeometry.PrimaryPoints[I].X -
        PlacementBounds.Left, MarkerGeometry.PrimaryPoints[I].Y -
        PlacementBounds.Top);
    if MarkerGeometry.PrimaryClosed then MarkerPathBuilder.Close;
    Paint.PathEffect := nil;
    if MarkerGeometry.Filled then
      Paint.Style := TSkPaintStyle.Fill
    else
    begin
      Paint.Style := TSkPaintStyle.Stroke;
      Paint.StrokeCap := TSkStrokeCap.Round;
      Paint.StrokeWidth := Max(Line.StrokeWidth, 0.1);
    end;
    Canvas.DrawPath(MarkerPathBuilder.Detach, Paint);
  end;
begin
  if (Line.StartMarker <> vlmNone) or (Line.EndMarker <> vlmNone) then
    Padding := Max(Max(Line.StartMarkerSize, Line.EndMarkerSize) *
      Max(Line.StrokeWidth, 2.0) + 2, 6.0)
  else
    Padding := Max(Line.StrokeWidth * 0.5 + 2, 2.0);
  PlacementBounds := TRectF.Create(Min(Line.StartPoint.X, Line.EndPoint.X) -
    Padding, Min(Line.StartPoint.Y, Line.EndPoint.Y) - Padding,
    Max(Line.StartPoint.X, Line.EndPoint.X) + Padding,
    Max(Line.StartPoint.Y, Line.EndPoint.Y) + Padding);
  Width := EnsureRange(Ceil(PlacementBounds.Width), 1, 16384);
  Height := EnsureRange(Ceil(PlacementBounds.Height), 1, 16384);
  SetLength(Pixels, Width * Height);
  ImageInfo := TSkImageInfo.Create(Width, Height, TSkColorType.RGBA8888,
    TSkAlphaType.Unpremul);
  Surface := TSkSurface.MakeRasterDirect(ImageInfo, @Pixels[0],
    NativeUInt(Width) * SizeOf(TVectArtRgbaPixel));
  if Surface = nil then
    raise EWriteError.Create('Cannot create line PNG surface');
  Canvas := Surface.Canvas;
  Canvas.Clear(TAlphaColorRec.Null);
  Paint := TSkPaint.Create(TSkPaintStyle.Stroke);
  Paint.AntiAlias := Line.AntiAlias;
  RGBColor := ColorToRGB(Line.StrokeColor);
  Paint.Color := TAlphaColor($FF000000 or
    (Cardinal(GetRValue(RGBColor)) shl 16) or
    (Cardinal(GetGValue(RGBColor)) shl 8) or Cardinal(GetBValue(RGBColor)));
  SetStrokePaint(Paint,Line.StrokeColor,Line.StrokePaint,
    RectF(Min(Line.StartPoint.X,Line.EndPoint.X)-PlacementBounds.Left,
      Min(Line.StartPoint.Y,Line.EndPoint.Y)-PlacementBounds.Top,
      Max(Line.StartPoint.X,Line.EndPoint.X)-PlacementBounds.Left,
      Max(Line.StartPoint.Y,Line.EndPoint.Y)-PlacementBounds.Top),Line.StrokeWidth,1);
  Paint.StrokeWidth := Line.StrokeWidth;
  DashIntervals := VectArtStrokeDashIntervals(Line.StrokeStyle,
    Line.StrokeWidth);
  if Length(DashIntervals) > 0 then
    Paint.PathEffect := TSkPathEffect.MakeDash(DashIntervals, 0);
  if VectArtStrokeUsesRoundCaps(Line.StrokeStyle) then
    Paint.StrokeCap := TSkStrokeCap.Round
  else
    case Line.LineCap of
      vlcSquare: Paint.StrokeCap := TSkStrokeCap.Square;
      vlcRound: Paint.StrokeCap := TSkStrokeCap.Round;
    else
      Paint.StrokeCap := TSkStrokeCap.Butt;
    end;
  case Line.LineJoin of
    vljBevel: Paint.StrokeJoin := TSkStrokeJoin.Bevel;
    vljRound: Paint.StrokeJoin := TSkStrokeJoin.Round;
  else
    Paint.StrokeJoin := TSkStrokeJoin.Miter;
  end;
  Canvas.DrawLine(TPointF.Create(Line.StartPoint.X - PlacementBounds.Left,
    Line.StartPoint.Y - PlacementBounds.Top), TPointF.Create(
    Line.EndPoint.X - PlacementBounds.Left,
    Line.EndPoint.Y - PlacementBounds.Top), Paint);
  DrawMarker(Line.StartMarker, Line.StartPoint, Line.EndPoint,
    Line.StartMarkerSize);
  DrawMarker(Line.EndMarker, Line.EndPoint, Line.StartPoint,
    Line.EndMarkerSize);
  Surface.Flush;
  Result := EncodeRgba(@Pixels[0], Width, Height);
  AddPhysicalDimensions(Result);
end;

function CreatePathRasterPng(PathLayer: TVectArtPathLayer;
  out PlacementBounds: TRectF): TBytes;
var
  Canvas: ISkCanvas;
  DashIntervals: TArray<Single>;
  DisplayPoints: TArray<TPointF>;
  FillPaint: ISkPaint;
  Height: Integer;
  I: Integer;
  ImageInfo: TSkImageInfo;
  MarkerGeometry: TVectArtMarkerGeometry;
  Padding: Single;
  Path: ISkPath;
  PathBuilder: ISkPathBuilder;
  Pixels: TArray<TVectArtRgbaPixel>;
  RGBColor: TColor;
  StrokePaint: ISkPaint;
  Surface: ISkSurface;
  Width: Integer;

  procedure DrawPathMarker(Marker: TVectArtLineMarker; const Tip,
    InsidePoint: TPointF; MarkerSize: Single);
  var
    PointIndex: Integer;
    MarkerBuilder: ISkPathBuilder;
  begin
    MarkerGeometry := BuildLineMarkerGeometry(Ord(Marker), Tip, InsidePoint,
      PathLayer.StrokeWidth, MarkerSize);
    if Length(MarkerGeometry.PrimaryPoints) < 2 then
      Exit;
    MarkerBuilder := TSkPathBuilder.Create;
    MarkerBuilder.MoveTo(MarkerGeometry.PrimaryPoints[0].X -
      PlacementBounds.Left, MarkerGeometry.PrimaryPoints[0].Y -
      PlacementBounds.Top);
    for PointIndex := 1 to High(MarkerGeometry.PrimaryPoints) do
      MarkerBuilder.LineTo(MarkerGeometry.PrimaryPoints[PointIndex].X -
        PlacementBounds.Left, MarkerGeometry.PrimaryPoints[PointIndex].Y -
        PlacementBounds.Top);
    if MarkerGeometry.PrimaryClosed then
      MarkerBuilder.Close;
    StrokePaint.PathEffect := nil;
    if MarkerGeometry.Filled then
      StrokePaint.Style := TSkPaintStyle.Fill
    else
    begin
      StrokePaint.Style := TSkPaintStyle.Stroke;
      StrokePaint.StrokeCap := TSkStrokeCap.Round;
      StrokePaint.StrokeWidth := Max(PathLayer.StrokeWidth, 0.1);
    end;
    Canvas.DrawPath(MarkerBuilder.Detach, StrokePaint);
  end;
begin
  DisplayPoints := BuildPathDisplayPolyline(PathLayer.Points,
    PathLayer.Bezier, PathLayer.Closed, 16);
  PlacementBounds := PointsBounds(DisplayPoints);
  if not PathLayer.Closed and
    ((PathLayer.StartMarker <> vlmNone) or
     (PathLayer.EndMarker <> vlmNone)) then
    Padding := Max(Max(PathLayer.StartMarkerSize,
      PathLayer.EndMarkerSize) * Max(PathLayer.StrokeWidth, 2.0) + 2, 6.0)
  else
    Padding := Max(PathLayer.StrokeWidth * 0.5 + 2, 2.0);
  PlacementBounds.Inflate(Padding, Padding);
  Width := EnsureRange(Ceil(PlacementBounds.Width), 1, 16384);
  Height := EnsureRange(Ceil(PlacementBounds.Height), 1, 16384);
  SetLength(Pixels, Width * Height);
  ImageInfo := TSkImageInfo.Create(Width, Height, TSkColorType.RGBA8888,
    TSkAlphaType.Unpremul);
  Surface := TSkSurface.MakeRasterDirect(ImageInfo, @Pixels[0],
    NativeUInt(Width) * SizeOf(TVectArtRgbaPixel));
  if Surface = nil then
    raise EWriteError.Create('Cannot create path PNG surface');
  Canvas := Surface.Canvas;
  Canvas.Clear(TAlphaColorRec.Null);
  PathBuilder := TSkPathBuilder.Create;
  PathBuilder.MoveTo(DisplayPoints[0].X - PlacementBounds.Left,
    DisplayPoints[0].Y - PlacementBounds.Top);
  for I := 1 to High(DisplayPoints) do
    PathBuilder.LineTo(DisplayPoints[I].X - PlacementBounds.Left,
      DisplayPoints[I].Y - PlacementBounds.Top);
  if PathLayer.Closed then
    PathBuilder.Close;
  Path := PathBuilder.Detach;
  if PathLayer.Filled and PathLayer.Closed then
  begin
    FillPaint := TSkPaint.Create(TSkPaintStyle.Fill);
    FillPaint.AntiAlias := PathLayer.AntiAlias;
    RGBColor := ColorToRGB(PathLayer.FillColor);
    FillPaint.Color := TAlphaColor($FF000000 or
      (Cardinal(GetRValue(RGBColor)) shl 16) or
      (Cardinal(GetGValue(RGBColor)) shl 8) or Cardinal(GetBValue(RGBColor)));
    SetFillPaint(FillPaint,PathLayer.FillColor,PathLayer.FillStyle,Path.Bounds,1);
    Canvas.DrawPath(Path, FillPaint);
  end;
  if PathLayer.StrokeWidth > 0 then
  begin
    StrokePaint := TSkPaint.Create(TSkPaintStyle.Stroke);
    StrokePaint.AntiAlias := PathLayer.AntiAlias;
    RGBColor := ColorToRGB(PathLayer.StrokeColor);
    StrokePaint.Color := TAlphaColor($FF000000 or
      (Cardinal(GetRValue(RGBColor)) shl 16) or
      (Cardinal(GetGValue(RGBColor)) shl 8) or Cardinal(GetBValue(RGBColor)));
    SetStrokePaint(StrokePaint,PathLayer.StrokeColor,PathLayer.StrokePaint,Path.Bounds,PathLayer.StrokeWidth,1);
    StrokePaint.StrokeWidth := PathLayer.StrokeWidth;
    DashIntervals := VectArtStrokeDashIntervals(PathLayer.StrokeStyle,
      PathLayer.StrokeWidth);
    if Length(DashIntervals) > 0 then
      StrokePaint.PathEffect := TSkPathEffect.MakeDash(DashIntervals, 0);
    if VectArtStrokeUsesRoundCaps(PathLayer.StrokeStyle) then
      StrokePaint.StrokeCap := TSkStrokeCap.Round
    else
      case PathLayer.LineCap of
        vlcSquare: StrokePaint.StrokeCap := TSkStrokeCap.Square;
        vlcRound: StrokePaint.StrokeCap := TSkStrokeCap.Round;
      else
        StrokePaint.StrokeCap := TSkStrokeCap.Butt;
      end;
    case PathLayer.LineJoin of
      vljBevel: StrokePaint.StrokeJoin := TSkStrokeJoin.Bevel;
      vljRound: StrokePaint.StrokeJoin := TSkStrokeJoin.Round;
    else
      StrokePaint.StrokeJoin := TSkStrokeJoin.Miter;
    end;
    Canvas.DrawPath(Path, StrokePaint);
    if not PathLayer.Closed then
    begin
      DrawPathMarker(PathLayer.StartMarker, DisplayPoints[0],
        DisplayPoints[1], PathLayer.StartMarkerSize);
      DrawPathMarker(PathLayer.EndMarker,
        DisplayPoints[High(DisplayPoints)],
        DisplayPoints[High(DisplayPoints) - 1],
        PathLayer.EndMarkerSize);
    end;
  end;
  Surface.Flush;
  Result := EncodeRgba(@Pixels[0], Width, Height);
  AddPhysicalDimensions(Result);
end;


end.
