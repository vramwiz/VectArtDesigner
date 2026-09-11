// 設定カテゴリの配置と、新しいUIから既存の編集コマンドへの接続。
type TControlFontAccess = class(TControl);
procedure TVectArtObjectPropertiesControl.BuildSettingsUI;
var
  PageBody: TScrollBox;
  I: Integer;
  C: TComboBox;
  Check: TCheckBox;
  Draft: TVectArtSettingsDraft;
  RowTop, SourceLabelY, StandaloneY, StandaloneTop: Integer;
  HasRow: Boolean;
  function Panel(Category: TVectArtSettingsCategory; const Caption: string;
    out Section: TVectArtSettingsPanel): TScrollBox;
  begin
    Section := FSections.AddSection(Category,Caption);
    Result := Section;
    RowTop := 8; StandaloneY:=-1000; StandaloneTop:=8; SourceLabelY := -1000; HasRow := False;
  end;
  procedure Put(Control: TControl; X, Y, W, H: Integer);
  begin
    Control.Parent := PageBody;
    if PageBody=FInfoPanel then
    begin
      TControlFontAccess(Control).ParentFont:=True;
      Control.StyleElements:=Control.StyleElements-[seFont];
      Control.SetBounds(X,MulDiv(Y,9,10),W,MulDiv(H,9,10));
      if W>=200 then Control.Tag:=240;
      Exit;
    end;
    // ページの共通フォントを継承し、VCLスタイルによる入力欄だけの字体変更を防ぐ。
    TControlFontAccess(Control).ParentFont := True;
    Control.StyleElements := Control.StyleElements - [seFont];
    if (Control is TStaticText) then
    begin
      Control.SetBounds(X,Y,W,H);
      RowTop:=Y+H+6;
      if W>=200 then Control.Tag:=240;
    end
    else if HasRow and (Y>=SourceLabelY) and (Y<=SourceLabelY+28) then
    begin
      // 同じ項目の入力欄・ボタン群はラベル右側の1行にまとめる。
      Control.SetBounds(108+(X-12)*144 div 240,RowTop,
        Max(28,W*144 div 240),H);
      Control.Tag:=260+X;
      Control.HelpContext:=W;
      if H>40 then Inc(RowTop,H-34);
    end
    else
    begin
      if HasRow then begin Inc(RowTop,40); HasRow:=False; end;
      if StandaloneY<>Y then
      begin StandaloneY:=Y; StandaloneTop:=RowTop; Inc(RowTop,H+6); end;
      Control.SetBounds(X,StandaloneTop,W,H);
      if W>=200 then Control.Tag:=240;
    end;
    Control.Anchors := [akLeft, akTop];
  end;
  procedure LabelAt(const Caption: string; Y: Integer);
  var L: TStaticText;
  begin
    L := TStaticText.Create(Self);
    L.Parent := PageBody;
    L.AutoSize := False;
    L.ParentColor := False;
    L.Color := COLOR_BACKGROUND;
    L.Font.Color := COLOR_TEXT;
    if PageBody=FInfoPanel then
    begin
      L.Caption:=Caption; Put(L,12,Y,240,22); Exit;
    end;
    if HasRow then Inc(RowTop,40);
    HasRow:=True; SourceLabelY:=Y;
    L.Caption := Caption + '：';
    L.Hint:=Caption; L.ShowHint:=True;
    L.SetBounds(8,RowTop+4,96,32);
    L.StyleElements:=L.StyleElements-[seFont];
  end;
  procedure PendingCombo(const Caption: string; Y: Integer; const Items: array of string);
  begin
    LabelAt(Caption, Y);
    C := TComboBox.Create(Self);
    C.Parent := PageBody;
    C.Style := csDropDownList;
    C.Items.AddStrings(Items);
    C.ItemIndex := 0;
    C.Enabled := False;
    Put(C, 12, Y + 24, 240, 28);
  end;
begin
  FBuildingSettings := True;
  try
  FSections := TVectArtSettingsSections.Create(Self);
  // スライダーの子ウィンドウはフォームへ接続した後に生成する。
  FStrokeWidthEdit.Free;
  FStrokeWidthSlider := TVectArtNumericSlider.CreateForParent(Self, Self);
  FStrokeWidthSlider.Name := 'StrokeWidthSlider';
  FStrokeWidthSlider.Configure(1,10000,1,2);
  FStrokeWidthSlider.SetSliderRange(1,100);
  FStrokeWidthSlider.OnChange := NumericSettingChanged;
  FStrokeWidthEdit := FStrokeWidthSlider.Edit;
  FOpacityEdit.Free;
  FTransparencySlider := TVectArtNumericSlider.CreateForParent(Self, Self);
  FTransparencySlider.Name := 'TransparencySlider';
  FTransparencySlider.Configure(0,100,1,2);
  FTransparencySlider.OnChange := NumericSettingChanged;
  FOpacityEdit := FTransparencySlider.Edit;
  FSections.Parent := Self;
  FSections.OnChange := LayoutSettings;
  PageBody := Panel(vscInfo, '情報', FInfoPanel);
  FTypeLabel := TStaticText.Create(Self);
  FTypeLabel.AutoSize := False;
  FTypeLabel.Caption := '種類';
  Put(FTypeLabel, 12, 12, 240, 24);
  LabelAt('X',46); PageBody.Controls[PageBody.ControlCount-1].Width:=28; PageBody.Controls[PageBody.ControlCount-1].Tag:=0;
  Put(FXEdit,44,42,80,26); FXEdit.Tag:=243;
  LabelAt('Y',46); PageBody.Controls[PageBody.ControlCount-1].Tag:=245;
  Put(FYEdit,172,42,80,26); FYEdit.Tag:=244;
  LabelAt('幅',78); PageBody.Controls[PageBody.ControlCount-1].Width:=28; PageBody.Controls[PageBody.ControlCount-1].Tag:=0;
  LabelAt('高さ',78); PageBody.Controls[PageBody.ControlCount-1].Tag:=245;
  Put(FWidthEdit,44,74,80,26); FWidthEdit.Tag:=243;
  Put(FHeightEdit,172,74,80,26); FHeightEdit.Tag:=244;
  FAspectCheck := TCheckBox.Create(Self);
  FAspectCheck.Caption := '縦横比を保持';
  Put(FAspectCheck,44,106,180,26);
  LabelAt('透明度 (%)',144);
  PageBody.Controls[PageBody.ControlCount-1].Width:=80;
  PageBody.Controls[PageBody.ControlCount-1].Tag:=0;
  Put(FTransparencySlider,92,140,160,34);
  FTransparencySlider.Tag:=242;
  PageBody := Panel(vscText, '文字', FTextPanel);
  LabelAt('文字列', 12);
  FTextMemo := TMemo.Create(Self);
  FTextMemo.ScrollBars := ssVertical;
  FTextMemo.OnExit := TextSettingsChanged;
  Put(FTextMemo, 12, 36, 240, 94);
  LabelAt('フォント', 142);
  FFontCombo := TComboBox.Create(Self);
  FFontCombo.Parent := PageBody;
  FFontCombo.Style := csDropDownList;
  FFontCombo.Items.Assign(Screen.Fonts);
  FFontCombo.OnSelect := TextSettingsChanged;
  FFontCombo.OnExit := TextSettingsChanged;
  Put(FFontCombo, 12, 166, 240, 28);
  LabelAt('サイズ (pt)', 206);
  FFontSize := TEdit.Create(Self);
  FFontSize.OnExit := TextSettingsChanged;
  Put(FFontSize, 12, 230, 112, 26);
  Check := TCheckBox.Create(Self);
  Check.Caption := '自動'; Check.Hint:='準備中'; Check.ShowHint:=True; Check.Enabled := False;
  Put(Check, 140, 230, 122, 26);
  for I := 0 to 3 do
  begin
    FFontChecks[I] := TCheckBox.Create(Self);
    case I of
      0: FFontChecks[I].Caption := '太字'; 1: FFontChecks[I].Caption := '斜体';
      2: FFontChecks[I].Caption := '下線'; 3: FFontChecks[I].Caption := '取消線';
    end;
    FFontChecks[I].OnClick := TextSettingsChanged;
    Put(FFontChecks[I], 12 + (I mod 2) * 128, 270 + (I div 2) * 32, 120, 26);
  end;
  LabelAt('字間 (%)', 344); Put(FLetterSpacingEdit, 12, 368, 240, 26);
  LabelAt('行間 (%)', 406); Put(FLineSpacingEdit, 12, 430, 240, 26);
  FVerticalTextCheck.Caption := '縦書き'; Put(FVerticalTextCheck, 12, 472, 240, 26);
  PendingCombo('行揃え', 516, ['左揃え', '中央揃え', '右揃え']);
  PendingCombo('文字配置', 584, ['標準', '文字フィット', 'パス追従']);
  Check := TCheckBox.Create(Self);
  Check.Caption := 'アンチエイリアス（常時有効）';
  Check.Checked := True; Check.Enabled := False;
  Put(Check, 12, 660, 240, 26);

  PageBody := Panel(vscLine, '線', FLinePanel);
  LabelAt('線の太さ', 12); Put(FStrokeWidthSlider, 12, 36, 240, 34);
  LabelAt('線種', 78); Put(FStrokeStyleCombo, 12, 102, 240, 28);
  LabelAt('線端形状', 144);
  for I := 0 to 2 do Put(FPathLineCapButtons[TVectArtLineCap(I)], 12 + I * 80, 168, 74, 30);
  LabelAt('接合形状', 210);
  for I := 0 to 2 do Put(FPathLineJoinButtons[TVectArtLineJoin(I)], 12 + I * 80, 234, 74, 30);
  LabelAt('始点', 278);
  Put(FPathStartMarkerCombo, 12, 302, 170, 28); Put(FPathStartMarkerSizeEdit, 192, 302, 60, 28);
  LabelAt('終点', 344);
  Put(FPathEndMarkerCombo, 12, 368, 170, 28); Put(FPathEndMarkerSizeEdit, 192, 368, 60, 28);
  LabelAt('品質',390);
  Put(FPathAntiAliasButton,12,414,64,30);
  LabelAt('枠と塗り潰し', 464);
  FAppearanceMode := TComboBox.Create(Self);
  FAppearanceMode.Parent := PageBody;
  FAppearanceMode.Style := csDropDownList;
  FAppearanceMode.Items.AddStrings(['枠のみ', '塗りのみ', '枠＋塗り']);
  FAppearanceMode.OnChange := AppearanceChanged;
  Put(FAppearanceMode, 12, 488, 240, 28);

  PageBody := Panel(vscFill, '塗り色', FFillPanel);
  LabelAt('色・塗り', 12);
  FFillSwatch := TVectArtColorSwatch.Create(Self);
  FFillSwatch.OnClick := OpenColor;
  Put(FFillSwatch, 12, 38, 240, 38);
  Put(FColorEdit, 12, 90, 240, 26); FColorEdit.Visible := False;




  PageBody := Panel(vscStroke, '線の色', FStrokePanel);
  LabelAt('現在の線色', 12);
  FStrokeSwatch := TVectArtColorSwatch.Create(Self);
  FStrokeSwatch.OnClick := OpenColor;
  Put(FStrokeSwatch, 12, 38, 240, 38);
  Put(FStrokeColorEdit, 12, 90, 240, 26); FStrokeColorEdit.Visible := False;


  PageBody := Panel(vscShadow, '影', FShadowPanel);
  FShadowSettings := TVectArtShadowSettings.CreateForParent(Self, PageBody);
  FShadowSettings.Parent := PageBody; FShadowSettings.Align := alClient;
  PageBody := Panel(vscOutline, '縁取り', FOutlinePanel);
  Draft := TVectArtSettingsDraft.CreateKind(Self, PageBody, 1); Draft.Parent := PageBody; Draft.Align := alClient;
  PageBody := Panel(vscEffects, '効果', FEffectsPanel);
  Draft := TVectArtSettingsDraft.CreateKind(Self, PageBody, 2); Draft.Parent := PageBody; Draft.Align := alClient;
  FSections.ActiveSection := FInfoPanel;
  Resize;
  ApplyVectArtSettingsFont(Self);
  finally FBuildingSettings := False; end;
end;

procedure TVectArtObjectPropertiesControl.RefreshSettingsUI;
var
  IsText, Editable: Boolean;
  N, I: Integer;
  S: string;
  TextLayer: TVectArtTextLayer;
  SameSelection, Filled: Boolean;
  StrokeWidth: Single;
  CurrentFill: TVectArtFillStyle;
  Cap: TVectArtLineCap;
  Join: TVectArtLineJoin;
begin
  if FSections = nil then Exit;
  FUpdating := True;
  try
    IsText := (FDocument <> nil) and (FDocument.SelectionCount = 1) and
      (FDocument[FDocument.SelectedIndex] is TVectArtTextLayer);
    Editable := (FDocument <> nil) and (FDocument.SelectionCount = 1) and not SelectedLayersHaveLock;
    FTextPanel.Available := IsText;
    FOutlinePanel.Available := IsText;
    FEffectsPanel.Available := IsText;
    FLinePanel.Available := not IsText;
    FStrokePanel.Available := not IsText;
    FShadowSettings.Configure(FDocument,FEditHistory,FColorHistory);
    FShadowPanel.Available := not IsText;
    if (FSections.ActiveSection = nil) or not FSections.ActiveSection.Available then FSections.ActiveSection := FInfoPanel;
    if IsText then FFillPanel.Caption := '文字色' else FFillPanel.Caption := '塗り色';
    FSections.RefreshSections;
    FTypeLabel.Caption := '種類：未選択';
    if (FDocument <> nil) and (FDocument.SelectionCount > 0) then
      FTypeLabel.Caption := '種類：' + FDocument[FDocument.SelectedIndex].ClassName.Replace('TVectArt', '').Replace('Layer', '');
    FAspectCheck.Enabled := Editable and ((FDocument[FDocument.SelectedIndex] is TVectArtRectangleLayer) or IsText);
    FAppearanceMode.Enabled := False;
    FAppearanceMode.ItemIndex := -1;
    if Editable then
      if (FDocument[FDocument.SelectedIndex] is TVectArtRectangleLayer) or
        ((FDocument[FDocument.SelectedIndex] is TVectArtPathLayer) and
          TVectArtPathLayer(FDocument[FDocument.SelectedIndex]).Closed) then
      begin
        if FDocument[FDocument.SelectedIndex] is TVectArtRectangleLayer then
        begin
          Filled := TVectArtRectangleLayer(FDocument[FDocument.SelectedIndex]).Filled;
          StrokeWidth := TVectArtRectangleLayer(FDocument[FDocument.SelectedIndex]).StrokeWidth;
        end
        else
        begin
          Filled := TVectArtPathLayer(FDocument[FDocument.SelectedIndex]).Filled;
          StrokeWidth := TVectArtPathLayer(FDocument[FDocument.SelectedIndex]).StrokeWidth;
        end;
        FAppearanceMode.Enabled := True;
        if not Filled then FAppearanceMode.ItemIndex := 0
        else if StrokeWidth <= 0 then FAppearanceMode.ItemIndex := 1
        else FAppearanceMode.ItemIndex := 2;
      end;
    if not ((FDocument <> nil) and (FDocument.SelectionCount = 1) and
      ((FDocument[FDocument.SelectedIndex] is TVectArtPathLayer) or
       (FDocument[FDocument.SelectedIndex] is TVectArtLineLayer))) then
    begin
      for Cap := Low(TVectArtLineCap) to High(TVectArtLineCap) do
      begin FPathLineCapButtons[Cap].Visible := True; FPathLineCapButtons[Cap].Enabled := False; end;
      for Join := Low(TVectArtLineJoin) to High(TVectArtLineJoin) do
      begin FPathLineJoinButtons[Join].Visible := True; FPathLineJoinButtons[Join].Enabled := False; end;
      FPathAntiAliasButton.Visible := True; FPathAntiAliasButton.Enabled := False;
      FPathStartMarkerCombo.Visible := True; FPathStartMarkerCombo.Enabled := False;
      FPathEndMarkerCombo.Visible := True; FPathEndMarkerCombo.Enabled := False;
      FPathStartMarkerSizeEdit.Visible := True; FPathStartMarkerSizeEdit.Enabled := False;
      FPathEndMarkerSizeEdit.Visible := True; FPathEndMarkerSizeEdit.Enabled := False;
    end;
    if SelectedLayersHaveLock then
    begin
      for Cap := Low(TVectArtLineCap) to High(TVectArtLineCap) do FPathLineCapButtons[Cap].Enabled := False;
      for Join := Low(TVectArtLineJoin) to High(TVectArtLineJoin) do FPathLineJoinButtons[Join].Enabled := False;
      FPathAntiAliasButton.Enabled := False;
      FPathStartMarkerCombo.Enabled := False;
      FPathEndMarkerCombo.Enabled := False;
      FPathStartMarkerSizeEdit.Enabled := False;
      FPathEndMarkerSizeEdit.Enabled := False;
    end;
    FFillSwatch.Enabled := FColorEdit.Enabled;
    FStrokeSwatch.Enabled := (FDocument <> nil) and (FDocument.SelectionCount > 0) and
      (Length(GetSelectedStrokeIndices) = FDocument.SelectionCount) and not SelectedLayersHaveLock;
    S := StringReplace(FColorEdit.Text, '#', '', [rfReplaceAll]);
    FFillSwatch.Empty := not TryStrToInt('$' + S, N);
    if not FFillSwatch.Empty then FFillSwatch.Value := RGB((N shr 16) and 255, (N shr 8) and 255, N and 255);
    CurrentFill := Default(TVectArtFillStyle);
    if (FDocument <> nil) and (FDocument.SelectionCount = 1) then
    begin
      if FDocument[FDocument.SelectedIndex] is TVectArtRectangleLayer then
        CurrentFill := TVectArtRectangleLayer(FDocument[FDocument.SelectedIndex]).FillStyle
      else if FDocument[FDocument.SelectedIndex] is TVectArtPathLayer then
        CurrentFill := TVectArtPathLayer(FDocument[FDocument.SelectedIndex]).FillStyle
      else if FDocument[FDocument.SelectedIndex] is TVectArtTextLayer then
        CurrentFill := TVectArtTextLayer(FDocument[FDocument.SelectedIndex]).FillStyle;
    end;
    FFillSwatch.FillStyle := CurrentFill;
    CurrentFill := Default(TVectArtFillStyle);
    if (FDocument <> nil) and (FDocument.SelectionCount = 1) then
      CurrentFill := FDocument[FDocument.SelectedIndex].StrokePaint;
    FStrokeSwatch.FillStyle := CurrentFill;
    S := StringReplace(FStrokeColorEdit.Text, '#', '', [rfReplaceAll]);
    FStrokeSwatch.Empty := not TryStrToInt('$' + S, N);
    if not FStrokeSwatch.Empty then FStrokeSwatch.Value := RGB((N shr 16) and 255, (N shr 8) and 255, N and 255);
    if IsText then
    begin
      TextLayer := TVectArtTextLayer(FDocument[FDocument.SelectedIndex]);
      if not FTextMemo.Focused then FTextMemo.Text := TextLayer.Text;
      if FFontCombo.Items.IndexOf(TextLayer.FontFamily) < 0 then
        FFontCombo.Items.Add(TextLayer.FontFamily);
      FFontCombo.ItemIndex := FFontCombo.Items.IndexOf(TextLayer.FontFamily);
      FFontCombo.Text := TextLayer.FontFamily;
      if not FFontSize.Focused then FFontSize.Text := FloatToStr(TextLayer.FontSize);
      for I := 0 to 3 do
      begin
        FFontChecks[I].Checked := TFontStyle(I) in TextLayer.FontStyle;
        FFontChecks[I].Enabled := Editable;
      end;
      FTextMemo.Enabled := Editable; FFontCombo.Enabled := Editable; FFontSize.Enabled := Editable;
    end;
    if Length(FPopupSelection) > 0 then
    begin
      SameSelection := FDocument <> nil;
      if SameSelection then
      begin
        SameSelection := FDocument.SelectionCount = Length(FPopupSelection);
        for I in FPopupSelection do SameSelection := SameSelection and FDocument.IsLayerSelected(I);
      end;
      if not SameSelection or SelectedLayersHaveLock then
      begin CloseVectArtColorPopup(Self); FPopupSelection := nil; end;
    end;
  finally FUpdating := False; end;
  LayoutSettings(nil);
end;

procedure TVectArtObjectPropertiesControl.OpenColor(Sender: TObject);
var I: Integer; Layer: TVectArtLayer; Value: TColor; Fill: TVectArtFillStyle;
begin
  if (FDocument = nil) or SelectedLayersHaveLock then Exit;
  FPopupStroke := Sender = FStrokeSwatch;
  if FPopupStroke then Value := FStrokeSwatch.Value else Value := FFillSwatch.Value;
  FPopupSelection := FDocument.GetSelectedLayerIndices;
  if FPopupStroke and (Length(FPopupSelection) > 0) then
  begin
    for I in FPopupSelection do
      if not ((FDocument[I] is TVectArtRectangleLayer) or (FDocument[I] is TVectArtLineLayer) or
        (FDocument[I] is TVectArtPathLayer)) then Exit;
    Layer := FDocument[FPopupSelection[0]];
    Fill := Layer.StrokePaint;
    if Layer is TVectArtRectangleLayer then Value := TVectArtRectangleLayer(Layer).StrokeColor
    else if Layer is TVectArtLineLayer then Value := TVectArtLineLayer(Layer).StrokeColor
    else Value := TVectArtPathLayer(Layer).StrokeColor;
    if FEditorState <> nil then
      ShowVectArtFillPopup(Self,Value,Fill,nil,PopupStrokePaintChanged,True,
        FColorHistory,FEditorState.Color1,FEditorState.Color2)
    else
      ShowVectArtFillPopup(Self,Value,Fill,nil,PopupStrokePaintChanged,True,
        FColorHistory);
    Exit;
  end;
  if not FPopupStroke and (FDocument.SelectionCount = 1) then
  begin
    Layer := FDocument[FDocument.SelectedIndex];
    if Layer is TVectArtRectangleLayer then Fill := TVectArtRectangleLayer(Layer).FillStyle
    else if (Layer is TVectArtPathLayer) and TVectArtPathLayer(Layer).Closed then
      Fill := TVectArtPathLayer(Layer).FillStyle
    else if Layer is TVectArtTextLayer then Fill := TVectArtTextLayer(Layer).FillStyle
    else
    begin
      ShowVectArtColorPopup(Self,'色を編集',Value,nil,PopupColorChanged,
        FColorHistory);
      Exit;
    end;
    if FEditorState <> nil then
      ShowVectArtFillPopup(Self,Value,Fill,nil,PopupFillChanged,True,
        FColorHistory,FEditorState.Color1,FEditorState.Color2)
    else
      ShowVectArtFillPopup(Self,Value,Fill,nil,PopupFillChanged,True,
        FColorHistory);
  end
  else
    ShowVectArtColorPopup(Self,'色を編集',Value,nil,PopupColorChanged,
      FColorHistory);
end;

procedure TVectArtObjectPropertiesControl.PopupStrokePaintChanged(Sender: TObject; Color: TColor;
  const Fill: TVectArtFillStyle);
var Command: TVectArtCompoundCommand; I: Integer;
begin
  if (FDocument = nil) or (FDocument.SelectionCount = 0) or SelectedLayersHaveLock then Exit;
  for I in FDocument.GetSelectedLayerIndices do
    if not ((FDocument[I] is TVectArtRectangleLayer) or (FDocument[I] is TVectArtLineLayer) or
      (FDocument[I] is TVectArtPathLayer)) then Exit;
  Command := TVectArtCompoundCommand.Create;
  for I in FDocument.GetSelectedLayerIndices do
    Command.Add(TVectArtStrokePaintCommand.Create(FDocument,I,Color,Fill));
  Command.Execute;
  if FEditHistory <> nil then FEditHistory.AddApplied(Command) else Command.Free;
  RefreshFromDocument;
end;

procedure TVectArtObjectPropertiesControl.PopupFillChanged(Sender: TObject; Color: TColor;
  const Fill: TVectArtFillStyle);
var Command: TVectArtFillCommand;
begin
  if (FDocument = nil) or (FDocument.SelectionCount <> 1) or SelectedLayersHaveLock then Exit;
  Command := TVectArtFillCommand.Create(FDocument,FDocument.SelectedIndex,Color,Fill);
  Command.Execute;
  if FEditHistory <> nil then FEditHistory.AddApplied(Command) else Command.Free;
  RefreshFromDocument;
end;
procedure TVectArtObjectPropertiesControl.PopupColorChanged(Sender: TObject; Color: TColor);
var S: string;
begin
  if (FDocument = nil) or SelectedLayersHaveLock then Exit;
  Color := ColorToRGB(Color);
  S := Format('#%.2x%.2x%.2x', [GetRValue(Color), GetGValue(Color), GetBValue(Color)]);
  if FPopupStroke then begin FStrokeColorEdit.Text := S; ApplyStrokeColor; end
  else begin FColorEdit.Text := S; ApplyColor; end;
  RefreshFromDocument;
end;

procedure TVectArtObjectPropertiesControl.TextSettingsChanged(Sender: TObject);
var
  BeforeData, AfterData: TVectArtTextData;
  Size: Double;
  I: Integer;
  OldLayout, NewLayout: TVectArtTextLayout;
begin
  if FUpdating or (FDocument = nil) or (FDocument.SelectionCount <> 1) or
    SelectedLayersHaveLock or not (FDocument[FDocument.SelectedIndex] is TVectArtTextLayer) then Exit;
  if not TryStrToFloat(FFontSize.Text, Size) or (Size < 1) or (Size > 4096) then
  begin RefreshFromDocument; Exit; end;
  BeforeData := CaptureVectArtTextData(TVectArtTextLayer(FDocument[FDocument.SelectedIndex]));
  AfterData := BeforeData;
  AfterData.Text := FTextMemo.Text;
  AfterData.FontFamily := FFontCombo.Text;
  AfterData.FontSize := Size;
  AfterData.FontStyle := [];
  for I := 0 to 3 do if FFontChecks[I].Checked then Include(AfterData.FontStyle, TFontStyle(I));
  if (BeforeData.Text = AfterData.Text) and (BeforeData.FontFamily = AfterData.FontFamily) and
    SameValue(BeforeData.FontSize, AfterData.FontSize) and (BeforeData.FontStyle = AfterData.FontStyle) then Exit;
  OldLayout := BuildVectArtTextLayout(BeforeData.Text, BeforeData.FontFamily, BeforeData.FontSize,
    BeforeData.FontStyle, BeforeData.LetterSpacingRatio, BeforeData.LineSpacingRatio, BeforeData.Vertical);
  NewLayout := BuildVectArtTextLayout(AfterData.Text, AfterData.FontFamily, AfterData.FontSize,
    AfterData.FontStyle, AfterData.LetterSpacingRatio, AfterData.LineSpacingRatio, AfterData.Vertical);
  AfterData.Bounds.Right := AfterData.Bounds.Left + Max(1, NewLayout.Width * BeforeData.Bounds.Width / Max(1, OldLayout.Width));
  AfterData.Bounds.Bottom := AfterData.Bounds.Top + Max(1, NewLayout.Height * BeforeData.Bounds.Height / Max(1, OldLayout.Height));
  FDocument.SetTextData(FDocument.SelectedIndex, AfterData);
  if FEditHistory <> nil then FEditHistory.AddApplied(TVectArtTextDataCommand.Create(FDocument,
    FDocument.SelectedIndex, BeforeData, AfterData));
  RefreshFromDocument;
end;

procedure TVectArtObjectPropertiesControl.AppearanceChanged(Sender: TObject);
var Command: TVectArtAppearanceModeCommand;
begin
  if FUpdating or (FDocument = nil) or (FDocument.SelectionCount <> 1) or
    SelectedLayersHaveLock or (FAppearanceMode.ItemIndex < 0) then Exit;
  Command := TVectArtAppearanceModeCommand.Create(FDocument, FDocument.SelectedIndex,
    TVectArtRectangleMode(FAppearanceMode.ItemIndex));
  Command.Execute;
  if FEditHistory <> nil then FEditHistory.AddApplied(Command) else Command.Free;
  RefreshFromDocument;
end;
procedure TVectArtObjectPropertiesControl.LayoutSettings(Sender: TObject);
var I,J: Integer; Body: TWinControl; Control: TControl; LayoutChanged: Boolean;
begin
  if FSections = nil then Exit;
  LayoutChanged := (Sender <> nil) or (FSections.Width <> ClientWidth) or
    (FSections.Height <> Max(0,ClientHeight-34));
  FSections.SetBounds(0, 34, ClientWidth, Max(0, ClientHeight - 34));
  for I := 0 to FSections.SectionCount-1 do
    if (FSections.Sections[I] <> nil) and (FSections.Sections[I].ControlCount > 0) then
    begin
      Body := FSections.Sections[I];
      for J := 0 to Body.ControlCount-1 do
      begin
        Control := Body.Controls[J];
        if (Control.Tag>=260) and (Control.Tag<500) then
          Control.SetBounds(108+(Control.Tag-260-12)*Max(96,Body.ClientWidth-120) div 240,
            Control.Top,Max(24,Control.HelpContext*Max(96,Body.ClientWidth-120) div 240),Control.Height);
        if Control.Tag = 240 then Control.Width := Max(100,Body.ClientWidth-24);
        if Control.Tag = 242 then Control.Width := Max(40,Body.ClientWidth-Control.Left-12);
        if Control.Tag = 243 then Control.Width := Max(30,Body.ClientWidth div 2-56);
        if Control.Tag = 244 then
          Control.SetBounds(Body.ClientWidth div 2+36,Control.Top,Max(30,Body.ClientWidth div 2-48),Control.Height);
        if Control.Tag = 245 then Control.SetBounds(Body.ClientWidth div 2+4,Control.Top,32,22);
      end;
    end;
  // 色の連続変更では配置が変わらないため、ここで全子の背景を繰り返し消去しない。
  if LayoutChanged then
    for I := 0 to FSections.SectionCount - 1 do
      if (FSections.Sections[I] <> nil) and FSections.Sections[I].Visible and
        FSections.Sections[I].HandleAllocated then
        RedrawWindow(FSections.Sections[I].Handle, nil, 0,
          RDW_INVALIDATE or RDW_ERASE or RDW_ALLCHILDREN);
end;
