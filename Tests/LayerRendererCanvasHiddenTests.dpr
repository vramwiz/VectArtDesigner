program LayerRendererCanvasHiddenTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerLayerRenderer in
    'Source\Layers\VectArtDesignerLayerRenderer.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function CenterY(const Bounds: TRect): Integer;
begin
  Result := Bounds.Top + Bounds.Height div 2;
end;

function LineData(const Name: string; Width: Single): TVectArtLineData;
begin
  Result.StartPoint := TPointF.Create(0, 0);
  Result.EndPoint := TPointF.Create(100, 100);
  Result.Locked := False;
  Result.LineCap := vlcButt;
  Result.AntiAlias := True;
  Result.EndMarker := vlmNone;
  Result.EndMarkerSize := 4.0;
  Result.StartMarker := vlmNone;
  Result.StartMarkerSize := 4.0;
  Result.LineJoin := vljMiter;
  Result.Name := Name;
  Result.Opacity := 1.0;
  Result.StrokeColor := clRed;
  Result.StrokeStyle := vssSolid;
  Result.StrokeWidth := Width;
  Result.Visible := True;
end;

function PathData: TVectArtPathData;
begin
  Result.Closed := False;
  Result.FillColor := clWhite;
  Result.Filled := False;
  Result.Locked := False;
  Result.Name := 'Continuous line';
  Result.Opacity := 1.0;
  SetLength(Result.Points, 4);
  Result.Points[0] := TPointF.Create(0, 80);
  Result.Points[1] := TPointF.Create(30, 0);
  Result.Points[2] := TPointF.Create(70, 80);
  Result.Points[3] := TPointF.Create(100, 20);
  Result.StrokeColor := clBlue;
  Result.StrokeStyle := vssSolid;
  Result.StrokeWidth := 5.0;
  Result.Visible := True;
end;

var
  Bitmap: TBitmap;
  Bounds: TRect;
  Data: TVectArtRectangleData;
  Document: TVectArtDocument;
  FirstRect: TRect;
  LineEnd: TPoint;
  LineItemRect: TRect;
  LineStart: TPoint;
  LineThumbnailRect: TRect;
  PathItemRect: TRect;
  PathThumbnailRect: TRect;
  BlueInside: Integer;
  BlueOutside: Integer;
  RedInside: Integer;
  RedOutside: Integer;
  Renderer: TVectArtLayerRenderer;
  SecondRect: TRect;
  X: Integer;
  Y: Integer;
begin
  Document := TVectArtDocument.Create;
  Renderer := TVectArtLayerRenderer.Create;
  Bitmap := TBitmap.Create;
  try
    Bounds := Rect(0, 0, 320, 480);
    Renderer.Document := Document;
    Require(Renderer.LayerItemRect(Bounds, 0).IsEmpty,
      'Canvas layer still has a visible row');
    Require(Renderer.LayerIndexAt(Bounds, Bounds.Bottom - 10) = -1,
      'Empty document exposes the canvas layer');

    Data.Bounds := TRectF.Create(0, 0, 100, 100);
    Data.FillColor := clRed;
    Data.Locked := False;
    Data.Name := 'Rectangle 1';
    Data.Opacity := 1.0;
    Data.RotationDegrees := 0.0;
    Data.StrokeColor := clBlack;
    Data.StrokeStyle := vssSolid;
    Data.StrokeWidth := 0.0;
    Data.Visible := True;
    Document.InsertRectangle(Document.LayerCount, Data);
    Data.Name := 'Rectangle 2';
    Document.InsertRectangle(Document.LayerCount, Data);

    FirstRect := Renderer.LayerItemRect(Bounds, 1);
    SecondRect := Renderer.LayerItemRect(Bounds, 2);
    Require(FirstRect.Bottom = Bounds.Bottom - 8,
      'First object row did not replace the hidden canvas row');
    Require(Renderer.LayerIndexAt(Bounds, CenterY(FirstRect)) = 1,
      'First object row hit test failed');
    Require(Renderer.LayerIndexAt(Bounds, CenterY(SecondRect)) = 2,
      'Second object row hit test failed');
    Require((VectArtLineThumbnailStrokeWidth(1.0) = 1) and
      (VectArtLineThumbnailStrokeWidth(4.0) > 1) and
      (VectArtLineThumbnailStrokeWidth(100.0) = 10) and
      (VectArtLineThumbnailStrokeWidth(10000.0) = 10),
      'Line thumbnail stroke mapping is not increasing and capped');
    VectArtLineThumbnailPoints(Rect(10, 20, 106, 74), 10,
      LineStart, LineEnd);
    Require((LineStart.X >= 18) and (LineStart.Y <= 66) and
      (LineEnd.X <= 98) and (LineEnd.Y >= 28),
      'Thick line thumbnail endpoints do not preserve an inner margin');

    Document.InsertLine(Document.LayerCount, LineData('Thick line', 1000));
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(Bounds.Width, Bounds.Height);
    Renderer.DrawLayers(Bitmap.Canvas, Bounds);
    LineItemRect := Renderer.LayerItemRect(Bounds, 3);
    LineThumbnailRect := Rect(LineItemRect.Left + 30,
      LineItemRect.Top + (LineItemRect.Height - 54) div 2,
      LineItemRect.Left + 30 + 96,
      LineItemRect.Top + (LineItemRect.Height + 54) div 2);
    RedInside := 0;
    RedOutside := 0;
    for Y := LineItemRect.Top to LineItemRect.Bottom - 1 do
      for X := LineItemRect.Left to LineItemRect.Right - 1 do
        if ColorToRGB(Bitmap.Canvas.Pixels[X, Y]) = ColorToRGB(clRed) then
          if PtInRect(LineThumbnailRect, Point(X, Y)) then
            Inc(RedInside)
          else
            Inc(RedOutside);
    Require((RedInside > 0) and (RedOutside = 0),
      'Thick line thumbnail escaped its background');
    Document.InsertPath(Document.LayerCount, PathData);
    Renderer.DrawLayers(Bitmap.Canvas, Bounds);
    PathItemRect := Renderer.LayerItemRect(Bounds, 4);
    PathThumbnailRect := Rect(PathItemRect.Left + 30,
      PathItemRect.Top + (PathItemRect.Height - 54) div 2,
      PathItemRect.Left + 30 + 96,
      PathItemRect.Top + (PathItemRect.Height + 54) div 2);
    BlueInside := 0;
    BlueOutside := 0;
    for Y := PathItemRect.Top to PathItemRect.Bottom - 1 do
      for X := PathItemRect.Left to PathItemRect.Right - 1 do
        if ColorToRGB(Bitmap.Canvas.Pixels[X, Y]) = ColorToRGB(clBlue) then
          if PtInRect(PathThumbnailRect, Point(X, Y)) then
            Inc(BlueInside)
          else
            Inc(BlueOutside);
    Require((BlueInside > 0) and (BlueOutside = 0),
      'Continuous-line thumbnail was not drawn inside its background');
    Writeln('Layer renderer canvas-hidden tests: PASS');
  finally
    Bitmap.Free;
    Renderer.Free;
    Document.Free;
  end;
end.
