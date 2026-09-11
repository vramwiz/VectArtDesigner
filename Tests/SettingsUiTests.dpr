// Validates the public controls and renders real VCL panels for layout inspection.
program SettingsUiTests;
{$APPTYPE CONSOLE}
uses
  VectArtDesignerSettingsSections,  Winapi.Windows, Winapi.Messages, System.Diagnostics, System.UITypes, System.Classes, System.SysUtils, System.Types, System.Math,
  Vcl.Buttons, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.Forms, Vcl.Grids, Vcl.Controls, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.Graphics,
  Vcl.Themes, Vcl.Styles, Vcl.Imaging.pngimage,
  VectArtDesignerCanvas, VectArtDesignerCreationColors, VectArtDesignerToolPalette, VectArtDesignerNumericSlider, ColorPickerSVArea, TextRendererSkiaBootstrap, TextRendererSkiaRuntime,
  VectArtDesignerDocument, VectArtDesignerEditorState, VectArtDesignerEditHistory,
  VectArtDesignerObjectPropertiesControl, VectArtDesignerObjectPropertiesFrame, VectArtDesignerTemplatePicker,
  VectArtDesignerTemplateGeometry, VectArtDesignerShapeCreation,
  VectArtDesignerColorSwatch, VectArtDesignerPaintPopup, VectArtDesignerAppearanceModeCommand;

// VCLが描画例外をダイアログ化しても、テストを成功扱いにしない。
type TUiExceptionRecorder = class
  ErrorText: string;
  procedure Handle(Sender: TObject; E: Exception);
end;
procedure TUiExceptionRecorder.Handle(Sender: TObject; E: Exception);
begin ErrorText := E.ClassName+': '+E.Message; end;

procedure Check(Value: Boolean; const Msg: string);
begin if not Value then raise Exception.Create(Msg); end;

function FindControl(Parent: TWinControl; Kind: TClass): TControl;
var I: Integer;
begin
  Result := nil;
  for I := 0 to Parent.ControlCount-1 do
  begin
    if Parent.Controls[I].InheritsFrom(Kind) then Exit(Parent.Controls[I]);
    if Parent.Controls[I] is TWinControl then
    begin
      Result := FindControl(TWinControl(Parent.Controls[I]), Kind);
      if Result <> nil then Exit;
    end;
  end;
end;

function FindCaptionControl(Parent: TWinControl; const Caption: string): TControl;
var I: Integer; Child: TControl;
begin
  Result := nil;
  for I := 0 to Parent.ControlCount-1 do
  begin
    Child := Parent.Controls[I];
    if (Child is TStaticText) and (TStaticText(Child).Caption=Caption) then Exit(Child);
    if Child is TWinControl then
    begin
      Result := FindCaptionControl(TWinControl(Child),Caption);
      if Result <> nil then Exit;
    end;
  end;
end;

procedure PickPopupColor(Form: TForm; Color: TColor);
var Grid: TDrawGrid; Col,Row: Integer; Allowed: Boolean;
begin
  Grid := TDrawGrid(FindControl(Form,TDrawGrid));
  for Row := 0 to Grid.RowCount-1 do
    for Col := 0 to Grid.ColCount-1 do
    begin
      Grid.OnDrawCell(Grid,Col,Row,Rect(0,0,32,32),[]);
      if Grid.Canvas.Brush.Color = Color then
      begin Allowed := True; Grid.OnSelectCell(Grid,Col,Row,Allowed); Exit; end;
    end;
  raise Exception.Create('Color chip missing');
end;
// 標準画像選択ダイアログへテスト画像を入力し、実際の読込イベントを通す。
var TextureDialogTimer: UINT_PTR; TextureDialogTicks: Integer; TextureFile: string;
function FindTextureDialog(Wnd: HWND; Param: LPARAM): BOOL; stdcall;
var Name: array[0..63] of Char;
begin
  GetClassName(Wnd,Name,Length(Name));
  if (string(Name)='#32770') and IsWindowVisible(Wnd) then
  begin PNativeUInt(Param)^ := Wnd; Exit(False); end;
  Result := True;
end;
procedure TextureDialogTick(Wnd: HWND; Msg: UINT; ID: UINT_PTR; Time: DWORD); stdcall;
var Dialog: HWND; ProcessID: DWORD; ClassName: array[0..63] of Char;
begin
  Inc(TextureDialogTicks);
  Dialog := 0;
  EnumThreadWindows(GetCurrentThreadId,@FindTextureDialog,LPARAM(@Dialog));
  if Dialog = 0 then Exit;
  GetWindowThreadProcessId(Dialog,@ProcessID);
  GetClassName(Dialog,ClassName,Length(ClassName));
  if (ProcessID=GetCurrentProcessId) and (string(ClassName)='#32770') then
  begin
    KillTimer(0,ID); TextureDialogTimer := 0;
    SendMessage(Dialog,WM_USER+104,1152,LPARAM(PChar(TextureFile)));
    PostMessage(Dialog,WM_COMMAND,IDOK,0);
  end
  else if TextureDialogTicks>50 then
  begin KillTimer(0,ID); TextureDialogTimer := 0; PostMessage(Dialog,WM_COMMAND,IDCANCEL,0); end;
end;
procedure PickTexture(Form: TForm);
var Button: TButton; Bitmap: TBitmap; Png: TPngImage; Previous: Boolean;
begin
  TextureFile := ExpandFileName(ExtractFilePath(ParamStr(0))+'ui-texture.png');
  Bitmap := TBitmap.Create; Png := TPngImage.Create;
  try
    Bitmap.SetSize(16,16); Bitmap.Canvas.Brush.Color := clRed;
    Bitmap.Canvas.FillRect(Rect(0,0,8,16)); Bitmap.Canvas.Brush.Color := clBlue;
    Bitmap.Canvas.FillRect(Rect(8,0,16,16)); Png.Assign(Bitmap); Png.SaveToFile(TextureFile);
  finally Png.Free; Bitmap.Free; end;
  Button := TButton(FindControl(Form,TButton)); Check(Button<>nil,'Texture button');
  Previous := UseLatestCommonDialogs; UseLatestCommonDialogs := False;
  TextureDialogTicks := 0;
  TextureDialogTimer := SetTimer(0,0,100,@TextureDialogTick);
  try Button.Click;
  finally
    if TextureDialogTimer<>0 then KillTimer(0,TextureDialogTimer);
    UseLatestCommonDialogs := Previous;
  end;
end;
procedure Capture(Control: TWinControl; const Name: string);
var B: TBitmap; P: TPngImage; DC: HDC;
begin
  B := TBitmap.Create; P := TPngImage.Create;
  try
    B.SetSize(Control.ClientWidth,Control.ClientHeight);
    Control.HandleNeeded;
    if (Control is TForm) and TForm(Control).Visible then
    begin
      Control.Repaint;
      Application.ProcessMessages;
      DC := GetDC(Control.Handle);
      try BitBlt(B.Canvas.Handle,0,0,Control.ClientWidth,Control.ClientHeight,DC,0,0,SRCCOPY);
      finally ReleaseDC(Control.Handle,DC); end;
    end
    else Control.PaintTo(B.Canvas,0,0);
    P.Assign(B);
    P.SaveToFile(ExtractFilePath(ParamStr(0))+Name+'.png');
  finally P.Free; B.Free; end;
end;

procedure CheckCreationColors;
var State,Fresh: TVectArtEditorState; Form,Popup: TForm; Palette: TVectArtToolPaletteControl;
  Colors: TVectArtCreationColors; Swatch: TVectArtColorSwatch; I: Integer;
  Doc: TVectArtDocument; Creation: TVectArtShapeCreation; Editor: TVectArtCanvasControl;
begin
  State := TVectArtEditorState.Create; Form := TForm.Create(nil);
  Doc := TVectArtDocument.Create; Creation := TVectArtShapeCreation.Create;
  try
    Check((State.Color1=clBlack) and (State.Color2=clWhite),'Startup colors');
    Form.SetBounds(20,20,80,730);
    Palette := TVectArtToolPaletteControl.Create(Form); Palette.Parent := Form;
    Palette.Align := alClient; Palette.EditorState := State;
    Form.Show; Application.ProcessMessages;
    Colors := TVectArtCreationColors(FindControl(Palette,TVectArtCreationColors));
    Check(Colors.Top+Colors.Height<=Palette.Height,'Creation colors clipped');
    for I := 1 to 2 do
    begin
      Swatch := TVectArtColorSwatch(Colors.FindComponent('CreationColor'+IntToStr(I)));
      Swatch.OnClick(Swatch); Popup := Screen.ActiveForm;
      Check(not TComboBox(FindControl(Popup,TComboBox)).Visible,'Creation colors must be solid only');
      if I=1 then PickPopupColor(Popup,clYellow) else PickPopupColor(Popup,clAqua);
      CloseVectArtColorPopup(Colors);
    end;
    Check((State.Color1=clYellow) and (State.Color2=clAqua),'Palette edits both colors');
    TSpeedButton(Colors.FindComponent('SwapCreationColors')).Click;
    Check((State.Color1=clAqua) and (State.Color2=clYellow),'Swap creation colors');
    TSpeedButton(Colors.FindComponent('SwapCreationColors')).Click;
    State.CurrentTool := vetRectangle; Creation.Configure(Doc,nil,State,Rect(0,0,400,300),1);
    Check(Creation.MouseDown(mbLeft,[],20,20),'Color rectangle start');
    Creation.MouseMove([ssLeft],120,100); Creation.MouseUp(mbLeft,[],120,100);
    Check((TVectArtRectangleLayer(Doc[1]).StrokeColor=clYellow) and
      (TVectArtRectangleLayer(Doc[1]).FillColor=clAqua),'Rectangle uses creation colors');
    State.CurrentTool := vetLine;
    Creation.MouseDown(mbLeft,[],20,150); Creation.MouseMove([ssLeft],120,180);
    Creation.MouseUp(mbLeft,[],120,180);
    Check(TVectArtLineLayer(Doc[2]).StrokeColor=clYellow,'Line uses Color1');
    State.Color1 := clRed;
    Check(TVectArtRectangleLayer(Doc[1]).StrokeColor=clYellow,'Default color changed existing object');
    Fresh := TVectArtEditorState.Create;
    try Check((Fresh.Color1=clBlack) and (Fresh.Color2=clWhite),'New session retained color');
    finally Fresh.Free; end;
    Palette.RefreshState; Capture(Form,'creation-colors');
    Palette.Hide; Form.ClientWidth := 640; Form.ClientHeight := 480;
    Editor := TVectArtCanvasControl.Create(Form); Editor.Parent := Form; Editor.Align := alClient;
    Editor.Document := Doc; Editor.EditorState := State; State.CurrentTool := vetText;
    Application.ProcessMessages;
    Editor.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(Editor.CanvasBounds.Left+20,Editor.CanvasBounds.Top+20));
    Check(Doc[Doc.LayerCount-1] is TVectArtTextLayer,'Text creation');
    Check(TVectArtTextLayer(Doc[Doc.LayerCount-1]).TextColor=clRed,'Text uses Color1');
    Check(TVectArtTextLayer(Doc[Doc.LayerCount-1]).FillStyle.Kind=vfkSolid,'Text starts solid');
  finally Form.Free; Creation.Free; Doc.Free; State.Free; end;
end;

var
  D: TVectArtDocument;
  H: TVectArtEditHistory;
  S: TVectArtEditorState;
  F: TForm;
  UI: TVectArtObjectPropertiesControl;
  Sections: TVectArtSettingsSections;
  Picker: TVectArtTemplatePicker;
  Creation: TVectArtShapeCreation;
  R: TVectArtRectangleData;
  T: TVectArtTextData;
  L: TVectArtLineData;
  I: Integer;
  Points: TArray<TPointF>;
  PointValue: TPointF;
  Command: TVectArtAppearanceModeCommand;
  Memo: TMemo;
  Frame: TObjectPropertiesFrame;
  Swatch: TVectArtColorSwatch;
  ColorForm: TForm;
  ColorEdit: TEdit;
  ModeCombo: TComboBox;
  PreviewTimer: TStopwatch;
  PreviewIteration: Integer;
  Exceptions: TUiExceptionRecorder;
  TransparencyLabel: TControl;
  HostPanel: TPanel;
  PreviousBottom, VisibleCount: Integer;
  PatternBytes: TBytes;
begin
  Application.Initialize;
  // キャンバスの文字描画はDLL読込だけでなくTextRenderer側のAcquireも必要。
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Exceptions := TUiExceptionRecorder.Create;
  Application.OnException := Exceptions.Handle;
  TStyleManager.LoadFromFile('C:\Users\Public\Documents\Embarcadero\Studio\37.0\Styles\WindowsModernDark.vsf');
  TStyleManager.TrySetStyle('Windows Modern Dark');
  D := TVectArtDocument.Create; H := TVectArtEditHistory.Create;
  S := TVectArtEditorState.Create; F := TForm.CreateNew(nil);
  Creation := TVectArtShapeCreation.Create;
  Picker := TVectArtTemplatePicker.Create(F);
  Picker.Parent := F;
  Picker.Visible := False;
  try
    Frame := TObjectPropertiesFrame.Create(F);
    Frame.Parent := F; Frame.HandleNeeded; Frame.Free;
    F.ClientWidth := 290; F.ClientHeight := 760;
    UI := TVectArtObjectPropertiesControl.Create(F); UI.Parent := F; UI.Align := alClient;
    UI.EditHistory := H; UI.EditorState := S; UI.Document := D;
    UI.RefreshFromDocument;
    F.Show; Application.ProcessMessages;
    S.SelectRectangleToolGroup;
    Creation.Configure(D,nil,S,Rect(0,0,400,300),1);
    Check(Creation.MouseDown(mbLeft,[],20,20),'Initial rectangle drag');
    Creation.MouseMove([ssLeft],120,100); Creation.MouseUp(mbLeft,[],120,100);
    Check(D.LayerCount = 2,'Initial rectangle missing');
    Check(TVectArtRectangleLayer(D[1]).Filled,'Initial rectangle fill disabled');
    Check(TVectArtRectangleLayer(D[1]).FillColor = S.Color2,'Initial rectangle wrong color');
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkSolid,'Initial rectangle wrong fill style');
    Check(TVectArtRectangleLayer(D[1]).Opacity = 1,'Initial rectangle transparent');
    D.RemoveRectangle(1,R);
    R := Default(TVectArtRectangleData); R.Bounds := RectF(10,20,110,120);
    R.Visible := True; R.Filled := True; R.Opacity := 1; R.FillColor := clRed;
    R.Name := 'Rectangle'; R.StrokeWidth := 2;
    D.InsertRectangle(1,R); D.SelectedIndex := 1; UI.RefreshFromDocument;
    with TVectArtNumericSlider(UI.FindComponent('TransparencySlider')) do
    begin
      Check(Value=0,'Opaque object must show zero transparency');
      Edit.Text:='25'; Edit.OnExit(Edit);
      Check(Abs(D[1].Opacity-0.75)<0.001,'Transparency conversion');
      H.Undo; UI.RefreshFromDocument; Check(Value=0,'Transparency undo');
      TrackBar.Position:=100;
      Check(D[1].Opacity=0,'Full transparency via slider');
      H.Undo; UI.RefreshFromDocument;
    end;
    with TVectArtNumericSlider(UI.FindComponent('StrokeWidthSlider')) do
    begin
      TrackBar.Position:=8;
      Check(TVectArtRectangleLayer(D[1]).StrokeWidth=8,'Stroke slider apply');
      H.Undo; UI.RefreshFromDocument;
      Check(Value=2,'Stroke slider undo');
      TrackBar.Position:=0;
      Check((TrackBar.Position=1) and
        (TVectArtRectangleLayer(D[1]).StrokeWidth=1),
        'Stroke slider must not allow zero width');
      H.Undo; UI.RefreshFromDocument;
    end;
    Sections := TVectArtSettingsSections(FindControl(UI,TVectArtSettingsSections));
    Check(Sections <> nil,'Stacked settings page missing');
    Check(FindControl(UI,TPageControl)=nil,'PageControl is still present');
    Check(FindCaptionControl(Sections.ActiveSection,'位置・サイズ (px)')=nil,
      'Position and size caption still consumes a row');
    TransparencyLabel := FindCaptionControl(Sections.ActiveSection,'透明度 (%)');
    Check(TransparencyLabel<>nil,'Transparency label missing');
    with TVectArtNumericSlider(UI.FindComponent('TransparencySlider')) do
      Check((Left>TransparencyLabel.Left) and
        (Abs((Top+Height div 2)-(TransparencyLabel.Top+TransparencyLabel.Height div 2))<=4),
        'Transparency label, bar and value are not on one row');
    F.ClientWidth:=150; Application.ProcessMessages;
    PreviousBottom := -1;
    VisibleCount := 0;
    for I:=0 to Sections.SectionCount-1 do
      if Sections.Sections[I].Available then
      begin
        Inc(VisibleCount);
        Check(Sections.Sections[I].Visible,'Available settings panel is hidden');
        HostPanel := TPanel(Sections.Sections[I].Parent);
        Check((HostPanel.Align=alTop) and (HostPanel.BevelWidth=1),
          'Settings section is not an alTop panel with a one-pixel bevel');
        Check(HostPanel.Top>=PreviousBottom,'Settings sections overlap or are out of order');
        PreviousBottom := HostPanel.Top+HostPanel.Height;
        Check(Sections.IconRect(Sections.Sections[I].Category).IsEmpty,
          'Legacy category icon is still visible');
      end;
    Check(VisibleCount=5,'Shape settings were not combined into one page');
    F.ClientWidth:=290; Application.ProcessMessages;
    Sections.ActiveSection:=Sections.Sections[Ord(vscInfo)];
    ColorEdit := TEdit(FindControl(Sections.ActiveSection,TEdit));
    ColorEdit.Text := '12.5'; ColorEdit.OnExit(ColorEdit);
    Check(TVectArtRectangleLayer(D[1]).Bounds.Left = 10,'Fractional pixels accepted');
    Check(ColorEdit.Text = '10','Invalid pixel input not restored');
    ColorEdit.Text := '-12'; ColorEdit.OnExit(ColorEdit);
    Check(TVectArtRectangleLayer(D[1]).Bounds.Left = -12,'Negative integer pixels rejected');
    H.Undo; UI.RefreshFromDocument;
    F.ClientWidth := 260; Application.ProcessMessages;
    Check(ColorEdit.Width > 30,'Pixel field collapsed after resize');
    F.ClientWidth := 290; Application.ProcessMessages;
    Capture(F,'settings-info');
    for I := 0 to Sections.SectionCount-1 do
      if Sections.Sections[I].Caption = '塗り色' then Sections.ActiveSection := Sections.Sections[I];
    Swatch := TVectArtColorSwatch(FindControl(Sections.ActiveSection,TVectArtColorSwatch));
    Swatch.OnClick(Swatch);
    ColorForm := nil;
    for I := 0 to Screen.FormCount-1 do
      if Screen.Forms[I].Caption = '色・塗りを編集' then ColorForm := Screen.Forms[I];
    Check(ColorForm <> nil,'Shared paint popup missing');
    Check(ColorForm.FindComponent('HexColorEdit') = nil,'HEX editor still present');
    PickPopupColor(ColorForm,clLime);
    Check(TVectArtRectangleLayer(D[1]).FillColor = clLime,'Popup live color apply');
    H.Undo;
    Check(TVectArtRectangleLayer(D[1]).FillColor = clRed,'Popup color undo');
    ModeCombo := TComboBox(FindControl(ColorForm,TComboBox));
    ModeCombo.ItemIndex := 1; ModeCombo.OnChange(ModeCombo);
    PickPopupColor(ColorForm,clBlue);
    Check(TVectArtRectangleLayer(D[1]).FillColor = clBlue,'Gradient color did not apply');
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkLinearHorizontal,'Gradient mode did not apply');
    with TVectArtNumericSlider(ColorForm.FindComponent('GradientAngleSlider')).Edit do
    begin
      Check(Visible,'Angle input hidden');
      Text := '45'; OnExit(TVectArtNumericSlider(ColorForm.FindComponent('GradientAngleSlider')).Edit);
      Check(TVectArtRectangleLayer(D[1]).FillStyle.Angle = 45,'Angle apply');
      H.Undo;
      Check(TVectArtRectangleLayer(D[1]).FillStyle.Angle = 0,'Angle undo');
      H.Redo;
      Check(TVectArtRectangleLayer(D[1]).FillStyle.Angle = 45,'Angle redo');
      Text := 'invalid'; OnExit(TVectArtNumericSlider(ColorForm.FindComponent('GradientAngleSlider')).Edit);
      Check(Text = '45','Invalid angle restored');
    end;
    CloseVectArtColorPopup(UI);
    Swatch.OnClick(Swatch);
    Check(TVectArtNumericSlider(ColorForm.FindComponent('GradientAngleSlider')).Edit.Text = '45','Angle reopen');
    PreviewTimer := TStopwatch.StartNew;
    for PreviewIteration := 1 to 100 do
    begin
      if Odd(PreviewIteration) then PickPopupColor(ColorForm,clRed) else PickPopupColor(ColorForm,clBlue);
      ColorForm.Repaint;
    end;
    Writeln(Format('100 gradient color updates + repaint: %.1f ms',
      [PreviewTimer.Elapsed.TotalMilliseconds]));
    PickPopupColor(ColorForm,clBlue);
    TRadioButton(ColorForm.FindComponent('ColorSlot2')).Checked := True;
    Check(TDrawGrid(FindControl(ColorForm,TDrawGrid)).Tag >= 0,'Color2 chip not selected');
    with TColorPickerSVArea(ColorForm.FindComponent('SVPicker')) do
    begin
      Color := RGB(17,43,79); OnChange(TColorPickerSVArea(ColorForm.FindComponent('SVPicker')));
    end;
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Color2 = TColor(RGB(17,43,79)),'Picker color2 apply');
    Check(TDrawGrid(FindControl(ColorForm,TDrawGrid)).Tag = -1,'Unlisted color has selection');
    TRadioButton(ColorForm.FindComponent('ColorSlot1')).Checked := True;
    Check(TDrawGrid(FindControl(ColorForm,TDrawGrid)).Tag >= 0,'Color1 selection not restored');
    with TComboBox(ColorForm.FindComponent('GradientKindCombo')) do
    begin
      ItemIndex := Items.IndexOf('円形'); OnChange(ColorForm.FindComponent('GradientKindCombo'));
    end;
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkCircle,'Circle UI apply');
    Check(not TVectArtNumericSlider(ColorForm.FindComponent('GradientAngleSlider')).Visible,'Circle angle visible');
    Check(S.Color2 = clWhite,'Circle creation default');
    H.Undo;
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkLinearHorizontal,'Circle UI undo');
    H.Redo;
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkCircle,'Circle UI redo');
    CloseVectArtColorPopup(UI); Swatch.OnClick(Swatch);
    Check(TComboBox(ColorForm.FindComponent('GradientKindCombo')).Text = '円形','Circle popup reopen');
    Capture(ColorForm,'paint-circle');
    with TComboBox(ColorForm.FindComponent('GradientKindCombo')) do
    begin
      ItemIndex := 0; OnChange(ColorForm.FindComponent('GradientKindCombo'));
    end;
    with TComboBox(ColorForm.FindComponent('GradientKindCombo')) do
    begin
      ItemIndex := Items.IndexOf('角形'); OnChange(ColorForm.FindComponent('GradientKindCombo'));
    end;
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkSquare,'Square UI apply');
    Check(not TVectArtNumericSlider(ColorForm.FindComponent('GradientAngleSlider')).Visible,'Square angle visible');
    Check(S.Color2 = clWhite,'Square creation default');
    H.Undo;
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkLinearHorizontal,'Square UI undo');
    H.Redo;
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkSquare,'Square UI redo');
    CloseVectArtColorPopup(UI); Swatch.OnClick(Swatch);
    Check(TComboBox(ColorForm.FindComponent('GradientKindCombo')).Text = '角形','Square popup reopen');
    Capture(ColorForm,'paint-square');
    with TComboBox(ColorForm.FindComponent('GradientKindCombo')) do
    begin
      ItemIndex := 0; OnChange(ColorForm.FindComponent('GradientKindCombo'));
    end;
    with TComboBox(ColorForm.FindComponent('GradientKindCombo')) do
    begin
      ItemIndex := Items.IndexOf('波状'); OnChange(ColorForm.FindComponent('GradientKindCombo'));
    end;
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkWave,'Wave UI apply');
    Check(not TVectArtNumericSlider(ColorForm.FindComponent('GradientAngleSlider')).Visible,'Wave angle visible');
    Check(S.Color2 = clWhite,'Wave creation default');
    H.Undo;
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkLinearHorizontal,'Wave UI undo');
    H.Redo;
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkWave,'Wave UI redo');
    CloseVectArtColorPopup(UI); Swatch.OnClick(Swatch);
    Check(TComboBox(ColorForm.FindComponent('GradientKindCombo')).Text = '波状','Wave popup reopen');
    with TVectArtNumericSlider(ColorForm.FindComponent('GradientWaveCountSlider')).Edit do
    begin
      Check(Text = '5','Wave default count');
      Text := '3'; OnExit(TVectArtNumericSlider(ColorForm.FindComponent('GradientWaveCountSlider')).Edit);
      Check(TVectArtRectangleLayer(D[1]).FillStyle.WaveCount = 3,'Wave count apply');
      H.Undo;
      Check(TVectArtRectangleLayer(D[1]).FillStyle.WaveCount = 5,'Wave count undo');
      H.Redo;
      Check(TVectArtRectangleLayer(D[1]).FillStyle.WaveCount = 3,'Wave count redo');
    end;
    CloseVectArtColorPopup(UI); Swatch.OnClick(Swatch);
    Check(TVectArtNumericSlider(ColorForm.FindComponent('GradientWaveCountSlider')).Edit.Text = '3','Wave count reopen');
    Capture(ColorForm,'paint-wave');
    with TComboBox(ColorForm.FindComponent('GradientKindCombo')) do
    begin
      ItemIndex := 0; OnChange(ColorForm.FindComponent('GradientKindCombo'));
    end;
    with TComboBox(ColorForm.FindComponent('GradientKindCombo')) do
    begin
      ItemIndex := Items.IndexOf('スペクトル'); OnChange(ColorForm.FindComponent('GradientKindCombo'));
    end;
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkSpectrum,'Spectrum UI apply');
    Check(not TRadioButton(ColorForm.FindComponent('ColorSlot2')).Visible,'Spectrum color2 visible');
    Check(S.Color2 = clWhite,'Spectrum creation default');
    H.Undo;
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkLinearHorizontal,'Spectrum UI undo');
    H.Redo;
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkSpectrum,'Spectrum UI redo');
    with TVectArtNumericSlider(ColorForm.FindComponent('GradientAngleSlider')).Edit do
    begin
      Text := '135'; OnExit(TVectArtNumericSlider(ColorForm.FindComponent('GradientAngleSlider')).Edit);
      Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkSpectrum,'Angle switched spectrum to linear');
      Check(TVectArtRectangleLayer(D[1]).FillStyle.Angle = 135,'Spectrum angle apply');
      Text := '45'; OnExit(TVectArtNumericSlider(ColorForm.FindComponent('GradientAngleSlider')).Edit);
    end;
    CloseVectArtColorPopup(UI);
    S.Color1 := clYellow;
    S.Color2 := clAqua;
    Swatch.OnClick(Swatch);
    Check(TComboBox(ColorForm.FindComponent('GradientKindCombo')).Text = 'スペクトル','Spectrum reopen');
    Capture(ColorForm,'paint-spectrum');
    with TComboBox(ColorForm.FindComponent('GradientKindCombo')) do
    begin
      ItemIndex := 0; OnChange(ColorForm.FindComponent('GradientKindCombo'));
    end;
    Check(TRadioButton(ColorForm.FindComponent('ColorSlot2')).Visible,'Linear color2 missing');
    Capture(ColorForm,'paint-gradient');
    ModeCombo := TComboBox(FindControl(ColorForm,TComboBox));
    ModeCombo.ItemIndex := 2; ModeCombo.OnChange(ModeCombo);
    Check(not FindControl(ColorForm,TDrawGrid).Visible,'Pattern color grid visible');
    Check(TColorPickerSVArea(ColorForm.FindComponent('SVPicker')).Visible,'Pattern picker missing');
    Check(ColorForm.ClientHeight > 400,'Pattern settings were not laid out');
    with TComboBox(ColorForm.FindComponent('TexturePatternCombo')) do
    begin
      ItemIndex := Items.IndexOf('斜線'); OnChange(ColorForm.FindComponent('TexturePatternCombo'));
    end;
    Check(not TDrawGrid(FindControl(ColorForm,TDrawGrid)).Visible,
      'Pattern should use the compact picker layout');
    Check(TColorPickerSVArea(ColorForm.FindComponent('SVPicker')).Visible,'Pattern picker missing');
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind=vfkTexture,'Pattern not applied as texture');
    Check((TVectArtRectangleLayer(D[1]).FillColor=clYellow) and
      (TVectArtRectangleLayer(D[1]).FillStyle.Color2=clAqua),
      'Pattern did not adopt tool color1/color2');
    PatternBytes := Copy(TVectArtRectangleLayer(D[1]).FillStyle.TexturePng);
    with TVectArtNumericSlider(ColorForm.FindComponent('PatternParameterSlider0')).Edit do
    begin
      Text := '9'; OnExit(TVectArtNumericSlider(ColorForm.FindComponent('PatternParameterSlider0')).Edit);
    end;
    Check(not CompareMem(@PatternBytes[0],
      @TVectArtRectangleLayer(D[1]).FillStyle.TexturePng[0],
      Min(Length(PatternBytes), Length(TVectArtRectangleLayer(D[1]).FillStyle.TexturePng))),
      'Pattern slider did not regenerate texture');
    Capture(ColorForm,'paint-pattern');
    H.Undo;
    H.Undo;
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind<>vfkTexture,
      'Pattern undo did not restore previous paint');
    S.Color1 := clBlack;
    S.Color2 := clWhite;
    TVectArtRectangleLayer(D[1]).FillColor := clBlue;
    UI.RefreshFromDocument;
    CloseVectArtColorPopup(UI);
    Swatch.OnClick(Swatch);
    ModeCombo := TComboBox(FindControl(ColorForm,TComboBox));
    ModeCombo.ItemIndex := 2;
    ModeCombo.OnChange(ModeCombo);
    with TComboBox(ColorForm.FindComponent('TexturePatternCombo')) do
    begin ItemIndex := 0; OnChange(ColorForm.FindComponent('TexturePatternCombo')); end;
    PickTexture(ColorForm);
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind=vfkTexture,'Texture file applied to fill');
    Check(S.Color2 = clWhite,'Texture creation default');
    H.Undo; Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind<>vfkTexture,'Texture fill undo');
    H.Redo; Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind=vfkTexture,'Texture fill redo');
    CloseVectArtColorPopup(UI); Swatch.OnClick(Swatch);
    Check(ModeCombo.ItemIndex=2,'Texture fill reopen');
    Capture(ColorForm,'paint-texture');
    ModeCombo.ItemIndex := 1; ModeCombo.OnChange(ModeCombo);
    CloseVectArtColorPopup(UI);
    for I := 0 to Sections.SectionCount-1 do
      if Sections.Sections[I].Caption = '線' then Sections.ActiveSection := Sections.Sections[I];
    Capture(F,'settings-line');
    Command := TVectArtAppearanceModeCommand.Create(D,1,vrmFill);
    try
      Command.Execute;
      Check(TVectArtRectangleLayer(D[1]).StrokeWidth = 0,'Fill-only mode');
      Command.Undo;
      Check(TVectArtRectangleLayer(D[1]).StrokeWidth = 2,'Appearance undo');
    finally Command.Free; end;
    for I := 0 to Sections.SectionCount-1 do
      if Sections.Sections[I].Caption = '線の色' then Sections.ActiveSection := Sections.Sections[I];
    Swatch := TVectArtColorSwatch(FindControl(Sections.ActiveSection,TVectArtColorSwatch));
    Swatch.OnClick(Swatch);
    ModeCombo := TComboBox(FindControl(ColorForm,TComboBox));
    Check(ModeCombo.Items.Count = 3,'Stroke popup allows texture');
    ModeCombo.ItemIndex := 2; ModeCombo.OnChange(ModeCombo); PickTexture(ColorForm);
    Check(D[1].StrokePaint.Kind=vfkTexture,'Texture file applied to stroke');
    Check(S.Color1=clBlack,'Object texture must not change creation color');
    H.Undo; Check(D[1].StrokePaint.Kind<>vfkTexture,'Texture stroke undo');
    H.Redo; Check(D[1].StrokePaint.Kind=vfkTexture,'Texture stroke redo');
    CloseVectArtColorPopup(UI); Swatch.OnClick(Swatch);
    Check(ModeCombo.ItemIndex=2,'Texture stroke reopen');
    Capture(ColorForm,'stroke-texture-popup');
    ModeCombo.ItemIndex := 1; ModeCombo.OnChange(ModeCombo);
    PickPopupColor(ColorForm,clRed);
    TRadioButton(ColorForm.FindComponent('ColorSlot2')).Checked := True;
    PickPopupColor(ColorForm,clBlue);
    with TVectArtNumericSlider(ColorForm.FindComponent('GradientAngleSlider')).Edit do
    begin
      Text := '45'; OnExit(TVectArtNumericSlider(ColorForm.FindComponent('GradientAngleSlider')).Edit);
    end;
    Check(D[1].StrokePaint.Kind = vfkLinearHorizontal,'Stroke UI apply');
    Check(D[1].StrokePaint.Angle = 45,'Stroke UI angle');
    Check(TVectArtRectangleLayer(D[1]).FillColor = clBlue,'Stroke UI altered interior');
    Check(TVectArtRectangleLayer(D[1]).StrokeWidth = 2,'Stroke UI altered width');
    ModeCombo.ItemIndex := 0; ModeCombo.OnChange(ModeCombo);
    Check(D[1].StrokePaint.Kind = vfkSolid,'Stroke solid switch');
    H.Undo;
    Check(D[1].StrokePaint.Kind = vfkLinearHorizontal,'Stroke gradient Undo');
    ModeCombo.ItemIndex := 1; ModeCombo.OnChange(ModeCombo);
    CloseVectArtColorPopup(UI); Swatch.OnClick(Swatch);
    Check(TVectArtNumericSlider(ColorForm.FindComponent('GradientAngleSlider')).Edit.Text = '45','Stroke popup reopen');
    Capture(ColorForm,'stroke-gradient-popup');
    CloseVectArtColorPopup(UI);
    Capture(F,'settings-stroke-gradient');
    T := Default(TVectArtTextData); T.Text := 'タイトル'; T.Name := 'Text';
    T.FontFamily := 'Yu Gothic UI'; T.FontSize := 32; T.Bounds := RectF(20,20,180,80);
    T.Opacity := 1; T.Visible := True; T.TextColor := clWhite;
    D.InsertText(2,T); D.SelectedIndex := 2; UI.RefreshFromDocument;
    Check(FindCaptionControl(Sections,'文字色')<>nil,
      'Stacked text color section header was not updated');
    for I := 0 to Sections.SectionCount-1 do
      if Sections.Sections[I].Caption = '文字色' then Sections.ActiveSection := Sections.Sections[I];
    Swatch := TVectArtColorSwatch(FindControl(Sections.ActiveSection,TVectArtColorSwatch));
    Swatch.OnClick(Swatch);
    ModeCombo := TComboBox(FindControl(ColorForm,TComboBox));
    Check(ModeCombo.Items.Count = 3,'Text popup allows texture');
    ModeCombo.ItemIndex := 2; ModeCombo.OnChange(ModeCombo); PickTexture(ColorForm);
    Check(TVectArtTextLayer(D[2]).FillStyle.Kind=vfkTexture,'Texture file applied to text');
    H.Undo; Check(TVectArtTextLayer(D[2]).FillStyle.Kind=vfkSolid,'Texture text undo');
    H.Redo; Check(TVectArtTextLayer(D[2]).FillStyle.Kind=vfkTexture,'Texture text redo');
    CloseVectArtColorPopup(UI); Swatch.OnClick(Swatch);
    Check(ModeCombo.ItemIndex=2,'Texture text reopen');
    Capture(ColorForm,'text-texture-popup');
    ModeCombo.ItemIndex := 1; ModeCombo.OnChange(ModeCombo);
    with TComboBox(ColorForm.FindComponent('GradientKindCombo')) do
    begin ItemIndex := 4; OnChange(TComboBox(ColorForm.FindComponent('GradientKindCombo'))); end;
    Check(TVectArtTextLayer(D[2]).FillStyle.Kind = vfkWave,'Text gradient UI');
    ModeCombo.ItemIndex := 0; ModeCombo.OnChange(ModeCombo);
    H.Undo; Check(TVectArtTextLayer(D[2]).FillStyle.Kind = vfkWave,'Text gradient Undo');
    CloseVectArtColorPopup(UI); Swatch.OnClick(Swatch);
    Check(TComboBox(ColorForm.FindComponent('GradientKindCombo')).Text = '波状','Text gradient reopen');
    Capture(ColorForm,'text-gradient-popup'); CloseVectArtColorPopup(UI);

    for I := 0 to Sections.SectionCount-1 do
      if Sections.Sections[I].Caption = '文字' then Sections.ActiveSection := Sections.Sections[I];
    Capture(F,'settings-text');
    ModeCombo := TComboBox(FindControl(Sections.ActiveSection,TComboBox));
    Check(ModeCombo.Text = 'Yu Gothic UI','Font selection lost when tab opens');
    ModeCombo.ItemIndex := ModeCombo.Items.IndexOf('Arial');
    ModeCombo.OnSelect(ModeCombo);
    Check(TVectArtTextLayer(D[2]).FontFamily = 'Arial','Font change did not apply');
    H.Undo;
    Check(TVectArtTextLayer(D[2]).FontFamily = 'Yu Gothic UI','Font undo');
    Memo := TMemo(FindControl(UI,TMemo)); Memo.Text := '編集した文字'; Memo.OnExit(Memo);
    Check(TVectArtTextLayer(D[2]).Text = '編集した文字','Text edit did not apply');
    H.Undo; Check(TVectArtTextLayer(D[2]).Text = 'タイトル','Text undo');
    Check(TVectArtTextLayer(D[2]).FillStyle.Kind = vfkWave,'Text editing retains gradient');
    D.SetLayerLocked(2,True); UI.RefreshFromDocument;
    Check(not Memo.Enabled,'Locked text editable');
    for I := 0 to Sections.SectionCount-1 do
      if Sections.Sections[I].Caption = '効果' then Sections.ActiveSection := Sections.Sections[I];
    ModeCombo := TComboBox(FindControl(Sections.ActiveSection,TComboBox));
    ModeCombo.ItemIndex := 3; ModeCombo.OnChange(ModeCombo);
    Capture(F,'settings-effects');
    L := Default(TVectArtLineData); L.Visible := True; L.Opacity := 1;
    L.StartPoint := PointF(10,10); L.EndPoint := PointF(100,100);
    D.InsertLine(3,L); D.SelectedIndex := 3; UI.RefreshFromDocument;
    UI.PathEndMarkerCombo.SetPendingMarker(vlmArrow,True);
    UI.PathEndMarkerCombo.OnChange(UI.PathEndMarkerCombo);
    Check(TVectArtLineLayer(D[3]).EndMarker = vlmArrow,'Line marker setting');
    H.Undo; Check(TVectArtLineLayer(D[3]).EndMarker = vlmNone,'Line marker undo');
    for I := 0 to VECTART_TEMPLATE_COUNT-1 do
    begin
      Points := VectArtTemplatePoints(I,RectF(0,0,1,1));
      Check(Length(Points)>=3,'Template polygon missing');
      for PointValue in Points do
        Check(not IsNan(PointValue.X) and not IsNan(PointValue.Y) and
          (PointValue.X >= -0.01) and (PointValue.X <= 1.01) and
          (PointValue.Y >= -0.01) and (PointValue.Y <= 1.01),'Template outside normalized bounds');
    end;
    S.TemplateIndex := 16; S.CurrentTool := vetTemplate; S.RectangleMode := vrmFillAndOutline;
    Creation.Configure(D,H,S,Rect(0,0,400,300),1);
    Check(Creation.MouseDown(mbLeft,[],100,100),'Template drag start');
    Creation.MouseMove([ssLeft],200,200); Creation.MouseUp(mbLeft,[],200,200);
    Check(D[D.LayerCount-1] is TVectArtPathLayer,'Template did not create Path');
    Check(TVectArtPathLayer(D[D.LayerCount-1]).Closed,'Template is not closed');
    Check(TVectArtPathLayer(D[D.LayerCount-1]).FillStyle.Kind = vfkSolid,'New shape must use solid fill');
    Check(TVectArtPathLayer(D[D.LayerCount-1]).FillStyle.Angle = 0,'New shape must not inherit angle');
    Check(TVectArtPathLayer(D[D.LayerCount-1]).FillColor = clWhite,'New shape must use Color2');
    I := D.LayerCount; H.Undo; Check(D.LayerCount=I-1,'Template undo');
    H.Redo; Check(D.LayerCount=I,'Template redo');
    Check(D[D.LayerCount-1].StrokePaint.Kind = vfkSolid,'Creation must use solid stroke');
    Check(D[D.LayerCount-1].StrokePaint.Angle = 0,'Creation must not inherit stroke angle');
    D.SetSelectedLayers([1,3]); UI.RefreshFromDocument;
    for I := 0 to Sections.SectionCount-1 do
      if Sections.Sections[I].Caption = '線の色' then Sections.ActiveSection := Sections.Sections[I];
    Swatch := TVectArtColorSwatch(FindControl(Sections.ActiveSection,TVectArtColorSwatch));
    Check(Swatch.Enabled,'Mixed strokes cannot edit'); Swatch.OnClick(Swatch);
    with TComboBox(ColorForm.FindComponent('GradientKindCombo')) do
    begin ItemIndex := Items.IndexOf('放射'); OnChange(ColorForm.FindComponent('GradientKindCombo')); end;
    Check((D[1].StrokePaint.Kind = vfkRadial) and (D[3].StrokePaint.Kind = vfkRadial),'Mixed stroke apply');
    H.Undo;
    Check((D[1].StrokePaint.Kind = vfkLinearHorizontal) and (D[3].StrokePaint.Kind = vfkSolid),'Mixed stroke single Undo');
    D.SetLayerLocked(3,True); UI.RefreshFromDocument;
    Check(not Swatch.Enabled,'Locked stroke enabled');
    Check(not ColorForm.Visible,'Locked selection kept popup open');
    D.SetLayerLocked(3,False);
    Picker.Open(S); Picker.Hide; Capture(Picker,'template-picker');
    ShowVectArtColorPopup(UI,'色・塗り',clRed,[clRed,clWhite],nil);
    for I := 0 to Screen.FormCount-1 do
      if Screen.Forms[I].Caption = '色・塗り' then
      begin
        Check(not FindControl(Screen.Forms[I],TComboBox).Visible,'Solid-only mode selector visible');
        Capture(Screen.Forms[I],'paint-popup');
      end;
    CloseVectArtColorPopup(UI);
    CheckCreationColors;
    Check(Exceptions.ErrorText='',Exceptions.ErrorText);
    Writeln('PASS settings UI, text/line commands, locks, appearance, 30 templates and undo/redo');
  finally
    Picker.Free; Creation.Free; F.Free; S.Free; H.Free; D.Free;
    Application.OnException := nil; Exceptions.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
