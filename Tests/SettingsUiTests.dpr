// Validates the public controls and renders real VCL panels for layout inspection.
program SettingsUiTests;
{$APPTYPE CONSOLE}
uses
  System.Classes, System.SysUtils, System.Types, System.Math,
  Vcl.Forms, Vcl.Controls, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.Graphics,
  Vcl.Themes, Vcl.Styles, Vcl.Imaging.pngimage,
  TextRendererSkiaBootstrap, TextRendererSkiaRuntime,
  VectArtDesignerDocument, VectArtDesignerEditorState, VectArtDesignerEditHistory,
  VectArtDesignerObjectPropertiesControl, VectArtDesignerObjectPropertiesFrame, VectArtDesignerTemplatePicker,
  VectArtDesignerTemplateGeometry, VectArtDesignerShapeCreation,
  VectArtDesignerPaintPopup, VectArtDesignerAppearanceModeCommand;

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

procedure Capture(Control: TWinControl; const Name: string);
var B: TBitmap; P: TPngImage;
begin
  B := TBitmap.Create; P := TPngImage.Create;
  try
    B.SetSize(Control.Width,Control.Height);
    Control.HandleNeeded;
    Control.PaintTo(B.Canvas,0,0);
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
    R := Default(TVectArtRectangleData); R.Bounds := RectF(10,20,110,120);
    R.Visible := True; R.Filled := True; R.Opacity := 1; R.FillColor := clRed;
    R.Name := 'Rectangle'; R.StrokeWidth := 2;
    D.InsertRectangle(1,R); D.SelectedIndex := 1; UI.RefreshFromDocument;
    Tabs := TPageControl(FindControl(UI,TPageControl));
    Check(Tabs <> nil,'Settings tabs missing');
    Capture(F,'settings-info');
    for I := 0 to Tabs.PageCount-1 do
      if Tabs.Pages[I].Caption = '塗り色' then Tabs.ActivePage := Tabs.Pages[I];
    Swatch := TVectArtColorSwatch(FindControl(Tabs.ActivePage,TVectArtColorSwatch));
    Swatch.OnClick(Swatch);
    ColorForm := nil;
    for I := 0 to Screen.FormCount-1 do
      if Screen.Forms[I].Caption = '色・塗りを編集' then ColorForm := Screen.Forms[I];
    Check(ColorForm <> nil,'Shared paint popup missing');
    ColorEdit := TEdit(FindControl(ColorForm,TEdit));
    ColorEdit.Text := '#00FF00'; ColorEdit.OnExit(ColorEdit);
    Check(TVectArtRectangleLayer(D[1]).FillColor = clLime,'Popup live color apply');
    H.Undo;
    Check(TVectArtRectangleLayer(D[1]).FillColor = clRed,'Popup color undo');
    ModeCombo := TComboBox(FindControl(ColorForm,TComboBox));
    ModeCombo.ItemIndex := 1; ModeCombo.OnChange(ModeCombo);
    ColorEdit.Text := '#0000FF'; ColorEdit.OnExit(ColorEdit);
    Check(TVectArtRectangleLayer(D[1]).FillColor = clRed,'Draft gradient modified document');
    Capture(ColorForm,'paint-gradient');
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
    T := Default(TVectArtTextData); T.Text := 'タイトル'; T.Name := 'Text';
    T.FontFamily := 'Yu Gothic UI'; T.FontSize := 32; T.Bounds := RectF(20,20,180,80);
    T.Opacity := 1; T.Visible := True; T.TextColor := clWhite;
    D.InsertText(2,T); D.SelectedIndex := 2; UI.RefreshFromDocument;
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
    I := D.LayerCount; H.Undo; Check(D.LayerCount=I-1,'Template undo');
    H.Redo; Check(D.LayerCount=I,'Template redo');
    Picker.Open(S); Picker.Hide; Capture(Picker,'template-picker');
    ShowVectArtColorPopup(UI,'色・塗り',clRed,[clRed,clWhite],True,nil);
    for I := 0 to Screen.FormCount-1 do
      if Screen.Forms[I].Caption = '色・塗り' then Capture(Screen.Forms[I],'paint-popup');
    CloseVectArtColorPopup(UI);
    Writeln('PASS settings UI, text/line commands, locks, appearance, 30 templates and undo/redo');
  finally Picker.Free; Creation.Free; F.Free; S.Free; H.Free; D.Free; end;
end.
