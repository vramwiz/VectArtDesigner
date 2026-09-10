// キャンバス実寸の画像生成、ファイル出力、PNGクリップボード出力を提供する。
// PNG以外は透明度を白へ合成し、全体／選択の対象差と切抜き規則は共通化する。
unit VectArtDesignerPngOutput;

interface

uses
  System.SysUtils, VectArtDesignerDocument;

type
  TVectArtPngOutputScope = (vposAllObjects, vposSelectedObjects);

function CanOutputVectArtPng(Document: TVectArtDocument;
  Scope: TVectArtPngOutputScope): Boolean;
function TryCreateVectArtPng(Document: TVectArtDocument;
  Scope: TVectArtPngOutputScope; out PngData: TBytes;
  out ErrorMessage: string): Boolean;
function TrySaveVectArtPng(Document: TVectArtDocument;
  Scope: TVectArtPngOutputScope; const FileName: string;
  out ErrorMessage: string): Boolean;
function TrySaveVectArtImage(Document: TVectArtDocument;
  Scope: TVectArtPngOutputScope; const FileName: string;
  out ErrorMessage: string): Boolean;
function TryCopyVectArtPngToClipboard(Document: TVectArtDocument;
  Scope: TVectArtPngOutputScope; out ErrorMessage: string): Boolean;

implementation

uses
  System.Classes, System.Types, Vcl.Clipbrd, Vcl.Graphics,
  Vcl.Imaging.pngimage, Winapi.Windows, VectArtDesignerImageFileEncoder,
  VectArtDesignerMifRaster, VectArtDesignerRenderer;

const
  CLIPBOARD_PNG_FORMAT_NAME = 'PNG';
  MAX_OUTPUT_DIMENSION = 16384;

function CanOutputVectArtPng(Document: TVectArtDocument;
  Scope: TVectArtPngOutputScope): Boolean;
var
  Canvas: TVectArtCanvasLayer;
begin
  Result := False;
  if Document = nil then
    Exit;
  Canvas := Document.CanvasLayer;
  if (Canvas = nil) or (Canvas.Width <= 0) or (Canvas.Height <= 0) or
    (Canvas.Width > MAX_OUTPUT_DIMENSION) or
    (Canvas.Height > MAX_OUTPUT_DIMENSION) or
    (Int64(Canvas.Width) * Canvas.Height > MaxInt) then
    Exit;
  Result := (Scope = vposAllObjects) or (Document.SelectionCount > 0);
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

procedure RenderSelectedObjects(Document: TVectArtDocument;
  Target: TVectArtRenderBuffer; Width, Height: Integer);
var
  Bounds: TRectF;
  I: Integer;
  LayerBuffer: TVectArtRenderBuffer;
begin
  Target.SetSize(Width, Height);
  Target.Clear;
  Bounds := RectF(0, 0, Width, Height);
  LayerBuffer := TVectArtRenderBuffer.Create;
  try
    for I := 1 to Document.LayerCount - 1 do
      if Document.IsLayerSelected(I) then
      begin
        RenderVectArtDocumentRegion(Document, LayerBuffer, Width, Height,
          Bounds, VECTART_NO_GROUP, 0, False, I);
        CompositeVectArtRgba(LayerBuffer, Target.Data, Width, Height);
      end;
  finally
    LayerBuffer.Free;
  end;
end;

function TryCreateVectArtPng(Document: TVectArtDocument;
  Scope: TVectArtPngOutputScope; out PngData: TBytes;
  out ErrorMessage: string): Boolean;
var
  Buffer: TVectArtRenderBuffer;
  Canvas: TVectArtCanvasLayer;
begin
  Result := False;
  PngData := nil;
  ErrorMessage := '';
  if (Document = nil) or (Document.CanvasLayer = nil) then
  begin
    ErrorMessage := 'キャンバスがありません。';
    Exit;
  end;
  Canvas := Document.CanvasLayer;
  if (Canvas.Width > MAX_OUTPUT_DIMENSION) or
    (Canvas.Height > MAX_OUTPUT_DIMENSION) or
    (Int64(Canvas.Width) * Canvas.Height > MaxInt) then
  begin
    ErrorMessage := Format('PNG出力は最大%d x %dピクセルです。',
      [MAX_OUTPUT_DIMENSION, MAX_OUTPUT_DIMENSION]);
    Exit;
  end;
  if not CanOutputVectArtPng(Document, Scope) then
  begin
    if Scope = vposSelectedObjects then
      ErrorMessage := '出力するオブジェクトが選択されていません。'
    else
      ErrorMessage := 'キャンバスサイズが正しくありません。';
    Exit;
  end;
  Buffer := TVectArtRenderBuffer.Create;
  try
    try
      if Scope = vposSelectedObjects then
        RenderSelectedObjects(Document, Buffer, Canvas.Width, Canvas.Height)
      else
        RenderVectArtDocument(Document, Buffer, Canvas.Width, Canvas.Height);
      CompositeCanvasBackground(Buffer, Canvas);
      PngData := EncodeRgba(Buffer.Data, Buffer.Width, Buffer.Height);
      Result := Length(PngData) > 0;
      if not Result then
        ErrorMessage := 'PNGデータを生成できませんでした。';
    except
      on E: Exception do
        ErrorMessage := 'PNG出力に失敗しました: ' + E.Message;
    end;
  finally
    Buffer.Free;
  end;
end;

function TrySaveVectArtPng(Document: TVectArtDocument;
  Scope: TVectArtPngOutputScope; const FileName: string;
  out ErrorMessage: string): Boolean;
var
  PngData: TBytes;
begin
  Result := TryCreateVectArtPng(Document, Scope, PngData, ErrorMessage);
  if not Result then
    Exit;
  Result := TryWriteVectArtImageFile(PngData, FileName, ErrorMessage);
end;

function TrySaveVectArtImage(Document: TVectArtDocument;
  Scope: TVectArtPngOutputScope; const FileName: string;
  out ErrorMessage: string): Boolean;
var
  ImageData: TBytes;
begin
  Result := TryCreateVectArtPng(Document, Scope, ImageData, ErrorMessage);
  if not Result then
    Exit;
  Result := TryWriteVectArtImageFile(ImageData, FileName, ErrorMessage);
end;

function BytesToGlobalHandle(const Data: TBytes): HGLOBAL;
var
  Target: Pointer;
begin
  Result := GlobalAlloc(GMEM_MOVEABLE or GMEM_ZEROINIT, Length(Data));
  if Result = 0 then
    RaiseLastOSError;
  Target := GlobalLock(Result);
  if Target = nil then
  begin
    GlobalFree(Result);
    RaiseLastOSError;
  end;
  try
    if Length(Data) > 0 then
      Move(Data[0], Target^, Length(Data));
  finally
    GlobalUnlock(Result);
  end;
end;

function TryCopyVectArtPngToClipboard(Document: TVectArtDocument;
  Scope: TVectArtPngOutputScope; out ErrorMessage: string): Boolean;
var
  Handle: HGLOBAL;
  Png: TPngImage;
  PngData: TBytes;
  Stream: TBytesStream;
begin
  Result := TryCreateVectArtPng(Document, Scope, PngData, ErrorMessage);
  if not Result then
    Exit;
  Stream := TBytesStream.Create(PngData);
  Png := TPngImage.Create;
  try
    try
      Png.LoadFromStream(Stream);
      Clipboard.Open;
      try
        Clipboard.Assign(Png);
        Handle := BytesToGlobalHandle(PngData);
        Clipboard.SetAsHandle(RegisterClipboardFormat(
          CLIPBOARD_PNG_FORMAT_NAME), Handle);
        Result := True;
      finally
        Clipboard.Close;
      end;
    except
      on E: Exception do
      begin
        Result := False;
        ErrorMessage := 'クリップボードへ出力できませんでした: ' + E.Message;
      end;
    end;
  finally
    Png.Free;
    Stream.Free;
  end;
end;

end.
