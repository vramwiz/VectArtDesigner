// 色履歴の重複排除、上限、ドキュメント読込、ピッカー確定境界を検証する。
program ColorHistoryTests;

{$APPTYPE CONSOLE}

uses
  System.Classes, System.SysUtils, System.Types, Winapi.Windows, Vcl.Forms,
  Vcl.Graphics,
  ColorPickerSVArea, VectArtDesignerColorHistory, VectArtDesignerDocument,
  VectArtDesignerPaintPopup;

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then
    raise Exception.Create(MessageText);
end;

function ContainsColor(const Colors: TArray<TColor>; Color: TColor): Boolean;
var
  Candidate: TColor;
begin
  Result := False;
  Color := ColorToRGB(Color);
  for Candidate in Colors do
    if ColorToRGB(Candidate) = Color then
      Exit(True);
end;

function FindPicker: TColorPickerSVArea;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Screen.FormCount - 1 do
    if Screen.Forms[I].FindComponent('SVPicker') is TColorPickerSVArea then
      Exit(TColorPickerSVArea(Screen.Forms[I].FindComponent('SVPicker')));
end;

var
  Colors: TArray<TColor>;
  Data: TVectArtRectangleData;
  Document: TVectArtDocument;
  History: TVectArtColorHistory;
  I: Integer;
  Picker: TColorPickerSVArea;
  Revision: Int64;
  Shadow: TVectArtShadow;
  Target: TComponent;
begin
  Application.Initialize;
  Document := TVectArtDocument.Create;
  History := TVectArtColorHistory.Create;
  Target := TComponent.Create(nil);
  try
    Check(Length(History.Colors) = 0, 'New history is not empty');
    Revision := Document.Revision;
    for I := 0 to TVectArtColorHistory.MaximumCount + 3 do
      History.Add(RGB(I, I + 1, I + 2));
    Check(Length(History.Colors) = TVectArtColorHistory.MaximumCount,
      'History limit failed');
    History.Add(RGB(10, 11, 12));
    Colors := History.Colors;
    Check(Colors[0] = ColorToRGB(RGB(10, 11, 12)),
      'Duplicate did not move to the front');
    Check(Document.Revision = Revision, 'History changed the document');

    Document.SetCanvasSettings(320, 240, RGB(1, 2, 3), False);
    Data := Default(TVectArtRectangleData);
    Data.Name := 'Color source';
    Data.Bounds := RectF(10, 10, 100, 100);
    Data.Filled := True;
    Data.FillColor := RGB(20, 30, 40);
    Data.FillStyle.Kind := vfkLinearHorizontal;
    Data.FillStyle.Color2 := RGB(50, 60, 70);
    Data.StrokeWidth := 2;
    Data.StrokeColor := RGB(80, 90, 100);
    Data.StrokePaint.Kind := vfkSolid;
    Shadow := Default(TVectArtShadow);
    Shadow.Enabled := True;
    Shadow.Color := RGB(110, 120, 130);
    Data.Shadow := Shadow;
    Document.InsertRectangle(Document.LayerCount, Data);
    History.LoadFromDocument(Document);
    Colors := History.Colors;
    Check(ContainsColor(Colors, RGB(1, 2, 3)), 'Canvas color missing');
    Check(ContainsColor(Colors, RGB(20, 30, 40)), 'Fill color missing');
    Check(ContainsColor(Colors, RGB(50, 60, 70)), 'Gradient color missing');
    Check(ContainsColor(Colors, RGB(80, 90, 100)), 'Stroke color missing');
    Check(ContainsColor(Colors, RGB(110, 120, 130)), 'Shadow color missing');

    History.Clear;
    ShowVectArtColorPopup(Target, 'History test', clBlack, nil, nil, History);
    Picker := FindPicker;
    Check(Picker <> nil, 'Picker missing');
    Picker.Color := RGB(12, 34, 56);
    Picker.OnChange(Picker);
    Picker.Color := RGB(65, 43, 21);
    Picker.OnChange(Picker);
    Check(Length(History.Colors) = 0,
      'Picker intermediate color entered history');
    CloseVectArtColorPopup(Target);
    Colors := History.Colors;
    Check((Length(Colors) = 1) and
      (Colors[0] = ColorToRGB(RGB(65, 43, 21))),
      'Final picker color was not committed once');
    Writeln('PASS color history load, MRU, limit and picker commit');
  finally
    CloseVectArtColorPopup(Target);
    Target.Free;
    History.Free;
    Document.Free;
  end;
end.
