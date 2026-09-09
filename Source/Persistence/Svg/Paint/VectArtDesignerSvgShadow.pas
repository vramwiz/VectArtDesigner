// 単一図形の影を標準SVG feDropShadowへ変換し、整数パラメータを再読込する。
unit VectArtDesignerSvgShadow;
interface
uses System.SysUtils, System.Types, Xml.XMLIntf, VectArtDesignerDocument;
function SvgShadowDefinition(Index: Integer; Layer: TVectArtLayer): string;
function ReadSvgShadow(const Node: IXMLNode): TVectArtShadow;
implementation
uses System.Variants, System.Math, VectArtDesignerSvgPrimitives, VectArtDesignerSvgPaintReader,
  VectArtDesignerGeometry, VectArtDesignerBezierGeometry, VectArtDesignerShadowPaint;
function SvgShadowDefinition(Index: Integer; Layer: TVectArtLayer): string;
var Bounds: TRectF; Value: TVectArtShadow; Width: Single;
begin
  Result:=''; Value:=Layer.Shadow; if not Value.Enabled then Exit;
  if Layer is TVectArtRectangleLayer then
  begin
    Bounds:=QuadBounds(RectangleCorners(TVectArtRectangleLayer(Layer).Bounds,
      TVectArtRectangleLayer(Layer).RotationDegrees));
    Width:=TVectArtRectangleLayer(Layer).StrokeWidth;
  end
  else if Layer is TVectArtPathLayer then
  begin
    Bounds:=PointsBounds(BuildPathDisplayPolyline(TVectArtPathLayer(Layer).Points,
      TVectArtPathLayer(Layer).Bezier,TVectArtPathLayer(Layer).Closed,16));
    Width:=TVectArtPathLayer(Layer).StrokeWidth;
  end
  else Exit;
  Bounds.Inflate(Width*0.5+1,Width*0.5+1);
  Bounds:=ShadowBounds(Bounds,Value);
  Result:=Format('<filter id="shadow%d" x="%s" y="%s" width="%s" height="%s" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"><feDropShadow dx="%d" dy="%d" stdDeviation="%d" flood-color="%s"/></filter>',
    [Index,SvgNumber(Bounds.Left),SvgNumber(Bounds.Top),SvgNumber(Bounds.Width),SvgNumber(Bounds.Height),
    Value.OffsetX,Value.OffsetY,Value.Blur,SvgColor(Value.Color)]);
end;
function FindId(const Node: IXMLNode; const Id: string): IXMLNode;
var I: Integer;
begin
  Result:=nil; if Node=nil then Exit;
  if Node.HasAttribute('id') and (VarToStr(Node.Attributes['id'])=Id) then Exit(Node);
  for I:=0 to Node.ChildNodes.Count-1 do
  begin Result:=FindId(Node.ChildNodes[I],Id); if Result<>nil then Exit; end;
end;
function ReadSvgShadow(const Node: IXMLNode): TVectArtShadow;
var N,Filter,Effect: IXMLNode; Ref: string; V: TVectArtShadow; I,Elements: Integer;
begin
  Result:=Default(TVectArtShadow); V:=Result; N:=Node;
  while N<>nil do
  begin
    if N.HasAttribute('filter') then Break;
    N:=N.ParentNode;
  end;
  if N=nil then Exit;
  Ref:=VarToStr(N.Attributes['filter']);
  if (Copy(Ref,1,5)<>'url(#') or (Copy(Ref,Length(Ref),1)<>')') then Exit;
  Filter:=FindId(Node.OwnerDocument.DocumentElement,Copy(Ref,6,Length(Ref)-6));
  if Filter=nil then Exit;
  Elements:=0;
  for I:=0 to Filter.ChildNodes.Count-1 do
    if Filter.ChildNodes[I].NodeType=ntElement then Inc(Elements);
  if Elements<>1 then Exit;
  Effect:=Filter.ChildNodes.FindNode('feDropShadow'); if Effect=nil then Exit;
  if Effect.HasAttribute('flood-opacity') and (VarToStr(Effect.Attributes['flood-opacity'])<>'1') then Exit;
  if not TryStrToInt(VarToStr(Effect.Attributes['dx']),V.OffsetX) or
    not TryStrToInt(VarToStr(Effect.Attributes['dy']),V.OffsetY) or
    not TryStrToInt(VarToStr(Effect.Attributes['stdDeviation']),V.Blur) or
    not TryParseSvgColor(VarToStr(Effect.Attributes['flood-color']),V.Color) then Exit;
  if not InRange(V.Blur,0,100) or not InRange(V.OffsetX,-10000,10000) or not InRange(V.OffsetY,-10000,10000) then Exit;
  V.Enabled:=True; Result:=V;
end;
end.
