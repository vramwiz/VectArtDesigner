// 数値入力と横型スライダーの同期・範囲検証を担当する。DocumentとUndoには依存しない。
unit VectArtDesignerNumericSlider;
interface
uses System.Classes, Vcl.Controls, Vcl.ExtCtrls, Vcl.StdCtrls,
  HorizontalTrackBarControl;
type
  TVectArtNumericSlider = class(TPanel)
  private
    FTrack: THorizontalTrackBarControl;
    FEdit: TEdit;
    FValue, FMinimum, FMaximum, FStep: Double;
    FDecimals: Integer;
    FMixed, FUpdating: Boolean;
    FOnChange: TNotifyEvent;
    procedure TrackChanged(Sender: TObject);
    procedure EditExit(Sender: TObject);
    procedure EditKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Sync;
    procedure SetValue(Value: Double);
  protected
    procedure Resize; override;
  public
    constructor CreateForParent(AOwner: TComponent; AParent: TWinControl);
    // 入力範囲と実用的なスライダー範囲を分離する。刻み幅はスライダーの分解能に用いる。
    procedure Configure(AMinimum, AMaximum, AStep: Double; ADecimals: Integer);
    procedure SetSliderRange(AMinimum, AMaximum: Double);
    // モデル同期は変更通知を出さず、混在状態やスライダー範囲外の入力値も保持する。
    procedure SetDisplay(AValue: Double; AMixed: Boolean = False);
    property Value: Double read FValue write SetValue;
    property Minimum: Double read FMinimum;
    property Maximum: Double read FMaximum;
    property Step: Double read FStep;
    property Decimals: Integer read FDecimals;
    property Mixed: Boolean read FMixed;
    property TrackBar: THorizontalTrackBarControl read FTrack;
    property Edit: TEdit read FEdit;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;
implementation
uses VectArtDesignerSettingsFont, System.SysUtils, System.StrUtils, System.Math, Winapi.Windows, Vcl.Graphics;
constructor TVectArtNumericSlider.CreateForParent(AOwner: TComponent; AParent: TWinControl);
begin
  inherited Create(AOwner);
  if AParent = nil then raise EArgumentNilException.Create('Numeric slider parent');
  Parent := AParent;
  ShowCaption := False;
  BevelOuter := bvNone; ParentBackground := False;
  Color := TColor($00282828); Height := 34; Width := 260;
  FTrack := THorizontalTrackBarControl.Create(Self); FTrack.Parent := Self;
  FTrack.ShowTicks := False; FTrack.BackgroundColor := Color;
  FTrack.FillColor := TColor($00D77800);
  FTrack.ThumbColor := TColor($00353535); FTrack.ThumbBorderColor := TColor($00EEEEEE);
  FTrack.OnChange := TrackChanged;
  FEdit := TEdit.Create(Self); FEdit.Parent := Self;
  FEdit.Color := TColor($00353535); FEdit.Font.Color := TColor($00EEEEEE);
  FEdit.Font.Name := VECTART_SETTINGS_FONT_NAME; FEdit.Font.Height := VECTART_SETTINGS_FONT_HEIGHT;
  FEdit.OnExit := EditExit; FEdit.OnKeyDown := EditKey;
  Configure(0,100,1,0); Resize;
end;
procedure TVectArtNumericSlider.Resize;
var EWidth: Integer;
begin
  inherited;
  if (FTrack = nil) or (FEdit = nil) then Exit;
  EWidth := Min(60,Max(24,ClientWidth div 3));
  FTrack.SetBounds(0,0,Max(1,ClientWidth-EWidth-10),ClientHeight);
  FEdit.SetBounds(Max(0,ClientWidth-EWidth),Max(0,(ClientHeight-25) div 2),EWidth,25);
end;
procedure TVectArtNumericSlider.Configure(AMinimum, AMaximum, AStep: Double; ADecimals: Integer);
begin
  if IsNan(AMinimum) or IsInfinite(AMinimum) or IsNan(AMaximum) or IsInfinite(AMaximum) or
    IsNan(AStep) or IsInfinite(AStep) or (AStep <= 0) or (AMaximum < AMinimum) or
    (ADecimals < 0) or (ADecimals > 6) or (Abs(AMinimum/AStep) > MaxInt-1) or
    (Abs(AMaximum/AStep) > MaxInt-1) then raise EArgumentException.Create('Invalid numeric slider range');
  FMinimum := AMinimum; FMaximum := AMaximum; FStep := AStep; FDecimals := ADecimals;
  SetSliderRange(AMinimum,AMaximum);
  SetDisplay(EnsureRange(FValue,FMinimum,FMaximum));
end;
procedure TVectArtNumericSlider.SetSliderRange(AMinimum, AMaximum: Double);
begin
  if IsNan(AMinimum) or IsInfinite(AMinimum) or IsNan(AMaximum) or IsInfinite(AMaximum) or
    (AMinimum < FMinimum) or (AMaximum > FMaximum) or (AMaximum < AMinimum) then
    raise EArgumentException.Create('Invalid slider range');
  FUpdating := True;
  try FTrack.SetRange(Round(AMinimum/FStep),Round(AMaximum/FStep));
    FTrack.SmallChange := 1; FTrack.LargeChange := 10;
  finally FUpdating := False; end;
  Sync;
end;
procedure TVectArtNumericSlider.Sync;
begin
  if Parent = nil then Exit;
  FUpdating := True;
  try
    FTrack.Position := EnsureRange(Round(FValue/FStep),FTrack.Minimum,FTrack.Maximum);
    if FMixed then FEdit.Text := ''
    else FEdit.Text := FormatFloat('0'+IfThen(FDecimals > 0,'.'+StringOfChar('#',FDecimals),''),FValue);
  finally FUpdating := False; end;
end;
procedure TVectArtNumericSlider.SetDisplay(AValue: Double; AMixed: Boolean);
begin
  if IsNan(AValue) or IsInfinite(AValue) then Exit;
  FValue := EnsureRange(AValue,FMinimum,FMaximum); FMixed := AMixed; Sync;
end;
procedure TVectArtNumericSlider.SetValue(Value: Double);
begin
  SetDisplay(Value);
end;
procedure TVectArtNumericSlider.TrackChanged(Sender: TObject);
begin
  if FUpdating or not Enabled or not FTrack.Enabled then Exit;
  FValue := EnsureRange(FTrack.Position*FStep,FMinimum,FMaximum); FMixed := False;
  Sync;
  if Assigned(FOnChange) then FOnChange(Self);
end;
procedure TVectArtNumericSlider.EditExit(Sender: TObject);
var N: Double; Changed: Boolean;
begin
  if FUpdating or not Enabled or not FEdit.Enabled then Exit;
  if not TryStrToFloat(Trim(FEdit.Text),N) or IsNan(N) or IsInfinite(N) or
    (N < FMinimum) or (N > FMaximum) then begin Sync; Exit; end;
  N := RoundTo(N,-FDecimals);
  Changed := FMixed or not SameValue(N,FValue);
  SetDisplay(N);
  if Changed and Assigned(FOnChange) then FOnChange(Self);
end;
procedure TVectArtNumericSlider.EditKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then begin EditExit(Sender); Key := 0; end
  else if Key = VK_ESCAPE then begin Sync; Key := 0; end;
end;
end.