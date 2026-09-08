// Documentの表示オブジェクトを、各表示先で共有できる透明RGBA8画像へ描画する。
// UI状態を参照せず、線装飾とベジェ属性を含むDocumentだけを描画の正本とする。
unit VectArtDesignerRenderer;

interface

uses
  System.SysUtils, VectArtDesignerDocument;

type
  TVectArtRgbaPixel = packed record
    R: Byte;
    G: Byte;
    B: Byte;
    A: Byte;
  end;
  PVectArtRgbaPixel = ^TVectArtRgbaPixel;

  TVectArtRenderBuffer = class
  private
    FHeight: Integer;
    FPixels: TArray<TVectArtRgbaPixel>;
    FWidth: Integer;
    function GetData: PVectArtRgbaPixel;
    function GetPixelCount: NativeInt;
    function GetStride: NativeInt;
  public
    procedure Clear;
    procedure SetSize(AWidth, AHeight: Integer);
    property Data: PVectArtRgbaPixel read GetData;
    property Height: Integer read FHeight;
    property PixelCount: NativeInt read GetPixelCount;
    property Pixels: TArray<TVectArtRgbaPixel> read FPixels;
    property Stride: NativeInt read GetStride;
    property Width: Integer read FWidth;
  end;

// Canvas背景を含めず、図形だけを透明RGBA8へ描画する。
// MinimumStrokeWidthは編集補助用の論理座標幅で、0ならDocumentの線幅を変更しない。
procedure RenderVectArtDocument(Document: TVectArtDocument;
  Target: TVectArtRenderBuffer; Width, Height: Integer;
  MinimumStrokeWidth: Single = 0.0);
// グループ所属レイヤーだけを元の配置・重なり順のままサムネイルへ収める。
procedure RenderVectArtGroupThumbnail(Document: TVectArtDocument;
  GroupId: TVectArtGroupId; Target: TVectArtRenderBuffer;
  Width, Height: Integer);
// ストレートアルファRGBA8同士をSource-overで合成する。
procedure CompositeVectArtRgba(const Source: TVectArtRenderBuffer;
  Destination: PVectArtRgbaPixel; Width, Height: Integer);

implementation

uses
  System.Math, System.Skia, System.Types, System.UITypes,
  TextRendererSkiaRuntime, Vcl.Graphics, Winapi.Windows,
  VectArtDesignerBezierGeometry, VectArtDesignerGeometry,
  VectArtDesignerTextGeometry;

const
  MAX_RENDER_DIMENSION = 16384;

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

{ TVectArtRenderBuffer }

procedure TVectArtRenderBuffer.Clear;
begin
  if Length(FPixels) > 0 then
    FillChar(FPixels[0], Length(FPixels) * SizeOf(TVectArtRgbaPixel), 0);
end;

function TVectArtRenderBuffer.GetData: PVectArtRgbaPixel;
begin
  if Length(FPixels) = 0 then
    Result := nil
  else
    Result := @FPixels[0];
end;

function TVectArtRenderBuffer.GetPixelCount: NativeInt;
begin
  Result := Length(FPixels);
end;

function TVectArtRenderBuffer.GetStride: NativeInt;
begin
  Result := NativeInt(FWidth) * SizeOf(TVectArtRgbaPixel);
end;

procedure TVectArtRenderBuffer.SetSize(AWidth, AHeight: Integer);
var
  Count: Int64;
begin
  if (AWidth < 0) or (AHeight < 0) or
    (AWidth > MAX_RENDER_DIMENSION) or (AHeight > MAX_RENDER_DIMENSION) then
    raise EArgumentOutOfRangeException.Create('Invalid render dimensions');
  Count := Int64(AWidth) * AHeight;
  if Count > MaxInt then
    raise EArgumentOutOfRangeException.Create('Render buffer is too large');
  if (FWidth = AWidth) and (FHeight = AHeight) then
    Exit;
  FWidth := AWidth;
  FHeight := AHeight;
  SetLength(FPixels, NativeInt(Count));
end;

procedure RenderVectArtDocumentRegion(Document: TVectArtDocument;
  Target: TVectArtRenderBuffer; Width, Height: Integer;
  const LogicalBounds: TRectF; GroupId: TVectArtGroupId;
  MinimumStrokeWidth: Single; ShowHiddenLayers: Boolean);
var
  Canvas: ISkCanvas;
  Control1: TPointF;
  Control2: TPointF;
  DashIntervals: TArray<Single>;
  I: Integer;
  J: Integer;
  ImageInfo: TSkImageInfo;
  ImageLayer: TVectArtImageLayer;
  ImagePaint: ISkPaint;
  RasterImage: ISkImage;
  EdgeWidth: Single;
  Font: ISkFont;
  MarkerGeometry: TVectArtMarkerGeometry;
  SignedHeight: Single;
  RotationDegrees: Single;
  Layer: TVectArtLayer;
  LayerOpacityMultiplier: Single;
  LineLayer: TVectArtLineLayer;
  Paint: ISkPaint;
  Path: ISkPath;
  PathBuilder: ISkPathBuilder;
  PathLayer: TVectArtPathLayer;
  RectangleLayer: TVectArtRectangleLayer;
  ScaleX: Single;
  ScaleY: Single;
  StrokeWidth: Single;
  StrokePaint: ISkPaint;
  Surface: ISkSurface;
  TextLayer: TVectArtTextLayer;
  TextLayout: TVectArtTextLayout;
  TextScaleX: Single;
  TextScaleY: Single;

  procedure DrawMarker(Marker: TVectArtLineMarker; const Tip,
    InsidePoint: TPointF; StrokeWidth, MarkerSize: Single;
    AntiAlias: Boolean);
  var
    K: Integer;
    MarkerPath: ISkPath;
    MarkerPathBuilder: ISkPathBuilder;
  begin
    MarkerGeometry := BuildLineMarkerGeometry(Ord(Marker), Tip, InsidePoint,
      StrokeWidth, MarkerSize);
    if Length(MarkerGeometry.PrimaryPoints) < 2 then Exit;
    MarkerPathBuilder := TSkPathBuilder.Create;
    MarkerPathBuilder.MoveTo(MarkerGeometry.PrimaryPoints[0]);
    for K := 1 to High(MarkerGeometry.PrimaryPoints) do
      MarkerPathBuilder.LineTo(MarkerGeometry.PrimaryPoints[K]);
    if MarkerGeometry.PrimaryClosed then MarkerPathBuilder.Close;
    MarkerPath := MarkerPathBuilder.Detach;
    if MarkerGeometry.Filled then
    begin
      Paint.Color := StrokePaint.Color;
      Paint.AntiAlias := AntiAlias;
      Canvas.DrawPath(MarkerPath, Paint);
    end
    else
    begin
      StrokePaint.PathEffect := nil;
      StrokePaint.StrokeCap := TSkStrokeCap.Round;
      StrokePaint.StrokeWidth := Max(StrokeWidth, 0.1);
      Canvas.DrawPath(MarkerPath, StrokePaint);
    end;
  end;
begin
  if Document = nil then
    raise EArgumentNilException.Create('Document');
  if Target = nil then
    raise EArgumentNilException.Create('Target');
  if not TTextRendererSkiaRuntime.IsAcquired then
    raise EInvalidOp.Create('Skia runtime is not acquired');
  if (Width <= 0) or (Height <= 0) then
    raise EArgumentOutOfRangeException.Create('Render dimensions must be positive');
  if (LogicalBounds.Width <= 0) or (LogicalBounds.Height <= 0) then
    raise EArgumentOutOfRangeException.Create('Render bounds must be positive');

  Target.SetSize(Width, Height);
  Target.Clear;
  ImageInfo := TSkImageInfo.Create(Width, Height, TSkColorType.RGBA8888,
    TSkAlphaType.Unpremul);
  Surface := TSkSurface.MakeRasterDirect(ImageInfo, Target.Data,
    Target.Stride);
  if Surface = nil then
    raise EInvalidOp.Create('Cannot create VectArt raster surface');
  Canvas := Surface.Canvas;
  Canvas.Clear(TAlphaColorRec.Null);
  ScaleX := Width / LogicalBounds.Width;
  ScaleY := Height / LogicalBounds.Height;
  MinimumStrokeWidth := Max(MinimumStrokeWidth, 0.0);
  Paint := TSkPaint.Create(TSkPaintStyle.Fill);
  Paint.AntiAlias := True;
  StrokePaint := TSkPaint.Create(TSkPaintStyle.Stroke);
  StrokePaint.AntiAlias := True;
  ImagePaint := TSkPaint.Create;
  ImagePaint.AntiAlias := True;
  Canvas.Scale(ScaleX, ScaleY);
  Canvas.Translate(-LogicalBounds.Left, -LogicalBounds.Top);
  for I := 1 to Document.LayerCount - 1 do
  begin
    Layer := Document[I];
    if (GroupId <> VECTART_NO_GROUP) and (Layer.GroupId <> GroupId) then
      Continue;
    if not Layer.Visible and not ShowHiddenLayers then
      Continue;
    if Layer.Visible then
      LayerOpacityMultiplier := 1.0
    else
      LayerOpacityMultiplier := 0.35;
    if Layer is TVectArtTextLayer then
    begin
      TextLayer := TVectArtTextLayer(Layer);
      if TextLayer.Text = '' then
        Continue;
      TextLayout := BuildVectArtTextLayout(TextLayer.Text,
        TextLayer.FontFamily, TextLayer.FontSize, TextLayer.FontStyle,
        TextLayer.LetterSpacingRatio, TextLayer.LineSpacingRatio,
        TextLayer.Vertical);
      Font := CreateVectArtTextFont(TextLayer.FontFamily,
        TextLayer.FontSize, TextLayer.FontStyle, TextLayer.Vertical);
      Paint.Style := TSkPaintStyle.Fill;
      Paint.Color := VclColorToAlphaColor(TextLayer.TextColor,
        TextLayer.Opacity * LayerOpacityMultiplier);
      Canvas.Save;
      try
        Canvas.Translate(TextLayer.Bounds.CenterPoint.X,
          TextLayer.Bounds.CenterPoint.Y);
        Canvas.Rotate(TextLayer.RotationDegrees);
        Canvas.Scale(IfThen(TextLayer.FlipHorizontal, -1.0, 1.0),
          IfThen(TextLayer.FlipVertical, -1.0, 1.0));
        Canvas.Translate(-TextLayer.Bounds.CenterPoint.X,
          -TextLayer.Bounds.CenterPoint.Y);
        TextScaleX := TextLayer.Bounds.Width / Max(TextLayout.Width, 1.0);
        TextScaleY := TextLayer.Bounds.Height / Max(TextLayout.Height, 1.0);
        Canvas.Translate(TextLayer.Bounds.Left, TextLayer.Bounds.Top);
        Canvas.Scale(TextScaleX, TextScaleY);
        if TextLayer.Vertical then
          for J := 0 to High(TextLayout.Lines) do
            DrawVectArtTextColumn(Canvas, TextLayout.Lines[J],
              TextLayout.Width - TextLayout.BaseLineHeight -
                J * TextLayout.LineHeight, 0, TextLayout.BaseLineHeight,
              TextLayout.Ascent, TextLayout.CharacterAdvance, Font, Paint)
        else
          for J := 0 to High(TextLayout.Lines) do
            DrawVectArtTextLine(Canvas, TextLayout.Lines[J], 0,
              TextLayout.Ascent + J * TextLayout.LineHeight, Font, Paint,
              TextLayer.FontSize * TextLayer.LetterSpacingRatio);
      finally
        Canvas.Restore;
      end;
      Continue;
    end;
    if Layer is TVectArtImageLayer then
    begin
      ImageLayer := TVectArtImageLayer(Layer);
      RasterImage := TSkImage.MakeFromEncoded(ImageLayer.PngData);
      if (RasterImage = nil) or (RasterImage.Width <= 0) or
        (RasterImage.Height <= 0) then
        Continue;
      EdgeWidth := Hypot(
        ImageLayer.Points[1].X - ImageLayer.Points[0].X,
        ImageLayer.Points[1].Y - ImageLayer.Points[0].Y);
      if EdgeWidth <= 0 then
        Continue;
      SignedHeight := (
        (ImageLayer.Points[1].X - ImageLayer.Points[0].X) *
          (ImageLayer.Points[3].Y - ImageLayer.Points[0].Y) -
        (ImageLayer.Points[1].Y - ImageLayer.Points[0].Y) *
          (ImageLayer.Points[3].X - ImageLayer.Points[0].X)) / EdgeWidth;
      if Abs(SignedHeight) <= 0 then
        Continue;
      RotationDegrees := RadToDeg(ArcTan2(
        ImageLayer.Points[1].Y - ImageLayer.Points[0].Y,
        ImageLayer.Points[1].X - ImageLayer.Points[0].X));
      ImagePaint.AlphaF := EnsureRange(
        ImageLayer.Opacity * LayerOpacityMultiplier, 0.0, 1.0);
      Canvas.Save;
      try
        Canvas.Translate(ImageLayer.Points[0].X, ImageLayer.Points[0].Y);
        Canvas.Rotate(RotationDegrees);
        Canvas.Scale(EdgeWidth / RasterImage.Width,
          SignedHeight / RasterImage.Height);
        Canvas.DrawImage(RasterImage, 0, 0, TSkSamplingOptions.Medium,
          ImagePaint);
      finally
        Canvas.Restore;
      end;
      Continue;
    end;
    if Layer is TVectArtLineLayer then
    begin
      LineLayer := TVectArtLineLayer(Layer);
      StrokePaint.AntiAlias := LineLayer.AntiAlias;
      StrokeWidth := Max(Max(LineLayer.StrokeWidth, 0.1),
        MinimumStrokeWidth);
      StrokePaint.Color := VclColorToAlphaColor(LineLayer.StrokeColor,
        LineLayer.Opacity * LayerOpacityMultiplier);
      StrokePaint.StrokeWidth := StrokeWidth;
      DashIntervals := VectArtStrokeDashIntervals(LineLayer.StrokeStyle,
        StrokeWidth);
      if Length(DashIntervals) > 0 then
        StrokePaint.PathEffect := TSkPathEffect.MakeDash(DashIntervals, 0)
      else
        StrokePaint.PathEffect := nil;
      if VectArtStrokeUsesRoundCaps(LineLayer.StrokeStyle) then
        StrokePaint.StrokeCap := TSkStrokeCap.Round
      else
        case LineLayer.LineCap of
          vlcSquare: StrokePaint.StrokeCap := TSkStrokeCap.Square;
          vlcRound: StrokePaint.StrokeCap := TSkStrokeCap.Round;
        else
          StrokePaint.StrokeCap := TSkStrokeCap.Butt;
        end;
      case LineLayer.LineJoin of
        vljBevel: StrokePaint.StrokeJoin := TSkStrokeJoin.Bevel;
        vljRound: StrokePaint.StrokeJoin := TSkStrokeJoin.Round;
      else
        StrokePaint.StrokeJoin := TSkStrokeJoin.Miter;
      end;
      Canvas.DrawLine(LineLayer.StartPoint, LineLayer.EndPoint, StrokePaint);
      DrawMarker(LineLayer.StartMarker, LineLayer.StartPoint,
        LineLayer.EndPoint, LineLayer.StrokeWidth,
        LineLayer.StartMarkerSize, LineLayer.AntiAlias);
      DrawMarker(LineLayer.EndMarker, LineLayer.EndPoint,
        LineLayer.StartPoint, LineLayer.StrokeWidth,
        LineLayer.EndMarkerSize, LineLayer.AntiAlias);
      Continue;
    end;
    if Layer is TVectArtPathLayer then
    begin
      PathLayer := TVectArtPathLayer(Layer);
      Paint.AntiAlias := PathLayer.AntiAlias;
      StrokePaint.AntiAlias := PathLayer.AntiAlias;
      if Length(PathLayer.Points) < 2 then
        Continue;
      PathBuilder := TSkPathBuilder.Create;
      PathBuilder.MoveTo(PathLayer.Points[0]);
      if PathLayer.Bezier then
      begin
        for J := 0 to High(PathLayer.Points) - 1 do
        begin
          SmoothBezierSegmentControls(PathLayer.Points, PathLayer.Closed,
            J, Control1, Control2);
          PathBuilder.CubicTo(Control1, Control2, PathLayer.Points[J + 1]);
        end;
        if PathLayer.Closed then
        begin
          SmoothBezierSegmentControls(PathLayer.Points, True,
            High(PathLayer.Points), Control1, Control2);
          PathBuilder.CubicTo(Control1, Control2, PathLayer.Points[0]);
        end;
      end
      else
        for J := 1 to High(PathLayer.Points) do
          PathBuilder.LineTo(PathLayer.Points[J]);
      if PathLayer.Closed then
        PathBuilder.Close;
      Path := PathBuilder.Detach;
      if PathLayer.Filled and PathLayer.Closed then
      begin
        Paint.Color := VclColorToAlphaColor(PathLayer.FillColor,
          PathLayer.Opacity * LayerOpacityMultiplier);
        Canvas.DrawPath(Path, Paint);
      end;
      if PathLayer.StrokeWidth > 0 then
      begin
        StrokeWidth := Max(PathLayer.StrokeWidth, MinimumStrokeWidth);
        StrokePaint.Color := VclColorToAlphaColor(PathLayer.StrokeColor,
          PathLayer.Opacity * LayerOpacityMultiplier);
        StrokePaint.StrokeWidth := StrokeWidth;
        DashIntervals := VectArtStrokeDashIntervals(PathLayer.StrokeStyle,
          StrokeWidth);
        if Length(DashIntervals) > 0 then
          StrokePaint.PathEffect := TSkPathEffect.MakeDash(DashIntervals, 0)
        else
          StrokePaint.PathEffect := nil;
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
          DrawMarker(PathLayer.StartMarker, PathLayer.Points[0],
            PathLayer.Points[1], PathLayer.StrokeWidth,
            PathLayer.StartMarkerSize, PathLayer.AntiAlias);
          DrawMarker(PathLayer.EndMarker,
            PathLayer.Points[High(PathLayer.Points)],
            PathLayer.Points[High(PathLayer.Points) - 1],
            PathLayer.StrokeWidth, PathLayer.EndMarkerSize,
            PathLayer.AntiAlias);
        end;
      end;
      Continue;
    end;
    if not (Layer is TVectArtRectangleLayer) then
      Continue;
    RectangleLayer := TVectArtRectangleLayer(Layer);
    Paint.AntiAlias := True;
    StrokePaint.AntiAlias := True;
    Paint.Color := VclColorToAlphaColor(RectangleLayer.FillColor,
      RectangleLayer.Opacity * LayerOpacityMultiplier);
    Canvas.Save;
    try
      Canvas.Rotate(RectangleLayer.RotationDegrees,
        (RectangleLayer.Bounds.Left + RectangleLayer.Bounds.Right) * 0.5,
        (RectangleLayer.Bounds.Top + RectangleLayer.Bounds.Bottom) * 0.5);
      if RectangleLayer.Filled then
      begin
        if RectangleLayer.Shape = vpsEllipse then
          Canvas.DrawOval(RectangleLayer.Bounds, Paint)
        else
          Canvas.DrawRect(RectangleLayer.Bounds, Paint);
      end;
      if RectangleLayer.StrokeWidth > 0 then
      begin
        StrokeWidth := Max(RectangleLayer.StrokeWidth,
          MinimumStrokeWidth);
        StrokePaint.Color := VclColorToAlphaColor(RectangleLayer.StrokeColor,
          RectangleLayer.Opacity * LayerOpacityMultiplier);
        StrokePaint.StrokeWidth := StrokeWidth;
        DashIntervals := VectArtStrokeDashIntervals(
          RectangleLayer.StrokeStyle, StrokeWidth);
        if Length(DashIntervals) > 0 then
          StrokePaint.PathEffect := TSkPathEffect.MakeDash(DashIntervals, 0)
        else
          StrokePaint.PathEffect := nil;
        if VectArtStrokeUsesRoundCaps(RectangleLayer.StrokeStyle) then
          StrokePaint.StrokeCap := TSkStrokeCap.Round
        else
          StrokePaint.StrokeCap := TSkStrokeCap.Butt;
        StrokePaint.StrokeJoin := TSkStrokeJoin.Miter;
        if RectangleLayer.Shape = vpsEllipse then
          Canvas.DrawOval(RectangleLayer.Bounds, StrokePaint)
        else
          Canvas.DrawRect(RectangleLayer.Bounds, StrokePaint);
      end;
    finally
      Canvas.Restore;
    end;
  end;
  Surface.Flush;
end;

procedure RenderVectArtDocument(Document: TVectArtDocument;
  Target: TVectArtRenderBuffer; Width, Height: Integer;
  MinimumStrokeWidth: Single);
var
  CanvasLayer: TVectArtCanvasLayer;
begin
  if Document = nil then
    raise EArgumentNilException.Create('Document');
  CanvasLayer := Document.CanvasLayer;
  if CanvasLayer = nil then
    raise EInvalidOp.Create('Document canvas is missing');
  RenderVectArtDocumentRegion(Document, Target, Width, Height,
    RectF(0, 0, Max(CanvasLayer.Width, 1), Max(CanvasLayer.Height, 1)),
    VECTART_NO_GROUP, MinimumStrokeWidth, False);
end;

procedure RenderVectArtGroupThumbnail(Document: TVectArtDocument;
  GroupId: TVectArtGroupId; Target: TVectArtRenderBuffer;
  Width, Height: Integer);
const
  THUMBNAIL_MARGIN = 5;
var
  AvailableHeight: Integer;
  AvailableWidth: Integer;
  Bounds: TRectF;
  Center: TPointF;
  ContentBounds: TRectF;
  ContentHeight: Single;
  ContentWidth: Single;
  Found: Boolean;
  I: Integer;
  ImageLayer: TVectArtImageLayer;
  Layer: TVectArtLayer;
  LayerBounds: TRectF;
  LineLayer: TVectArtLineLayer;
  LogicalHeight: Single;
  LogicalWidth: Single;
  PathLayer: TVectArtPathLayer;
  PointIndex: Integer;
  RectangleLayer: TVectArtRectangleLayer;
  Scale: Single;
  TextLayer: TVectArtTextLayer;
begin
  if Document = nil then
    raise EArgumentNilException.Create('Document');
  if Target = nil then
    raise EArgumentNilException.Create('Target');
  if GroupId = VECTART_NO_GROUP then
    raise EArgumentOutOfRangeException.Create('GroupId');
  Found := False;
  ContentBounds := TRectF.Empty;
  for I in Document.GetGroupLayerIndices(GroupId) do
  begin
    Layer := Document[I];
    if Layer is TVectArtTextLayer then
    begin
      TextLayer := TVectArtTextLayer(Layer);
      LayerBounds := QuadBounds(RectangleCorners(TextLayer.Bounds,
        TextLayer.RotationDegrees));
    end
    else if Layer is TVectArtRectangleLayer then
    begin
      RectangleLayer := TVectArtRectangleLayer(Layer);
      LayerBounds := QuadBounds(RectangleCorners(RectangleLayer.Bounds,
        RectangleLayer.RotationDegrees));
    end
    else if Layer is TVectArtLineLayer then
    begin
      LineLayer := TVectArtLineLayer(Layer);
      LayerBounds := RectF(Min(LineLayer.StartPoint.X, LineLayer.EndPoint.X),
        Min(LineLayer.StartPoint.Y, LineLayer.EndPoint.Y),
        Max(LineLayer.StartPoint.X, LineLayer.EndPoint.X),
        Max(LineLayer.StartPoint.Y, LineLayer.EndPoint.Y));
    end
    else if Layer is TVectArtPathLayer then
    begin
      PathLayer := TVectArtPathLayer(Layer);
      if Length(PathLayer.Points) = 0 then
        Continue;
      LayerBounds := PointsBounds(PathLayer.Points);
    end
    else if Layer is TVectArtImageLayer then
    begin
      ImageLayer := TVectArtImageLayer(Layer);
      LayerBounds := RectF(ImageLayer.Points[0].X, ImageLayer.Points[0].Y,
        ImageLayer.Points[0].X, ImageLayer.Points[0].Y);
      for PointIndex := 1 to High(ImageLayer.Points) do
      begin
        LayerBounds.Left := Min(LayerBounds.Left,
          ImageLayer.Points[PointIndex].X);
        LayerBounds.Top := Min(LayerBounds.Top,
          ImageLayer.Points[PointIndex].Y);
        LayerBounds.Right := Max(LayerBounds.Right,
          ImageLayer.Points[PointIndex].X);
        LayerBounds.Bottom := Max(LayerBounds.Bottom,
          ImageLayer.Points[PointIndex].Y);
      end;
    end
    else
      Continue;
    if not Found then
    begin
      ContentBounds := LayerBounds;
      Found := True;
    end
    else
    begin
      ContentBounds.Left := Min(ContentBounds.Left, LayerBounds.Left);
      ContentBounds.Top := Min(ContentBounds.Top, LayerBounds.Top);
      ContentBounds.Right := Max(ContentBounds.Right, LayerBounds.Right);
      ContentBounds.Bottom := Max(ContentBounds.Bottom, LayerBounds.Bottom);
    end;
  end;
  Target.SetSize(Width, Height);
  Target.Clear;
  AvailableWidth := Width - THUMBNAIL_MARGIN * 2;
  AvailableHeight := Height - THUMBNAIL_MARGIN * 2;
  if not Found or (AvailableWidth <= 0) or (AvailableHeight <= 0) then
    Exit;
  ContentWidth := Max(ContentBounds.Width, 1.0);
  ContentHeight := Max(ContentBounds.Height, 1.0);
  Scale := Min(AvailableWidth / ContentWidth,
    AvailableHeight / ContentHeight);
  if Scale <= 0 then
    Exit;
  LogicalWidth := Width / Scale;
  LogicalHeight := Height / Scale;
  Center := ContentBounds.CenterPoint;
  Bounds := RectF(Center.X - LogicalWidth * 0.5,
    Center.Y - LogicalHeight * 0.5, Center.X + LogicalWidth * 0.5,
    Center.Y + LogicalHeight * 0.5);
  RenderVectArtDocumentRegion(Document, Target, Width, Height, Bounds,
    GroupId, 1.0 / Scale, True);
end;

procedure CompositeVectArtRgba(const Source: TVectArtRenderBuffer;
  Destination: PVectArtRgbaPixel; Width, Height: Integer);
var
  AlphaDenominator: Cardinal;
  DestinationAlpha: Cardinal;
  DestinationPixel: PVectArtRgbaPixel;
  I: NativeInt;
  PixelCount: NativeInt;
  SourceAlpha: Cardinal;
  SourcePixel: PVectArtRgbaPixel;
begin
  if (Source = nil) or (Destination = nil) or
    (Source.Width <> Width) or (Source.Height <> Height) then
    Exit;
  PixelCount := NativeInt(Width) * Height;
  SourcePixel := Source.Data;
  DestinationPixel := Destination;
  for I := 0 to PixelCount - 1 do
  begin
    SourceAlpha := SourcePixel^.A;
    if SourceAlpha = 255 then
      DestinationPixel^ := SourcePixel^
    else if SourceAlpha <> 0 then
    begin
      DestinationAlpha := DestinationPixel^.A;
      AlphaDenominator := SourceAlpha * 255 +
        DestinationAlpha * (255 - SourceAlpha);
      if AlphaDenominator <> 0 then
      begin
        DestinationPixel^.R :=
          (Cardinal(SourcePixel^.R) * SourceAlpha * 255 +
           Cardinal(DestinationPixel^.R) * DestinationAlpha *
             (255 - SourceAlpha) + AlphaDenominator div 2) div
          AlphaDenominator;
        DestinationPixel^.G :=
          (Cardinal(SourcePixel^.G) * SourceAlpha * 255 +
           Cardinal(DestinationPixel^.G) * DestinationAlpha *
             (255 - SourceAlpha) + AlphaDenominator div 2) div
          AlphaDenominator;
        DestinationPixel^.B :=
          (Cardinal(SourcePixel^.B) * SourceAlpha * 255 +
           Cardinal(DestinationPixel^.B) * DestinationAlpha *
             (255 - SourceAlpha) + AlphaDenominator div 2) div
          AlphaDenominator;
        DestinationPixel^.A := (AlphaDenominator + 127) div 255;
      end;
    end;
    Inc(SourcePixel);
    Inc(DestinationPixel);
  end;
end;

end.
