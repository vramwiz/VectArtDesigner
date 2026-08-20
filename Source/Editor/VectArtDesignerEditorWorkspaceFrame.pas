// 中央編集領域のFrameを提供し、Documentを編集キャンバスへ接続する。
unit VectArtDesignerEditorWorkspaceFrame;

interface

uses
  System.Classes, VectArtDesignerCanvas, VectArtDesignerDocument,
  VectArtDesignerEditHistory, VectArtDesignerEditorState,
  VectArtDesignerToolFrames;

type
  TEditorWorkspaceFrame = class(TPlaceholderFrame)
  private
    FCanvasControl: TVectArtCanvasControl;
    function GetDocument: TVectArtDocument;
    function GetEditHistory: TVectArtEditHistory;
    function GetEditorState: TVectArtEditorState;
    procedure SetDocument(const Value: TVectArtDocument);
    procedure SetEditHistory(const Value: TVectArtEditHistory);
    procedure SetEditorState(const Value: TVectArtEditorState);
  public
    constructor Create(AOwner: TComponent); override;
    property CanvasControl: TVectArtCanvasControl read FCanvasControl;
    property Document: TVectArtDocument read GetDocument write SetDocument;
    property EditHistory: TVectArtEditHistory read GetEditHistory
      write SetEditHistory;
    property EditorState: TVectArtEditorState read GetEditorState
      write SetEditorState;
  end;

implementation

uses
  Vcl.Controls, Vcl.Graphics;

{$R VectArtDesignerEditorWorkspaceFrame.dfm}

const
  COLOR_EDITOR_BACKGROUND = TColor($00121212);

constructor TEditorWorkspaceFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  SetPlaceholderAppearance('Editor Workspace', COLOR_EDITOR_BACKGROUND);
  TitleLabel.Visible := False;
  FCanvasControl := TVectArtCanvasControl.Create(Self);
  FCanvasControl.Parent := Self;
  FCanvasControl.Align := alClient;
end;

function TEditorWorkspaceFrame.GetDocument: TVectArtDocument;
begin
  Result := FCanvasControl.Document;
end;

function TEditorWorkspaceFrame.GetEditHistory: TVectArtEditHistory;
begin
  Result := FCanvasControl.EditHistory;
end;

function TEditorWorkspaceFrame.GetEditorState: TVectArtEditorState;
begin
  Result := FCanvasControl.EditorState;
end;

procedure TEditorWorkspaceFrame.SetDocument(const Value: TVectArtDocument);
begin
  FCanvasControl.Document := Value;
end;

procedure TEditorWorkspaceFrame.SetEditHistory(
  const Value: TVectArtEditHistory);
begin
  FCanvasControl.EditHistory := Value;
end;

procedure TEditorWorkspaceFrame.SetEditorState(
  const Value: TVectArtEditorState);
begin
  FCanvasControl.EditorState := Value;
end;

end.
