// 編集ツールパレットのFrame外枠を提供する。
unit VectArtDesignerToolPaletteFrame;

interface

uses
  System.Classes, VectArtDesignerEditorState, VectArtDesignerToolFrames,
  VectArtDesignerToolPalette;

type
  TToolPaletteFrame = class(TToolPlaceholderFrame)
  private
    FToolPalette: TVectArtToolPaletteControl;
    function GetEditorState: TVectArtEditorState;
    procedure SetEditorState(const Value: TVectArtEditorState);
  public
    constructor Create(AOwner: TComponent); override;
    procedure RefreshState;
    property EditorState: TVectArtEditorState read GetEditorState
      write SetEditorState;
  end;

implementation

uses
  Vcl.Controls, Vcl.Graphics;

{$R VectArtDesignerToolPaletteFrame.dfm}

const
  COLOR_TOOL_BACKGROUND = TColor($00252525);

constructor TToolPaletteFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ConfigureToolAppearance('Tools', 'Tools', COLOR_TOOL_BACKGROUND, 58);
  TitleLabel.Visible := False;
  FToolPalette := TVectArtToolPaletteControl.Create(Self);
  FToolPalette.Parent := Self;
  FToolPalette.Align := alClient;
end;

function TToolPaletteFrame.GetEditorState: TVectArtEditorState;
begin
  Result := FToolPalette.EditorState;
end;

procedure TToolPaletteFrame.RefreshState;
begin
  FToolPalette.RefreshState;
end;

procedure TToolPaletteFrame.SetEditorState(const Value: TVectArtEditorState);
begin
  FToolPalette.EditorState := Value;
end;

end.
