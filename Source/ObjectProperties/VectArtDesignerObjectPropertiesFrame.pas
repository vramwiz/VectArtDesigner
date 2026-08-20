// 選択オブジェクト設定ツールのFrame外枠を提供する。
unit VectArtDesignerObjectPropertiesFrame;

interface

uses
  System.Classes, VectArtDesignerDocument,
  VectArtDesignerEditHistory, VectArtDesignerEditorState,
  VectArtDesignerObjectPropertiesControl, VectArtDesignerToolFrames;

type
  TObjectPropertiesFrame = class(TToolPlaceholderFrame)
  private
    FPropertiesControl: TVectArtObjectPropertiesControl;
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
  end;

implementation

uses
  Vcl.Controls, Vcl.Graphics;

{$R VectArtDesignerObjectPropertiesFrame.dfm}

const
  COLOR_PANEL_BACKGROUND = TColor($00212121);

constructor TObjectPropertiesFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ConfigureToolAppearance('ObjectProperties', 'Object Properties',
    COLOR_PANEL_BACKGROUND, 290);
  TitleLabel.Visible := False;
  FPropertiesControl := TVectArtObjectPropertiesControl.Create(Self);
  FPropertiesControl.Parent := Self;
  FPropertiesControl.Align := alClient;
end;

function TObjectPropertiesFrame.GetDocument: TVectArtDocument;
begin
  Result := FPropertiesControl.Document;
end;

function TObjectPropertiesFrame.GetEditHistory: TVectArtEditHistory;
begin
  Result := FPropertiesControl.EditHistory;
end;

function TObjectPropertiesFrame.GetEditorState: TVectArtEditorState;
begin
  Result := FPropertiesControl.EditorState;
end;

procedure TObjectPropertiesFrame.RefreshFromDocument;
begin
  FPropertiesControl.RefreshFromDocument;
end;

procedure TObjectPropertiesFrame.SetDocument(const Value: TVectArtDocument);
begin
  FPropertiesControl.Document := Value;
end;

procedure TObjectPropertiesFrame.SetEditHistory(
  const Value: TVectArtEditHistory);
begin
  FPropertiesControl.EditHistory := Value;
end;

procedure TObjectPropertiesFrame.SetEditorState(
  const Value: TVectArtEditorState);
begin
  FPropertiesControl.EditorState := Value;
end;

end.
