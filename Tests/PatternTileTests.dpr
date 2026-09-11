// 参照プロジェクトから移した6種類が独立したPNGタイルを生成できることを検証する。
program PatternTileTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Math, System.Skia, Vcl.Graphics,
  VectArtDesignerPatternTiles;

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then
    raise Exception.Create(MessageText);
end;

var
  Bytes: TBytes;
  ChangedBytes: TBytes;
  Image: ISkImage;
  Kind: TVectArtPatternKind;
  Settings: TVectArtPatternSettings;
begin
  for Kind := Low(Kind) to High(Kind) do
  begin
    Bytes := CreateVectArtPatternPng(Kind, clBlue, clWhite, 0);
    Check(Length(Bytes) > 0, 'Pattern PNG is empty');
    Image := TSkImage.MakeFromEncoded(Bytes);
    Check((Image <> nil) and (Image.Width > 0) and (Image.Height > 0),
      'Pattern PNG cannot be decoded');
  end;
  Settings := DefaultVectArtPatternSettings(vpkHatch);
  Bytes := CreateVectArtPatternPng(Settings, clBlue, clWhite, 255);
  Settings.Width := 9;
  Settings.Spacing := 31;
  Settings.Angle := -23;
  Settings.OffsetX := 17;
  Settings.OffsetY := -11;
  ChangedBytes := CreateVectArtPatternPng(Settings, clBlue, clWhite, 255);
  Check(Length(ChangedBytes) > 0, 'Configured pattern PNG is empty');
  Check(not CompareMem(@Bytes[0], @ChangedBytes[0],
    Min(Length(Bytes), Length(ChangedBytes))), 'Pattern settings did not change PNG');
  Image := TSkImage.MakeFromEncoded(ChangedBytes);
  Check((Image <> nil) and (Image.Width = 512) and (Image.Height = 512),
    'Configured pattern PNG dimensions');
  Writeln('PASS six patterns and configurable fixed PNG texture');
end.
