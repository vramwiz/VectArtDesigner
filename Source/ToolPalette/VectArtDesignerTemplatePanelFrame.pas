// テンプレ図形一覧を独立したドッキング可能Frameとして提供する。
unit VectArtDesignerTemplatePanelFrame;

interface

uses
  System.Classes, VectArtDesignerContext, VectArtDesignerTemplatePicker,
  VectArtDesignerToolFrames;

type
  TTemplatePanelFrame = class(TToolPlaceholderFrame)
  private
    FContext: IVectArtDesignerContext;
    FPicker: TVectArtTemplatePicker;
    procedure SetContext(const Value: IVectArtDesignerContext);
  public
    constructor Create(AOwner: TComponent); override;
    procedure RefreshState;
    property Context: IVectArtDesignerContext read FContext write SetContext;
  end;

implementation

uses
  Vcl.Controls, Vcl.Graphics;

{$R VectArtDesignerTemplatePanelFrame.dfm}

const
  COLOR_TEMPLATE_BACKGROUND = TColor($00252525);
  TEMPLATE_PANEL_WIDTH = 199;

constructor TTemplatePanelFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ConfigureToolAppearance('Templates', 'テンプレ図形',
    COLOR_TEMPLATE_BACKGROUND, TEMPLATE_PANEL_WIDTH);
  TitleLabel.Visible := False;
  FPicker := TVectArtTemplatePicker.Create(Self);
  FPicker.Parent := Self;
  FPicker.Align := alClient;
end;

procedure TTemplatePanelFrame.RefreshState;
begin
  FPicker.Refresh;
end;

procedure TTemplatePanelFrame.SetContext(
  const Value: IVectArtDesignerContext);
begin
  FContext := Value;
  if FContext = nil then
    FPicker.Open(nil)
  else
    FPicker.Open(FContext.EditorState);
end;

end.
