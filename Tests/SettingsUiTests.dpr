// Validates the public controls and renders real VCL panels for layout inspection.
program SettingsUiTests;
{$APPTYPE CONSOLE}
uses
  Winapi.Windows, System.Diagnostics, System.UITypes, System.Classes, System.SysUtils, System.Types, System.Math,
  Vcl.Forms, Vcl.Grids, Vcl.Controls, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.Graphics,
  Vcl.Themes, Vcl.Styles, Vcl.Imaging.pngimage,
  VectArtDesignerNumericSlider, ColorPickerSVArea, TextRendererSkiaBootstrap, TextRendererSkiaRuntime,
  VectArtDesignerDocument, VectArtDesignerEditorState, VectArtDesignerEditHistory,
  VectArtDesignerObjectPropertiesControl, VectArtDesignerObjectPropertiesFrame, VectArtDesignerTemplatePicker,
  VectArtDesignerTemplateGeometry, VectArtDesignerShapeCreation,
  VectArtDesignerColorSwatch, VectArtDesignerPaintPopup, VectArtDesignerAppearanceModeCommand;

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
procedure Capture(Control: TWinControl; const Name: string);
var B: TBitmap; P: TPngImage; DC: HDC;
begin
  B := TBitmap.Create; P := TPngImage.Create;
  try
    B.SetSize(Control.Width,Control.Height);
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

var
  D: TVectArtDocument;
  H: TVectArtEditHistory;
  S: TVectArtEditorState;
  F: TForm;
  UI: TVectArtObjectPropertiesControl;
  Tabs: TPageControl;
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
begin
  Application.Initialize;
  TStyleManager.LoadFromFile('C:\Users\Public\Documents\Embarcadero\Studio\37.0\Styles\WindowsModernDark.vsf');
  TStyleManager.TrySetStyle('Windows Modern Dark');
  D := TVectArtDocument.Create; H := TVectArtEditHistory.Create;
  S := TVectArtEditorState.Create; F := TForm.CreateNew(nil);
  Creation := TVectArtShapeCreation.Create;
  Picker := TVectArtTemplatePicker.Create(nil);
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
    Check(TVectArtRectangleLayer(D[1]).FillColor = S.RectangleFillColor,'Initial rectangle wrong color');
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkSolid,'Initial rectangle wrong fill style');
    Check(TVectArtRectangleLayer(D[1]).Opacity = 1,'Initial rectangle transparent');
    D.RemoveRectangle(1,R);
    R := Default(TVectArtRectangleData); R.Bounds := RectF(10,20,110,120);
    R.Visible := True; R.Filled := True; R.Opacity := 1; R.FillColor := clRed;
    R.Name := 'Rectangle'; R.StrokeWidth := 2;
    D.InsertRectangle(1,R); D.SelectedIndex := 1; UI.RefreshFromDocument;
    Tabs := TPageControl(FindControl(UI,TPageControl));
    Check(Tabs <> nil,'Settings tabs missing');
    ColorEdit := TEdit(FindControl(Tabs.ActivePage,TEdit));
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
    for I := 0 to Tabs.PageCount-1 do
      if Tabs.Pages[I].Caption = '塗り色' then Tabs.ActivePage := Tabs.Pages[I];
    Swatch := TVectArtColorSwatch(FindControl(Tabs.ActivePage,TVectArtColorSwatch));
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
    Check(S.RectangleFillStyle.Kind = vfkCircle,'Circle creation default');
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
    Check(S.RectangleFillStyle.Kind = vfkSquare,'Square creation default');
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
    Check(S.RectangleFillStyle.Kind = vfkWave,'Wave creation default');
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
    Check(S.RectangleFillStyle.Kind = vfkSpectrum,'Spectrum creation default');
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
    CloseVectArtColorPopup(UI); Swatch.OnClick(Swatch);
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
    Check(not FindControl(ColorForm,TDrawGrid).Visible,'Texture color grid visible');
    Check(not TColorPickerSVArea(ColorForm.FindComponent('SVPicker')).Visible,'Texture picker visible');
    Check(ColorForm.ClientHeight < 220,'Texture popup retains color space');
    Capture(ColorForm,'paint-texture');
    ModeCombo.ItemIndex := 1; ModeCombo.OnChange(ModeCombo);
    CloseVectArtColorPopup(UI);
    for I := 0 to Tabs.PageCount-1 do
      if Tabs.Pages[I].Caption = '線' then Tabs.ActivePage := Tabs.Pages[I];
    Capture(F,'settings-line');
    Command := TVectArtAppearanceModeCommand.Create(D,1,vrmFill);
    try
      Command.Execute;
      Check(TVectArtRectangleLayer(D[1]).StrokeWidth = 0,'Fill-only mode');
      Command.Undo;
      Check(TVectArtRectangleLayer(D[1]).StrokeWidth = 2,'Appearance undo');
    finally Command.Free; end;
    for I := 0 to Tabs.PageCount-1 do
      if Tabs.Pages[I].Caption = '線の色' then Tabs.ActivePage := Tabs.Pages[I];
    Swatch := TVectArtColorSwatch(FindControl(Tabs.ActivePage,TVectArtColorSwatch));
    Swatch.OnClick(Swatch);
    ModeCombo := TComboBox(FindControl(ColorForm,TComboBox));
    Check(ModeCombo.Items.Count = 2,'Stroke popup should allow solid and gradient only');
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
    for I := 0 to Tabs.PageCount-1 do
      if Tabs.Pages[I].Caption = '文字色' then Tabs.ActivePage := Tabs.Pages[I];
    Swatch := TVectArtColorSwatch(FindControl(Tabs.ActivePage,TVectArtColorSwatch));
    Swatch.OnClick(Swatch);
    ModeCombo := TComboBox(FindControl(ColorForm,TComboBox));
    Check(ModeCombo.Items.Count = 2,'Text allows solid and gradient');
    ModeCombo.ItemIndex := 1; ModeCombo.OnChange(ModeCombo);
    with TComboBox(ColorForm.FindComponent('GradientKindCombo')) do
    begin ItemIndex := 4; OnChange(TComboBox(ColorForm.FindComponent('GradientKindCombo'))); end;
    Check(TVectArtTextLayer(D[2]).FillStyle.Kind = vfkWave,'Text gradient UI');
    ModeCombo.ItemIndex := 0; ModeCombo.OnChange(ModeCombo);
    H.Undo; Check(TVectArtTextLayer(D[2]).FillStyle.Kind = vfkWave,'Text gradient Undo');
    CloseVectArtColorPopup(UI); Swatch.OnClick(Swatch);
    Check(TComboBox(ColorForm.FindComponent('GradientKindCombo')).Text = '波状','Text gradient reopen');
    Capture(ColorForm,'text-gradient-popup'); CloseVectArtColorPopup(UI);

    for I := 0 to Tabs.PageCount-1 do
      if Tabs.Pages[I].Caption = '文字' then Tabs.ActivePage := Tabs.Pages[I];
    Capture(F,'settings-text');
    ModeCombo := TComboBox(FindControl(Tabs.ActivePage,TComboBox));
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
    for I := 0 to Tabs.PageCount-1 do
      if Tabs.Pages[I].Caption = '効果' then Tabs.ActivePage := Tabs.Pages[I];
    ModeCombo := TComboBox(FindControl(Tabs.ActivePage,TComboBox));
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
    Check(TVectArtPathLayer(D[D.LayerCount-1]).FillStyle.Kind = vfkLinearHorizontal,'New shape lost selected gradient');
    Check(TVectArtPathLayer(D[D.LayerCount-1]).FillStyle.Angle = 45,'New shape lost angle');
    Check(TVectArtPathLayer(D[D.LayerCount-1]).FillColor = clBlue,'New shape lost selected fill color');
    I := D.LayerCount; H.Undo; Check(D.LayerCount=I-1,'Template undo');
    H.Redo; Check(D.LayerCount=I,'Template redo');
    Check(D[D.LayerCount-1].StrokePaint.Kind = vfkLinearHorizontal,'Creation lost stroke gradient');
    Check(D[D.LayerCount-1].StrokePaint.Angle = 45,'Creation lost stroke angle');
    D.SetSelectedLayers([1,3]); UI.RefreshFromDocument;
    for I := 0 to Tabs.PageCount-1 do
      if Tabs.Pages[I].Caption = '線の色' then Tabs.ActivePage := Tabs.Pages[I];
    Swatch := TVectArtColorSwatch(FindControl(Tabs.ActivePage,TVectArtColorSwatch));
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
    Writeln('PASS settings UI, text/line commands, locks, appearance, 30 templates and undo/redo');
  finally Picker.Free; Creation.Free; F.Free; S.Free; H.Free; D.Free; end;
end.
