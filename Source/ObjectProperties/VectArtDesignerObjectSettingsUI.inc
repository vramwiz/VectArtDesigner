// 設定カテゴリの配置と、新しいUIから既存の編集コマンドへの接続。
procedure TVectArtObjectPropertiesControl.BuildSettingsUI;
var
  PageBody: TScrollBox;
  I: Integer;
  C: TComboBox;
  Check: TCheckBox;
  Draft: TVectArtSettingsDraft;
  function Page(const Caption: string; out Tab: TTabSheet): TScrollBox;
  begin
    Tab := TTabSheet.Create(Self);
    Tab.PageControl := FPages;
    Tab.Caption := Caption;
    Result := TScrollBox.Create(Self);
    Result.Parent := Tab;
    Result.Align := alClient;
    Result.BorderStyle := bsNone;
    Result.HorzScrollBar.Visible := False;
  end;
  procedure Put(Control: TControl; X, Y, W, H: Integer);
  begin
    Control.Parent := PageBody;
    Control.SetBounds(X, Y, W, H);
    if W >= 200 then Control.Tag := 240;
    Control.Anchors := [akLeft, akTop];
  end;
  procedure LabelAt(const Caption: string; Y: Integer);
  var L: TLabel;
  begin
    L := TLabel.Create(Self);
    L.Caption := Caption;
    Put(L, 12, Y, 240, 22);
  end;
  procedure PendingCombo(const Caption: string; Y: Integer; const Items: array of string);
  begin
    LabelAt(Caption + '（準備中）', Y);
    C := TComboBox.Create(Self);
    C.Parent := PageBody;
    C.Style := csDropDownList;
    C.Items.AddStrings(Items);
    C.ItemIndex := 0;
    C.Enabled := False;
    Put(C, 12, Y + 24, 240, 28);
  end;
begin
  FPages := TPageControl.Create(Self);
  FPages.Parent := Self;
  FPages.MultiLine := True;
  FPages.OnChange := LayoutSettings;
  FPages.Width := 284;
  FPages.Height := 620;
  PageBody := Page('情報', FInfoPage);
  FTypeLabel := TLabel.Create(Self);
  FTypeLabel.Caption := '種類';
  Put(FTypeLabel, 12, 12, 240, 24);
  LabelAt('位置 X / Y', 50);
  Put(FXEdit, 12, 74, 112, 26); Put(FYEdit, 140, 74, 112, 26);
  LabelAt('幅 / 高さ', 112);
  Put(FWidthEdit, 12, 136, 112, 26); Put(FHeightEdit, 140, 136, 112, 26);
  FAspectCheck := TCheckBox.Create(Self);
  FAspectCheck.Caption := '縦横比を保持';
  Put(FAspectCheck, 12, 174, 240, 26);
  LabelAt('不透明度 (%)', 218);
  Put(FOpacityEdit, 12, 242, 240, 26);

  PageBody := Page('文字', FTextPage);
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
  LabelAt('フォントサイズ', 206);
  FFontSize := TEdit.Create(Self);
  FFontSize.OnExit := TextSettingsChanged;
  Put(FFontSize, 12, 230, 112, 26);
  Check := TCheckBox.Create(Self);
  Check.Caption := '自動（準備中）'; Check.Enabled := False;
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

  PageBody := Page('線', FLinePage);
  LabelAt('線の太さ（0で枠なし）', 12); Put(FStrokeWidthEdit, 12, 36, 240, 26);
  LabelAt('線種', 78); Put(FStrokeStyleCombo, 12, 102, 240, 28);
  LabelAt('線端形状', 144);
  for I := 0 to 2 do Put(FPathLineCapButtons[TVectArtLineCap(I)], 12 + I * 80, 168, 74, 30);
  LabelAt('接合形状', 210);
  for I := 0 to 2 do Put(FPathLineJoinButtons[TVectArtLineJoin(I)], 12 + I * 80, 234, 74, 30);
  LabelAt('始点マーカー / サイズ', 278);
  Put(FPathStartMarkerCombo, 12, 302, 170, 28); Put(FPathStartMarkerSizeEdit, 192, 302, 60, 28);
  LabelAt('終点マーカー / サイズ', 344);
  Put(FPathEndMarkerCombo, 12, 368, 170, 28); Put(FPathEndMarkerSizeEdit, 192, 368, 60, 28);
  Put(FPathAntiAliasButton, 12, 414, 64, 30);
  LabelAt('枠と塗り潰し', 464);
  FAppearanceMode := TComboBox.Create(Self);
  FAppearanceMode.Parent := PageBody;
  FAppearanceMode.Style := csDropDownList;
  FAppearanceMode.Items.AddStrings(['枠のみ', '塗りのみ', '枠＋塗り']);
  FAppearanceMode.OnChange := AppearanceChanged;
  Put(FAppearanceMode, 12, 488, 240, 28);

  PageBody := Page('塗り色', FFillPage);
  LabelAt('現在の色・塗り', 12);
  FFillSwatch := TVectArtColorSwatch.Create(Self);
  FFillSwatch.OnClick := OpenColor;
  Put(FFillSwatch, 12, 38, 240, 38);
  Put(FColorEdit, 12, 90, 240, 26); FColorEdit.Visible := False;
  LabelAt('クリックして色・塗りを編集', 92);
  LabelAt('グラデーション・テクスチャは', 132);
  LabelAt('ポップアップ内でプレビューできます。', 154);

  PageBody := Page('線の色', FStrokePage);
  LabelAt('現在の線色', 12);
  FStrokeSwatch := TVectArtColorSwatch.Create(Self);
  FStrokeSwatch.OnClick := OpenColor;
  Put(FStrokeSwatch, 12, 38, 240, 38);
  Put(FStrokeColorEdit, 12, 90, 240, 26); FStrokeColorEdit.Visible := False;
  LabelAt('クリックして線色・塗りを編集', 92);

  PageBody := Page('影', FShadowPage);
  Draft := TVectArtSettingsDraft.CreateKind(Self, PageBody, 0); Draft.Parent := PageBody; Draft.Align := alClient;
  PageBody := Page('縁取り', FOutlinePage);
  Draft := TVectArtSettingsDraft.CreateKind(Self, PageBody, 1); Draft.Parent := PageBody; Draft.Align := alClient;
  PageBody := Page('効果', FEffectsPage);
  Draft := TVectArtSettingsDraft.CreateKind(Self, PageBody, 2); Draft.Parent := PageBody; Draft.Align := alClient;
  FPages.ActivePage := FInfoPage;
  Resize;
end;

procedure TVectArtObjectPropertiesControl.RefreshSettingsUI;
var
  IsText, Editable: Boolean;
  N, I: Integer;
  S: string;
  TextLayer: TVectArtTextLayer;
  SameSelection, Filled: Boolean;
  StrokeWidth: Single;
  Cap: TVectArtLineCap;
  Join: TVectArtLineJoin;
begin
  if FPages = nil then Exit;
  FUpdating := True;
  try
    IsText := (FDocument <> nil) and (FDocument.SelectionCount = 1) and
      (FDocument[FDocument.SelectedIndex] is TVectArtTextLayer);
    Editable := (FDocument <> nil) and (FDocument.SelectionCount = 1) and not SelectedLayersHaveLock;
    FTextPage.TabVisible := IsText;
    FOutlinePage.TabVisible := IsText;
    FEffectsPage.TabVisible := IsText;
    FLinePage.TabVisible := not IsText;
    FStrokePage.TabVisible := not IsText;
    FShadowPage.TabVisible := not IsText;
    if not FPages.ActivePage.TabVisible then FPages.ActivePage := FInfoPage;
    if IsText then FFillPage.Caption := '文字色' else FFillPage.Caption := '塗り色';
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
    FStrokeSwatch.Enabled := FStrokeColorEdit.Enabled;
    S := StringReplace(FColorEdit.Text, '#', '', [rfReplaceAll]);
    FFillSwatch.Empty := not TryStrToInt('$' + S, N);
    if not FFillSwatch.Empty then FFillSwatch.Value := RGB((N shr 16) and 255, (N shr 8) and 255, N and 255);
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
var Colors: TArray<TColor>; I: Integer; Layer: TVectArtLayer; Value: TColor;
begin
  if (FDocument = nil) or SelectedLayersHaveLock then Exit;
  FPopupStroke := Sender = FStrokeSwatch;
  if FPopupStroke then Value := FStrokeSwatch.Value else Value := FFillSwatch.Value;
  Colors := nil;
  for I := 1 to FDocument.LayerCount - 1 do
  begin
    Layer := FDocument[I];
    if Layer is TVectArtRectangleLayer then
      Colors := Colors + [TVectArtRectangleLayer(Layer).FillColor, TVectArtRectangleLayer(Layer).StrokeColor]
    else if Layer is TVectArtTextLayer then Colors := Colors + [TVectArtTextLayer(Layer).TextColor]
    else if Layer is TVectArtLineLayer then Colors := Colors + [TVectArtLineLayer(Layer).StrokeColor]
    else if Layer is TVectArtPathLayer then
      Colors := Colors + [TVectArtPathLayer(Layer).FillColor, TVectArtPathLayer(Layer).StrokeColor];
  end;
  FPopupSelection := FDocument.GetSelectedLayerIndices;
  ShowVectArtColorPopup(Self, '色・塗りを編集', Value, Colors, True, PopupColorChanged);
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
var I,J: Integer; Body: TWinControl; Control: TControl;
begin
  if FPages = nil then Exit;
  for I := 0 to FPages.PageCount-1 do
    if FPages.Pages[I].ControlCount > 0 then
    begin
      Body := TWinControl(FPages.Pages[I].Controls[0]);
      for J := 0 to Body.ControlCount-1 do
      begin
        Control := Body.Controls[J];
        if Control.Tag = 240 then Control.Width := Max(100,Body.ClientWidth-24);
      end;
    end;
end;
