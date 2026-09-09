// 選択された画像を保存用の埋込PNGへ変換する。ダイアログ・Document・Undoには依存しない。
// PNGの透明度は維持し、JPEGとBMPは従来どおりVCLのビットマップ経由で変換する。
unit VectArtDesignerTextureImage;

interface

uses System.SysUtils;
function LoadVectArtTexturePng(const FileName: string): TBytes;

implementation

uses System.Classes, Vcl.Graphics, Vcl.Imaging.pngimage, Vcl.Imaging.jpeg;

function LoadVectArtTexturePng(const FileName: string): TBytes;
var Picture: TPicture; Png: TPngImage; Stream: TMemoryStream; Bitmap: TBitmap;
begin
  Picture := TPicture.Create;
  try
    Picture.LoadFromFile(FileName);
    Png := TPngImage.Create;
    try
      if Picture.Graphic is TPngImage then Png.Assign(Picture.Graphic)
      else
      begin
        Bitmap := TBitmap.Create;
        try
          Bitmap.SetSize(Picture.Width,Picture.Height);
          Bitmap.Canvas.Draw(0,0,Picture.Graphic);
          Png.Assign(Bitmap);
        finally Bitmap.Free; end;
      end;
      Stream := TMemoryStream.Create;
      try
        Png.SaveToStream(Stream);
        SetLength(Result,Stream.Size);
        if Stream.Size > 0 then Move(Stream.Memory^,Result[0],Stream.Size);
      finally Stream.Free; end;
    finally Png.Free; end;
  finally Picture.Free; end;
end;

end.
