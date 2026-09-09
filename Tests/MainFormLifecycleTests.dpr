program MainFormLifecycleTests;
{$APPTYPE CONSOLE}
uses
  VectArtDesignerSettingsSections,  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Types, System.IOUtils,
  Vcl.Forms, Vcl.Controls, Vcl.ComCtrls, Vcl.Graphics, Vcl.Themes, Vcl.Styles, Vcl.Imaging.pngimage,
  VectArtDesignerMainForm, VectArtDesignerDocument;
function FindSections(Parent: TWinControl): TVectArtSettingsSections;
var J: Integer;
begin
  Result := nil;
  for J := 0 to Parent.ControlCount-1 do
  begin
    if Parent.Controls[J] is TVectArtSettingsSections then Exit(TVectArtSettingsSections(Parent.Controls[J]));
    if Parent.Controls[J] is TWinControl then
    begin
      Result := FindSections(TWinControl(Parent.Controls[J]));
      if Result <> nil then Exit;
    end;
  end;
end;

// 選択直後の画面を再描画で補修する前に取得し、欠けが隠れないよう比較する。
procedure CheckSelectionPaint(Control: TWinControl);
var BeforeImage,AfterImage: TBitmap; DC: HDC; X,Y,Differences: Integer; BeforeRow,AfterRow: PByte;
  procedure Capture(Bitmap: TBitmap);
  begin
    Bitmap.PixelFormat:=pf32bit;
    Bitmap.SetSize(Control.ClientWidth,Control.ClientHeight);
    DC:=GetDC(Control.Handle);
    try BitBlt(Bitmap.Canvas.Handle,0,0,Bitmap.Width,Bitmap.Height,DC,0,0,SRCCOPY);
    finally ReleaseDC(Control.Handle,DC); end;
  end;
begin
  BeforeImage:=TBitmap.Create; AfterImage:=TBitmap.Create;
  try
    Capture(BeforeImage);
    RedrawWindow(Control.Handle,nil,0,RDW_INVALIDATE or RDW_ERASE or RDW_ALLCHILDREN or RDW_UPDATENOW);
    Capture(AfterImage); Differences:=0;
    for Y:=0 to BeforeImage.Height-1 do
    begin
      BeforeRow:=BeforeImage.ScanLine[Y]; AfterRow:=AfterImage.ScanLine[Y];
      for X:=0 to BeforeImage.Width-1 do
      begin
        if not CompareMem(BeforeRow,AfterRow,3) then Inc(Differences);
        Inc(BeforeRow,4); Inc(AfterRow,4);
      end;
    end;
    if Differences>0 then
    begin
      BeforeImage.SaveToFile('TestOutput/selection-before-repaint.bmp');
      AfterImage.SaveToFile('TestOutput/selection-after-repaint.bmp');
      raise Exception.CreateFmt('Selection paint differs from full child redraw: %d pixels',[Differences]);
    end;
  finally AfterImage.Free; BeforeImage.Free; end;
end;

var
  Sections: TVectArtSettingsSections;
  J, K, Cycle, VisibleCount, AvailableCount, SelectedLayer: Integer;
  F: TMainForm;
  R: TVectArtRectangleData;
  T: TVectArtTextData;
  B: TBitmap;
  P: TPngImage;
  DC: HDC;
  I, FormIndex: Integer;
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
        F.Document.InsertRectangle(1,R);
        T:=Default(TVectArtTextData); T.Text:='Display text'; T.FontFamily:='Arial';
        T.FontSize:=24; T.TextColor:=clBlack; T.Opacity:=1; T.Visible:=True;
        T.Bounds:=RectF(10,140,210,190); F.Document.InsertText(2,T);
        F.Document.SelectedIndex := 1;
        Application.ProcessMessages;
        F.Width := 1000; Application.ProcessMessages;
        F.Width := 1100; Application.ProcessMessages;
        Sections := FindSections(F);
        // 保存済みレイアウトで設定欄がフローティングしていても同じ操作を検証する。
        if Sections = nil then
          for FormIndex := 0 to Screen.FormCount-1 do
          begin
            Sections := FindSections(Screen.Forms[FormIndex]);
            if Sections <> nil then Break;
          end;
        if Sections = nil then raise Exception.Create('Stacked settings page missing');
        for Cycle := 1 to 3 do
        begin
          SelectedLayer:=1+(Cycle mod 2);
          F.Document.SelectedIndex:=SelectedLayer; Application.ProcessMessages;
          VisibleCount:=0; AvailableCount:=0;
          for J := 0 to Sections.SectionCount-1 do
          begin
            if Sections.Sections[J].Available then Inc(AvailableCount);
            if Sections.Sections[J].Visible then Inc(VisibleCount);
          end;
          if (AvailableCount=0) or (VisibleCount<>AvailableCount) then
            raise Exception.Create('Available settings panels are not visible together');
          F.Document.SetSelectedLayers([]); Application.ProcessMessages;
          F.Document.SetSelectedLayers([SelectedLayer]); Application.ProcessMessages;
          for K:=0 to Sections.SectionCount-1 do
            if Sections.Sections[K].Visible then
              CheckSelectionPaint(Sections.Sections[K]);
        end;
        F.Document.SelectedIndex:=1; Application.ProcessMessages;
        // 通常ページと同じ巡回後に、入れ子の影設定も実画面から取得する。
        for J := 0 to Sections.SectionCount-1 do
          if Sections.Sections[J].Caption = '影' then
          begin
            Sections.ActiveSection := Sections.Sections[J];
            Sections.ScrollInView(Sections.Sections[J].Parent);
          end;
        Sections.OnChange(Sections); Application.ProcessMessages;
        if I = 1 then
        begin
          B := TBitmap.Create; P := TPngImage.Create;
          try
            B.SetSize(Sections.ClientWidth,Sections.ClientHeight);
            Sections.Repaint; Application.ProcessMessages;
            DC := GetDC(Sections.Handle);
            try BitBlt(B.Canvas.Handle,0,0,B.Width,B.Height,DC,0,0,SRCCOPY);
            finally ReleaseDC(Sections.Handle,DC); end;
            P.Assign(B);
            P.SaveToFile(ExtractFilePath(ParamStr(0))+'main-form-shadow-live.png');
          finally P.Free; B.Free; end;
        end;
        for J := 0 to Sections.SectionCount-1 do
          if Sections.Sections[J].Caption = '線' then
          begin
            Sections.ActiveSection := Sections.Sections[J];
            Sections.ScrollInView(Sections.Sections[J].Parent);
          end;
        Sections.OnChange(Sections);
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
    Writeln('PASS main form selection pixels, stacked shape/text panels, resize and destruction (3 cycles)');
  finally
    if HadLayout then TFile.WriteAllBytes(LayoutPath,SavedLayout)
    else if TFile.Exists(LayoutPath) then TFile.Delete(LayoutPath);
  end;
end.
