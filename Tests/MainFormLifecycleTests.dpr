program MainFormLifecycleTests;
{$APPTYPE CONSOLE}
uses
  Winapi.Windows, System.SysUtils, System.Types, System.IOUtils,
  Vcl.Forms, Vcl.Controls, Vcl.ComCtrls, Vcl.Graphics, Vcl.Themes, Vcl.Styles, Vcl.Imaging.pngimage,
  VectArtDesignerMainForm, VectArtDesignerDocument;
function FindTabs(Parent: TWinControl): TPageControl;
var J: Integer;
begin
  Result := nil;
  for J := 0 to Parent.ControlCount-1 do
  begin
    if Parent.Controls[J] is TPageControl then Exit(TPageControl(Parent.Controls[J]));
    if Parent.Controls[J] is TWinControl then
    begin
      Result := FindTabs(TWinControl(Parent.Controls[J]));
      if Result <> nil then Exit;
    end;
  end;
end;
var
  Tabs: TPageControl;
  J, Cycle: Integer;
  F: TMainForm;
  R: TVectArtRectangleData;
  B: TBitmap;
  P: TPngImage;
  DC: HDC;
  I: Integer;
  LayoutPath: string;
  SavedLayout: TBytes;
  HadLayout: Boolean;
begin
  Application.Initialize;
  TStyleManager.LoadFromFile('C:\Users\Public\Documents\Embarcadero\Studio\37.0\Styles\WindowsModernDark.vsf');
  if not TStyleManager.TrySetStyle('Windows Modern Dark') then
    raise Exception.Create('Dark style unavailable');
  LayoutPath := TPath.Combine(TPath.GetDocumentsPath,'VectArtDesigner\MainForm.ini');
  HadLayout := TFile.Exists(LayoutPath);
  if HadLayout then SavedLayout := TFile.ReadAllBytes(LayoutPath);
  try
    for I := 1 to 3 do
    begin
      F := TMainForm.Create(nil);
      try
        F.SetBounds(20,20,1100,720);
        F.Show;
        R := Default(TVectArtRectangleData);
        R.Bounds := RectF(10,20,210,120); R.Visible := True;
        R.Filled := True; R.FillColor := clYellow; R.Opacity := 1;
        R.FillStyle.Kind := vfkLinearVertical; R.FillStyle.Color2 := clRed;
        R.Name := 'Display regression';
        F.Document.InsertRectangle(1,R); F.Document.SelectedIndex := 1;
        Application.ProcessMessages;
        F.Width := 1000; Application.ProcessMessages;
        F.Width := 1100; Application.ProcessMessages;
        Tabs := FindTabs(F);
        if Tabs = nil then raise Exception.Create('Settings tabs missing');
        for Cycle := 1 to 3 do
          for J := 0 to Tabs.PageCount-1 do
            if Tabs.Pages[J].TabVisible then
            begin
              Tabs.ActivePage := Tabs.Pages[J];
              Tabs.OnChange(Tabs);
              Application.ProcessMessages;
            end;
        for J := 0 to Tabs.PageCount-1 do
          if Tabs.Pages[J].Caption = '線' then Tabs.ActivePage := Tabs.Pages[J];
        Tabs.OnChange(Tabs);
        Application.ProcessMessages;
        if I = 1 then
        begin
          B := TBitmap.Create; P := TPngImage.Create;
          try
            B.SetSize(F.ClientWidth,F.ClientHeight);
            F.Repaint; Application.ProcessMessages;
            DC := GetDC(F.Handle);
            try BitBlt(B.Canvas.Handle,0,0,B.Width,B.Height,DC,0,0,SRCCOPY);
            finally ReleaseDC(F.Handle,DC); end;
            P.Assign(B);
            P.SaveToFile(ExtractFilePath(ParamStr(0))+'main-form-line-live.png');
          finally P.Free; B.Free; end;
        end;
      finally F.Free; end;
      Application.ProcessMessages;
    end;
    Writeln('PASS main form live display, resize and destruction (3 cycles)');
  finally
    if HadLayout then TFile.WriteAllBytes(LayoutPath,SavedLayout)
    else if TFile.Exists(LayoutPath) then TFile.Delete(LayoutPath);
  end;
end.