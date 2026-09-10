// ドキュメントごとの最近使用色を保持し、読込済み図形から初期履歴を構築する。
// 基本色パレットやUndo、ドキュメントの変更状態には関与しない。
unit VectArtDesignerColorHistory;

interface

uses
  System.Generics.Collections, Vcl.Graphics, VectArtDesignerDocument;

type
  TVectArtColorHistory = class
  private
    FColors: TList<TColor>;
    function GetColors: TArray<TColor>;
    procedure AppendLoadedColor(Color: TColor);
    procedure AppendPaint(Color: TColor; const Fill: TVectArtFillStyle);
  public
    const MaximumCount = 16;
    constructor Create;
    destructor Destroy; override;
    procedure Add(Color: TColor);
    procedure Clear;
    procedure LoadFromDocument(Document: TVectArtDocument);
    property Colors: TArray<TColor> read GetColors;
  end;

implementation

uses
  System.SysUtils;

constructor TVectArtColorHistory.Create;
begin
  inherited Create;
  FColors := TList<TColor>.Create;
end;

destructor TVectArtColorHistory.Destroy;
begin
  FColors.Free;
  inherited;
end;

procedure TVectArtColorHistory.Add(Color: TColor);
var
  I: Integer;
begin
  Color := ColorToRGB(Color);
  for I := FColors.Count - 1 downto 0 do
    if ColorToRGB(FColors[I]) = Color then
      FColors.Delete(I);
  FColors.Insert(0, Color);
  while FColors.Count > MaximumCount do
    FColors.Delete(FColors.Count - 1);
end;

procedure TVectArtColorHistory.AppendLoadedColor(Color: TColor);
var
  Existing: TColor;
begin
  if FColors.Count >= MaximumCount then
    Exit;
  Color := ColorToRGB(Color);
  for Existing in FColors do
    if ColorToRGB(Existing) = Color then
      Exit;
  FColors.Add(Color);
end;

procedure TVectArtColorHistory.AppendPaint(Color: TColor;
  const Fill: TVectArtFillStyle);
begin
  // 画像の画素色は履歴に展開せず、実際に色指定として使う塗りだけを収集する。
  if Fill.Kind = vfkTexture then
    Exit;
  AppendLoadedColor(Color);
  if Fill.Kind in [vfkLinearHorizontal, vfkLinearVertical, vfkRadial,
    vfkCircle, vfkSquare, vfkWave] then
    AppendLoadedColor(Fill.Color2);
end;

procedure TVectArtColorHistory.Clear;
begin
  FColors.Clear;
end;

function TVectArtColorHistory.GetColors: TArray<TColor>;
begin
  Result := FColors.ToArray;
end;

procedure TVectArtColorHistory.LoadFromDocument(Document: TVectArtDocument);
var
  I: Integer;
  Layer: TVectArtLayer;
  Line: TVectArtLineLayer;
  Path: TVectArtPathLayer;
  Rectangle: TVectArtRectangleLayer;
  TextLayer: TVectArtTextLayer;
begin
  Clear;
  if Document = nil then
    Exit;
  if (Document.CanvasLayer <> nil) and not Document.CanvasLayer.Transparent then
    AppendLoadedColor(Document.CanvasLayer.BackgroundColor);
  // 前面側から走査し、読込直後に目につくオブジェクトの色を優先する。
  for I := Document.LayerCount - 1 downto 1 do
  begin
    Layer := Document[I];
    if Layer.Shadow.Enabled then
      AppendLoadedColor(Layer.Shadow.Color);
    if Layer is TVectArtRectangleLayer then
    begin
      Rectangle := TVectArtRectangleLayer(Layer);
      if Rectangle.Filled then
        AppendPaint(Rectangle.FillColor, Rectangle.FillStyle);
      if Rectangle.StrokeWidth > 0 then
        AppendPaint(Rectangle.StrokeColor, Rectangle.StrokePaint);
    end
    else if Layer is TVectArtLineLayer then
    begin
      Line := TVectArtLineLayer(Layer);
      if Line.StrokeWidth > 0 then
        AppendPaint(Line.StrokeColor, Line.StrokePaint);
    end
    else if Layer is TVectArtPathLayer then
    begin
      Path := TVectArtPathLayer(Layer);
      if Path.Closed and Path.Filled then
        AppendPaint(Path.FillColor, Path.FillStyle);
      if Path.StrokeWidth > 0 then
        AppendPaint(Path.StrokeColor, Path.StrokePaint);
    end
    else if Layer is TVectArtTextLayer then
    begin
      TextLayer := TVectArtTextLayer(Layer);
      AppendPaint(TextLayer.TextColor, TextLayer.FillStyle);
    end;
  end;
end;

end.
