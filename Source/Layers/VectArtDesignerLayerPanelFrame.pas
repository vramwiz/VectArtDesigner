// レイヤーツールのFrameを提供し、Documentをレイヤー一覧へ接続する。
unit VectArtDesignerLayerPanelFrame;

interface

uses
  System.Classes, VectArtDesignerContext, VectArtDesignerLayerActions,
  VectArtDesignerLayerList, VectArtDesignerToolFrames;

type
  TLayerPanelFrame = class(TToolPlaceholderFrame)
  private
    FLayerList: TVectArtLayerListControl;
    FLayerActions: TVectArtLayerActionsControl;
    FContext: IVectArtDesignerContext;
    procedure SetContext(const Value: IVectArtDesignerContext);
  public
    constructor Create(AOwner: TComponent); override;
    procedure RefreshFromDocument;
    // Contextを交換すると、一覧と操作バーへ同じサービス一式を接続する。
    property Context: IVectArtDesignerContext read FContext write SetContext;
    property LayerList: TVectArtLayerListControl read FLayerList;
  end;

implementation

uses
  Vcl.Controls, Vcl.Graphics;

{$R VectArtDesignerLayerPanelFrame.dfm}

const
  COLOR_PANEL_BACKGROUND = TColor($00212121);

constructor TLayerPanelFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ConfigureToolAppearance('Layers', 'Layers', COLOR_PANEL_BACKGROUND, 224);
  TitleLabel.Visible := False;
  FLayerList := TVectArtLayerListControl.Create(Self);
  FLayerList.Parent := Self;
  FLayerList.Align := alClient;
  FLayerActions := TVectArtLayerActionsControl.Create(Self);
  FLayerActions.Parent := Self;
  FLayerActions.Align := alBottom;
  FLayerActions.Height := 34;
  FLayerActions.BringToFront;
end;

procedure TLayerPanelFrame.RefreshFromDocument;
begin
  FLayerList.Invalidate;
  FLayerActions.RefreshState;
end;

procedure TLayerPanelFrame.SetContext(const Value: IVectArtDesignerContext);
begin
  FContext := Value;
  if FContext = nil then
  begin
    FLayerActions.EditorState := nil;
    FLayerActions.EditHistory := nil;
    FLayerActions.Document := nil;
    FLayerList.EditHistory := nil;
    FLayerList.Document := nil;
  end
  else
  begin
    FLayerList.Document := FContext.Document;
    FLayerList.EditHistory := FContext.EditHistory;
    FLayerActions.Document := FContext.Document;
    FLayerActions.EditHistory := FContext.EditHistory;
    FLayerActions.EditorState := FContext.EditorState;
  end;
end;

end.
