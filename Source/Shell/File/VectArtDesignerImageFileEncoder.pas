// 生成済みPNGを指定されたPNG／GIF／JPEGファイルへ保存する。
// GIF／JPEGでは完全なアルファを表現できないため、透明部分を白へ合成する。
unit VectArtDesignerImageFileEncoder;

interface

uses
  System.SysUtils;

function TryWriteVectArtImageFile(const PngData: TBytes;
  const FileName: string; out ErrorMessage: string): Boolean;

implementation

uses
  System.Classes, System.IOUtils, System.StrUtils, System.Types,
  Vcl.Graphics, Vcl.Imaging.GIFImg, Vcl.Imaging.jpeg,
  Vcl.Imaging.pngimage;

function ConvertPngToOpaqueFormat(const PngData: TBytes;
  const Extension: string): TBytes;
var
  Gif: TGIFImage;
  Jpeg: TJPEGImage;
  Png: TPngImage;
  RasterBitmap: Vcl.Graphics.TBitmap;
  SourceStream: TBytesStream;
  TargetStream: TMemoryStream;
begin
  SourceStream := TBytesStream.Create(PngData);
  TargetStream := TMemoryStream.Create;
  Png := TPngImage.Create;
  RasterBitmap := Vcl.Graphics.TBitmap.Create;
  try
    Png.LoadFromStream(SourceStream);
    RasterBitmap.PixelFormat := pf24bit;
    RasterBitmap.SetSize(Png.Width, Png.Height);
    RasterBitmap.Canvas.Brush.Color := clWhite;
    RasterBitmap.Canvas.FillRect(Rect(0, 0, RasterBitmap.Width,
      RasterBitmap.Height));
    RasterBitmap.Canvas.Draw(0, 0, Png);
    if SameText(Extension, '.gif') then
    begin
      Gif := TGIFImage.Create;
      try
        Gif.Assign(RasterBitmap);
        Gif.SaveToStream(TargetStream);
      finally
        Gif.Free;
      end;
    end
    else
    begin
      Jpeg := TJPEGImage.Create;
      try
        Jpeg.CompressionQuality := 92;
        Jpeg.ProgressiveEncoding := False;
        Jpeg.Assign(RasterBitmap);
        Jpeg.SaveToStream(TargetStream);
      finally
        Jpeg.Free;
      end;
    end;
    SetLength(Result, TargetStream.Size);
    if TargetStream.Size > 0 then
    begin
      TargetStream.Position := 0;
      TargetStream.ReadBuffer(Result[0], TargetStream.Size);
    end;
  finally
    RasterBitmap.Free;
    Png.Free;
    TargetStream.Free;
    SourceStream.Free;
  end;
end;

function TryWriteVectArtImageFile(const PngData: TBytes;
  const FileName: string; out ErrorMessage: string): Boolean;
var
  Extension: string;
  ImageData: TBytes;
begin
  Result := False;
  ErrorMessage := '';
  Extension := LowerCase(ExtractFileExt(FileName));
  if not MatchText(Extension, ['.png', '.gif', '.jpg', '.jpeg']) then
  begin
    ErrorMessage := '出力形式はPNG、GIF、JPEGから選択してください。';
    Exit;
  end;
  try
    if Extension = '.png' then
      ImageData := PngData
    else
      ImageData := ConvertPngToOpaqueFormat(PngData, Extension);
    TFile.WriteAllBytes(FileName, ImageData);
    Result := True;
  except
    on E: Exception do
      ErrorMessage := '画像ファイルを保存できませんでした: ' + E.Message;
  end;
end;

end.
