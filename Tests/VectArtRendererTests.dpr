program VectArtRendererTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  TextRendererSkiaBootstrap in
    'Lib\TextRenderer\TextRendererSkiaBootstrap.pas',
  TextRendererSkiaRuntime in
    'Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  VectArtDesignerDocument in
    'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerRenderer in
    'Source\Rendering\VectArtDesignerRenderer.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function PixelAt(Buffer: TVectArtRenderBuffer;
  X, Y: Integer): PVectArtRgbaPixel;
begin
  Result := Buffer.Data;
  Inc(Result, NativeInt(Y) * Buffer.Width + X);
end;

var
  Data: TVectArtRectangleData;
  ButtCapAlpha: Byte;
  DefaultThinAlpha: Byte;
  LineData: TVectArtLineData;
  Destination: TVectArtRenderBuffer;
  Document: TVectArtDocument;
  I: NativeInt;
  Pixel: PVectArtRgbaPixel;
  Rendered: TVectArtRenderBuffer;
  RoundCapAlpha: Byte;
  EnhancedThinAlpha: Byte;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Document := TVectArtDocument.Create;
  Rendered := TVectArtRenderBuffer.Create;
  Destination := TVectArtRenderBuffer.Create;
  try
    Document.CanvasLayer.Width := 8;
    Document.CanvasLayer.Height := 8;
    RenderVectArtDocument(Document, Rendered, 8, 8);
    Require(PixelAt(Rendered, 3, 3)^.A = 0,
      'Empty document is not transparent');

    Data.Bounds := TRectF.Create(2, 2, 6, 6);
    Data.FillColor := TColor($000000FF);
    Data.Locked := False;
    Data.Name := 'Rectangle 1';
    Data.Opacity := 0.5;
    Data.RotationDegrees := 0.0;
    Data.StrokeColor := clBlack;
    Data.MifStrokeStyle := vssSolid;
    Data.StrokeWidth := 0.0;
    Data.Visible := True;
    Document.InsertRectangle(Document.LayerCount, Data);
    RenderVectArtDocument(Document, Rendered, 8, 8);
    Pixel := PixelAt(Rendered, 3, 3);
    Require((Pixel^.R >= 250) and (Pixel^.G <= 5) and (Pixel^.B <= 5),
      'Rectangle color differs');
    Require((Pixel^.A >= 127) and (Pixel^.A <= 128),
      'Rectangle opacity differs');
    Require(PixelAt(Rendered, 0, 0)^.A = 0,
      'Outside rectangle is not transparent');

    Document.SetRectangleBounds(1, TRectF.Create(1, 3, 7, 5));
    Document.SetRectangleRotation(1, 90.0);
    RenderVectArtDocument(Document, Rendered, 8, 8);
    Require(PixelAt(Rendered, 4, 1)^.A > 0,
      'Rotated rectangle was not drawn at the rotated position');
    Require(PixelAt(Rendered, 1, 4)^.A = 0,
      'Rotated rectangle still occupies the unrotated position');

    Destination.SetSize(8, 8);
    Pixel := Destination.Data;
    for I := 0 to Destination.PixelCount - 1 do
    begin
      Pixel^.R := 0;
      Pixel^.G := 0;
      Pixel^.B := 255;
      Pixel^.A := 255;
      Inc(Pixel);
    end;
    CompositeVectArtRgba(Rendered, Destination.Data, 8, 8);
    Pixel := PixelAt(Destination, 3, 3);
    Require((Pixel^.R >= 127) and (Pixel^.R <= 128) and
      (Pixel^.B >= 127) and (Pixel^.B <= 128) and (Pixel^.A = 255),
      'RGBA source-over composition differs');

    Document.SetRectangleBounds(1, TRectF.Create(2, 2, 6, 6));
    Document.SetRectangleRotation(1, 0.0);
    Document.SetRectangleFillColor(1, clWhite);
    Document.SetLayerOpacity(1, 1.0);
    Document.SetRectangleStroke(1, clBlack, 2.0, vssSolid);
    RenderVectArtDocument(Document, Rendered, 8, 8);
    Pixel := PixelAt(Rendered, 2, 4);
    Require((Pixel^.R <= 5) and (Pixel^.G <= 5) and (Pixel^.B <= 5) and
      (Pixel^.A >= 250), 'Rectangle stroke was not rendered');
    Pixel := PixelAt(Rendered, 4, 4);
    Require((Pixel^.R >= 250) and (Pixel^.G >= 250) and (Pixel^.B >= 250),
      'Rectangle fill was not kept separate from the stroke');
    LineData.StartPoint := TPointF.Create(0, 0);
    LineData.EndPoint := TPointF.Create(7, 7);
    LineData.Locked := False;
    LineData.LineCap := vlcButt;
    LineData.MifAntiAlias := True;
    LineData.MifEndMarker := vlmNone;
    LineData.MifEndMarkerSize := 4.0;
    LineData.MifStartMarker := vlmNone;
    LineData.MifStartMarkerSize := 4.0;
    LineData.LineJoin := vljMiter;
    LineData.Name := 'Line 1';
    LineData.Opacity := 1.0;
    LineData.StrokeColor := clRed;
    LineData.MifStrokeStyle := vssSolid;
    LineData.StrokeWidth := 2.0;
    LineData.Visible := True;
    Document.InsertLine(Document.LayerCount, LineData);
    RenderVectArtDocument(Document, Rendered, 8, 8);
    Pixel := PixelAt(Rendered, 0, 0);
    Require((Pixel^.R >= 200) and (Pixel^.A > 0),
      'Line was not rendered');
    Document.SetLayerVisible(1, False);
    Document.SetLinePoints(2, TPointF.Create(1, 0), TPointF.Create(6, 0));
    Document.SetLineStroke(2, clRed, 0.1, vssSolid);
    RenderVectArtDocument(Document, Rendered, 8, 8);
    DefaultThinAlpha := PixelAt(Rendered, 3, 1)^.A;
    RenderVectArtDocument(Document, Rendered, 8, 8, 3.0);
    EnhancedThinAlpha := PixelAt(Rendered, 3, 1)^.A;
    Require(EnhancedThinAlpha > DefaultThinAlpha,
      'Preview minimum stroke width was not applied');
    Document.SetLinePoints(2, TPointF.Create(3, 4), TPointF.Create(6, 4));
    Document.SetLineStroke(2, clRed, 4.0, vssSolid);
    Document.SetLineCap(2, vlcButt);
    RenderVectArtDocument(Document, Rendered, 8, 8);
    ButtCapAlpha := PixelAt(Rendered, 1, 4)^.A;
    Document.SetLineCap(2, vlcRound);
    RenderVectArtDocument(Document, Rendered, 8, 8);
    RoundCapAlpha := PixelAt(Rendered, 1, 4)^.A;
    Require(RoundCapAlpha > ButtCapAlpha,
      'Round line cap did not extend beyond a butt cap');
    Writeln('VectArt shared renderer: PASS');
  finally
    Destination.Free;
    Rendered.Free;
    Document.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
