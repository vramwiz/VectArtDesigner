program MifVectorPayloadInspect;

{$APPTYPE CONSOLE}

// WebArt Designerのvector IPNGをRGBAへ復号し、内部ペイロードの並びを調査する。

uses
  System.Skia,
  System.SysUtils,
  TextRendererSkiaBootstrap in
    'Lib\TextRenderer\TextRendererSkiaBootstrap.pas',
  TextRendererSkiaRuntime in
    'Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  VectArtDesignerMifContainer in
    'Source\Persistence\Mif\VectArtDesignerMifContainer.pas';

var
  Bytes: TBytes;
  ChunkIndex: Integer;
  Container: TVectArtMifContainer;
  ErrorMessage: string;
  FileName: string;
  I: Integer;
  Image: ISkImage;
  ImageInfo: TSkImageInfo;
  Reader: IVectArtMifContainerReader;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Container := nil;
  try
    if ParamCount > 0 then
      FileName := ParamStr(1)
    else
      FileName := 'mif' + PathDelim + #$56DB#$89D2 + '.mif';
    ChunkIndex := 5;
    if ParamCount > 1 then
      TryStrToInt(ParamStr(2), ChunkIndex);
    Reader := CreateVectArtMifContainerReader;
    if not Reader.TryReadFile(FileName, Container, ErrorMessage) then
      raise Exception.Create(ErrorMessage);
    Image := TSkImage.MakeFromEncoded(Container[ChunkIndex].Data);
    if Image = nil then
      raise Exception.Create('Cannot decode vector PNG');
    SetLength(Bytes, Image.Width * Image.Height * 4);
    ImageInfo := TSkImageInfo.Create(Image.Width, Image.Height,
      TSkColorType.RGBA8888, TSkAlphaType.Unpremul);
    if not Image.ReadPixels(ImageInfo, @Bytes[0], Image.Width * 4) then
      raise Exception.Create('Cannot read vector pixels');
    Writeln(Format('size=%dx%d bytes=%d',
      [Image.Width, Image.Height, Length(Bytes)]));
    for I := 0 to High(Bytes) do
    begin
      Write(IntToHex(Bytes[I], 2));
      if I < High(Bytes) then
        Write(' ');
    end;
    Writeln;
  finally
    Container.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
