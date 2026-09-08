program GroupThumbnailRendererTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  TextRendererSkiaBootstrap in
    'Lib\TextRenderer\TextRendererSkiaBootstrap.pas',
  TextRendererSkiaRuntime in
    'Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerTextGeometry in
    'Source\Core\VectArtDesignerTextGeometry.pas',
  VectArtDesignerBezierGeometry in
    'Source\Editor\Geometry\VectArtDesignerBezierGeometry.pas',
  VectArtDesignerRenderer in
    'Source\Rendering\VectArtDesignerRenderer.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function RectangleData(const Bounds: TRectF; Color: TColor;
  GroupId: TVectArtGroupId): TVectArtRectangleData;
begin
  Result := Default(TVectArtRectangleData);
  Result.Bounds := Bounds;
  Result.FillColor := Color;
  Result.Filled := True;
  Result.GroupId := GroupId;
  Result.Name := 'Member';
  Result.Opacity := 1;
  Result.Visible := True;
end;

function PixelAt(Buffer: TVectArtRenderBuffer; X,
  Y: Integer): TVectArtRgbaPixel;
begin
  Result := Buffer.Pixels[Y * Buffer.Width + X];
end;

var
  BluePixel: TVectArtRgbaPixel;
  Buffer: TVectArtRenderBuffer;
  Document: TVectArtDocument;
  GroupId: TVectArtGroupId;
  RedPixel: TVectArtRgbaPixel;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Buffer := TVectArtRenderBuffer.Create;
  Document := TVectArtDocument.Create;
  try
    GroupId := Document.AllocateGroupId;
    Document.InsertRectangle(1,
      RectangleData(RectF(0, 0, 20, 20), clRed, GroupId));
    Document.InsertRectangle(2,
      RectangleData(RectF(80, 0, 100, 20), clBlue, GroupId));
    RenderVectArtGroupThumbnail(Document, GroupId, Buffer, 100, 40);
    RedPixel := PixelAt(Buffer, 14, 20);
    BluePixel := PixelAt(Buffer, 86, 20);
    Require((RedPixel.A > 0) and (RedPixel.R > RedPixel.B),
      'First group member is missing from the thumbnail');
    Require((BluePixel.A > 0) and (BluePixel.B > BluePixel.R),
      'Second group member is missing from the thumbnail');
    Writeln('PASS group thumbnail renders every member');
  finally
    Document.Free;
    Buffer.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
