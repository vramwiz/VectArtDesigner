// 影の一式を1件の履歴にし、対象レイヤーだけの描画キャッシュを失効させる。
unit VectArtDesignerShadowCommand;
interface
uses VectArtDesignerDocument, VectArtDesignerEditCommands;
type TVectArtShadowCommand = class(TVectArtEditCommand)
private
  FDocument: TVectArtDocument;
  FIndex: Integer;
  FBefore, FAfter: TVectArtShadow;
  procedure Apply(const Value: TVectArtShadow);
public
  constructor Create(Document: TVectArtDocument; Index: Integer; const Value: TVectArtShadow);
  procedure Execute; override;
  procedure Undo; override;
end;
implementation
constructor TVectArtShadowCommand.Create(Document: TVectArtDocument; Index: Integer; const Value: TVectArtShadow);
begin inherited Create; FDocument:=Document; FIndex:=Index; FBefore:=Document[Index].Shadow; FAfter:=Value; end;
procedure TVectArtShadowCommand.Apply(const Value: TVectArtShadow);
begin FDocument[FIndex].Shadow:=Value; FDocument.ChangedLayer(FIndex); end;
procedure TVectArtShadowCommand.Execute;
begin Apply(FAfter); end;
procedure TVectArtShadowCommand.Undo;
begin Apply(FBefore); end;
end.
