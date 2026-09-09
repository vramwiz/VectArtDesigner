// 利用可能な設定パネルを、区切り付きの単一スクロールページへ上詰めで配置する。
// 入力欄の所有権と編集処理は呼出側に残し、既存パネルの表示条件と積み上げだけを担当する。
unit VectArtDesignerSettingsSections;

interface

uses
  System.Classes, System.Types, Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms,
  Vcl.StdCtrls;

type
  TVectArtSettingsCategory = (vscLine, vscStroke, vscFill, vscShadow,
    vscInfo, vscText, vscOutline, vscEffects);

  TVectArtSettingsPanel = class(TScrollBox)
  private
    FAvailable: Boolean;
    FCategory: TVectArtSettingsCategory;
  public
    property Available: Boolean read FAvailable write FAvailable;
    property Category: TVectArtSettingsCategory read FCategory;
    property Caption;
  end;

  TVectArtSettingsSections = class(TScrollBox)
  private
    FSections: array[TVectArtSettingsCategory] of TVectArtSettingsPanel;
    FHosts: array[TVectArtSettingsCategory] of TPanel;
    FHeaders: array[TVectArtSettingsCategory] of TStaticText;
    FActiveSection: TVectArtSettingsPanel;
    FOnChange: TNotifyEvent;
    FLayoutInitialized: Boolean;
    FLastTextMode: Boolean;
    FLastAvailable: array[TVectArtSettingsCategory] of Boolean;
    FLastHeight: array[TVectArtSettingsCategory] of Integer;
    FLastCaption: array[TVectArtSettingsCategory] of string;
    function GetSectionCount: Integer;
    function GetSection(Index: Integer): TVectArtSettingsPanel;
    function MeasureSectionHeight(Section: TVectArtSettingsPanel): Integer;
    procedure SetActiveSection(Value: TVectArtSettingsPanel);
  protected
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    function AddSection(Category: TVectArtSettingsCategory;
      const Title: string): TVectArtSettingsPanel;
    // 旧アイコンUIとのソース互換用。単一ページ化後は常に空矩形を返す。
    function IconRect(Category: TVectArtSettingsCategory): TRect;
    procedure RefreshSections;
    property SectionCount: Integer read GetSectionCount;
    property Sections[Index: Integer]: TVectArtSettingsPanel read GetSection;
    // ActiveSectionはテストや既存呼出しから対象位置へスクロールする窓口として残す。
    property ActiveSection: TVectArtSettingsPanel read FActiveSection
      write SetActiveSection;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

uses
  System.Math, System.UITypes, Winapi.Windows, Vcl.Graphics,
  VectArtDesignerSettingsFont;

const
  SECTION_HEADER_HEIGHT = 25;
  SECTION_BOTTOM_MARGIN = 4;
  SECTION_WHEEL_STEP = 120;
  COLOR_SECTION_HEADER = TColor($002D2D2D);

function SectionTopOrder(Category: TVectArtSettingsCategory;
  TextMode: Boolean): Integer;
begin
  if TextMode then
    case Category of
      vscFill:
        Result := 0;
      vscText:
        Result := 1;
      vscOutline:
        Result := 2;
      vscEffects:
        Result := 3;
      vscInfo:
        Result := 4;
    else
      Result := 100 + Ord(Category);
    end
  else
    Result := Ord(Category);
end;

constructor TVectArtSettingsSections.Create(AOwner: TComponent);
begin
  inherited;
  ParentBackground := False;
  ParentDoubleBuffered := False;
  DoubleBuffered := False;
  BorderStyle := bsNone;
  Color := TColor($00212121);
  Font.Color := TColor($00EEEEEE);
  ApplyVectArtSettingsFont(Self);
  HorzScrollBar.Visible := False;
  VertScrollBar.Tracking := True;
  AutoScroll := True;
  Width := 284;
  Height := 620;
end;

function TVectArtSettingsSections.DoMouseWheel(Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  OldPosition: Integer;
begin
  OldPosition := VertScrollBar.Position;
  if (WheelDelta <> 0) and (VertScrollBar.Range > ClientHeight) then
  begin
    VertScrollBar.Position := OldPosition -
      MulDiv(WheelDelta, SECTION_WHEEL_STEP, WHEEL_DELTA);
    Result := VertScrollBar.Position <> OldPosition;
    if Result then
      Exit;
  end;
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
end;

function TVectArtSettingsSections.AddSection(
  Category: TVectArtSettingsCategory;
  const Title: string): TVectArtSettingsPanel;
var
  Header: TStaticText;
  Host: TPanel;
begin
  Host := TPanel.Create(Self);
  Host.Parent := Self;
  Host.Align := alTop;
  Host.BevelInner := bvNone;
  Host.BevelOuter := bvLowered;
  Host.BevelWidth := 1;
  Host.BorderStyle := bsNone;
  Host.Caption := '';
  Host.Color := Color;
  Host.ParentBackground := False;
  Host.ParentColor := False;
  Host.ShowCaption := False;

  Header := TStaticText.Create(Host);
  Header.Parent := Host;
  Header.Align := alTop;
  Header.AutoSize := False;
  Header.Height := SECTION_HEADER_HEIGHT;
  Header.BorderStyle := sbsNone;
  Header.Caption := Title;
  Header.Color := COLOR_SECTION_HEADER;
  Header.Font.Assign(Font);
  Header.Font.Height := VECTART_SETTINGS_FONT_HEIGHT;
  Header.Font.Color := TColor($00EEEEEE);
  Header.ParentColor := False;
  Header.ParentFont := False;
  Header.StyleElements := Header.StyleElements - [seFont];

  Result := TVectArtSettingsPanel.Create(Self);
  Result.Parent := Host;
  Result.Align := alClient;
  Result.Caption := Title;
  Result.FCategory := Category;
  Result.Available := True;
  Result.ParentBackground := False;
  Result.ParentDoubleBuffered := False;
  Result.DoubleBuffered := False;
  Result.ParentColor := False;
  Result.Color := Color;
  Result.Font.Assign(Font);
  Result.Font.Height := VECTART_SETTINGS_FONT_HEIGHT;
  Result.BorderStyle := bsNone;
  Result.HorzScrollBar.Visible := False;
  Result.VertScrollBar.Visible := False;

  FHosts[Category] := Host;
  FHeaders[Category] := Header;
  FSections[Category] := Result;
  FLayoutInitialized := False;
end;

function TVectArtSettingsSections.GetSectionCount: Integer;
begin
  Result := Length(FSections);
end;

function TVectArtSettingsSections.GetSection(
  Index: Integer): TVectArtSettingsPanel;
begin
  Result := FSections[TVectArtSettingsCategory(Index)];
end;

function TVectArtSettingsSections.IconRect(
  Category: TVectArtSettingsCategory): TRect;
begin
  Result := TRect.Empty;
end;

function TVectArtSettingsSections.MeasureSectionHeight(
  Section: TVectArtSettingsPanel): Integer;
var
  Control: TControl;
  I: Integer;
begin
  case Section.Category of
    vscShadow:
      Exit(210);
    vscOutline, vscEffects:
      Exit(330);
  end;
  Result := 40;
  for I := 0 to Section.ControlCount - 1 do
  begin
    Control := Section.Controls[I];
    if Control.Visible and (Control.Align = alNone) then
      Result := Max(Result, Control.Top + Control.Height + 8);
  end;
end;

procedure TVectArtSettingsSections.RefreshSections;
var
  Category: TVectArtSettingsCategory;
  Host: TPanel;
  LayoutChanged: Boolean;
  SectionHeight: array[TVectArtSettingsCategory] of Integer;
  Section: TVectArtSettingsPanel;
  TextMode: Boolean;
begin
  if (FActiveSection = nil) or not FActiveSection.Available then
  begin
    FActiveSection := FSections[vscInfo];
    if (FActiveSection = nil) or not FActiveSection.Available then
      for Category := Low(Category) to High(Category) do
        if (FSections[Category] <> nil) and FSections[Category].Available then
        begin
          FActiveSection := FSections[Category];
          Break;
        end;
  end;

  TextMode := (FSections[vscText] <> nil) and
    FSections[vscText].Available;
  LayoutChanged := not FLayoutInitialized or (FLastTextMode <> TextMode);
  for Category := Low(Category) to High(Category) do
  begin
    Section := FSections[Category];
    if Section = nil then
    begin
      SectionHeight[Category] := 0;
      Continue;
    end;
    if Section.Available then
      SectionHeight[Category] := SECTION_HEADER_HEIGHT +
        MeasureSectionHeight(Section) + SECTION_BOTTOM_MARGIN
    else
      SectionHeight[Category] := 0;
    LayoutChanged := LayoutChanged or
      (FLastAvailable[Category] <> Section.Available) or
      (FLastHeight[Category] <> SectionHeight[Category]) or
      (FLastCaption[Category] <> Section.Caption);
    if (FHeaders[Category] <> nil) and
      (FHeaders[Category].Caption <> Section.Caption) then
      FHeaders[Category].Caption := Section.Caption;
  end;
  if not LayoutChanged then
    Exit;

  DisableAlign;
  try
    // alTopの整列前にTopを自由に設定できる状態へ戻す。
    for Category := Low(Category) to High(Category) do
      if FHosts[Category] <> nil then
        FHosts[Category].Align := alNone;

    for Category := Low(Category) to High(Category) do
    begin
      Host := FHosts[Category];
      Section := FSections[Category];
      if (Host = nil) or (Section = nil) then
        Continue;
      Host.Visible := Section.Available;
      Section.Visible := Section.Available;
      if Section.Available then
      begin
        Host.Height := SectionHeight[Category];
        Host.Top := SectionTopOrder(Category, TextMode) * 10000;
      end;
    end;

    for Category := Low(Category) to High(Category) do
      if FHosts[Category] <> nil then
        FHosts[Category].Align := alTop;
  finally
    EnableAlign;
  end;
  FLayoutInitialized := True;
  FLastTextMode := TextMode;
  for Category := Low(Category) to High(Category) do
    if FSections[Category] <> nil then
    begin
      FLastAvailable[Category] := FSections[Category].Available;
      FLastHeight[Category] := SectionHeight[Category];
      FLastCaption[Category] := FSections[Category].Caption;
    end;
  Realign;
  Invalidate;
end;

procedure TVectArtSettingsSections.SetActiveSection(
  Value: TVectArtSettingsPanel);
var
  Host: TPanel;
begin
  if (Value = nil) or not Value.Available then
    Exit;
  Host := FHosts[Value.Category];
  if (Host = nil) or (Value.Parent <> Host) then
    Exit;
  FActiveSection := Value;
  if Value.HandleAllocated then
    Value.Invalidate;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TVectArtSettingsSections.Resize;
begin
  inherited;
  RefreshSections;
end;

end.
