program PngOutputTests;

{$APPTYPE CONSOLE}

// PNG出力のキャンバス寸法、背景、全体／選択対象の差を検証する。

uses
  System.Classes, System.IOUtils, System.SysUtils, System.Types,
  Vcl.Graphics, Vcl.Imaging.GIFImg, Vcl.Imaging.jpeg,
  Vcl.Imaging.pngimage, Vcl.Menus,
  TextRendererSkiaBootstrap, TextRendererSkiaRuntime,
  VectArtDesignerDocument in
    'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerObjectContextMenu in
    'Source\Editor\Menus\VectArtDesignerObjectContextMenu.pas',
  VectArtDesignerPngOutput in
    'Source\Shell\File\VectArtDesignerPngOutput.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function RectangleData(const Name: string; const Bounds: TRectF;
  Color: TColor): TVectArtRectangleData;
begin
  Result := Default(TVectArtRectangleData);
  Result.Bounds := Bounds;
  Result.FillColor := Color;
  Result.Filled := True;
  Result.Name := Name;
  Result.Opacity := 1;
  Result.Shape := vpsRectangle;
  Result.StrokeColor := Color;
  Result.StrokeStyle := vssSolid;
  Result.StrokeWidth := 0;
  Result.Visible := True;
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

function FindMenuItem(Menu: TMenuItem; const Caption: string): TMenuItem;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Menu.Count - 1 do
    if Menu.Items[I].Caption = Caption then
      Exit(Menu.Items[I]);
end;

procedure RequirePixel(Image: TPngImage; X, Y: Integer; Color: TColor;
  const MessageText: string);
begin
  Require(ColorToRGB(Image.Pixels[X, Y]) = ColorToRGB(Color), MessageText);
end;

var
  Data: TBytes;
  Document: TVectArtDocument;
  ErrorMessage: string;
  Gif: TGIFImage;
  GifFileName: string;
  Image: TPngImage;
  Jpeg: TJPEGImage;
  JpegFileName: string;
  Menu: TVectArtObjectContextMenu;
  OutputMenu: TMenuItem;
  OutputFileName: string;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Document := TVectArtDocument.Create;
  OutputFileName := TPath.Combine(GetCurrentDir,
    'TestOutput\png-output-test.png');
  GifFileName := ChangeFileExt(OutputFileName, '.gif');
  JpegFileName := ChangeFileExt(OutputFileName, '.jpg');
  try
    Document.SetCanvasSettings(12, 10, clBlue, False);
    Document.InsertRectangle(Document.LayerCount,
      RectangleData('Selected red', RectF(1, 1, 5, 5), clRed));
    Document.InsertRectangle(Document.LayerCount,
      RectangleData('Unselected green', RectF(7, 1, 11, 5), clLime));
    Document.SelectedIndex := 1;

    Menu := TVectArtObjectContextMenu.Create(nil);
    try
      Menu.Document := Document;
      Menu.RefreshState;
      OutputMenu := FindMenuItem(Menu.Items, '出力(&E)');
      Require((OutputMenu <> nil) and OutputMenu.Enabled and
        (OutputMenu.MenuIndex = Menu.Items.Count - 1) and
        (Menu.Items[OutputMenu.MenuIndex - 1].Caption = '-') and
        (OutputMenu.Count = 2) and
        (OutputMenu.Items[0].Caption = 'ファイル...(&F)') and
        (OutputMenu.Items[1].Caption = 'クリップボード(&C)'),
        'Selection output submenu is missing from the context menu');
    finally
      Menu.Free;
    end;

    Require(TryCreateVectArtPng(Document, vposAllObjects, Data,
      ErrorMessage), ErrorMessage);
    Image := DecodePng(Data);
    try
      Require((Image.Width = 12) and (Image.Height = 10),
        'All-object output did not use the canvas dimensions');
      RequirePixel(Image, 0, 0, clBlue,
        'Opaque canvas background was not exported');
      RequirePixel(Image, 3, 3, clRed,
        'Selected object is missing from all-object output');
      RequirePixel(Image, 9, 3, clLime,
        'Unselected object is missing from all-object output');
    finally
      Image.Free;
    end;

    Require(TryCreateVectArtPng(Document, vposSelectedObjects, Data,
      ErrorMessage), ErrorMessage);
    Image := DecodePng(Data);
    try
      Require((Image.Width = 12) and (Image.Height = 10),
        'Selection output did not use the canvas dimensions');
      RequirePixel(Image, 3, 3, clRed,
        'Selected object is missing from selection output');
      RequirePixel(Image, 9, 3, clBlue,
        'Unselected object leaked into selection output');
    finally
      Image.Free;
    end;

    Document.SetCanvasSettings(12, 10, clBlue, True);
    Require(TryCreateVectArtPng(Document, vposSelectedObjects, Data,
      ErrorMessage), ErrorMessage);
    Image := DecodePng(Data);
    try
      Require(Image.AlphaScanline[0]^[0] = 0,
        'Transparent canvas background became opaque');
      Require(Image.AlphaScanline[3]^[3] = 255,
        'Selected object lost opacity on a transparent canvas');
    finally
      Image.Free;
    end;

    ForceDirectories(ExtractFileDir(OutputFileName));
    Require(TrySaveVectArtPng(Document, vposAllObjects, OutputFileName,
      ErrorMessage), ErrorMessage);
    Require(TFile.Exists(OutputFileName) and
      (TFile.GetSize(OutputFileName) > 0), 'PNG file was not written');

    Require(TrySaveVectArtImage(Document, vposAllObjects, GifFileName,
      ErrorMessage), ErrorMessage);
    Gif := TGIFImage.Create;
    try
      Gif.LoadFromFile(GifFileName);
      Require((Gif.Width = 12) and (Gif.Height = 10),
        'GIF output did not use the canvas dimensions');
      Require(ColorToRGB(Gif.Bitmap.Canvas.Pixels[0, 0]) =
        ColorToRGB(clWhite),
        'Transparent GIF output was not flattened onto white');
    finally
      Gif.Free;
    end;

    Require(TrySaveVectArtImage(Document, vposAllObjects, JpegFileName,
      ErrorMessage), ErrorMessage);
    Jpeg := TJPEGImage.Create;
    try
      Jpeg.LoadFromFile(JpegFileName);
      Require((Jpeg.Width = 12) and (Jpeg.Height = 10),
        'JPEG output did not use the canvas dimensions');
    finally
      Jpeg.Free;
    end;

    Document.SelectedIndex := -1;
    Require(not CanOutputVectArtPng(Document, vposSelectedObjects),
      'Selection output stayed enabled without a selection');
    Writeln('Image output tests: PASS');
  finally
    if TFile.Exists(OutputFileName) then
      TFile.Delete(OutputFileName);
    if TFile.Exists(GifFileName) then
      TFile.Delete(GifFileName);
    if TFile.Exists(JpegFileName) then
      TFile.Delete(JpegFileName);
    Document.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
