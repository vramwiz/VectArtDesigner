// 内蔵6模様を固定寸法の繰り返しPNGへ展開する。
// SYNC_ScreenLayoutのパターン形状を再利用し、設定値の保持やUI、Undoは担当しない。
unit VectArtDesignerPatternTiles;

interface

uses
  System.Skia, System.SysUtils, Vcl.Graphics;

type
  TVectArtPatternKind = (vpkHatch, vpkDots, vpkGrid, vpkChecker,
    vpkWave, vpkHoneycomb);

const
  VECTART_PATTERN_NAMES: array[TVectArtPatternKind] of string =
    ('斜線', 'ドット', '格子', '市松', '波線', 'ハニカム');

function MakeVectArtPatternTile(Kind: TVectArtPatternKind;
  ForegroundColor, BackgroundColor: TColor;
  BackgroundAlpha: Byte = 0): ISkImage;
function CreateVectArtPatternPng(Kind: TVectArtPatternKind;
  ForegroundColor, BackgroundColor: TColor;
  BackgroundAlpha: Byte = 0): TBytes;

implementation

uses
  System.Classes, System.Math, System.Types, System.UITypes,
  Winapi.Windows;

function AlphaColor(Color: TColor; Alpha: Byte): TAlphaColor;
var
  RGBColor: TColor;
begin
  RGBColor := ColorToRGB(Color);
  Result := TAlphaColor((Cardinal(Alpha) shl 24) or
    (Cardinal(GetRValue(RGBColor)) shl 16) or
    (Cardinal(GetGValue(RGBColor)) shl 8) or
    Cardinal(GetBValue(RGBColor)));
end;

procedure PatternDimensions(Kind: TVectArtPatternKind; out Width,
  Height: Integer);
begin
  case Kind of
    vpkHatch, vpkDots:
      begin Width := 16; Height := 16; end;
    vpkGrid:
      begin Width := 24; Height := 24; end;
    vpkChecker:
      begin Width := 32; Height := 32; end;
    vpkWave:
      begin Width := 32; Height := 24; end;
  else
    begin Width := 42; Height := 24; end;
  end;
end;

function MakeVectArtPatternTile(Kind: TVectArtPatternKind;
  ForegroundColor, BackgroundColor: TColor;
  BackgroundAlpha: Byte): ISkImage;
const
  CURVE_STEPS = 128;
var
  CenterX: Single;
  CenterY: Single;
  Height: Integer;
  I: Integer;
  J: Integer;
  Paint: ISkPaint;
  Path: ISkPathBuilder;
  Radius: Single;
  Surface: ISkSurface;
  Width: Integer;
  X: Integer;
  Y: Integer;
begin
  PatternDimensions(Kind, Width, Height);
  Surface := TSkSurface.MakeRaster(Width, Height);
  if Surface = nil then
    raise EInvalidGraphic.Create('Pattern surface creation failed');
  Surface.Canvas.Clear(AlphaColor(BackgroundColor, BackgroundAlpha));
  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;
  Paint.Color := AlphaColor(ForegroundColor, 255);
  Paint.Style := TSkPaintStyle.Stroke;
  Paint.StrokeWidth := 2;
  Path := TSkPathBuilder.Create;
  case Kind of
    vpkHatch:
      for I := -1 to 1 do
      begin
        Path.MoveTo(I * Width, 0);
        Path.LineTo((I + 1) * Width, Height);
      end;
    vpkDots:
      begin
        Paint.Style := TSkPaintStyle.Fill;
        Path.AddCircle(Width / 2, Height / 2, 3);
      end;
    vpkGrid:
      begin
        Path.MoveTo(1, 0);
        Path.LineTo(1, Height);
        Path.MoveTo(0, 1);
        Path.LineTo(Width, 1);
      end;
    vpkChecker:
      begin
        Paint.Style := TSkPaintStyle.Fill;
        Path.AddRect(TRectF.Create(0, 0, Width / 2, Height / 2));
        Path.AddRect(TRectF.Create(Width / 2, Height / 2, Width, Height));
      end;
    vpkWave:
      begin
        for I := -2 to CURVE_STEPS + 2 do
        begin
          CenterX := Width * I / CURVE_STEPS;
          CenterY := Height / 2 + 6 * Sin(2 * Pi * I / CURVE_STEPS);
          if I = -2 then
            Path.MoveTo(CenterX, CenterY)
          else
            Path.LineTo(CenterX, CenterY);
        end;
      end;
    vpkHoneycomb:
      begin
        Radius := 14;
        for X := -1 to 1 do
          for Y := -1 to 1 do
            for J := 0 to 1 do
            begin
              CenterX := (X * 3 + J * 1.5) * Radius;
              CenterY := (Y + J * 0.5) * Sqrt(3) * Radius;
              for I := 0 to 5 do
                if I = 0 then
                  Path.MoveTo(CenterX + Radius * Cos(I * Pi / 3),
                    CenterY + Radius * Sin(I * Pi / 3))
                else
                  Path.LineTo(CenterX + Radius * Cos(I * Pi / 3),
                    CenterY + Radius * Sin(I * Pi / 3));
              Path.Close;
            end;
      end;
  end;
  Surface.Canvas.DrawPath(Path.Detach, Paint);
  Result := Surface.MakeImageSnapshot;
end;

function CreateVectArtPatternPng(Kind: TVectArtPatternKind;
  ForegroundColor, BackgroundColor: TColor;
  BackgroundAlpha: Byte): TBytes;
var
  Image: ISkImage;
  Stream: TMemoryStream;
begin
  Image := MakeVectArtPatternTile(Kind, ForegroundColor, BackgroundColor,
    BackgroundAlpha);
  Stream := TMemoryStream.Create;
  try
    Image.EncodeToStream(Stream);
    if Stream.Size = 0 then
      raise EInvalidGraphic.Create('Pattern PNG encoding failed');
    SetLength(Result, Stream.Size);
    if Stream.Size > 0 then
      Move(Stream.Memory^, Result[0], Stream.Size);
  finally
    Stream.Free;
  end;
end;

end.
