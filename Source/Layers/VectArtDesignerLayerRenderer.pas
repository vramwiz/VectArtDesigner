// レイヤー一覧の行配置、サムネイル、状態アイコンをGDI／Direct2Dで描画する。
unit VectArtDesignerLayerRenderer;

interface

uses
  System.Types, Vcl.Direct2D, Vcl.Graphics, VectArtDesignerDocument;

type
  TVectArtLayerRenderer = class
  private
    FDocument: TVectArtDocument;
    procedure DrawImageThumbnail(ACanvas: TCustomCanvas;
      const ThumbnailRect: TRect; ImageLayer: TVectArtImageLayer);
    procedure DrawLayerItem(ACanvas: TCanvas; const ItemRect: TRect;
      Layer: TVectArtLayer; Selected: Boolean); overload;
    procedure DrawLayerItem(ACanvas: TDirect2DCanvas;
      const ItemRect: TRect; Layer: TVectArtLayer;
      Selected: Boolean); overload;
    function FitThumbnailRect(const AvailableRect: TRect;
      LogicalWidth, LogicalHeight: Integer): TRect;
  public
    procedure DrawLayers(ACanvas: TCanvas;
      const Bounds: TRect); overload;
    procedure DrawLayers(ACanvas: TDirect2DCanvas;
      const Bounds: TRect); overload;
    function LayerIndexAt(const Bounds: TRect; Y: Integer): Integer;
    function LayerItemRect(const Bounds: TRect; Index: Integer): TRect;
    function LockButtonRect(const ItemRect: TRect): TRect;
    function VisibilityButtonRect(const ItemRect: TRect): TRect;
    property Document: TVectArtDocument read FDocument write FDocument;
  end;

implementation

uses
  System.Classes, System.Math, System.SysUtils, Vcl.Imaging.pngimage,
  Winapi.Windows;

const
  COLOR_LIST_BACKGROUND   = TColor($001A1A1A);
  COLOR_ROW_BACKGROUND    = TColor($00272727);
  COLOR_ROW_BORDER        = TColor($00424242);
  COLOR_ROW_SELECTED      = TColor($003D352A);
  COLOR_TEXT_PRIMARY      = TColor($00E6E6E6);
  COLOR_TEXT_SECONDARY    = TColor($00A8A8A8);
  COLOR_THUMB_BORDER      = TColor($00606060);
  LAYER_GAP               = 6;
  LAYER_LIST_PADDING      = 8;
  LAYER_ROW_HEIGHT        = 82;
  LOCK_BUTTON_TOP         = 45;
  STATE_BUTTON_SIZE       = 20;
  STATE_COLUMN_LEFT       = 4;
  THUMBNAIL_CHECKER_SIZE  = 6;
  THUMBNAIL_HEIGHT        = 54;
  THUMBNAIL_WIDTH         = 96;
  VISIBILITY_BUTTON_TOP   = 17;

function BlendThumbnailColor(Foreground: TColor; Opacity: Single): TColor;
var
  ColorValue: TColor;
begin
  ColorValue := ColorToRGB(Foreground);
  Opacity := EnsureRange(Opacity, 0.0, 1.0);
  Result := RGB(
    Round(GetRValue(ColorValue) * Opacity + $FF * (1 - Opacity)),
    Round(GetGValue(ColorValue) * Opacity + $FF * (1 - Opacity)),
    Round(GetBValue(ColorValue) * Opacity + $FF * (1 - Opacity)));
end;

procedure TVectArtLayerRenderer.DrawImageThumbnail(ACanvas: TCustomCanvas;
  const ThumbnailRect: TRect; ImageLayer: TVectArtImageLayer);
var
  ImageRect: TRect;
  PngImage: TPngImage;
  Stream: TBytesStream;
begin
  if (ACanvas = nil) or (ImageLayer = nil) or
    (Length(ImageLayer.PngData) = 0) then
    Exit;
  PngImage := TPngImage.Create;
  Stream := TBytesStream.Create(ImageLayer.PngData);
  try
    try
      PngImage.LoadFromStream(Stream);
      if (PngImage.Width <= 0) or (PngImage.Height <= 0) then
        Exit;
      ImageRect := FitThumbnailRect(ThumbnailRect, PngImage.Width,
        PngImage.Height);
      ACanvas.StretchDraw(ImageRect, PngImage);
    except
      on EInvalidGraphic do
        Exit;
      on EReadError do
        Exit;
    end;
  finally
    Stream.Free;
    PngImage.Free;
  end;
end;

procedure TVectArtLayerRenderer.DrawLayerItem(ACanvas: TCanvas;
  const ItemRect: TRect; Layer: TVectArtLayer; Selected: Boolean);
var
  CanvasLayer: TVectArtCanvasLayer;
  CellRect: TRect;
  Column: Integer;
  DetailText: string;
  LockRect: TRect;
  LineLayer: TVectArtLineLayer;
  RectangleLayer: TVectArtRectangleLayer;
  RectangleRect: TRect;
  Row: Integer;
  TextX: Integer;
  ThumbnailArea: TRect;
  ThumbnailRect: TRect;
  VisibilityRect: TRect;
begin
  ACanvas.Brush.Style := bsSolid;
  if Selected then
    ACanvas.Brush.Color := COLOR_ROW_SELECTED
  else
    ACanvas.Brush.Color := COLOR_ROW_BACKGROUND;
  ACanvas.FillRect(ItemRect);
  ACanvas.Brush.Style := bsClear;
  ACanvas.Pen.Color := COLOR_ROW_BORDER;
  ACanvas.FrameRect(ItemRect);

  ThumbnailArea := Rect(ItemRect.Left + 30,
    ItemRect.Top + (ItemRect.Height - THUMBNAIL_HEIGHT) div 2,
    Min(ItemRect.Left + 30 + THUMBNAIL_WIDTH, ItemRect.Right - 8),
    ItemRect.Top + (ItemRect.Height + THUMBNAIL_HEIGHT) div 2);
  CanvasLayer := nil;
  if FDocument <> nil then
    CanvasLayer := FDocument.CanvasLayer;
  if (Layer is TVectArtCanvasLayer) and (CanvasLayer <> nil) then
    ThumbnailRect := FitThumbnailRect(ThumbnailArea, CanvasLayer.Width,
      CanvasLayer.Height)
  else
    ThumbnailRect := ThumbnailArea;

  ACanvas.Brush.Style := bsSolid;
  if (Layer is TVectArtCanvasLayer) and
    not TVectArtCanvasLayer(Layer).Transparent then
  begin
    ACanvas.Brush.Color := TVectArtCanvasLayer(Layer).BackgroundColor;
    ACanvas.FillRect(ThumbnailRect);
  end
  else
  begin
    Row := 0;
    while ThumbnailRect.Top + Row * THUMBNAIL_CHECKER_SIZE <
      ThumbnailRect.Bottom do
    begin
      Column := 0;
      while ThumbnailRect.Left + Column * THUMBNAIL_CHECKER_SIZE <
        ThumbnailRect.Right do
      begin
        CellRect := Rect(
          ThumbnailRect.Left + Column * THUMBNAIL_CHECKER_SIZE,
          ThumbnailRect.Top + Row * THUMBNAIL_CHECKER_SIZE,
          Min(ThumbnailRect.Left + (Column + 1) * THUMBNAIL_CHECKER_SIZE,
            ThumbnailRect.Right),
          Min(ThumbnailRect.Top + (Row + 1) * THUMBNAIL_CHECKER_SIZE,
            ThumbnailRect.Bottom));
        if Odd(Row + Column) then
          ACanvas.Brush.Color := TColor($00B8B8B8)
        else
          ACanvas.Brush.Color := clWhite;
        ACanvas.FillRect(CellRect);
        Inc(Column);
      end;
      Inc(Row);
    end;
  end;
  if Layer is TVectArtRectangleLayer then
  begin
    RectangleLayer := TVectArtRectangleLayer(Layer);
    RectangleRect := FitThumbnailRect(ThumbnailRect,
      Max(Round(RectangleLayer.Bounds.Width), 1),
      Max(Round(RectangleLayer.Bounds.Height), 1));
    if Layer.Visible then
      ACanvas.Brush.Color := BlendThumbnailColor(RectangleLayer.FillColor,
        RectangleLayer.Opacity)
    else
      ACanvas.Brush.Color := BlendThumbnailColor(RectangleLayer.FillColor,
        RectangleLayer.Opacity * 0.35);
    ACanvas.FillRect(RectangleRect);
    if RectangleLayer.StrokeWidth > 0 then
    begin
      ACanvas.Pen.Color := BlendThumbnailColor(RectangleLayer.StrokeColor,
        RectangleLayer.Opacity);
      ACanvas.Pen.Width := Max(Round(RectangleLayer.StrokeWidth), 1);
      if RectangleLayer.StrokeStyle <> vssSolid then
        ACanvas.Pen.Style := psDash
      else
        ACanvas.Pen.Style := psSolid;
    end
    else
      ACanvas.Pen.Color := TColor($00707070);
    ACanvas.FrameRect(RectangleRect);
    ACanvas.Pen.Style := psSolid;
    ACanvas.Pen.Width := 1;
  end;
  if Layer is TVectArtLineLayer then
  begin
    LineLayer := TVectArtLineLayer(Layer);
    ACanvas.Pen.Color := BlendThumbnailColor(LineLayer.StrokeColor,
      LineLayer.Opacity);
    ACanvas.Pen.Width := Max(Round(LineLayer.StrokeWidth), 1);
    if LineLayer.StrokeStyle <> vssSolid then
      ACanvas.Pen.Style := psDash
    else
      ACanvas.Pen.Style := psSolid;
    ACanvas.MoveTo(ThumbnailRect.Left + 8, ThumbnailRect.Bottom - 8);
    ACanvas.LineTo(ThumbnailRect.Right - 8, ThumbnailRect.Top + 8);
    ACanvas.Pen.Style := psSolid;
    ACanvas.Pen.Width := 1;
  end;
  if Layer is TVectArtImageLayer then
    DrawImageThumbnail(ACanvas, ThumbnailRect,
      TVectArtImageLayer(Layer));
  ACanvas.Brush.Style := bsClear;
  ACanvas.Pen.Color := COLOR_THUMB_BORDER;
  ACanvas.FrameRect(ThumbnailRect);

  TextX := ThumbnailArea.Right + 8;
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Height := -13;
  ACanvas.Font.Color := COLOR_TEXT_PRIMARY;
  ACanvas.TextOut(TextX, ItemRect.Top + 20, Layer.Name);
  if Layer is TVectArtCanvasLayer then
    DetailText := Format('%d x %d  %d%%', [TVectArtCanvasLayer(Layer).Width,
      TVectArtCanvasLayer(Layer).Height, Round(Layer.Opacity * 100)])
  else if Layer is TVectArtRectangleLayer then
    DetailText := Format('%d x %d  %d%%',
      [Round(TVectArtRectangleLayer(Layer).Bounds.Width),
       Round(TVectArtRectangleLayer(Layer).Bounds.Height),
       Round(Layer.Opacity * 100)])
  else if Layer is TVectArtImageLayer then
    if TVectArtImageLayer(Layer).SourceKind = visLogo then
      DetailText := Format('Logo  %d%%', [Round(Layer.Opacity * 100)])
    else
      DetailText := Format('Image  %d%%', [Round(Layer.Opacity * 100)])
  else if Layer is TVectArtPathLayer then
    DetailText := Format('Path  %d%%', [Round(Layer.Opacity * 100)])
  else
    DetailText := Format('Line  %d%%', [Round(Layer.Opacity * 100)]);
  ACanvas.Font.Height := -11;
  ACanvas.Font.Color := COLOR_TEXT_SECONDARY;
  ACanvas.TextOut(TextX, ItemRect.Top + 43, DetailText);

  VisibilityRect := VisibilityButtonRect(ItemRect);
  LockRect := LockButtonRect(ItemRect);
  ACanvas.Pen.Color := COLOR_TEXT_SECONDARY;
  ACanvas.Brush.Style := bsClear;
  ACanvas.Ellipse(VisibilityRect.Left + 2, VisibilityRect.Top + 5,
    VisibilityRect.Right - 2, VisibilityRect.Bottom - 5);
  if Layer.Visible then
  begin
    ACanvas.Brush.Style := bsSolid;
    ACanvas.Brush.Color := COLOR_TEXT_PRIMARY;
    ACanvas.Ellipse(VisibilityRect.Left + 8, VisibilityRect.Top + 8,
      VisibilityRect.Left + 12, VisibilityRect.Top + 12);
  end;
  ACanvas.Brush.Style := bsClear;
  ACanvas.Rectangle(LockRect.Left + 3, LockRect.Top + 8,
    LockRect.Right - 3, LockRect.Bottom - 2);
  ACanvas.MoveTo(LockRect.Left + 6, LockRect.Top + 8);
  ACanvas.LineTo(LockRect.Left + 6, LockRect.Top + 3);
  ACanvas.LineTo(LockRect.Right - 6, LockRect.Top + 3);
  if Layer.Locked then
    ACanvas.LineTo(LockRect.Right - 6, LockRect.Top + 8);
end;

procedure TVectArtLayerRenderer.DrawLayerItem(ACanvas: TDirect2DCanvas;
  const ItemRect: TRect; Layer: TVectArtLayer; Selected: Boolean);
var
  CanvasLayer: TVectArtCanvasLayer;
  CellRect: TRect;
  Column: Integer;
  DetailText: string;
  LockRect: TRect;
  LineLayer: TVectArtLineLayer;
  RectangleLayer: TVectArtRectangleLayer;
  RectangleRect: TRect;
  Row: Integer;
  TextX: Integer;
  ThumbnailArea: TRect;
  ThumbnailRect: TRect;
  VisibilityRect: TRect;
begin
  ACanvas.Brush.Style := bsSolid;
  if Selected then
    ACanvas.Brush.Color := COLOR_ROW_SELECTED
  else
    ACanvas.Brush.Color := COLOR_ROW_BACKGROUND;
  ACanvas.FillRect(ItemRect);
  ACanvas.Brush.Style := bsClear;
  ACanvas.Pen.Color := COLOR_ROW_BORDER;
  ACanvas.FrameRect(ItemRect);

  ThumbnailArea := Rect(ItemRect.Left + 30,
    ItemRect.Top + (ItemRect.Height - THUMBNAIL_HEIGHT) div 2,
    Min(ItemRect.Left + 30 + THUMBNAIL_WIDTH, ItemRect.Right - 8),
    ItemRect.Top + (ItemRect.Height + THUMBNAIL_HEIGHT) div 2);
  CanvasLayer := nil;
  if FDocument <> nil then
    CanvasLayer := FDocument.CanvasLayer;
  if (Layer is TVectArtCanvasLayer) and (CanvasLayer <> nil) then
    ThumbnailRect := FitThumbnailRect(ThumbnailArea, CanvasLayer.Width,
      CanvasLayer.Height)
  else
    ThumbnailRect := ThumbnailArea;

  ACanvas.Brush.Style := bsSolid;
  if (Layer is TVectArtCanvasLayer) and
    not TVectArtCanvasLayer(Layer).Transparent then
  begin
    ACanvas.Brush.Color := TVectArtCanvasLayer(Layer).BackgroundColor;
    ACanvas.FillRect(ThumbnailRect);
  end
  else
  begin
    Row := 0;
    while ThumbnailRect.Top + Row * THUMBNAIL_CHECKER_SIZE <
      ThumbnailRect.Bottom do
    begin
      Column := 0;
      while ThumbnailRect.Left + Column * THUMBNAIL_CHECKER_SIZE <
        ThumbnailRect.Right do
      begin
        CellRect := Rect(
          ThumbnailRect.Left + Column * THUMBNAIL_CHECKER_SIZE,
          ThumbnailRect.Top + Row * THUMBNAIL_CHECKER_SIZE,
          Min(ThumbnailRect.Left + (Column + 1) * THUMBNAIL_CHECKER_SIZE,
            ThumbnailRect.Right),
          Min(ThumbnailRect.Top + (Row + 1) * THUMBNAIL_CHECKER_SIZE,
            ThumbnailRect.Bottom));
        if Odd(Row + Column) then
          ACanvas.Brush.Color := TColor($00B8B8B8)
        else
          ACanvas.Brush.Color := clWhite;
        ACanvas.FillRect(CellRect);
        Inc(Column);
      end;
      Inc(Row);
    end;
  end;
  if Layer is TVectArtRectangleLayer then
  begin
    RectangleLayer := TVectArtRectangleLayer(Layer);
    RectangleRect := FitThumbnailRect(ThumbnailRect,
      Max(Round(RectangleLayer.Bounds.Width), 1),
      Max(Round(RectangleLayer.Bounds.Height), 1));
    ACanvas.Brush.Color := RectangleLayer.FillColor;
    if Layer.Visible then
      ACanvas.Brush.Handle.SetOpacity(RectangleLayer.Opacity)
    else
      ACanvas.Brush.Handle.SetOpacity(RectangleLayer.Opacity * 0.35);
    ACanvas.FillRect(RectangleRect);
    ACanvas.Brush.Handle.SetOpacity(1.0);
    if RectangleLayer.StrokeWidth > 0 then
    begin
      if Layer.Visible then
        ACanvas.Pen.Color := BlendThumbnailColor(RectangleLayer.StrokeColor,
          RectangleLayer.Opacity)
      else
        ACanvas.Pen.Color := BlendThumbnailColor(RectangleLayer.StrokeColor,
          RectangleLayer.Opacity * 0.35);
      ACanvas.Pen.Width := Max(Round(RectangleLayer.StrokeWidth), 1);
      if RectangleLayer.StrokeStyle <> vssSolid then
        ACanvas.Pen.Style := psDash
      else
        ACanvas.Pen.Style := psSolid;
    end
    else
      ACanvas.Pen.Color := TColor($00707070);
    ACanvas.FrameRect(RectangleRect);
    ACanvas.Pen.Style := psSolid;
    ACanvas.Pen.Width := 1;
  end;
  if Layer is TVectArtLineLayer then
  begin
    LineLayer := TVectArtLineLayer(Layer);
    ACanvas.Pen.Color := BlendThumbnailColor(LineLayer.StrokeColor,
      LineLayer.Opacity);
    ACanvas.Pen.Width := Max(Round(LineLayer.StrokeWidth), 1);
    if LineLayer.StrokeStyle <> vssSolid then
      ACanvas.Pen.Style := psDash
    else
      ACanvas.Pen.Style := psSolid;
    ACanvas.MoveTo(ThumbnailRect.Left + 8, ThumbnailRect.Bottom - 8);
    ACanvas.LineTo(ThumbnailRect.Right - 8, ThumbnailRect.Top + 8);
    ACanvas.Pen.Style := psSolid;
    ACanvas.Pen.Width := 1;
  end;
  if Layer is TVectArtImageLayer then
    DrawImageThumbnail(ACanvas, ThumbnailRect,
      TVectArtImageLayer(Layer));
  ACanvas.Brush.Style := bsClear;
  ACanvas.Pen.Color := COLOR_THUMB_BORDER;
  ACanvas.FrameRect(ThumbnailRect);

  TextX := ThumbnailArea.Right + 8;
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Height := -13;
  ACanvas.Font.Color := COLOR_TEXT_PRIMARY;
  ACanvas.TextOut(TextX, ItemRect.Top + 20, Layer.Name);
  if Layer is TVectArtCanvasLayer then
    DetailText := Format('%d x %d  %d%%', [TVectArtCanvasLayer(Layer).Width,
      TVectArtCanvasLayer(Layer).Height, Round(Layer.Opacity * 100)])
  else if Layer is TVectArtRectangleLayer then
    DetailText := Format('%d x %d  %d%%',
      [Round(TVectArtRectangleLayer(Layer).Bounds.Width),
       Round(TVectArtRectangleLayer(Layer).Bounds.Height),
       Round(Layer.Opacity * 100)])
  else if Layer is TVectArtImageLayer then
    if TVectArtImageLayer(Layer).SourceKind = visLogo then
      DetailText := Format('Logo  %d%%', [Round(Layer.Opacity * 100)])
    else
      DetailText := Format('Image  %d%%', [Round(Layer.Opacity * 100)])
  else if Layer is TVectArtPathLayer then
    DetailText := Format('Path  %d%%', [Round(Layer.Opacity * 100)])
  else
    DetailText := Format('Line  %d%%', [Round(Layer.Opacity * 100)]);
  ACanvas.Font.Height := -11;
  ACanvas.Font.Color := COLOR_TEXT_SECONDARY;
  ACanvas.TextOut(TextX, ItemRect.Top + 43, DetailText);

  VisibilityRect := VisibilityButtonRect(ItemRect);
  LockRect := LockButtonRect(ItemRect);
  ACanvas.Pen.Color := COLOR_TEXT_SECONDARY;
  ACanvas.Brush.Style := bsClear;
  ACanvas.Ellipse(VisibilityRect.Left + 2, VisibilityRect.Top + 5,
    VisibilityRect.Right - 2, VisibilityRect.Bottom - 5);
  if Layer.Visible then
  begin
    ACanvas.Brush.Style := bsSolid;
    ACanvas.Brush.Color := COLOR_TEXT_PRIMARY;
    ACanvas.Ellipse(VisibilityRect.Left + 8, VisibilityRect.Top + 8,
      VisibilityRect.Left + 12, VisibilityRect.Top + 12);
  end;
  ACanvas.Brush.Style := bsClear;
  ACanvas.Rectangle(LockRect.Left + 3, LockRect.Top + 8,
    LockRect.Right - 3, LockRect.Bottom - 2);
  ACanvas.MoveTo(LockRect.Left + 6, LockRect.Top + 8);
  ACanvas.LineTo(LockRect.Left + 6, LockRect.Top + 3);
  ACanvas.LineTo(LockRect.Right - 6, LockRect.Top + 3);
  if Layer.Locked then
    ACanvas.LineTo(LockRect.Right - 6, LockRect.Top + 8);
end;

procedure TVectArtLayerRenderer.DrawLayers(ACanvas: TCanvas;
  const Bounds: TRect);
var
  I: Integer;
  ItemRect: TRect;
begin
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := COLOR_LIST_BACKGROUND;
  ACanvas.FillRect(Bounds);
  if FDocument = nil then
    Exit;
  for I := 1 to FDocument.LayerCount - 1 do
  begin
    ItemRect := LayerItemRect(Bounds, I);
    if ItemRect.Bottom <= Bounds.Top then
      Break;
    DrawLayerItem(ACanvas, ItemRect, FDocument[I],
      FDocument.IsLayerSelected(I));
  end;
end;

procedure TVectArtLayerRenderer.DrawLayers(ACanvas: TDirect2DCanvas;
  const Bounds: TRect);
var
  I: Integer;
  ItemRect: TRect;
begin
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := COLOR_LIST_BACKGROUND;
  ACanvas.FillRect(Bounds);
  if FDocument = nil then
    Exit;
  for I := 1 to FDocument.LayerCount - 1 do
  begin
    ItemRect := LayerItemRect(Bounds, I);
    if ItemRect.Bottom <= Bounds.Top then
      Break;
    DrawLayerItem(ACanvas, ItemRect, FDocument[I],
      FDocument.IsLayerSelected(I));
  end;
end;

function TVectArtLayerRenderer.FitThumbnailRect(
  const AvailableRect: TRect; LogicalWidth, LogicalHeight: Integer): TRect;
var
  DrawHeight: Integer;
  DrawWidth: Integer;
  Scale: Double;
begin
  if (AvailableRect.Width <= 0) or (AvailableRect.Height <= 0) then
    Exit(TRect.Empty);
  Scale := Min(AvailableRect.Width / Max(LogicalWidth, 1),
    AvailableRect.Height / Max(LogicalHeight, 1));
  DrawWidth := Max(Round(LogicalWidth * Scale), 1);
  DrawHeight := Max(Round(LogicalHeight * Scale), 1);
  Result.Left := AvailableRect.Left + (AvailableRect.Width - DrawWidth) div 2;
  Result.Top := AvailableRect.Top + (AvailableRect.Height - DrawHeight) div 2;
  Result.Right := Result.Left + DrawWidth;
  Result.Bottom := Result.Top + DrawHeight;
end;

function TVectArtLayerRenderer.LayerIndexAt(const Bounds: TRect;
  Y: Integer): Integer;
var
  I: Integer;
  ItemRect: TRect;
begin
  Result := -1;
  if FDocument = nil then
    Exit;
  for I := 1 to FDocument.LayerCount - 1 do
  begin
    ItemRect := LayerItemRect(Bounds, I);
    if (Y >= ItemRect.Top) and (Y < ItemRect.Bottom) then
      Exit(I);
  end;
end;

function TVectArtLayerRenderer.LayerItemRect(const Bounds: TRect;
  Index: Integer): TRect;
var
  ItemBottom: Integer;
begin
  if Index <= 0 then
    Exit(TRect.Empty);
  ItemBottom := Bounds.Bottom - LAYER_LIST_PADDING -
    (Index - 1) * (LAYER_ROW_HEIGHT + LAYER_GAP);
  Result := Rect(Bounds.Left + LAYER_LIST_PADDING,
    ItemBottom - LAYER_ROW_HEIGHT,
    Bounds.Right - LAYER_LIST_PADDING, ItemBottom);
end;

function TVectArtLayerRenderer.LockButtonRect(
  const ItemRect: TRect): TRect;
begin
  Result := Rect(ItemRect.Left + STATE_COLUMN_LEFT,
    ItemRect.Top + LOCK_BUTTON_TOP,
    ItemRect.Left + STATE_COLUMN_LEFT + STATE_BUTTON_SIZE,
    ItemRect.Top + LOCK_BUTTON_TOP + STATE_BUTTON_SIZE);
end;

function TVectArtLayerRenderer.VisibilityButtonRect(
  const ItemRect: TRect): TRect;
begin
  Result := Rect(ItemRect.Left + STATE_COLUMN_LEFT,
    ItemRect.Top + VISIBILITY_BUTTON_TOP,
    ItemRect.Left + STATE_COLUMN_LEFT + STATE_BUTTON_SIZE,
    ItemRect.Top + VISIBILITY_BUTTON_TOP + STATE_BUTTON_SIZE);
end;

end.
