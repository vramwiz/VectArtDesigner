// Measures and lays out editable multi-line text with the same Skia font used by rendering.
unit VectArtDesignerTextGeometry;

interface

uses
  System.Skia, Vcl.Graphics;

type
  TVectArtTextLayout = record
    Ascent: Single;
    Height: Single;
    Lines: TArray<string>;
    LineHeight: Single;
    Width: Single;
  end;

function CreateVectArtTextFont(const FontFamily: string; FontSize: Single;
  FontStyle: TFontStyles = []): ISkFont;
function BuildVectArtTextLayout(const Text, FontFamily: string;
  FontSize: Single; FontStyle: TFontStyles = [];
  LetterSpacingRatio: Single = 0; LineSpacingRatio: Single = 0):
  TVectArtTextLayout;
function VectArtTextCaretIndexAtPoint(const Text, FontFamily: string;
  FontSize, TargetX, TargetY: Single;
  FontStyle: TFontStyles = []; LetterSpacingRatio: Single = 0;
  LineSpacingRatio: Single = 0): Integer;
function MeasureVectArtText(const Text: string; Font: ISkFont;
  LetterSpacing: Single): Single;
procedure DrawVectArtTextLine(Canvas: ISkCanvas; const Text: string;
  X, Baseline: Single; Font: ISkFont; Paint: ISkPaint;
  LetterSpacing: Single);
function VectArtTextUnitLengthAt(const Text: string; Index: Integer): Integer;

implementation

uses
  System.Math, System.SysUtils;

function VectArtTextUnitLengthAt(const Text: string; Index: Integer): Integer;
begin
  Result := 1;
  if (Index >= 1) and (Index < Length(Text)) and
    (Ord(Text[Index]) >= $D800) and (Ord(Text[Index]) <= $DBFF) and
    (Ord(Text[Index + 1]) >= $DC00) and (Ord(Text[Index + 1]) <= $DFFF) then
    Result := 2;
end;

function CreateVectArtTextFont(const FontFamily: string; FontSize: Single;
  FontStyle: TFontStyles): ISkFont;
var
  Slant: TSkFontSlant;
  Typeface: ISkTypeface;
  Weight: TSkFontWeight;
begin
  if fsBold in FontStyle then
    Weight := TSkFontWeight.Bold
  else
    Weight := TSkFontWeight.Normal;
  if fsItalic in FontStyle then
    Slant := TSkFontSlant.Italic
  else
    Slant := TSkFontSlant.Upright;
  Typeface := nil;
  if FontFamily <> '' then
    Typeface := TSkTypeface.MakeFromName(FontFamily,
      TSkFontStyle.Create(Weight, TSkFontWidth.Normal, Slant));
  if Typeface = nil then
    Typeface := TSkTypeface.MakeFromName('Yu Gothic UI',
      TSkFontStyle.Create(Weight, TSkFontWidth.Normal, Slant));
  if Typeface = nil then
    Typeface := TSkTypeface.MakeDefault;
  Result := TSkFont.Create(Typeface, Max(FontSize, 1.0));
  Result.Edging := TSkFontEdging.AntiAlias;
end;

function BuildVectArtTextLayout(const Text, FontFamily: string;
  FontSize: Single; FontStyle: TFontStyles; LetterSpacingRatio,
  LineSpacingRatio: Single): TVectArtTextLayout;
var
  BaseLineHeight: Single;
  Font: ISkFont;
  Metrics: TSkFontMetrics;
  Normalized: string;
  I: Integer;
  LetterSpacing: Single;
begin
  Result := Default(TVectArtTextLayout);
  Font := CreateVectArtTextFont(FontFamily, FontSize, FontStyle);
  Font.GetMetrics(Metrics);
  Result.Ascent := Max(-Metrics.Ascent, 1.0);
  LetterSpacing := FontSize * LetterSpacingRatio;
  BaseLineHeight := Max(Font.Spacing, 1.0);
  // 行間は行と行の間だけに加え、最終行の下には加えない。
  Result.LineHeight := Max(BaseLineHeight + FontSize * LineSpacingRatio, 1.0);
  Normalized := StringReplace(Text, #13#10, #10, [rfReplaceAll]);
  Normalized := StringReplace(Normalized, #13, #10, [rfReplaceAll]);
  Result.Lines := Normalized.Split([#10], TStringSplitOptions.None);
  if Length(Result.Lines) = 0 then
    Result.Lines := [''];
  for I := 0 to High(Result.Lines) do
    Result.Width := Max(Result.Width, MeasureVectArtText(Result.Lines[I],
      Font, LetterSpacing));
  Result.Height := BaseLineHeight +
    Max(Length(Result.Lines) - 1, 0) * Result.LineHeight;
end;

function VectArtTextCaretIndexAtPoint(const Text, FontFamily: string;
  FontSize, TargetX, TargetY: Single; FontStyle: TFontStyles;
  LetterSpacingRatio, LineSpacingRatio: Single): Integer;
var
  CharacterLength: Integer;
  Font: ISkFont;
  I: Integer;
  LineEnd: Integer;
  LineIndex: Integer;
  LineStart: Integer;
  PreviousWidth: Single;
  Width: Single;
begin
  Font := CreateVectArtTextFont(FontFamily, FontSize, FontStyle);
  LineIndex := Max(Floor(TargetY / Max(Font.Spacing +
    FontSize * LineSpacingRatio, 1.0)), 0);
  LineStart := 1;
  while (LineIndex > 0) and (LineStart <= Length(Text)) do
  begin
    if Text[LineStart] = #13 then
    begin
      Dec(LineIndex);
      Inc(LineStart);
      if (LineStart <= Length(Text)) and (Text[LineStart] = #10) then
        Inc(LineStart);
    end
    else if Text[LineStart] = #10 then
    begin
      Dec(LineIndex);
      Inc(LineStart);
    end
    else
      Inc(LineStart, VectArtTextUnitLengthAt(Text, LineStart));
  end;
  if LineIndex > 0 then
    Exit(Length(Text));
  LineEnd := LineStart;
  while (LineEnd <= Length(Text)) and
    not CharInSet(Text[LineEnd], [#10, #13]) do
    Inc(LineEnd, VectArtTextUnitLengthAt(Text, LineEnd));
  Result := LineStart - 1;
  PreviousWidth := 0;
  I := LineStart;
  while I < LineEnd do
  begin
    CharacterLength := VectArtTextUnitLengthAt(Text, I);
    Width := MeasureVectArtText(Copy(Text, LineStart,
      I - LineStart + CharacterLength), Font,
      FontSize * LetterSpacingRatio);
    if TargetX < (PreviousWidth + Width) * 0.5 then
      Exit;
    Inc(Result, CharacterLength);
    PreviousWidth := Width;
    Inc(I, CharacterLength);
  end;
end;

function MeasureVectArtText(const Text: string; Font: ISkFont;
  LetterSpacing: Single): Single;
var
  CharacterLength: Integer;
  I: Integer;
begin
  Result := 0;
  if (Font = nil) or (Text = '') then
    Exit;
  I := 1;
  while I <= Length(Text) do
  begin
    CharacterLength := VectArtTextUnitLengthAt(Text, I);
    Result := Result + Font.MeasureText(Copy(Text, I, CharacterLength));
    Inc(I, CharacterLength);
    if I <= Length(Text) then
      Result := Result + LetterSpacing;
  end;
  Result := Max(Result, 0.0);
end;

procedure DrawVectArtTextLine(Canvas: ISkCanvas; const Text: string;
  X, Baseline: Single; Font: ISkFont; Paint: ISkPaint;
  LetterSpacing: Single);
var
  CharacterLength: Integer;
  CharacterText: string;
  I: Integer;
begin
  if (Canvas = nil) or (Font = nil) or (Paint = nil) then
    Exit;
  I := 1;
  while I <= Length(Text) do
  begin
    CharacterLength := VectArtTextUnitLengthAt(Text, I);
    CharacterText := Copy(Text, I, CharacterLength);
    Canvas.DrawSimpleText(CharacterText, X, Baseline, Font, Paint);
    X := X + Font.MeasureText(CharacterText);
    Inc(I, CharacterLength);
    if I <= Length(Text) then
      X := X + LetterSpacing;
  end;
end;

end.
