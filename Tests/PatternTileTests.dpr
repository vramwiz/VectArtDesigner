// 参照プロジェクトから移した6種類が独立したPNGタイルを生成できることを検証する。
program PatternTileTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Skia, Vcl.Graphics,
  VectArtDesignerPatternTiles;

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then
    raise Exception.Create(MessageText);
end;

var
  Bytes: TBytes;
  Image: ISkImage;
  Kind: TVectArtPatternKind;
begin
  for Kind := Low(Kind) to High(Kind) do
  begin
    Bytes := CreateVectArtPatternPng(Kind, clBlue, clWhite, 0);
    Check(Length(Bytes) > 0, 'Pattern PNG is empty');
    Image := TSkImage.MakeFromEncoded(Bytes);
    Check((Image <> nil) and (Image.Width > 0) and (Image.Height > 0),
      'Pattern PNG cannot be decoded');
  end;
  Writeln('PASS six reusable pattern PNG tiles');
end.
