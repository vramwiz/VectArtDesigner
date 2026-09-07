// 画像ファイルを自己完結したPNGデータへ変換し、ドロップ配置用Imageデータを作る。
// 取込元パスは出典情報として残すが、描画と保存は埋め込みPNGだけに依存する。
unit VectArtDesignerImageFileImport;

interface

uses
  System.Types, VectArtDesignerDocument;

function TryCreateVectArtImageFromFile(const FileName: string;
  const DropPoint: TPointF; CanvasWidth, CanvasHeight: Single;
  out Data: TVectArtImageData; out ErrorMessage: string): Boolean;

implementation

uses
  System.Classes, System.IOUtils, System.Math, System.SysUtils,
  Vcl.Graphics, Vcl.WicImageInit;

function WicImageAsPng(Image: TWICImage): TBytes;
var
  Stream: TMemoryStream;
begin
  Result := nil;
  Stream := TMemoryStream.Create;
  try
    Image.ImageFormat := wifPng;
    Image.SaveToStream(Stream);
    if Stream.Size <= 0 then
      Exit;
    SetLength(Result, Stream.Size);
    Stream.Position := 0;
    Stream.ReadBuffer(Result[0], Length(Result));
  finally
    Stream.Free;
  end;
end;

function TryCreateVectArtImageFromFile(const FileName: string;
  const DropPoint: TPointF; CanvasWidth, CanvasHeight: Single;
  out Data: TVectArtImageData; out ErrorMessage: string): Boolean;
var
  DisplayHeight: Single;
  DisplayWidth: Single;
  FullFileName: string;
  Left: Single;
  Image: TWICImage;
  Scale: Single;
  Top: Single;
begin
  Result := False;
  Data := Default(TVectArtImageData);
  ErrorMessage := '';
  try
    FullFileName := TPath.GetFullPath(FileName);
    if not TFile.Exists(FullFileName) then
      raise EFileNotFoundException.Create('Image file was not found.');
    Image := TWICImage.Create;
    try
      Image.LoadFromFile(FullFileName);
      if Image.Empty or (Image.Width <= 0) or (Image.Height <= 0) then
        raise EInvalidGraphic.Create('The file does not contain a usable image.');
      Data.PngData := WicImageAsPng(Image);
      if Length(Data.PngData) = 0 then
        raise EInvalidGraphic.Create('The image could not be embedded as PNG.');
      CanvasWidth := Max(CanvasWidth, 1.0);
      CanvasHeight := Max(CanvasHeight, 1.0);
      Scale := Min(1.0, Min(CanvasWidth * 0.8 / Image.Width,
        CanvasHeight * 0.8 / Image.Height));
      DisplayWidth := Max(Image.Width * Scale, 1.0);
      DisplayHeight := Max(Image.Height * Scale, 1.0);
      Left := EnsureRange(DropPoint.X - DisplayWidth * 0.5, 0.0,
        Max(CanvasWidth - DisplayWidth, 0.0));
      Top := EnsureRange(DropPoint.Y - DisplayHeight * 0.5, 0.0,
        Max(CanvasHeight - DisplayHeight, 0.0));
      Data.Name := TPath.GetFileNameWithoutExtension(FullFileName);
      if Data.Name = '' then
        Data.Name := 'Image';
      Data.Opacity := 1.0;
      Data.Points[0] := PointF(Left, Top);
      Data.Points[1] := PointF(Left + DisplayWidth, Top);
      Data.Points[2] := PointF(Left + DisplayWidth, Top + DisplayHeight);
      Data.Points[3] := PointF(Left, Top + DisplayHeight);
      Data.SourceFileName := FullFileName;
      Data.SourceKind := visImage;
      Data.Visible := True;
      Result := True;
    finally
      Image.Free;
    end;
  except
    on E: Exception do
      ErrorMessage := E.Message;
  end;
end;

end.
