// 単色専用と線・塗り・文字のペイント設定で、色表示・使用色・編集窓を共有する。
// 適用先への変更通知だけを行い、Documentの更新とUndoは呼び出し側に委ねる。
// 内蔵パターンは操作中の軽量プレビューと確定後の保存画像をここで切り替える。
unit VectArtDesignerPaintPopup;

interface

uses
  System.Classes, System.Types, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Graphics, Vcl.Grids, VectArtDesignerColorHistory,
  VectArtDesignerDocument;

type
  TVectArtFillChanged = procedure(Sender: TObject; Color: TColor; const Fill: TVectArtFillStyle) of object;
  TVectArtColorChanged = procedure(Sender: TObject; Color: TColor) of object;
procedure ShowVectArtColorPopup(Target: TComponent; const Title: string;
  Color: TColor; const UsedColors: TArray<TColor>;
  OnChanged: TVectArtColorChanged;
  ColorHistory: TVectArtColorHistory = nil);
procedure ShowVectArtFillPopup(Target: TComponent; Color: TColor;
  const Fill: TVectArtFillStyle; const UsedColors: TArray<TColor>;
  OnChanged: TVectArtFillChanged; AllowTexture: Boolean = True;
  ColorHistory: TVectArtColorHistory = nil;
  PatternColor1: TColor = clNone; PatternColor2: TColor = clNone);
procedure CloseVectArtColorPopup(Target: TComponent);

implementation

uses VectArtDesignerSettingsFont,
  System.SysUtils, System.Math, System.UITypes, Winapi.Windows,
  Vcl.Dialogs, VectArtDesignerNumericSlider, ColorPickerHueBar,
  ColorPickerSVArea, ColorPickerColorMath, VectArtDesignerTextureImage,
  VectArtDesignerPaintPreview, VectArtDesignerColorSwatch,
  VectArtDesignerPatternTiles;

type
  TVectArtPaintPopup = class(TForm)
  private
    FTarget: TComponent;
    FChanged: TVectArtColorChanged;
    FFillChanged: TVectArtFillChanged;
    FTexturePng: TBytes;

    FMode, FGradient: TComboBox;
    FSlot1, FSlot2: TRadioButton;
    FAngle, FWaveCount: TVectArtNumericSlider;
    FAngleLabel, FWaveCountLabel, FPaletteLabel: TLabel;
    FAllowPaint: Boolean;
    FAngleValue, FWaveCountValue: Integer;
    FPreview: TPaintBox;
    FPreviewBitmap: Vcl.Graphics.TBitmap;
    FPreviewDirty: Boolean;
    FPalette: TDrawGrid;
    FSelectedColor: Integer;
    FSwatch1, FSwatch2: TShape;
    FHue: TColorPickerHueBar;
    FSV: TColorPickerSVArea;
    FTextureButton: TButton;
    FTexturePattern: TComboBox;
    FPatternLabels: TArray<TLabel>;
    FPatternSliders: TArray<TVectArtNumericSlider>;
    FPatternSettings: TVectArtPatternSettings;
    FTexture: TPicture;
    FColors: TArray<TColor>;
    FColorHistory: TVectArtColorHistory;
    FColor1, FColor2: TColor;
    FPatternColor1, FPatternColor2: TColor;
    FHistoryPending: Boolean;
    FHistoryPendingColor: TColor;
    FHistoryPendingSlot: Integer;
    FUpdating, FPicking: Boolean;
    FTexturePatternKind: Integer;
    FPatternCommitPending: Boolean;
    FPatternCommitTimer: TTimer;
    procedure PickerChanged(Sender: TObject);
    procedure CommitFill;
    procedure ApplyTexturePattern(Sender: TObject);
    procedure PatternParameterChanged(Sender: TObject);
    procedure PatternParameterMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PatternCommitTimer(Sender: TObject);
    procedure CommitPendingPattern;
    procedure UpdatePatternPreview;
    procedure SyncPatternControls(var Y: Integer);
    procedure RegeneratePattern;
    procedure LoadTextureBytes(const Bytes: TBytes);
    procedure EditAngle(Sender: TObject);
    procedure EditWaveCount(Sender: TObject);
    procedure Changed(Sender: TObject);
    procedure DrawPreview(Sender: TObject);
    procedure DrawColor(Sender: TObject; ACol, ARow: Longint;
      Rect: TRect; State: TGridDrawState);
    procedure PickColor(Sender: TObject; ACol, ARow: Longint; var CanSelect: Boolean);
    procedure LoadTexture(Sender: TObject);
    procedure ApplyColor(Color: TColor);
    procedure BuildPaletteColors(const AdditionalColors: TArray<TColor>);
    procedure CommitPendingColor;
    procedure PopupDeactivate(Sender: TObject);
    procedure Sync;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  Popup: TVectArtPaintPopup;

const
  BASIC_COLORS: array[0..15] of TColor = (clBlack, clWhite, clRed, clYellow,
    clLime, clAqua, clBlue, clFuchsia, clGray, clSilver, clMaroon, clOlive,
    clGreen, clTeal, clNavy, clPurple);

constructor TVectArtPaintPopup.Create(AOwner: TComponent);
var I: Integer;

  procedure DarkCombo(Combo: TComboBox);
  begin
    Combo.Color := TColor($00303030);
    Combo.Font.Color := TColor($00EEEEEE);
    Combo.StyleElements := Combo.StyleElements - [seFont];
  end;
begin
  inherited CreateNew(AOwner);
  BorderStyle := bsToolWindow;
  DoubleBuffered := True;
  Position := poScreenCenter;
  OnDeactivate := PopupDeactivate;
  ClientWidth := 370;
  ClientHeight := 466;
  Color := TColor($00181818);
  Font.Name := VECTART_SETTINGS_FONT_NAME;
  Font.Height := VECTART_SETTINGS_FONT_HEIGHT;
  Font.Color := TColor($00EEEEEE);
  FTexture := TPicture.Create;
  FPatternCommitTimer := TTimer.Create(Self);
  FPatternCommitTimer.Enabled := False;
  FPatternCommitTimer.Interval := 150;
  FPatternCommitTimer.OnTimer := PatternCommitTimer;
  FPreviewBitmap := Vcl.Graphics.TBitmap.Create;
  FPreviewBitmap.PixelFormat := pf32bit;
  FPreviewDirty := True;
  FMode := TComboBox.Create(Self);
  FMode.Parent := Self;
  FMode.Style := csDropDownList;
  FMode.Items.AddStrings(['ベタ', 'グラデーション', 'テクスチャ']);
  FMode.SetBounds(16, 94, 338, 28);
  FMode.ItemIndex := 0;
  FMode.OnChange := Changed;
  DarkCombo(FMode);
  FPreview := TPaintBox.Create(Self);
  FPreview.Parent := Self;
  FPreview.SetBounds(16, 16, 338, 68);
  FPreview.OnPaint := DrawPreview;
  FGradient := TComboBox.Create(Self);
  FGradient.Parent := Self;
  FGradient.Name := 'GradientKindCombo';
  FGradient.Style := csDropDownList;
  FGradient.Items.AddStrings(['線形', '放射', '円形', '角形', '波状', 'スペクトル']);
  FGradient.ItemIndex := 0;
  FGradient.SetBounds(16, 132, 172, 28);
  FGradient.OnChange := Changed;
  DarkCombo(FGradient);
  FAngleLabel := TLabel.Create(Self);
  FAngleLabel.Parent := Self;
  FAngleLabel.Caption := '角度（°）';
  FAngleLabel.SetBounds(196,138,66,20);
  FAngle := TVectArtNumericSlider.CreateForParent(Self,Self);
  FAngle.Name := 'GradientAngleSlider';
  FAngle.Configure(0,359,1,0);
  FAngle.TrackBar.LargeChange := 15;
  FAngle.OnChange := EditAngle;
  FWaveCountLabel := TLabel.Create(Self);
  FWaveCountLabel.Parent := Self;
  FWaveCountLabel.Caption := '繰り返し';
  FWaveCount := TVectArtNumericSlider.CreateForParent(Self,Self);
  FWaveCount.Name := 'GradientWaveCountSlider';
  FWaveCount.Configure(0,100,1,0);
  FWaveCount.SetSliderRange(0,20);
  FWaveCount.OnChange := EditWaveCount;
  FWaveCountValue := 5;
  FTextureButton := TButton.Create(Self);
  FTextureButton.Parent := Self;
  FTextureButton.Caption := 'テクスチャ画像を選択…';
  FTextureButton.SetBounds(16, 132, 338, 28);
  FTextureButton.OnClick := LoadTexture;
  FTexturePattern := TComboBox.Create(Self);
  FTexturePattern.Parent := Self;
  FTexturePattern.Name := 'TexturePatternCombo';
  FTexturePattern.Style := csDropDownList;
  FTexturePattern.Items.Add('画像');
  FTexturePattern.Items.AddStrings(VECTART_PATTERN_NAMES);
  FTexturePattern.ItemIndex := 0;
  FTexturePattern.OnChange := ApplyTexturePattern;
  DarkCombo(FTexturePattern);
  FTexturePatternKind := 0;
  FPatternSettings := DefaultVectArtPatternSettings(vpkHatch);
  SetLength(FPatternLabels, 7);
  SetLength(FPatternSliders, 7);
  for I := 0 to High(FPatternSliders) do
  begin
    FPatternLabels[I] := TLabel.Create(Self);
    FPatternLabels[I].Parent := Self;
    FPatternLabels[I].AutoSize := False;
    FPatternLabels[I].Font.Color := TColor($00EEEEEE);
    FPatternSliders[I] := TVectArtNumericSlider.CreateForParent(Self, Self);
    FPatternSliders[I].Name := 'PatternParameterSlider' + IntToStr(I);
    FPatternSliders[I].OnChange := PatternParameterChanged;
    FPatternSliders[I].TrackBar.OnMouseUp := PatternParameterMouseUp;
  end;
  // スタイル付きグループ枠の内部余白で文字が切れないよう、独立した選択ボタンにする。
  FSlot1 := TRadioButton.Create(Self);
  FSlot1.Parent := Self;
  FSlot1.Name := 'ColorSlot1';
  FSlot1.Caption := '色1';
  FSlot1.SetBounds(24,166,154,26);
  FSlot1.Checked := True;
  FSlot1.OnClick := Changed;
  FSlot1.Font.Color := TColor($00EEEEEE);
  FSlot1.StyleElements := FSlot1.StyleElements - [seFont];
  FSlot2 := TRadioButton.Create(Self);
  FSlot2.Parent := Self;
  FSlot2.Name := 'ColorSlot2';
  FSlot2.Caption := '色2';
  FSlot2.SetBounds(188,166,154,26);
  FSlot2.OnClick := Changed;
  FSlot2.Font.Color := TColor($00EEEEEE);
  FSlot2.StyleElements := FSlot2.StyleElements - [seFont];
  FPaletteLabel := TLabel.Create(Self);
  FPaletteLabel.Parent := Self;
  FPaletteLabel.Caption := '最近使用した色／基本色';
  FPaletteLabel.Font.Color := TColor($00EEEEEE);
  FPalette := TDrawGrid.Create(Self);
  FPalette.Parent := Self;
  FPalette.SetBounds(16, 342, 338, 108);
  FPalette.FixedCols := 0;
  FPalette.FixedRows := 0;
  FPalette.ColCount := 10;
  FPalette.RowCount := 3;
  FPalette.DefaultColWidth := 31;
  FPalette.DefaultRowHeight := 31;
  FPalette.DefaultDrawing := False;
  FPalette.OnDrawCell := DrawColor;
  FPalette.OnSelectCell := PickColor;
  FSwatch1 := TShape.Create(Self); FSwatch1.Parent := Self;
  FSwatch2 := TShape.Create(Self); FSwatch2.Parent := Self;
  FHue := TColorPickerHueBar.Create(Self); FHue.Parent := Self;
  FHue.Name := 'HuePicker'; FHue.OnChange := PickerChanged;
  FSV := TColorPickerSVArea.Create(Self); FSV.Parent := Self;
  FSV.Name := 'SVPicker'; FSV.OnChange := PickerChanged;

  ApplyVectArtSettingsFont(Self);
  // 種類名を他の設定文字より2px大きくし、下側が欠けない高さを確保する。
  FTexturePattern.Font.Height := Font.Height - 2;
end;

destructor TVectArtPaintPopup.Destroy;
begin
  FPatternCommitPending := False;
  FPatternCommitTimer.Enabled := False;
  // Applicationが先にこのフォームを破棄しても、主画面の終了処理へ参照を残さない。
  if Popup = Self then Popup := nil;
  FChanged := nil;
  FFillChanged := nil;
  FColorHistory := nil;
  if FTarget <> nil then FTarget.RemoveFreeNotification(Self);
  FTarget := nil;
  FPreviewBitmap.Free;
  FTexture.Free;
  inherited;
end;

procedure TVectArtPaintPopup.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FTarget) then
  begin
    FPatternCommitPending := False;
    FPatternCommitTimer.Enabled := False;
    CommitPendingColor;
    FTarget := nil;
    FChanged := nil;
    FFillChanged := nil;
    if not (csDestroying in ComponentState) then Hide;
  end;
end;

procedure TVectArtPaintPopup.BuildPaletteColors(
  const AdditionalColors: TArray<TColor>);
var
  Candidate: TColor;
  HistoryColors: TArray<TColor>;

  procedure AppendUnique(Color: TColor);
  var
    Existing: TColor;
    Found: Boolean;
  begin
    Color := ColorToRGB(Color);
    Found := False;
    for Existing in FColors do
      if ColorToRGB(Existing) = Color then
      begin
        Found := True;
        Break;
      end;
    if not Found then
      FColors := FColors + [Color];
  end;

begin
  FColors := nil;
  if FColorHistory <> nil then
  begin
    HistoryColors := FColorHistory.Colors;
    for Candidate in HistoryColors do
      AppendUnique(Candidate);
  end;
  for Candidate in AdditionalColors do
    AppendUnique(Candidate);
  for Candidate in BASIC_COLORS do
    AppendUnique(Candidate);
  FPalette.RowCount := Max(3, (Length(FColors) + FPalette.ColCount - 1) div
    FPalette.ColCount);
end;

procedure TVectArtPaintPopup.CommitPendingColor;
begin
  if not FHistoryPending then
    Exit;
  if FColorHistory <> nil then
  begin
    FColorHistory.Add(FHistoryPendingColor);
    BuildPaletteColors(nil);
    FPalette.Invalidate;
  end;
  FHistoryPending := False;
  FHistoryPendingSlot := 0;
end;

procedure TVectArtPaintPopup.PopupDeactivate(Sender: TObject);
begin
  // HSV操作中の中間色は捨て、操作を終えた時点の色だけを履歴へ確定する。
  CommitPendingColor;
  CommitPendingPattern;
end;

procedure TVectArtPaintPopup.Sync;
var Y,I,PaletteHeight: Integer; C: TColor; PatternMode, ColorControls: Boolean;
begin
  FUpdating := True;
  try
    if not FAllowPaint then FMode.ItemIndex := 0;
    Y := 94;
    FMode.Visible := FAllowPaint;
    if FAllowPaint then
    begin FMode.SetBounds(16,Y,338,28); Inc(Y,38); end;
    FGradient.Visible := FMode.ItemIndex = 1;
    FAngle.Visible := FGradient.Visible and (FGradient.ItemIndex in [0,5]);
    FAngleLabel.Visible := FAngle.Visible;
    FWaveCount.Visible := FGradient.Visible and (FGradient.ItemIndex = 4);
    FWaveCountLabel.Visible := FWaveCount.Visible;
    FSlot1.Visible := FGradient.Visible;
    FSlot2.Visible := FGradient.Visible and (FGradient.ItemIndex <> 5);
    if FGradient.ItemIndex = 5 then FSlot1.Checked := True;
    if FGradient.Visible then
    begin
      FGradient.SetBounds(16,Y,338,28); Inc(Y,38);
      if FAngle.Visible then
      begin
        FAngleLabel.SetBounds(16,Y+5,80,20);
        FAngle.SetBounds(84,Y,270,30); Inc(Y,38);
      end;
      if FWaveCount.Visible then
      begin
        FWaveCountLabel.SetBounds(16,Y+5,68,20);
        FWaveCount.SetBounds(84,Y,270,30); Inc(Y,38);
      end;
      FSlot1.SetBounds(24,Y,60,26); FSlot2.SetBounds(188,Y,60,26);
      FSwatch1.SetBounds(92,Y+2,70,22); FSwatch2.SetBounds(256,Y+2,70,22);
      Inc(Y,36);
    end;
    FSwatch1.Visible := FSlot1.Visible; FSwatch2.Visible := FSlot2.Visible;
    FSwatch1.Brush.Color := FColor1; FSwatch2.Brush.Color := FColor2;
    FAngle.SetDisplay(((FAngleValue mod 360)+360) mod 360);
    FWaveCount.SetDisplay(FWaveCountValue);
    PatternMode := (FMode.ItemIndex = 2) and (FTexturePattern.ItemIndex > 0);
    ColorControls := (FMode.ItemIndex <> 2) or PatternMode;
    FTextureButton.Visible := (FMode.ItemIndex = 2) and not PatternMode;
    FTexturePattern.Visible := FMode.ItemIndex = 2;
    FTextureButton.Enabled := FTextureButton.Visible;
    if FTexturePattern.Visible then
    begin
      FTexturePattern.SetBounds(16,Y,338,32);
      Inc(Y,42);
      if FTextureButton.Visible then
      begin
        FTextureButton.SetBounds(16,Y,338,28);
        Inc(Y,38);
      end;
      if PatternMode then
        SyncPatternControls(Y);
    end;
    FPaletteLabel.SetBounds(16,Y,338,20); Inc(Y,24);
    PaletteHeight := FPalette.RowCount * FPalette.DefaultRowHeight + 4;
    if PatternMode then
    begin
      Dec(Y,24);
      PaletteHeight := 0;
    end;
    FPalette.SetBounds(16,Y,338,PaletteHeight);
    FPalette.Enabled := FMode.ItemIndex <> 2;
    FPalette.Visible := FPalette.Enabled; FPaletteLabel.Visible := FPalette.Enabled;
    FSV.SetBounds(16,Y+PaletteHeight+12,302,160);
    FHue.SetBounds(330,Y+PaletteHeight+12,24,160);
    FSV.Visible := ColorControls; FHue.Visible := ColorControls;
    C := FColor1;
    if ((FMode.ItemIndex = 1) or ((FMode.ItemIndex = 2) and
      not FTextureButton.Enabled)) and FSlot2.Checked then C := FColor2;
    FSelectedColor := -1;
    for I := 0 to High(FColors) do
      if ColorToRGB(FColors[I]) = ColorToRGB(C) then
      begin FSelectedColor := I; Break; end;
    if FSelectedColor >= 0 then
    begin FPalette.Col := FSelectedColor mod 10; FPalette.Row := FSelectedColor div 10; end;
    FPalette.Tag := FSelectedColor;
    // 操作中のRGB丸め誤差をHSVへ戻すと色相が揺れるため、ピッカーへ再同期しない。
    if not FPicking then
    begin FHue.Color := C; FSV.BaseColor := C; FSV.Color := C; end;
    if (FMode.ItemIndex = 2) and FTextureButton.Enabled then
    begin
      if FTextureButton.Visible then
        ClientHeight := FTextureButton.Top + FTextureButton.Height + 16
      else
        ClientHeight := FTexturePattern.Top + FTexturePattern.Height + 16;
    end
    else
      ClientHeight := Y+PaletteHeight+12+160+16;
    FPreviewDirty := True;
    FPreview.Invalidate; FPalette.Invalidate;
  finally FUpdating := False; end;
end;

procedure TVectArtPaintPopup.SyncPatternControls(var Y: Integer);
var I, Count: Integer;

  procedure AddParameter(const Caption: string; Tag: Integer;
    Minimum, Maximum, Value: Single);
  begin
    FPatternLabels[Count].Caption := Caption;
    FPatternLabels[Count].Tag := Tag;
    FPatternLabels[Count].SetBounds(16, Y + 5, 68, 20);
    FPatternLabels[Count].Visible := True;
    FPatternSliders[Count].Tag := Tag;
    FPatternSliders[Count].Configure(Minimum, Maximum, 0.1, 1);
    FPatternSliders[Count].SetDisplay(Value);
    FPatternSliders[Count].SetBounds(84, Y, 270, 30);
    FPatternSliders[Count].Visible := True;
    Inc(Count);
    Inc(Y, 34);
  end;

begin
  for I := 0 to High(FPatternSliders) do
  begin
    FPatternLabels[I].Visible := False;
    FPatternSliders[I].Visible := False;
  end;
  FSlot1.Caption := '線の色';
  if FPatternSettings.Kind = vpkDots then FSlot1.Caption := '点の色'
  else if FPatternSettings.Kind = vpkChecker then FSlot1.Caption := '前景色';
  FSlot2.Caption := '背景色';
  FSlot1.Visible := True;
  FSlot2.Visible := True;
  FSwatch1.Visible := True;
  FSwatch2.Visible := True;
  FSlot1.SetBounds(24,Y,72,26); FSlot2.SetBounds(188,Y,72,26);
  FSwatch1.SetBounds(100,Y+2,62,22); FSwatch2.SetBounds(264,Y+2,62,22);
  Inc(Y,36);
  Count := 0;
  case FPatternSettings.Kind of
    vpkHatch:
      begin AddParameter('線幅', 1, 0.1, 64, FPatternSettings.Width);
        AddParameter('間隔', 2, 1, 256, FPatternSettings.Spacing); end;
    vpkDots:
      begin AddParameter('点サイズ', 4, 0.1, 128, FPatternSettings.Size);
        AddParameter('間隔', 2, 1, 256, FPatternSettings.Spacing); end;
    vpkGrid:
      begin AddParameter('線幅', 1, 0.1, 64, FPatternSettings.Width);
        AddParameter('横間隔', 2, 1, 256, FPatternSettings.Spacing);
        AddParameter('縦間隔', 3, 1, 256, FPatternSettings.SpacingY); end;
    vpkChecker: AddParameter('マスサイズ', 4, 1, 128, FPatternSettings.Size);
    vpkWave:
      begin AddParameter('線幅', 1, 0.1, 64, FPatternSettings.Width);
        AddParameter('振幅', 5, 0.1, 128, FPatternSettings.Amplitude);
        AddParameter('周期', 6, 1, 256, FPatternSettings.Period);
        AddParameter('行間隔', 3, 1, 256, FPatternSettings.SpacingY); end;
    vpkHoneycomb:
      begin AddParameter('六角半径', 4, 1, 128, FPatternSettings.Size);
        AddParameter('線幅', 1, 0.1, 64, FPatternSettings.Width);
        AddParameter('間隔', 2, 0, 128, FPatternSettings.Spacing); end;
  end;
  AddParameter('角度', 7, -180, 180, FPatternSettings.Angle);
  AddParameter('横移動', 8, -256, 256, FPatternSettings.OffsetX);
  AddParameter('縦移動', 9, -256, 256, FPatternSettings.OffsetY);
end;
procedure TVectArtPaintPopup.Changed(Sender: TObject);
begin
  if FUpdating then Exit;
  CommitPendingPattern;
  if (Sender = FSlot1) or (Sender = FSlot2) or (Sender = FMode) or
    (Sender = FGradient) then
    CommitPendingColor;
  if (Sender = FMode) or (Sender = FGradient) then CommitFill;
  Sync;
end;

procedure TVectArtPaintPopup.LoadTextureBytes(const Bytes: TBytes);
var Stream: TBytesStream;
begin
  FTexturePng := Copy(Bytes);
  if Length(FTexturePng) = 0 then
  begin
    FTexture.Assign(nil);
    Exit;
  end;
  Stream := TBytesStream.Create(FTexturePng);
  try
    FTexture.LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TVectArtPaintPopup.RegeneratePattern;
begin
  FTexturePng := CreateVectArtPatternPng(FPatternSettings,
    FColor1, FColor2, 255);
  UpdatePatternPreview;
end;

procedure TVectArtPaintPopup.UpdatePatternPreview;
var PreviewBytes: TBytes; Stream: TBytesStream;
begin
  PreviewBytes := CreateVectArtPatternPreviewPng(FPatternSettings,
    FColor1, FColor2, Max(FPreview.Width, 1), Max(FPreview.Height, 1), 255);
  Stream := TBytesStream.Create(PreviewBytes);
  try
    FTexture.LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TVectArtPaintPopup.CommitPendingPattern;
begin
  if not FPatternCommitPending then
    Exit;
  FPatternCommitTimer.Enabled := False;
  FPatternCommitPending := False;
  FTexturePng := CreateVectArtPatternPng(FPatternSettings,
    FColor1, FColor2, 255);
  CommitFill;
end;

procedure TVectArtPaintPopup.PatternCommitTimer(Sender: TObject);
var I: Integer;
begin
  FPatternCommitTimer.Enabled := False;
  // ドラッグ中の休止を操作終了と誤認せず、512px画像とUndoを途中生成しない。
  for I := 0 to High(FPatternSliders) do
    if GetCapture = FPatternSliders[I].TrackBar.Handle then
    begin
      FPatternCommitTimer.Enabled := True;
      Exit;
    end;
  CommitPendingPattern;
end;

procedure TVectArtPaintPopup.PatternParameterMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  // 最終座標はTrackBar側ですでに反映済みなので、マウス解放時に一度だけ確定する。
  if Button = mbLeft then
    CommitPendingPattern;
end;

procedure TVectArtPaintPopup.ApplyTexturePattern(Sender: TObject);
begin
  if FUpdating or not Visible then Exit;
  CommitPendingPattern;
  FTexturePatternKind := FTexturePattern.ItemIndex;
  if FTexturePatternKind > 0 then
  begin
    FColor1 := FPatternColor1;
    FColor2 := FPatternColor2;
    FPatternSettings := DefaultVectArtPatternSettings(
      TVectArtPatternKind(FTexturePatternKind - 1));
    RegeneratePattern;
  end
  else
  begin
    FTexturePng := nil;
    FTexture.Assign(nil);
  end;
  FPreviewDirty := True;
  if Assigned(FFillChanged) then CommitFill;
  Sync;
end;

procedure TVectArtPaintPopup.PatternParameterChanged(Sender: TObject);
var Slider: TVectArtNumericSlider;
begin
  if FUpdating or not Visible then Exit;
  Slider := TVectArtNumericSlider(Sender);
  case Slider.Tag of
    1: FPatternSettings.Width := Slider.Value;
    2: FPatternSettings.Spacing := Slider.Value;
    3: FPatternSettings.SpacingY := Slider.Value;
    4: FPatternSettings.Size := Slider.Value;
    5: FPatternSettings.Amplitude := Slider.Value;
    6: FPatternSettings.Period := Slider.Value;
    7: FPatternSettings.Angle := Slider.Value;
    8: FPatternSettings.OffsetX := Slider.Value;
    9: FPatternSettings.OffsetY := Slider.Value;
  end;
  // 操作中は小さな表示用画像だけを更新し、512px画像の生成、Document更新、
  // Undo追加はマウスを離した時点または連続入力が止まった後へ集約する。
  UpdatePatternPreview;
  FPreviewDirty := True;
  FPreview.Invalidate;
  FPatternCommitPending := True;
  FPatternCommitTimer.Enabled := False;
  FPatternCommitTimer.Enabled := True;
  // 数値欄の確定は連続ドラッグではないため、その場で保存用画像まで反映する。
  if not Slider.TrackBar.Focused then
    CommitPendingPattern;
end;

procedure TVectArtPaintPopup.EditWaveCount(Sender: TObject);
var Value: Integer;
begin
  if FUpdating or not Visible then Exit;
  Value := Round(FWaveCount.Value);
  if Value <> FWaveCountValue then
  begin FWaveCountValue := Value; CommitFill; end;
  Sync;
end;

procedure TVectArtPaintPopup.EditAngle(Sender: TObject);
var Value: Integer;
begin
  if FUpdating or not Visible then Exit;
  Value := Round(FAngle.Value);
  if Value <> FAngleValue then
  begin
    FAngleValue := Value;
    if FGradient.ItemIndex <> 5 then FGradient.ItemIndex := 0;
    CommitFill;
  end;
  Sync;
end;
procedure TVectArtPaintPopup.ApplyColor(Color: TColor);
var
  Slot: Integer;
begin
  CommitPendingPattern;
  Color := ColorToRGB(Color);
  if ((FMode.ItemIndex = 1) or ((FMode.ItemIndex = 2) and
    (FTexturePattern.ItemIndex > 0))) and FSlot2.Checked then Slot := 2 else Slot := 1;
  if FHistoryPending and (FHistoryPendingSlot <> Slot) then
    CommitPendingColor;
  FHistoryPending := True;
  FHistoryPendingColor := Color;
  FHistoryPendingSlot := Slot;
  if Slot = 2 then FColor2 := Color else FColor1 := Color;
  if (FMode.ItemIndex = 2) and (FTexturePattern.ItemIndex > 0) then
    RegeneratePattern;
  if Assigned(FFillChanged) then CommitFill;
  if (FMode.ItemIndex = 0) and Assigned(FChanged) then FChanged(Self,Color);
  Sync;
end;
procedure TVectArtPaintPopup.DrawPreview(Sender: TObject);
begin
  DrawPaintPreview(FPreview,FPreviewBitmap,FPreviewDirty,FMode.ItemIndex,
    FGradient.ItemIndex,FAngleValue,FWaveCountValue,FColor1,FColor2,FTexture);
end;
procedure TVectArtPaintPopup.PickerChanged(Sender: TObject);
begin
  if FUpdating then Exit;
  FPicking := True;
  try
    if Sender = FHue then
    begin
      FSV.BaseColor := FHue.Color; FSV.Color := FHue.Color;
      ApplyColor(FHue.Color);
    end
    else ApplyColor(FSV.Color);
  finally FPicking := False; end;
end;

procedure TVectArtPaintPopup.DrawColor(Sender: TObject; ACol, ARow: Longint;
  Rect: TRect; State: TGridDrawState);
var I: Integer;
begin
  I := ARow * 10 + ACol;
  FPalette.Canvas.Brush.Color := clBtnFace;
  FPalette.Canvas.FillRect(Rect);
  InflateRect(Rect,-3,-3);
  if I < Length(FColors) then
  begin
    FPalette.Canvas.Brush.Color := FColors[I];
    FPalette.Canvas.FillRect(Rect);
    // 選択枠は編集中の色との一致で決め、グリッドのフォーカス位置には追従させない。
    if I = FSelectedColor then
    begin
      FPalette.Canvas.Pen.Color := clWhite;
      FPalette.Canvas.Brush.Style := bsClear;
      FPalette.Canvas.Rectangle(Rect);
      InflateRect(Rect,-1,-1);
      FPalette.Canvas.Pen.Color := clBlack;
      FPalette.Canvas.Rectangle(Rect);
      FPalette.Canvas.Brush.Style := bsSolid;
      FPalette.Canvas.Brush.Color := FColors[I];
    end;
  end;
end;
procedure TVectArtPaintPopup.PickColor(Sender: TObject; ACol, ARow: Longint; var CanSelect: Boolean);
var I: Integer;
begin
  I := ARow * 10 + ACol;
  if (I < Length(FColors)) and not FUpdating then ApplyColor(FColors[I]);
end;

procedure TVectArtPaintPopup.LoadTexture(Sender: TObject);
var Dialog: TOpenDialog; Bytes: TBytes;
begin
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Filter := '画像|*.png;*.jpg;*.jpeg;*.bmp';
    if Dialog.Execute then
      try
        // 変換完了まで現在の設定を維持し、プレビューと保存データを同じPNGから更新する。
        Bytes := LoadVectArtTexturePng(Dialog.FileName);
        FTexturePattern.ItemIndex := 0;
        FTexturePatternKind := 0;
        LoadTextureBytes(Bytes);
        FPreviewDirty := True; FPreview.Invalidate; CommitFill;
      except on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0); end;
  finally Dialog.Free; end;
end;

procedure ShowVectArtColorPopup(Target: TComponent; const Title: string;
  Color: TColor; const UsedColors: TArray<TColor>;
  OnChanged: TVectArtColorChanged; ColorHistory: TVectArtColorHistory);
begin
  if Popup <> nil then
    Popup.CommitPendingPattern
  else
    Popup := TVectArtPaintPopup.Create(Application);
  Popup.CommitPendingColor;
  if Popup.FTarget <> nil then Popup.FTarget.RemoveFreeNotification(Popup);
  Popup.FTarget := Target;
  Target.FreeNotification(Popup);
  Popup.FFillChanged := nil;
  Popup.FChanged := OnChanged;
  Popup.FColorHistory := ColorHistory;
  Popup.Caption := Title;
  Popup.FColor1 := Color;
  Popup.FColor2 := clWhite;
  Popup.FMode.ItemIndex := 0;
  Popup.FGradient.ItemIndex := 0;
  Popup.FAngleValue := 0;
  Popup.FSlot1.Checked := True;
  Popup.FAllowPaint := False;
  Popup.FHistoryPending := False;
  Popup.FHistoryPendingSlot := 0;
  Popup.BuildPaletteColors(UsedColors);
  Popup.Sync;
  Popup.Show;
end;

procedure TVectArtPaintPopup.CommitFill;
var Fill: TVectArtFillStyle;
begin
  if not Assigned(FFillChanged) then Exit;
  Fill := Default(TVectArtFillStyle);
  Fill.Color2 := FColor2;
  Fill.Angle := FAngleValue;
  if FMode.ItemIndex = 1 then begin
    if FGradient.ItemIndex = 5 then Fill.Kind := vfkSpectrum
    else if FGradient.ItemIndex = 4 then
      begin Fill.Kind := vfkWave; Fill.WaveCount := FWaveCountValue; end
    else if FGradient.ItemIndex = 3 then Fill.Kind := vfkSquare
    else if FGradient.ItemIndex = 2 then Fill.Kind := vfkCircle
    else if FGradient.ItemIndex = 1 then Fill.Kind := vfkRadial
    else if FAngleValue = 90 then Fill.Kind := vfkLinearVertical
    else Fill.Kind := vfkLinearHorizontal;
  end;
  if FMode.ItemIndex = 2 then
  begin
    if FTexturePattern.ItemIndex > 0 then
    begin
      FTexturePng := CreateVectArtPatternPng(FPatternSettings,
        FColor1, FColor2, 255);
    end;
    if Length(FTexturePng) = 0 then Exit;
    Fill.Kind := vfkTexture; Fill.TexturePng := Copy(FTexturePng);
  end;
  FFillChanged(Self,FColor1,Fill);
end;

procedure ShowVectArtFillPopup(Target: TComponent; Color: TColor;
  const Fill: TVectArtFillStyle; const UsedColors: TArray<TColor>;
  OnChanged: TVectArtFillChanged; AllowTexture: Boolean;
  ColorHistory: TVectArtColorHistory; PatternColor1, PatternColor2: TColor);
var Stream: TBytesStream;
begin
  ShowVectArtColorPopup(Target,'色・塗りを編集',Color,UsedColors,nil,
    ColorHistory);
  Popup.FUpdating := True;
  try
    Popup.FAllowPaint := True;
    Popup.FAngleValue := Fill.Angle;
    Popup.FWaveCountValue := 5;
    if Fill.Kind = vfkWave then Popup.FWaveCountValue := Fill.WaveCount;
    if Fill.Kind = vfkLinearVertical then Popup.FAngleValue := 90;
    Popup.FColor2 := Fill.Color2;
    if Fill.Kind = vfkSolid then Popup.FColor2 := clWhite;
    if PatternColor1 = clNone then Popup.FPatternColor1 := Color
    else Popup.FPatternColor1 := ColorToRGB(PatternColor1);
    if PatternColor2 = clNone then Popup.FPatternColor2 := Popup.FColor2
    else Popup.FPatternColor2 := ColorToRGB(PatternColor2);
    Popup.FPatternSettings := DefaultVectArtPatternSettings(vpkHatch);
    if Popup.FMode.Items.Count < 3 then Popup.FMode.Items.Add('テクスチャ');
    Popup.FMode.Items[1] := 'グラデーション';
    Popup.FMode.Items[2] := 'テクスチャ';
    Popup.FTexturePng := Copy(Fill.TexturePng);
    Popup.FTexture.Assign(nil);
    Popup.FTexturePatternKind := 0;
    Popup.FTexturePattern.ItemIndex := 0;
    Popup.FSlot1.Checked := True;
    if Fill.Kind in [vfkLinearHorizontal,vfkLinearVertical,vfkRadial,vfkCircle,vfkSquare,vfkWave,vfkSpectrum] then
    begin
      Popup.FMode.ItemIndex := 1;
      if Fill.Kind = vfkSpectrum then Popup.FGradient.ItemIndex := 5
      else if Fill.Kind = vfkWave then Popup.FGradient.ItemIndex := 4
      else if Fill.Kind = vfkSquare then Popup.FGradient.ItemIndex := 3
      else if Fill.Kind = vfkCircle then Popup.FGradient.ItemIndex := 2
      else if Fill.Kind = vfkRadial then Popup.FGradient.ItemIndex := 1
      else Popup.FGradient.ItemIndex := 0;
    end
    else if Fill.Kind = vfkTexture then
    begin
      Popup.FMode.ItemIndex := 2;
      Stream := TBytesStream.Create(Fill.TexturePng);
      try Popup.FTexture.LoadFromStream(Stream); finally Stream.Free; end;
      Popup.FTexturePattern.ItemIndex := 0;
      Popup.FTexturePatternKind := 0;
    end;
    if not AllowTexture then Popup.FMode.Items.Delete(2);
    Popup.FFillChanged := OnChanged;
  finally Popup.FUpdating := False; end;
  Popup.Sync;
end;
procedure CloseVectArtColorPopup(Target: TComponent);
begin
  if (Popup <> nil) and (Popup.FTarget = Target) then
  begin
    Popup.CommitPendingPattern;
    Popup.CommitPendingColor;
    Popup.FChanged := nil;
    Popup.FFillChanged := nil;
    Popup.FColorHistory := nil;
    Popup.Hide;
  end;
end;

end.
