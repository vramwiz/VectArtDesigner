// レイヤーツールのFrameを提供し、Documentをレイヤー一覧へ接続する。
unit VectArtDesignerLayerPanelFrame;

interface

uses
  System.Classes, VectArtDesignerDocument, VectArtDesignerEditHistory,
  VectArtDesignerEditorState, VectArtDesignerLayerActions, VectArtDesignerLayerList,
  VectArtDesignerToolFrames;

type
  TLayerPanelFrame = class(TToolPlaceholderFrame)
  private
    FLayerList: TVectArtLayerListControl;
    FLayerActions: TVectArtLayerActionsControl;
    function GetDocument: TVectArtDocument;
    function GetEditHistory: TVectArtEditHistory;
    function GetEditorState: TVectArtEditorState;
    procedure SetDocument(const Value: TVectArtDocument);
    procedure SetEditHistory(const Value: TVectArtEditHistory);
    procedure SetEditorState(const Value: TVectArtEditorState);
  public
    constructor Create(AOwner: TComponent); override;
    procedure RefreshFromDocument;
    property Document: TVectArtDocument read GetDocument write SetDocument;
    property EditHistory: TVectArtEditHistory read GetEditHistory
      write SetEditHistory;
    property EditorState: TVectArtEditorState read GetEditorState
      write SetEditorState;
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

function TLayerPanelFrame.GetDocument: TVectArtDocument;
begin
  Result := FLayerList.Document;
end;

function TLayerPanelFrame.GetEditHistory: TVectArtEditHistory;
begin
  Result := FLayerActions.EditHistory;
end;

function TLayerPanelFrame.GetEditorState: TVectArtEditorState;
begin
  Result := FLayerActions.EditorState;
end;

procedure TLayerPanelFrame.RefreshFromDocument;
begin
  FLayerList.Invalidate;
  FLayerActions.RefreshState;
end;

procedure TLayerPanelFrame.SetDocument(const Value: TVectArtDocument);
begin
  FLayerList.Document := Value;
  FLayerActions.Document := Value;
end;

procedure TLayerPanelFrame.SetEditHistory(const Value: TVectArtEditHistory);
begin
  FLayerList.EditHistory := Value;
  FLayerActions.EditHistory := Value;
end;

procedure TLayerPanelFrame.SetEditorState(const Value: TVectArtEditorState);
begin
  FLayerActions.EditorState := Value;
end;

end.
