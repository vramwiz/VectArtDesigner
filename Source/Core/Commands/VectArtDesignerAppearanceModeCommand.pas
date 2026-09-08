// 枠と塗りの表示方式を既存属性へ適用し、切替全体を1件のUndoにする。
unit VectArtDesignerAppearanceModeCommand;

interface

uses VectArtDesignerDocument, VectArtDesignerEditCommands, VectArtDesignerEditorState;

type
  TVectArtAppearanceModeCommand = class(TVectArtEditCommand)
  private
    FDocument: TVectArtDocument;
    FIndex: Integer;
    FBeforeFill, FAfterFill: Boolean;
    FBeforeWidth, FAfterWidth: Single;
    procedure Apply(Filled: Boolean; Width: Single);
  public
    constructor Create(Document: TVectArtDocument; Index: Integer; Mode: TVectArtRectangleMode);
    procedure Execute; override;
    procedure Undo; override;
  end;

implementation

uses System.Math;

constructor TVectArtAppearanceModeCommand.Create(Document: TVectArtDocument;
  Index: Integer; Mode: TVectArtRectangleMode);
begin
  inherited Create;
  FDocument := Document; FIndex := Index;
  if Document[Index] is TVectArtRectangleLayer then
  begin
    FBeforeFill := TVectArtRectangleLayer(Document[Index]).Filled;
    FBeforeWidth := TVectArtRectangleLayer(Document[Index]).StrokeWidth;
  end
  else
  begin
    FBeforeFill := TVectArtPathLayer(Document[Index]).Filled;
    FBeforeWidth := TVectArtPathLayer(Document[Index]).StrokeWidth;
  end;
  FAfterFill := VectArtRectangleModeHasFill(Mode);
  FAfterWidth := 0;
  if VectArtRectangleModeHasStroke(Mode) then FAfterWidth := Max(1,FBeforeWidth);
end;

procedure TVectArtAppearanceModeCommand.Apply(Filled: Boolean; Width: Single);
begin
  if FDocument[FIndex] is TVectArtRectangleLayer then
  begin
    TVectArtRectangleLayer(FDocument[FIndex]).Filled := Filled;
    TVectArtRectangleLayer(FDocument[FIndex]).StrokeWidth := Width;
  end
  else if FDocument[FIndex] is TVectArtPathLayer then
  begin
    TVectArtPathLayer(FDocument[FIndex]).Filled := Filled and TVectArtPathLayer(FDocument[FIndex]).Closed;
    TVectArtPathLayer(FDocument[FIndex]).StrokeWidth := Width;
  end;
  FDocument.ChangedLayer(FIndex);
end;

procedure TVectArtAppearanceModeCommand.Execute;
begin Apply(FAfterFill,FAfterWidth); end;

procedure TVectArtAppearanceModeCommand.Undo;
begin Apply(FBeforeFill,FBeforeWidth); end;

end.
