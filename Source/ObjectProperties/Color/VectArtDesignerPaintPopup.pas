// 単色専用と図形の塗り設定で、色表示・使用色・編集窓を共有する。
// 適用先への変更通知だけを行い、Documentの更新とUndoは呼び出し側に委ねる。
unit VectArtDesignerPaintPopup;

interface

uses
  System.Classes, System.Types, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Graphics, Vcl.Grids, VectArtDesignerDocument;

type
  TVectArtFillChanged = procedure(Sender: TObject; Color: TColor; const Fill: TVectArtFillStyle) of object;
  TVectArtColorChanged = procedure(Sender: TObject; Color: TColor) of object;
procedure ShowVectArtColorPopup(Target: TComponent; const Title: string;
  Color: TColor; const UsedColors: TArray<TColor>;
  OnChanged: TVectArtColorChanged);
procedure ShowVectArtFillPopup(Target: TComponent; Color: TColor;
  const Fill: TVectArtFillStyle; const UsedColors: TArray<TColor>;
  OnChanged: TVectArtFillChanged);
procedure CloseVectArtColorPopup(Target: TComponent);

implementation

uses
  System.SysUtils, System.Math, System.UITypes, Winapi.Windows, Vcl.Dialogs,
  VectArtDesignerNumericSlider, ColorPickerHueBar, ColorPickerSVArea, ColorPickerColorMath, Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, VectArtDesignerPaintPreview, VectArtDesignerColorSwatch;

type
  TVectArtPaintPopup = class(TForm)
  private
    FTarget: TComponent;
    FChanged: TVectArtColorChanged;
    FFillChanged: TVectArtFillChanged;
    FTexturePng: TBytes;

    FMode, FGradient: TComboBox;
    FSlot1, FSlot2: TRadioButton;
    FAngle: TVectArtNumericSlider;
    FAngleLabel, FPaletteLabel: TLabel;
    FAllowPaint: Boolean;
    FAngleValue: Integer;
    FPreview: TPaintBox;
    FPreviewBitmap: Vcl.Graphics.TBitmap;
    FPreviewDirty: Boolean;
    FPalette: TDrawGrid;
    FSelectedColor: Integer;
    FSwatch1, FSwatch2: TShape;
    FHue: TColorPickerHueBar;
    FSV: TColorPickerSVArea;
    FTextureButton: TButton;
    FTexture: TPicture;
    FColors: TArray<TColor>;
    FColor1, FColor2: TColor;
    FUpdating, FPicking: Boolean;
    procedure PickerChanged(Sender: TObject);
    procedure CommitFill;
    procedure EditAngle(Sender: TObject);
    procedure Changed(Sender: TObject);
    procedure DrawPreview(Sender: TObject);
    procedure DrawColor(Sender: TObject; ACol, ARow: Longint;
      Rect: TRect; State: TGridDrawState);
    procedure PickColor(Sender: TObject; ACol, ARow: Longint; var CanSelect: Boolean);
    procedure LoadTexture(Sender: TObject);
    procedure ApplyColor(Color: TColor);
    procedure Sync;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  Popup: TVectArtPaintPopup;

constructor TVectArtPaintPopup.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  BorderStyle := bsToolWindow;
  DoubleBuffered := True;
  Position := poScreenCenter;
  ClientWidth := 370;
  ClientHeight := 466;
  Font.Name := 'Yu Gothic UI';
  Font.Size := 9;
  FTexture := TPicture.Create;
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
  FPreview := TPaintBox.Create(Self);
  FPreview.Parent := Self;
  FPreview.SetBounds(16, 16, 338, 68);
  FPreview.OnPaint := DrawPreview;
  FGradient := TComboBox.Create(Self);
  FGradient.Parent := Self;
  FGradient.Style := csDropDownList;
  FGradient.Items.AddStrings(['線形', '放射']);
  FGradient.ItemIndex := 0;
  FGradient.SetBounds(16, 132, 172, 28);
  FGradient.OnChange := Changed;
  FAngleLabel := TLabel.Create(Self);
  FAngleLabel.Parent := Self;
  FAngleLabel.Caption := '角度（°）';
  FAngleLabel.SetBounds(196,138,66,20);
  FAngle := TVectArtNumericSlider.CreateForParent(Self,Self);
  FAngle.Name := 'GradientAngleSlider';
  FAngle.Configure(0,359,1,0);
  FAngle.TrackBar.LargeChange := 15;
  FAngle.OnChange := EditAngle;
  FTextureButton := TButton.Create(Self);
  FTextureButton.Parent := Self;
  FTextureButton.Caption := 'テクスチャ画像を選択…';
  FTextureButton.SetBounds(16, 132, 338, 28);
  FTextureButton.OnClick := LoadTexture;
  // スタイル付きグループ枠の内部余白で文字が切れないよう、独立した選択ボタンにする。
  FSlot1 := TRadioButton.Create(Self);
  FSlot1.Parent := Self;
  FSlot1.Name := 'ColorSlot1';
  FSlot1.Caption := '色1';
  FSlot1.SetBounds(24,166,154,26);
  FSlot1.Checked := True;
  FSlot1.OnClick := Changed;
  FSlot2 := TRadioButton.Create(Self);
  FSlot2.Parent := Self;
  FSlot2.Name := 'ColorSlot2';
  FSlot2.Caption := '色2';
  FSlot2.SetBounds(188,166,154,26);
  FSlot2.OnClick := Changed;
  FPaletteLabel := TLabel.Create(Self);
  FPaletteLabel.Parent := Self;
  FPaletteLabel.Caption := '使用された色';
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

end;

destructor TVectArtPaintPopup.Destroy;
begin
  FPreviewBitmap.Free;
  FTexture.Free;
  inherited;
end;

procedure TVectArtPaintPopup.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FTarget) then
  begin
    FTarget := nil;
    FChanged := nil;
    FFillChanged := nil;
    Hide;
  end;
end;

procedure TVectArtPaintPopup.Sync;
var Y,I: Integer; C: TColor;
begin
  FUpdating := True;
  try
    if not FAllowPaint then FMode.ItemIndex := 0;
    Y := 94;
    FMode.Visible := FAllowPaint;
    if FAllowPaint then
    begin FMode.SetBounds(16,Y,338,28); Inc(Y,38); end;
    FGradient.Visible := FMode.ItemIndex = 1;
    FAngle.Visible := FGradient.Visible and (FGradient.ItemIndex = 0);
    FAngleLabel.Visible := FAngle.Visible;
    FSlot1.Visible := FGradient.Visible; FSlot2.Visible := FGradient.Visible;
    if FGradient.Visible then
    begin
      FGradient.SetBounds(16,Y,338,28); Inc(Y,38);
      if FAngle.Visible then
      begin
        FAngleLabel.SetBounds(16,Y+5,80,20);
        FAngle.SetBounds(84,Y,270,30); Inc(Y,38);
      end;
      FSlot1.SetBounds(24,Y,60,26); FSlot2.SetBounds(188,Y,60,26);
      FSwatch1.SetBounds(92,Y+2,70,22); FSwatch2.SetBounds(256,Y+2,70,22);
      Inc(Y,36);
    end;
    FSwatch1.Visible := FSlot1.Visible; FSwatch2.Visible := FSlot2.Visible;
    FSwatch1.Brush.Color := FColor1; FSwatch2.Brush.Color := FColor2;
    FAngle.SetDisplay(((FAngleValue mod 360)+360) mod 360);
    FTextureButton.Visible := FMode.ItemIndex = 2;
    if FTextureButton.Visible then
    begin FTextureButton.SetBounds(16,Y,338,28); Inc(Y,38); end;
    FPaletteLabel.SetBounds(16,Y,338,20); Inc(Y,24);
    FPalette.SetBounds(16,Y,338,108);
    FPalette.Enabled := FMode.ItemIndex <> 2;
    FPalette.Visible := FPalette.Enabled; FPaletteLabel.Visible := FPalette.Enabled;
    FSV.SetBounds(16,Y+120,302,160); FHue.SetBounds(330,Y+120,24,160);
    FSV.Visible := FPalette.Enabled; FHue.Visible := FPalette.Enabled;
    C := FColor1;
    if (FMode.ItemIndex = 1) and FSlot2.Checked then C := FColor2;
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
    if FMode.ItemIndex = 2 then ClientHeight := FTextureButton.Top+FTextureButton.Height+16
    else ClientHeight := Y+108+12+160+16;
    FPreviewDirty := True;
    FPreview.Invalidate; FPalette.Invalidate;
  finally FUpdating := False; end;
end;
procedure TVectArtPaintPopup.Changed(Sender: TObject);
begin
  if FUpdating then Exit;
  if (Sender = FMode) or (Sender = FGradient) then CommitFill;
  Sync;
end;

procedure TVectArtPaintPopup.EditAngle(Sender: TObject);
var Value: Integer;
begin
  if FUpdating or not Visible then Exit;
  Value := Round(FAngle.Value);
  if Value <> FAngleValue then
  begin FAngleValue := Value; FGradient.ItemIndex := 0; CommitFill; end;
  Sync;
end;
procedure TVectArtPaintPopup.ApplyColor(Color: TColor);
begin
  if (FMode.ItemIndex = 1) and FSlot2.Checked then FColor2 := Color
  else FColor1 := Color;
  if Assigned(FFillChanged) then CommitFill;
  if (FMode.ItemIndex = 0) and Assigned(FChanged) then FChanged(Self,Color);
  Sync;
end;
procedure TVectArtPaintPopup.DrawPreview(Sender: TObject);
begin
  DrawPaintPreview(FPreview,FPreviewBitmap,FPreviewDirty,FMode.ItemIndex,
    FGradient.ItemIndex,FAngleValue,FColor1,FColor2,FTexture);
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
var D: TOpenDialog; P: TPngImage; Stream: TMemoryStream; Bitmap: Vcl.Graphics.TBitmap;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := '画像|*.png;*.jpg;*.jpeg;*.bmp';
    if D.Execute then
      try
        FTexture.LoadFromFile(D.FileName);
        P := TPngImage.Create; Stream := TMemoryStream.Create;
        try
          if FTexture.Graphic is TPngImage then P.Assign(FTexture.Graphic)
          else
          begin
            Bitmap := Vcl.Graphics.TBitmap.Create;
            try
              Bitmap.SetSize(FTexture.Width,FTexture.Height);
              Bitmap.Canvas.Draw(0,0,FTexture.Graphic);
              P.Assign(Bitmap);
            finally Bitmap.Free; end;
          end;
          P.SaveToStream(Stream);
          SetLength(FTexturePng,Stream.Size);
          Move(Stream.Memory^,FTexturePng[0],Stream.Size);
        finally Stream.Free; P.Free; end;
        FPreviewDirty := True; FPreview.Invalidate; CommitFill;
      except on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0); end;
  finally D.Free; end;
end;

procedure ShowVectArtColorPopup(Target: TComponent; const Title: string;
  Color: TColor; const UsedColors: TArray<TColor>;
  OnChanged: TVectArtColorChanged);
begin
  if Popup = nil then Popup := TVectArtPaintPopup.Create(Application);
  if Popup.FTarget <> nil then Popup.FTarget.RemoveFreeNotification(Popup);
  Popup.FTarget := Target;
  Target.FreeNotification(Popup);
  Popup.FFillChanged := nil;
  Popup.FChanged := OnChanged;
  Popup.Caption := Title;
  Popup.FColor1 := Color;
  Popup.FColor2 := clWhite;
  Popup.FMode.ItemIndex := 0;
  Popup.FGradient.ItemIndex := 0;
  Popup.FAngleValue := 0;
  Popup.FSlot1.Checked := True;
  Popup.FAllowPaint := False;
  Popup.FColors := UsedColors + [clBlack, clWhite, clRed, clYellow,
    clLime, clAqua, clBlue, clFuchsia, clGray, clSilver, clMaroon, clOlive, clGreen, clTeal, clNavy, clPurple];
  Popup.FPalette.RowCount := Max(3, (Length(Popup.FColors) + 9) div 10);
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
    if FGradient.ItemIndex = 1 then Fill.Kind := vfkRadial
    else if FAngleValue = 90 then Fill.Kind := vfkLinearVertical
    else Fill.Kind := vfkLinearHorizontal;
  end;
  if FMode.ItemIndex = 2 then
  begin
    if Length(FTexturePng) = 0 then Exit;
    Fill.Kind := vfkTexture; Fill.TexturePng := Copy(FTexturePng);
  end;
  FFillChanged(Self,FColor1,Fill);
end;

procedure ShowVectArtFillPopup(Target: TComponent; Color: TColor;
  const Fill: TVectArtFillStyle; const UsedColors: TArray<TColor>;
  OnChanged: TVectArtFillChanged);
var Stream: TBytesStream;
begin
  ShowVectArtColorPopup(Target,'色・塗りを編集',Color,UsedColors,nil);
  Popup.FUpdating := True;
  try
    Popup.FAllowPaint := True;
    Popup.FAngleValue := Fill.Angle;
    if Fill.Kind = vfkLinearVertical then Popup.FAngleValue := 90;
    Popup.FColor2 := Fill.Color2;
    if Fill.Kind = vfkSolid then Popup.FColor2 := clWhite;
    Popup.FMode.Items[1] := 'グラデーション';
    Popup.FMode.Items[2] := 'テクスチャ';
    Popup.FTexturePng := Copy(Fill.TexturePng);
    Popup.FTexture.Assign(nil);
    Popup.FSlot1.Checked := True;
    if Fill.Kind in [vfkLinearHorizontal,vfkLinearVertical,vfkRadial] then
    begin
      Popup.FMode.ItemIndex := 1;
      if Fill.Kind = vfkRadial then Popup.FGradient.ItemIndex := 1
      else Popup.FGradient.ItemIndex := 0;
    end
    else if Fill.Kind = vfkTexture then
    begin
      Popup.FMode.ItemIndex := 2;
      Stream := TBytesStream.Create(Fill.TexturePng);
      try Popup.FTexture.LoadFromStream(Stream); finally Stream.Free; end;
    end;
    Popup.FFillChanged := OnChanged;
  finally Popup.FUpdating := False; end;
  Popup.Sync;
end;
procedure CloseVectArtColorPopup(Target: TComponent);
begin
  if (Popup <> nil) and (Popup.FTarget = Target) then
  begin Popup.FChanged := nil; Popup.FFillChanged := nil; Popup.Hide; end;
end;

end.
