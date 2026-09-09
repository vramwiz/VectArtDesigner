// 設定カテゴリの配置と、新しいUIから既存の編集コマンドへの接続。
type TControlFontAccess = class(TControl);
procedure TVectArtObjectPropertiesControl.BuildSettingsUI;
var
  PageBody: TScrollBox;
  I: Integer;
  C: TComboBox;
  Check: TCheckBox;
  Draft: TVectArtSettingsDraft;
  LastLabel: TStaticText;
  function Page(const Caption: string; out Tab: TTabSheet): TScrollBox;
  begin
    Tab := TTabSheet.Create(Self);
    Tab.PageControl := FPages;
    Tab.Caption := Caption;
    Tab.ParentDoubleBuffered := False;
    Tab.DoubleBuffered := False;
    Result := TScrollBox.Create(Self);
    Result.Parent := Tab;
    Result.Align := alClient;
    Result.Font.Assign(Font);
    Result.Font.Height := -13;
    Result.BorderStyle := bsNone;
    Result.ParentBackground := False;
    Result.Color := COLOR_BACKGROUND;
    Result.ParentDoubleBuffered := False;
    Result.DoubleBuffered := False;
    Result.HorzScrollBar.Visible := False;
  end;
  procedure Put(Control: TControl; X, Y, W, H: Integer);
  begin
    Control.Parent := PageBody;
    // Use the same inherited font as the draft pages; prevent the VCL style
    // from substituting its own font for native static labels and edits.
    TControlFontAccess(Control).ParentFont := True;
    Control.StyleElements := Control.StyleElements - [seFont];
    Control.SetBounds(X, MulDiv(Y, 9, 10), W, MulDiv(H, 9, 10));
    if W >= 200 then Control.Tag := 240;
    Control.Anchors := [akLeft, akTop];
  end;
  procedure LabelAt(const Caption: string; Y: Integer);
  var L: TStaticText;
  begin
    L := TStaticText.Create(Self);
    LastLabel := L;
    L.AutoSize := False;
    L.ParentColor := False;
    L.Color := COLOR_BACKGROUND;
    L.Font.Color := COLOR_TEXT;
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
  FPages.ParentDoubleBuffered := False;
  FPages.DoubleBuffered := False;
  FPages.MultiLine := True;
  FPages.OnChange := LayoutSettings;
  FPages.Width := 284;
  FPages.Height := 620;
  PageBody := Page('情報', FInfoPage);
  FTypeLabel := TStaticText.Create(Self);
  FTypeLabel.AutoSize := False;
  FTypeLabel.Caption := '種類';
  Put(FTypeLabel, 12, 12, 240, 24);
  LabelAt('位置・サイズ (px)', 42);
  LabelAt('X', 76); LastLabel.Tag := 0; LastLabel.Width := 96;
  Put(FXEdit, 44, 72, 80, 26); FXEdit.Tag := 243;
  LabelAt('Y', 76); LastLabel.Tag := 245;
  Put(FYEdit, 172, 72, 80, 26); FYEdit.Tag := 244;
  LabelAt('幅', 108); LastLabel.Tag := 0; LastLabel.Width := 96;
  Put(FWidthEdit, 44, 104, 80, 26); FWidthEdit.Tag := 243;
  LabelAt('高さ', 108); LastLabel.Tag := 245;
  Put(FHeightEdit, 172, 104, 80, 26); FHeightEdit.Tag := 244;
  FAspectCheck := TCheckBox.Create(Self);
  FAspectCheck.Caption := '縦横比を保持';
  Put(FAspectCheck, 44, 136, 180, 26);
  LabelAt('不透明度 (%)', 174); LastLabel.Tag := 0; LastLabel.Width := 96;
  Put(FOpacityEdit, 112, 170, 140, 26); FOpacityEdit.Tag := 242;
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
  LabelAt('閉じた図形の塗りに対応', 132);
  LabelAt('変更は図形へ即時反映します。', 154);

  PageBody := Page('線の色', FStrokePage);
  LabelAt('現在の線色', 12);
  FStrokeSwatch := TVectArtColorSwatch.Create(Self);
  FStrokeSwatch.OnClick := OpenColor;
  Put(FStrokeSwatch, 12, 38, 240, 38);
  Put(FStrokeColorEdit, 12, 90, 240, 26); FStrokeColorEdit.Visible := False;
  LabelAt('クリックして線色・塗りを編集', 92);

  PageBody := Page('影', FShadowPage);
  FShadowSettings := TVectArtShadowSettings.Create(Self);
  FShadowSettings.Parent := PageBody; FShadowSettings.Align := alClient;
  PageBody := Page('縁取り', FOutlinePage);
  Draft := TVectArtSettingsDraft.CreateKind(Self, PageBody, 1); Draft.Parent := PageBody; Draft.Align := alClient;
  PageBody := Page('効果', FEffectsPage);
  Draft := TVectArtSettingsDraft.CreateKind(Self, PageBody, 2); Draft.Parent := PageBody; Draft.Align := alClient;
  FLinePage.PageIndex := 0;
  FStrokePage.PageIndex := 1;
  FFillPage.PageIndex := 2;
  FShadowPage.PageIndex := 3;
  FInfoPage.PageIndex := 4;
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
  CurrentFill: TVectArtFillStyle;
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
    FShadowSettings.Configure(FDocument,FEditHistory);
    FShadowPage.TabVisible := not IsText;
    if (FPages.ActivePage = nil) or not FPages.ActivePage.TabVisible then FPages.ActivePage := FInfoPage;
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
var Colors: TArray<TColor>; I: Integer; Layer: TVectArtLayer; Value: TColor; Fill: TVectArtFillStyle;
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
    ShowVectArtFillPopup(Self,Value,Fill,Colors,PopupStrokePaintChanged);
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
    begin ShowVectArtColorPopup(Self,'色を編集',Value,Colors,PopupColorChanged); Exit; end;
    ShowVectArtFillPopup(Self,Value,Fill,Colors,PopupFillChanged);
  end
  else ShowVectArtColorPopup(Self,'色を編集',Value,Colors,PopupColorChanged);
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
  if FPages = nil then Exit;
  LayoutChanged := (Sender <> nil) or (FPages.Width <> ClientWidth) or
    (FPages.Height <> Max(0,ClientHeight-34));
  FPages.SetBounds(0, 34, ClientWidth, Max(0, ClientHeight - 34));
  for I := 0 to FPages.PageCount-1 do
    if FPages.Pages[I].ControlCount > 0 then
    begin
      Body := TWinControl(FPages.Pages[I].Controls[0]);
      for J := 0 to Body.ControlCount-1 do
      begin
        Control := Body.Controls[J];
        if Control.Tag = 240 then Control.Width := Max(100,Body.ClientWidth-24);
        if Control.Tag = 242 then Control.Width := Max(40,Body.ClientWidth-Control.Left-12);
        if Control.Tag = 243 then Control.Width := Max(30,Body.ClientWidth div 2-56);
        if Control.Tag = 244 then
          Control.SetBounds(Body.ClientWidth div 2+36,Control.Top,Max(30,Body.ClientWidth div 2-48),Control.Height);
        if Control.Tag = 245 then Control.SetBounds(Body.ClientWidth div 2+4,Control.Top,32,22);
      end;
    end;
  // Color notifications do not change layout and must not erase every child.
  if LayoutChanged and (FPages.ActivePage <> nil) and FPages.ActivePage.HandleAllocated then
    RedrawWindow(FPages.ActivePage.Handle, nil, 0,
      RDW_INVALIDATE or RDW_ERASE or RDW_ALLCHILDREN);
end;
