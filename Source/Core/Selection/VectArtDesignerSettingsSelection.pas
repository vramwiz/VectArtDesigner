// 設定の適用対象を選択状態から抽出する。UIや履歴を変更せず、対象分類を一元化する。
// Boundsは従来の四角選択専用であり、Pathや文字の外接矩形へ意味を広げない。
unit VectArtDesignerSettingsSelection;
interface
uses System.Types, VectArtDesignerDocument;
function GetSelectedFillIndices(Document: TVectArtDocument):
  TArray<Integer>;
function GetSelectedOpacityIndices(Document: TVectArtDocument):
  TArray<Integer>;
function GetSelectedRectangleIndices(Document: TVectArtDocument):
  TArray<Integer>;
function GetSelectedStrokeIndices(Document: TVectArtDocument):
  TArray<Integer>;
function SelectedLayersHaveLock(Document: TVectArtDocument): Boolean;
function SelectedBounds(Document: TVectArtDocument;
  out Bounds: TRectF): Boolean;
implementation
uses System.Generics.Collections, System.Math;
function GetSelectedFillIndices(Document: TVectArtDocument):
  TArray<Integer>;
var
  I: Integer;
  Indices: TList<Integer>;
begin
  Indices := TList<Integer>.Create;
  try
    if Document <> nil then
      for I := 1 to Document.LayerCount - 1 do
        if Document.IsLayerSelected(I) and
          ((Document[I] is TVectArtRectangleLayer) or
           (Document[I] is TVectArtPathLayer) or
           (Document[I] is TVectArtTextLayer)) then
          Indices.Add(I);
    Result := Indices.ToArray;
  finally
    Indices.Free;
  end;
end;

function GetSelectedOpacityIndices(Document: TVectArtDocument):
  TArray<Integer>;
var
  I: Integer;
  Indices: TList<Integer>;
begin
  Indices := TList<Integer>.Create;
  try
    if Document <> nil then
      for I := 1 to Document.LayerCount - 1 do
        if Document.IsLayerSelected(I) and
          ((Document[I] is TVectArtRectangleLayer) or
           (Document[I] is TVectArtLineLayer) or
           (Document[I] is TVectArtPathLayer) or
           (Document[I] is TVectArtImageLayer) or
           (Document[I] is TVectArtTextLayer)) then
          Indices.Add(I);
    Result := Indices.ToArray;
  finally
    Indices.Free;
  end;
end;

function GetSelectedRectangleIndices(Document: TVectArtDocument):
  TArray<Integer>;
var
  I: Integer;
  Indices: TList<Integer>;
begin
  Indices := TList<Integer>.Create;
  try
    if Document <> nil then
      for I := 1 to Document.LayerCount - 1 do
        if Document.IsLayerSelected(I) and
          (Document[I] is TVectArtRectangleLayer) then
          Indices.Add(I);
    Result := Indices.ToArray;
  finally
    Indices.Free;
  end;
end;

function GetSelectedStrokeIndices(Document: TVectArtDocument):
  TArray<Integer>;
var
  I: Integer;
  Indices: TList<Integer>;
begin
  Indices := TList<Integer>.Create;
  try
    if Document <> nil then
      for I := 1 to Document.LayerCount - 1 do
        if Document.IsLayerSelected(I) and
          ((Document[I] is TVectArtRectangleLayer) or
           (Document[I] is TVectArtLineLayer) or
           (Document[I] is TVectArtPathLayer)) then
          Indices.Add(I);
    Result := Indices.ToArray;
  finally
    Indices.Free;
  end;
end;

function SelectedLayersHaveLock(Document: TVectArtDocument): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Document = nil then
    Exit;
  for I := 1 to Document.LayerCount - 1 do
    if Document.IsLayerSelected(I) and Document[I].Locked then
      Exit(True);
end;

function SelectedBounds(Document: TVectArtDocument;
  out Bounds: TRectF): Boolean;
var
  I: Integer;
  LayerBounds: TRectF;
begin
  Bounds := TRectF.Empty;
  Result := False;
  if Document = nil then
    Exit;
  for I := 1 to Document.LayerCount - 1 do
    if Document.IsLayerSelected(I) and
      (Document[I] is TVectArtRectangleLayer) then
    begin
      LayerBounds := TVectArtRectangleLayer(Document[I]).Bounds;
      if not Result then
      begin
        Bounds := LayerBounds;
        Result := True;
      end
      else
      begin
        Bounds.Left := Min(Bounds.Left, LayerBounds.Left);
        Bounds.Top := Min(Bounds.Top, LayerBounds.Top);
        Bounds.Right := Max(Bounds.Right, LayerBounds.Right);
        Bounds.Bottom := Max(Bounds.Bottom, LayerBounds.Bottom);
      end;
    end;
end;

end.
