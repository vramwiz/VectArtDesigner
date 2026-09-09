// 設定UIの文字寸法を集約し、親フォントやVCLスタイルによるページ間の差を防ぐ。
unit VectArtDesignerSettingsFont;
interface
uses Vcl.Controls;
const
  VECTART_SETTINGS_FONT_NAME = 'Segoe UI';
  VECTART_SETTINGS_FONT_HEIGHT = -13;
procedure ApplyVectArtSettingsFont(Control: TControl);
implementation
type TSettingsFontAccess = class(TControl);
procedure ApplyVectArtSettingsFont(Control: TControl);
var I: Integer;
begin
  TSettingsFontAccess(Control).Font.Name := VECTART_SETTINGS_FONT_NAME;
  TSettingsFontAccess(Control).Font.Height := VECTART_SETTINGS_FONT_HEIGHT;
  Control.StyleElements := Control.StyleElements - [seFont];
  // 入れ子の設定欄や動的生成した欄も同じ基準を使う。文字色と書式は維持する。
  if Control is TWinControl then
    for I := 0 to TWinControl(Control).ControlCount-1 do
      ApplyVectArtSettingsFont(TWinControl(Control).Controls[I]);
end;
end.
