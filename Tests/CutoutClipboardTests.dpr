program CutoutClipboardTests;

{$APPTYPE CONSOLE}

// Verify raster bounds, canvas clipping, and transparent non-rectangular masks.

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
  TextRendererSkiaBootstrap,
  TextRendererSkiaRuntime,
  VectArtDesignerGeometry in
    'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerDocument in
    'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerEditHistory in
    'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerEditorState in
    'Source\Core\VectArtDesignerEditorState.pas',
  VectArtDesignerClipboardOperations in
    'Source\Editor\Clipboard\VectArtDesignerClipboardOperations.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function DecodePng(const Data: TBytes): TPngImage;
var
  Stream: TBytesStream;
begin
  Result := TPngImage.Create;
  Stream := TBytesStream.Create(Data);
  try
    Result.LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

var
  Data: TBytes;
  Document: TVectArtDocument;
  Image: TPngImage;
  Points: TArray<TPointF>;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Document := TVectArtDocument.Create;
  try
    Document.SetCanvasSize(100, 80);
    Document.CanvasLayer.BackgroundColor := clRed;
    Document.CanvasLayer.Transparent := False;

    Points := [PointF(10, 10), PointF(30, 10), PointF(30, 30),
      PointF(10, 30)];
    Data := CreateVectArtRegionPng(Document, vcmEllipse, Points);
    Image := DecodePng(Data);
    try
      Require((Image.Width = 20) and (Image.Height = 20),
        Format('Ellipse copy dimensions differ: %d x %d',
          [Image.Width, Image.Height]));
      Require(Image.AlphaScanline[0]^[0] = 0,
        'Ellipse corner is not transparent');
      Require(Image.AlphaScanline[10]^[10] = 255,
        'Ellipse center is not opaque');
    finally
      Image.Free;
    end;

    Points := [PointF(-10, -10), PointF(10, -10), PointF(10, 10),
      PointF(-10, 10)];
    Data := CreateVectArtRegionPng(Document, vcmRectangle, Points);
    Image := DecodePng(Data);
    try
      Require((Image.Width = 10) and (Image.Height = 10),
        'Rectangle copy was not clipped to the canvas');
      Require(Image.AlphaScanline[5]^[5] = 255,
        'Opaque canvas background was not copied');
    finally
      Image.Free;
    end;

    Points := [PointF(10, 10), PointF(30, 10), PointF(20, 30)];
    Data := CreateVectArtRegionPng(Document, vcmPolygon, Points);
    Image := DecodePng(Data);
    try
      Require(Image.AlphaScanline[19]^[0] = 0,
        'Polygon exterior is not transparent');
      Require(Image.AlphaScanline[5]^[10] = 255,
        'Polygon interior is not opaque');
    finally
      Image.Free;
    end;
    Writeln('Cutout clipboard tests: PASS');
  finally
    Document.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
