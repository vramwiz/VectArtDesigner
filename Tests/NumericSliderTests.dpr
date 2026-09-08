program NumericSliderTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Math, Vcl.Forms, Winapi.Windows,
  VectArtDesignerNumericSlider;
procedure Check(B: Boolean; const S: string);
begin if not B then raise Exception.Create(S); end;
var F:TForm; N:TVectArtNumericSlider; K:Word;
begin
  Application.Initialize;
  F:=TForm.Create(nil);
  try
    N:=TVectArtNumericSlider.CreateForParent(F,F);
    N.Configure(-10,10,0.1,2);
    N.SetDisplay(-2.35);
    Check(SameValue(N.Value,-2.35),'decimal display');
    N.TrackBar.Position:=35;
    Check(SameValue(N.Value,3.5),'track sync');
    N.Edit.Text:='4.25'; N.Edit.OnExit(N.Edit);
    Check(SameValue(N.Value,4.25),'input precision');
    N.Edit.Text:='100'; N.Edit.OnExit(N.Edit);
    Check(SameValue(N.Value,4.25),'range rejection');
    N.Edit.Text:='invalid'; N.Edit.OnExit(N.Edit);
    Check(N.Edit.Text='4.25','invalid restore');
    N.SetDisplay(3,True); Check(N.Edit.Text='','mixed');
    N.Edit.Text:='2'; K:=VK_ESCAPE; N.Edit.OnKeyDown(N.Edit,K,[]);
    Check(N.Mixed and (N.Edit.Text=''),'escape mixed');
    N.SetSliderRange(-1,1); N.SetDisplay(8);
    Check(SameValue(N.Value,8) and (N.TrackBar.Position=10),'independent slider bounds');
    N.Width:=140; Check(N.Edit.Left>N.TrackBar.Left+N.TrackBar.Width,'layout');
    Writeln('Numeric slider tests: PASS');
  finally F.Free; end;
end.