// Application所有のポップアップが編集対象より先に破棄される終了順を再現する。
program PaintPopupLifetimeTests;
{$APPTYPE CONSOLE}
uses System.Classes, System.SysUtils, Vcl.Forms, Vcl.Graphics,
  VectArtDesignerPaintPopup;
var Target: TComponent; Window: TForm; I: Integer;
function FindPopup: TForm;
var J: Integer;
begin
  Result:=nil;
  for J:=0 to Screen.FormCount-1 do
    if Screen.Forms[J].Caption='Lifetime test' then Exit(Screen.Forms[J]);
end;
begin
  Application.Initialize;
  Target:=TComponent.Create(nil);
  try
    for I:=1 to 3 do
    begin
      ShowVectArtColorPopup(Target,'Lifetime test',clBlack,[clWhite],nil);
      Window:=FindPopup;
      if Window=nil then raise Exception.Create('Popup missing');
      Window.Free;
      // 解放済みフォームをHideせず、再生成も可能であることを確認する。
      CloseVectArtColorPopup(Target);
    end;
    ShowVectArtColorPopup(Target,'Lifetime test',clBlack,[clWhite],nil);
    Target.Free; Target:=nil;
    Window:=FindPopup;
    if (Window=nil) or Window.Visible then raise Exception.Create('Target destruction did not hide popup');
    Window.Free;
    CloseVectArtColorPopup(nil);
    Writeln('PASS popup-first destruction, recreation, target-first destruction');
  finally Target.Free; end;
end.
