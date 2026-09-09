// PageControlを使わず、アイコンで選んだ設定パネル1枚だけを表示する。
// 入力欄の所有権と編集処理は呼出側に残し、カテゴリの選択・配置だけを担当する。
unit VectArtDesignerSettingsSections;
interface
uses System.Classes, System.Types, Vcl.Controls, Vcl.Forms, Winapi.Messages;
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
  TVectArtSettingsSections = class(TCustomControl)
  private
    FSections: array[TVectArtSettingsCategory] of TVectArtSettingsPanel;
    FActiveSection: TVectArtSettingsPanel;
    FOnChange: TNotifyEvent;
    FHeaderHeight: Integer;
    function GetSectionCount: Integer;
    function GetSection(Index: Integer): TVectArtSettingsPanel;
    procedure SetActiveSection(Value: TVectArtSettingsPanel);
    procedure DrawIcon(Category: TVectArtSettingsCategory; const Bounds: TRect);
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X,Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X,Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    function AddSection(Category: TVectArtSettingsCategory; const Title: string): TVectArtSettingsPanel;
    function IconRect(Category: TVectArtSettingsCategory): TRect;
    procedure RefreshSections;
    property SectionCount: Integer read GetSectionCount;
    property Sections[Index: Integer]: TVectArtSettingsPanel read GetSection;
    property ActiveSection: TVectArtSettingsPanel read FActiveSection write SetActiveSection;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;
implementation
uses VectArtDesignerSettingsFont, System.UITypes, System.Math, Vcl.Graphics, Winapi.Windows;
const ICON_SIZE=34; ICON_PITCH=40; MARGIN=6;
constructor TVectArtSettingsSections.Create(AOwner: TComponent);
begin
  inherited;
  ParentBackground:=False; ParentDoubleBuffered:=False; DoubleBuffered:=False;
  Color:=TColor($00212121); Font.Color:=TColor($00EEEEEE);
  ApplyVectArtSettingsFont(Self);
  Width:=284; Height:=620; TabStop:=True; ShowHint:=True;
end;
function TVectArtSettingsSections.AddSection(Category: TVectArtSettingsCategory; const Title: string): TVectArtSettingsPanel;
begin
  Result:=TVectArtSettingsPanel.Create(Self);
  Result.Visible:=False; Result.Parent:=Self; Result.Caption:=Title;
  Result.FCategory:=Category; Result.Available:=True;
  Result.ParentBackground:=False; Result.ParentDoubleBuffered:=False; Result.DoubleBuffered:=False;
  Result.ParentColor:=False; Result.Color:=Color;
  Result.Font.Assign(Font); Result.Font.Height:=VECTART_SETTINGS_FONT_HEIGHT;
  Result.BorderStyle:=bsNone; Result.HorzScrollBar.Visible:=False;
  FSections[Category]:=Result;
end;
function TVectArtSettingsSections.GetSectionCount: Integer;
begin Result:=Length(FSections); end;
function TVectArtSettingsSections.GetSection(Index: Integer): TVectArtSettingsPanel;
begin Result:=FSections[TVectArtSettingsCategory(Index)]; end;
function TVectArtSettingsSections.IconRect(Category: TVectArtSettingsCategory): TRect;
var C: TVectArtSettingsCategory; N,Columns: Integer;
begin
  Result:=TRect.Empty;
  if (FSections[Category]=nil) or not FSections[Category].Available then Exit;
  N:=0;
  for C:=Low(C) to High(C) do
  begin
    if C=Category then Break;
    if (FSections[C]<>nil) and FSections[C].Available then Inc(N);
  end;
  Columns:=Max(1,(ClientWidth-2*MARGIN) div ICON_PITCH);
  Result:=Rect(MARGIN+(N mod Columns)*ICON_PITCH,MARGIN+(N div Columns)*ICON_PITCH,
    MARGIN+(N mod Columns)*ICON_PITCH+ICON_SIZE,MARGIN+(N div Columns)*ICON_PITCH+ICON_SIZE);
end;
procedure TVectArtSettingsSections.RefreshSections;
var C: TVectArtSettingsCategory; R: TRect; Header: Integer;
begin
  if (FActiveSection=nil) or not FActiveSection.Available then
  begin
    FActiveSection:=FSections[vscInfo];
    if (FActiveSection=nil) or not FActiveSection.Available then
      for C:=Low(C) to High(C) do
        if (FSections[C]<>nil) and FSections[C].Available then
        begin FActiveSection:=FSections[C]; Break; end;
  end;
  Header:=0;
  for C:=Low(C) to High(C) do
  begin R:=IconRect(C); Header:=Max(Header,R.Bottom); end;
  FHeaderHeight:=Header+28;
  // 全パネルは兄弟として置き、非選択パネルが入力欄の上に重ならないようにする。
  for C:=Low(C) to High(C) do
    if FSections[C]<>nil then
    begin
      FSections[C].SetBounds(0,FHeaderHeight,ClientWidth,Max(0,ClientHeight-FHeaderHeight));
      FSections[C].Visible:=FSections[C]=FActiveSection;
    end;
  R:=Rect(0,0,ClientWidth,FHeaderHeight);
  if HandleAllocated then InvalidateRect(Handle,@R,False);
end;
procedure TVectArtSettingsSections.SetActiveSection(Value: TVectArtSettingsPanel);
begin
  if (Value=nil) or not Value.Available or (Value.Parent<>Self) or (FActiveSection=Value) then Exit;
  // 編集欄のOnExitを、非表示へ切り替える前に通常のフォーカス移動で確定させる。
  if CanFocus then SetFocus;
  if FActiveSection<>nil then FActiveSection.Visible:=False;
  FActiveSection:=Value; RefreshSections;
  if Value.HandleAllocated then
    RedrawWindow(Value.Handle,nil,0,RDW_INVALIDATE or RDW_ERASE or RDW_ALLCHILDREN);
  if Assigned(FOnChange) then FOnChange(Self);
end;
procedure TVectArtSettingsSections.DrawIcon(Category: TVectArtSettingsCategory; const Bounds: TRect);
var X,Y: Integer;
begin
  X:=(Bounds.Left+Bounds.Right) div 2; Y:=(Bounds.Top+Bounds.Bottom) div 2;
  Canvas.Brush.Style:=bsSolid;
  if FSections[Category]=FActiveSection then Canvas.Brush.Color:=TColor($0046382B)
  else Canvas.Brush.Color:=TColor($002D2D2D);
  Canvas.Pen.Color:=Canvas.Brush.Color; Canvas.Rectangle(Bounds);
  if FSections[Category]=FActiveSection then
  begin Canvas.Pen.Color:=TColor($00D69C4A); Canvas.MoveTo(Bounds.Left+3,Bounds.Bottom-2); Canvas.LineTo(Bounds.Right-3,Bounds.Bottom-2); end;
  Canvas.Pen.Color:=TColor($00EEEEEE); Canvas.Pen.Width:=2; Canvas.Brush.Style:=bsClear;
  case Category of
    vscLine: begin Canvas.MoveTo(X-10,Y+8); Canvas.LineTo(X+10,Y-8); end;
    vscStroke: begin
      Canvas.Rectangle(X-10,Y-8,X+10,Y+8);
      Canvas.Pen.Color:=TColor($0060C0F0); Canvas.MoveTo(X-10,Y+8); Canvas.LineTo(X+10,Y-8);
    end;
    vscFill: begin
      Canvas.Brush.Style:=bsSolid; Canvas.Brush.Color:=TColor($0060C0F0);
      Canvas.Polygon([Point(X,Y-10),Point(X+10,Y),Point(X,Y+10),Point(X-10,Y)]);
    end;
    vscShadow: begin
      Canvas.Brush.Style:=bsSolid; Canvas.Brush.Color:=clGray; Canvas.Pen.Color:=clGray;
      Canvas.Rectangle(X-4,Y-4,X+12,Y+12); Canvas.Brush.Color:=TColor($002D2D2D);
      Canvas.Pen.Color:=clWhite; Canvas.Rectangle(X-11,Y-11,X+5,Y+5);
    end;
    vscOutline: begin Canvas.Rectangle(X-11,Y-11,X+11,Y+11); Canvas.Rectangle(X-6,Y-6,X+6,Y+6); end;
    vscEffects: begin
      Canvas.MoveTo(X,Y-12); Canvas.LineTo(X,Y+12); Canvas.MoveTo(X-12,Y); Canvas.LineTo(X+12,Y);
      Canvas.MoveTo(X-8,Y-8); Canvas.LineTo(X+8,Y+8); Canvas.MoveTo(X-8,Y+8); Canvas.LineTo(X+8,Y-8);
    end;
    vscInfo,vscText: begin
      Canvas.Font.Assign(Font); Canvas.Font.Size:=17; Canvas.Font.Style:=[fsBold]; Canvas.Font.Color:=clWhite;
      if Category=vscInfo then Canvas.TextOut(X-4,Y-14,'i') else Canvas.TextOut(X-9,Y-14,'T');
    end;
  end;
  Canvas.Pen.Width:=1; Canvas.Brush.Style:=bsSolid;
end;
procedure TVectArtSettingsSections.Paint;
var C: TVectArtSettingsCategory; R: TRect;
begin
  // 背景描画はアイコン帯だけに限定する。パネル内のネイティブ入力欄を上描きしない。
  Canvas.Brush.Color:=Color; Canvas.FillRect(Rect(0,0,ClientWidth,FHeaderHeight));
  for C:=Low(C) to High(C) do
  begin R:=IconRect(C); if not R.IsEmpty then DrawIcon(C,R); end;
  if FActiveSection<>nil then
  begin
    Canvas.Font.Assign(Font); Canvas.Font.Height:=VECTART_SETTINGS_FONT_HEIGHT; Canvas.Brush.Style:=bsClear;
    Canvas.TextOut(12,FHeaderHeight-21,FActiveSection.Caption); Canvas.Brush.Style:=bsSolid;
  end;
end;
procedure TVectArtSettingsSections.Resize;
begin inherited; RefreshSections; end;
procedure TVectArtSettingsSections.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin Message.Result:=1; end;
procedure TVectArtSettingsSections.MouseDown(Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
var C: TVectArtSettingsCategory;
begin
  inherited;
  if Button<>mbLeft then Exit;
  for C:=Low(C) to High(C) do
    if PtInRect(IconRect(C),Point(X,Y)) then begin ActiveSection:=FSections[C]; Exit; end;
end;
procedure TVectArtSettingsSections.MouseMove(Shift: TShiftState; X,Y: Integer);
var C: TVectArtSettingsCategory; Text: string;
begin
  inherited; Text:='';
  for C:=Low(C) to High(C) do
    if PtInRect(IconRect(C),Point(X,Y)) then begin Text:=FSections[C].Caption; Break; end;
  if Hint<>Text then begin Application.CancelHint; Hint:=Text; end;
end;
procedure TVectArtSettingsSections.KeyDown(var Key: Word; Shift: TShiftState);
var Index,Step,N: Integer;
begin
  inherited;
  if not (Key in [VK_LEFT,VK_RIGHT,VK_UP,VK_DOWN]) or (FActiveSection=nil) then Exit;
  if Key in [VK_LEFT,VK_UP] then Step:=-1 else Step:=1;
  Index:=Ord(FActiveSection.Category);
  for N:=1 to SectionCount do
  begin
    Index:=(Index+Step+SectionCount) mod SectionCount;
    if (Sections[Index]<>nil) and Sections[Index].Available then
    begin ActiveSection:=Sections[Index]; Break; end;
  end;
  Key:=0;
end;
end.
