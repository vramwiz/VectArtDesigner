// MIF変換の公開窓口と書出し互換性の判定を担当し、読込・PNG描画・属性変換を専用ユニットへ委譲する。
// MIF保存では独自情報を出力せず、読み込み元の互換用ベクター情報を可能な範囲で再利用する。
unit VectArtDesignerMifDocument;

interface

uses
  System.SysUtils, VectArtDesignerDocument, VectArtDesignerMifContainer;

type
  TMifExportCompatibility = (mecExact, mecNeedsConfirmation, mecUnsupported);
  TMifExportIssueKind = (meikConversion, meikUnsupported, meikUnchecked);

  TMifExportIssue = record
    Kind: TMifExportIssueKind; // 変換、非対応、未判定の区分。
    LayerIndex: Integer;      // Document内の対象レイヤー位置。
    LayerName: string;        // 確認画面へ表示するレイヤー名。
    MessageText: string;      // 実際に行う変換または保存できない内容。
  end;

  TMifExportReport = record
    Compatibility: TMifExportCompatibility; // MIF生成全体の判定結果。
    Issues: TArray<TMifExportIssue>;         // 生成処理が検出した注意事項。
    procedure AddIssue(AKind: TMifExportIssueKind; ALayerIndex: Integer;
      const ALayerName, AMessageText: string);
    procedure Clear;
    function ToDisplayText: string;
  end;

// MIF内容をDocumentへ適用する。両引数を所有しない。
function TryLoadVectArtDocumentFromMif(Container: TVectArtMifContainer;
  Document: TVectArtDocument; out ErrorMessage: string): Boolean;
// MIF生成を行わず、現在のDocumentで発生する変換・非対応内容を判定する。
function TryAnalyzeVectArtMifExport(Document: TVectArtDocument;
  out Report: TMifExportReport; out ErrorMessage: string): Boolean;
// 現在のDocumentから新しいMIFを生成し、成功時の所有権を呼び出し側へ渡す。
function TryCreateVectArtMifFromDocument(Document: TVectArtDocument;
  out Container: TVectArtMifContainer; out ErrorMessage: string): Boolean; overload;
// SourceContainer内のRectangle互換情報を順番に再利用してMIFを生成する。両Containerを所有しない。
function TryCreateVectArtMifFromDocument(Document: TVectArtDocument;
  SourceContainer: TVectArtMifContainer; out Container: TVectArtMifContainer;
  out ErrorMessage: string): Boolean; overload;
// MIF生成と同じ処理で互換性を判定し、生成物と注意事項を同時に返す。
function TryCreateVectArtMifFromDocument(Document: TVectArtDocument;
  SourceContainer: TVectArtMifContainer; out Container: TVectArtMifContainer;
  out Report: TMifExportReport; out ErrorMessage: string): Boolean; overload;

implementation

uses VectArtDesignerMifShadow,
  System.Classes, System.Generics.Collections, System.Math,
  System.NetEncoding, System.Types,
  Vcl.Graphics, Vcl.Imaging.pngimage, Winapi.Windows,
  VectArtDesignerBezierGeometry, VectArtDesignerDocumentJson,
  VectArtDesignerGeometry,
  VectArtDesignerMifPngMetadata, VectArtDesignerMifRaster,
  VectArtDesignerMifPlacement, VectArtDesignerMifPaint, VectArtDesignerMifReader, VectArtDesignerRenderer;

const
  // 旧版が埋め込んだ編集情報は読み込みだけを継続し、互換保存には出力しない。
  DOCUMENT_TEXT_KEY = 'VectArtDesigner document';
  // WebArt Designer 7が四角形用に生成した76x1のvector IPNGをそのまま使用する。
  RECTANGLE_VECTOR_PNG_BASE64 =
    'iVBORw0KGgoAAAANSUhEUgAAAEwAAAABCAYAAAB0UUiZAAAACXBIWXMAAAsSAAALEgHS3X78' +
    'AAAAEnRFWHRvYmplY3QgdHlwZQB2ZWN0b3KhamnfAAAAPUlEQVR4nGNgYGBlYGBgZACBGA' +
    'cGBxAdBaWJA0wMfwPO/S+S/0+R3l8L5/zPjP9Pkl4QALmZdL3MxCtFAwBmBRfKcYTSHQAA' +
    'AABJRU5ErkJggg==';
  // WebArt Designer 7が楕円用に生成した106x1のvector IPNGをそのまま使用する。
  ELLIPSE_VECTOR_PNG_BASE64 =
    'iVBORw0KGgoAAAANSUhEUgAAAGoAAAABCAYAAAA2EjsOAAAACXBIWXMAAAsSAAALEgHS3X78' +
    'AAAAEnRFWHRvYmplY3QgdHlwZQB2ZWN0b3KhamnfAAAAdUlEQVR4nGNgYGBnYGBgZACBrA' +
    'UMDiA6EUoTBziIV4oBWMBk8gOIfWkKEBrkjvxtuWkpMtYOyyculkyfFYkij6w3ygHh5oi' +
    '82GcJqstQ1ILkYWbhshdmBohWmKxuHOfeiWIWTJ5a/kUOZ2T/wewBycPcAdMJABE6LGgCK' +
    'wGjAAAAAElFTkSuQmCC';
  LINE_VECTOR_PNG_BASE64 =
    'iVBORw0KGgoAAAANSUhEUgAAAB8AAAABCAYAAAAmcnXSAAAACXBIWXMAAAsSAAALEgHS3X78' +
    'AAAAEnRFWHRvYmplY3QgdHlwZQB2ZWN0b3KhamnfAAAALklEQVR4nGNgYGBiYGBgZACBrg' +
    'YGBxBd4wChiQNMYHLCGwaH0NCw0JqjoUTrBQDb9wczCnO/awAAAABJRU5ErkJggg==';

{ TMifExportReport }

procedure TMifExportReport.AddIssue(AKind: TMifExportIssueKind;
  ALayerIndex: Integer; const ALayerName, AMessageText: string);
var
  IssueIndex: Integer;
begin
  IssueIndex := Length(Issues);
  SetLength(Issues, IssueIndex + 1);
  Issues[IssueIndex].Kind := AKind;
  Issues[IssueIndex].LayerIndex := ALayerIndex;
  Issues[IssueIndex].LayerName := ALayerName;
  Issues[IssueIndex].MessageText := AMessageText;
  if AKind = meikUnsupported then
    Compatibility := mecUnsupported
  else if Compatibility = mecExact then
    Compatibility := mecNeedsConfirmation;
end;

procedure TMifExportReport.Clear;
begin
  Compatibility := mecExact;
  Issues := nil;
end;

function TMifExportReport.ToDisplayText: string;
const
  ISSUE_PREFIXES: array[TMifExportIssueKind] of string =
    ('変換', '非対応', '未判定');
var
  I: Integer;
  LayerText: string;
begin
  if Length(Issues) = 0 then
    Exit('MIFへ変換なしで書き出せます。');
  Result := '';
  for I := 0 to High(Issues) do
  begin
    if Issues[I].LayerName <> '' then
      LayerText := Format('「%s」', [Issues[I].LayerName])
    else
      LayerText := Format('レイヤー%d', [Issues[I].LayerIndex]);
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + Format('・[%s] %s: %s',
      [ISSUE_PREFIXES[Issues[I].Kind], LayerText, Issues[I].MessageText]);
  end;
end;

type
  TMifPathExportShape = (mpesUnsupported, mpesLine, mpesPath);

  TRectangleMifSource = record
    ElementType: Integer;         // 元オブジェクトの図形種別
    OriginalLeft: Integer;       // ベクターペイロードが使用する基準矩形の左端
    OriginalTop: Integer;        // ベクターペイロードが使用する基準矩形の上端
    OriginalRight: Integer;      // ベクターペイロードが使用する基準矩形の右端
    OriginalBottom: Integer;     // ベクターペイロードが使用する基準矩形の下端
    StrokeEnabled: Boolean;      // 元オブジェクトのストロークテクスチャ有効状態
    VectorPng: TBytes;           // 元オブジェクトのWebArtベクターペイロード
    StrokeTexturePng: TBytes;    // 元オブジェクトのストロークテクスチャ
    Valid: Boolean;              // 基準座標とペイロードを安全に再利用できる場合True
  end;

function MifRectangleStrokeWidth(Value: Single): Double;
begin
  Result := Max(Value, 1.0);
end;

procedure AddRectangleVectorMetadata(var Png: TBytes;
  Rectangle: TVectArtRectangleLayer; Width, Height: Integer;
  const Source: TRectangleMifSource);
const
  TEMPLATE_LEFT = 113;
  TEMPLATE_TOP = 105;
  TEMPLATE_RIGHT = 289;
  TEMPLATE_BOTTOM = 202;
  ELLIPSE_TEMPLATE_LEFT = 105;
  ELLIPSE_TEMPLATE_TOP = 105;
  ELLIPSE_TEMPLATE_RIGHT = 212;
  ELLIPSE_TEMPLATE_BOTTOM = 176;
var
  OriginalBottom: Integer;
  OriginalLeft: Integer;
  OriginalRight: Integer;
  OriginalTop: Integer;
  PlacementBounds: TRectF;
  Quad: TVectArtQuad;
  ScaleX: Double;
  ScaleY: Double;
begin
  if Source.Valid and
    (((Rectangle.Shape = vpsEllipse) and (Source.ElementType = 2)) or
     ((Rectangle.Shape = vpsRectangle) and (Source.ElementType = 4))) then
  begin
    OriginalLeft := Source.OriginalLeft;
    OriginalTop := Source.OriginalTop;
    OriginalRight := Source.OriginalRight;
    OriginalBottom := Source.OriginalBottom;
  end
  else
  begin
    if Rectangle.Shape = vpsEllipse then
    begin
      OriginalLeft := ELLIPSE_TEMPLATE_LEFT;
      OriginalTop := ELLIPSE_TEMPLATE_TOP;
      OriginalRight := ELLIPSE_TEMPLATE_RIGHT;
      OriginalBottom := ELLIPSE_TEMPLATE_BOTTOM;
    end
    else
    begin
      OriginalLeft := TEMPLATE_LEFT;
      OriginalTop := TEMPLATE_TOP;
      OriginalRight := TEMPLATE_RIGHT;
      OriginalBottom := TEMPLATE_BOTTOM;
    end;
  end;
  AddWadaInteger(Png, 'vector closed', 1);
  AddWadaInteger(Png, 'vector quality', 1);
  if Rectangle.Shape = vpsEllipse then
    AddWadaInteger(Png, 'vector element type', 2)
  else
    AddWadaInteger(Png, 'vector element type', 4);
  AddWadaInteger(Png, 'vector stroke style', Ord(Rectangle.StrokeStyle));
  AddWadaInteger(Png, 'vector stroke cap', 0);
  AddWadaInteger(Png, 'vector stroke join', 2);
  AddWadaInteger(Png, 'vector start stroke marker', 0);
  AddWadaInteger(Png, 'vector end stroke marker', 0);
  AddWadaInteger(Png, 'vector start marker size', 4);
  AddWadaInteger(Png, 'vector end marker size', 4);
  AddWadaDouble(Png, 'vector stroke width',
    MifRectangleStrokeWidth(Rectangle.StrokeWidth));
  ScaleX := Max(Width - 1, 0) / (OriginalRight - OriginalLeft);
  ScaleY := Max(Height - 1, 0) / (OriginalBottom - OriginalTop);
  PlacementBounds := TRectF.Create(Rectangle.Bounds.Left,
    Rectangle.Bounds.Top, Rectangle.Bounds.Left + Width - 1,
    Rectangle.Bounds.Top + Height - 1);
  Quad := RectangleCorners(PlacementBounds, Rectangle.RotationDegrees);
  AddWadaDouble(Png, 'vector matrix a',
    (Quad[1].X - Quad[0].X) / (OriginalRight - OriginalLeft));
  AddWadaDouble(Png, 'vector matrix b',
    (Quad[1].Y - Quad[0].Y) / (OriginalRight - OriginalLeft));
  AddWadaDouble(Png, 'vector matrix c',
    (Quad[3].X - Quad[0].X) / (OriginalBottom - OriginalTop));
  AddWadaDouble(Png, 'vector matrix d',
    (Quad[3].Y - Quad[0].Y) / (OriginalBottom - OriginalTop));
  AddWadaDouble(Png, 'vector matrix e', Quad[0].X -
    OriginalLeft * ScaleX * Cos(DegToRad(Rectangle.RotationDegrees)) +
    OriginalTop * ScaleY * Sin(DegToRad(Rectangle.RotationDegrees)));
  AddWadaDouble(Png, 'vector matrix f', Quad[0].Y -
    OriginalLeft * ScaleX * Sin(DegToRad(Rectangle.RotationDegrees)) -
    OriginalTop * ScaleY * Cos(DegToRad(Rectangle.RotationDegrees)));
  AddWadaInteger(Png, 'vector original position1 x', OriginalLeft);
  AddWadaInteger(Png, 'vector original position1 y', OriginalTop);
  AddWadaInteger(Png, 'vector original position2 x', OriginalRight);
  AddWadaInteger(Png, 'vector original position2 y', OriginalTop);
  AddWadaInteger(Png, 'vector original position3 x', OriginalRight);
  AddWadaInteger(Png, 'vector original position3 y', OriginalBottom);
  AddWadaInteger(Png, 'vector original position4 x', OriginalLeft);
  AddWadaInteger(Png, 'vector original position4 y', OriginalBottom);
  AddWadaInteger(Png, 'vector enable stroke texture',
    Ord(Rectangle.StrokeWidth > 0));
  AddWadaInteger(Png, 'vector enable fill texture', Ord(Rectangle.Filled));
  WriteMifShadow(Png,Rectangle.Shadow);
end;

function MifRectangleDimension(Value: Single): Integer;
begin
  Result := Max(Round(Abs(Value)), 1);
end;

procedure AnalyzeRectangleExport(Rectangle: TVectArtRectangleLayer;
  LayerIndex, RectangleOrdinal: Integer; var Report: TMifExportReport);
var
  ExpectedName: string;
  Height: Integer;
  I: Integer;
  PlacementBounds: TRectF;
  PlacementQuad: TVectArtQuad;
  RoundedPlacement: Boolean;
  StoredOpacity: Single;
  Width: Integer;
begin
  if Rectangle.Shape = vpsEllipse then
    ExpectedName := Format('Ellipse %d', [RectangleOrdinal])
  else
    ExpectedName := Format('Rectangle %d', [RectangleOrdinal]);
  if Rectangle.Name <> ExpectedName then
    Report.AddIssue(meikConversion, LayerIndex, Rectangle.Name,
      Format('レイヤー名はMIFへ保持されず、再読込時に「%s」になります。',
      [ExpectedName]));
  if Rectangle.Locked then
    Report.AddIssue(meikConversion, LayerIndex, Rectangle.Name,
      '編集ロックはMIFへ保持されません。');
  Width := MifRectangleDimension(Rectangle.Bounds.Width);
  Height := MifRectangleDimension(Rectangle.Bounds.Height);
  if (Rectangle.Bounds.Width < 0) or (Rectangle.Bounds.Height < 0) or
    not SameValue(Abs(Rectangle.Bounds.Width), Width, 0.000001) or
    not SameValue(Abs(Rectangle.Bounds.Height), Height, 0.000001) then
    Report.AddIssue(meikConversion, LayerIndex, Rectangle.Name,
      Format('幅と高さはMIF画像寸法の整数値%d×%dへ丸められます。',
      [Width, Height]));
  PlacementBounds := TRectF.Create(Rectangle.Bounds.Left,
    Rectangle.Bounds.Top, Rectangle.Bounds.Left + Width - 1,
    Rectangle.Bounds.Top + Height - 1);
  PlacementQuad := RectangleCorners(PlacementBounds,
    Rectangle.RotationDegrees);
  RoundedPlacement := False;
  for I := 0 to High(PlacementQuad) do
    if not SameValue(PlacementQuad[I].X,
      MifImageCoordinate(PlacementQuad[I].X), 0.000001) or
      not SameValue(PlacementQuad[I].Y,
      MifImageCoordinate(PlacementQuad[I].Y), 0.000001) then
    begin
      RoundedPlacement := True;
      Break;
    end;
  if RoundedPlacement then
    Report.AddIssue(meikConversion, LayerIndex, Rectangle.Name,
      '回転後の配置頂点はMIFの整数座標へ丸められます。');
  StoredOpacity := MifAlpha(Rectangle.Opacity) / 255.0;
  if not SameValue(Rectangle.Opacity, StoredOpacity, 0.000001) then
    Report.AddIssue(meikConversion, LayerIndex, Rectangle.Name,
      Format('不透明度はMIFの8bit値%dへ丸められます。',
      [MifAlpha(Rectangle.Opacity)]));
  if (Rectangle.StrokeWidth > 0) and not SameValue(Rectangle.StrokeWidth,
    MifRectangleStrokeWidth(Rectangle.StrokeWidth), 0.000001) then
    Report.AddIssue(meikConversion, LayerIndex, Rectangle.Name,
      '1未満の線幅はMIFでは1へ変換されます。')
  else if Rectangle.StrokeWidth < 0 then
    Report.AddIssue(meikConversion, LayerIndex, Rectangle.Name,
      '負の線幅はMIFでは線なしとして扱われます。');
end;

function CreateRectangleVectorPng(Rectangle: TVectArtRectangleLayer;
  const Source: TRectangleMifSource): TBytes;
begin
  if Source.Valid and
    (((Rectangle.Shape = vpsEllipse) and (Source.ElementType = 2)) or
     ((Rectangle.Shape = vpsRectangle) and (Source.ElementType = 4))) then
    Result := Copy(Source.VectorPng)
  else if Rectangle.Shape = vpsEllipse then
    Result := TNetEncoding.Base64.DecodeStringToBytes(
      ELLIPSE_VECTOR_PNG_BASE64)
  else
    Result := TNetEncoding.Base64.DecodeStringToBytes(
      RECTANGLE_VECTOR_PNG_BASE64);
  Result := RemovePngChunk(Result, 'sBIT');
end;

function CreateRectangleImagePng(Rectangle: TVectArtRectangleLayer;
  const Source: TRectangleMifSource): TBytes;
var
  Height: Integer;
  PlacementBounds: TRectF;
  PlacementQuad: TVectArtQuad;
  Width: Integer;
begin
  Width := MifRectangleDimension(Rectangle.Bounds.Width);
  Height := MifRectangleDimension(Rectangle.Bounds.Height);

  // WebArtの四隅座標はPNGの最終ピクセルを指すため、右端と下端は包含座標へ直す。
  PlacementBounds := TRectF.Create(Rectangle.Bounds.Left,
    Rectangle.Bounds.Top, Rectangle.Bounds.Left + Width - 1,
    Rectangle.Bounds.Top + Height - 1);
  PlacementQuad := RectangleCorners(PlacementBounds,
    Rectangle.RotationDegrees);
  if Rectangle.Shadow.Enabled then
  begin
    // ベクター変換は本体寸法のまま、PNGの配置だけ影の外寸に合わせる。
    Result := CreateShadowRaster(Rectangle,PlacementBounds);
    PlacementQuad := RectangleCorners(PlacementBounds,0);
  end
  else Result := CreateRectangleRasterPng(Rectangle,Width,Height);
  AddText(Result,'object type','image');
  AddWadaString(Result,'object subtype','vector');
  AddImagePlacementMetadata(Result, PlacementQuad,
    MifAlpha(Rectangle.Opacity), not Rectangle.Visible);
  AddRectangleVectorMetadata(Result, Rectangle, Width, Height, Source);
end;

function CreateLineVectorPng: TBytes;
begin
  Result := TNetEncoding.Base64.DecodeStringToBytes(LINE_VECTOR_PNG_BASE64);
  Result := RemovePngChunk(Result, 'sBIT');
end;

function CreatePathVectorPng(PathLayer: TVectArtPathLayer): TBytes;
const
  RECORD_SIZE = 60;
var
  Command: UInt32;
  Count: UInt32;
  I: Integer;
  Offset: Integer;
  PathPoints: TArray<TPointF>;
  Pixels: TArray<TVectArtRgbaPixel>;
  Raw: TBytes;
  X: Double;
  Y: Double;
begin
  PathPoints := BuildPathDisplayPolyline(PathLayer.Points,
    PathLayer.Bezier, PathLayer.Closed, 16);
  if PathLayer.Closed and (Length(PathPoints) > 1) and
    SameValue(PathPoints[0].X, PathPoints[High(PathPoints)].X) and
    SameValue(PathPoints[0].Y, PathPoints[High(PathPoints)].Y) then
    SetLength(PathPoints, Length(PathPoints) - 1);
  Count := Length(PathPoints) + Ord(PathLayer.Closed);
  SetLength(Raw, 4 + Integer(Count) * RECORD_SIZE);
  Move(Count, Raw[0], SizeOf(Count));
  for I := 0 to High(PathPoints) do
  begin
    Offset := 4 + I * RECORD_SIZE;
    if I = 0 then
      Command := 1
    else
      Command := 2;
    Move(Command, Raw[Offset], SizeOf(Command));
    X := PathPoints[I].X;
    Y := PathPoints[I].Y;
    Move(X, Raw[Offset + 4], SizeOf(X));
    Move(Y, Raw[Offset + 12], SizeOf(Y));
  end;
  if PathLayer.Closed then
  begin
    Offset := 4 + Length(PathPoints) * RECORD_SIZE;
    Command := 3;
    Move(Command, Raw[Offset], SizeOf(Command));
  end;
  SetLength(Pixels, Length(Raw) div 4);
  for I := 0 to High(Pixels) do
  begin
    Pixels[I].R := Raw[I * 4 + 2];
    Pixels[I].G := Raw[I * 4 + 1];
    Pixels[I].B := Raw[I * 4];
    Pixels[I].A := Raw[I * 4 + 3];
  end;
  Result := EncodeRgba(@Pixels[0], Length(Pixels), 1);
  AddPhysicalDimensions(Result);
  AddText(Result, 'object type', 'vector');
end;

function MifPathExportShape(PathLayer: TVectArtPathLayer):
  TMifPathExportShape;
begin
  if Length(PathLayer.Points) < 2 then
    Result := mpesUnsupported
  else if Length(PathLayer.Points) = 2 then
    Result := mpesLine
  else
    Result := mpesPath;
end;

function MifPathFilled(PathLayer: TVectArtPathLayer): Boolean;
begin
  Result := PathLayer.Closed and PathLayer.Filled;
end;

function LineMarkerToMif(Value: TVectArtLineMarker): Integer; forward;
function MifLineMarkerSize(Value: Single): Integer; forward;

procedure AnalyzePathExport(PathLayer: TVectArtPathLayer; LayerIndex,
  PathOrdinal, ConvertedLineOrdinal: Integer; var Report: TMifExportReport);
var
  ExpectedName: string;
  ExportShape: TMifPathExportShape;
  StoredOpacity: Single;
begin
  ExportShape := MifPathExportShape(PathLayer);
  if ExportShape = mpesUnsupported then
  begin
    Report.AddIssue(meikUnsupported, LayerIndex, PathLayer.Name,
      '頂点が2個未満のPathはMIFへ書き出せません。');
    Exit;
  end;
  if ExportShape = mpesLine then
  begin
    Report.AddIssue(meikConversion, LayerIndex, PathLayer.Name,
      Format('2頂点のPathはMIF再読込時に「Line %d」へ変換されます。',
      [ConvertedLineOrdinal]));
    if PathLayer.Closed then
      Report.AddIssue(meikConversion, LayerIndex, PathLayer.Name,
        '2頂点Pathの閉じた状態はLineへの変換時に失われます。');
    if PathLayer.Filled then
      Report.AddIssue(meikConversion, LayerIndex, PathLayer.Name,
        '2頂点Pathの塗りはLineへの変換時に失われます。');
  end
  else
  begin
    ExpectedName := Format('Path %d', [PathOrdinal]);
    if PathLayer.Name <> ExpectedName then
      Report.AddIssue(meikConversion, LayerIndex, PathLayer.Name,
        Format('レイヤー名はMIFへ保持されず、再読込時に「%s」になります。',
        [ExpectedName]));
  end;
  if PathLayer.Locked then
    Report.AddIssue(meikConversion, LayerIndex, PathLayer.Name,
      '編集ロックはMIFへ保持されません。');
  if PathLayer.Bezier then
    Report.AddIssue(meikConversion, LayerIndex, PathLayer.Name,
      'ベジェ曲線はMIFへ16分割の連続直線として保存されます。');
  StoredOpacity := MifAlpha(PathLayer.Opacity) / 255.0;
  if not SameValue(PathLayer.Opacity, StoredOpacity, 0.000001) then
    Report.AddIssue(meikConversion, LayerIndex, PathLayer.Name,
      Format('不透明度はMIFの8bit値%dへ丸められます。',
      [MifAlpha(PathLayer.Opacity)]));
  if (ExportShape = mpesPath) and
    (PathLayer.Filled <> MifPathFilled(PathLayer)) then
    Report.AddIssue(meikConversion, LayerIndex, PathLayer.Name,
      '開いたPathの塗りはMIFへ保持されず、塗りなしになります。');
  if ((ExportShape = mpesLine) and
    not SameValue(PathLayer.StrokeWidth,
    MifLineStrokeWidth(PathLayer.StrokeWidth), 0.000001)) or
    ((ExportShape = mpesPath) and
    not SameValue(PathLayer.StrokeWidth,
    MifPathStrokeWidth(PathLayer.StrokeWidth), 0.000001)) then
    Report.AddIssue(meikConversion, LayerIndex, PathLayer.Name,
      '線幅は変換先のMIF表現で使用できる最小値へ変換されます。');
  if not PathLayer.Closed then
  begin
    if not SameValue(PathLayer.StartMarkerSize,
      MifLineMarkerSize(PathLayer.StartMarkerSize), 0.000001) then
      Report.AddIssue(meikConversion, LayerIndex, PathLayer.Name,
        Format('始点マーカーサイズはMIFの整数値%dへ変換されます。',
        [MifLineMarkerSize(PathLayer.StartMarkerSize)]));
    if not SameValue(PathLayer.EndMarkerSize,
      MifLineMarkerSize(PathLayer.EndMarkerSize), 0.000001) then
      Report.AddIssue(meikConversion, LayerIndex, PathLayer.Name,
        Format('終点マーカーサイズはMIFの整数値%dへ変換されます。',
        [MifLineMarkerSize(PathLayer.EndMarkerSize)]));
  end;
end;

function CreatePathImagePng(PathLayer: TVectArtPathLayer): TBytes;
var
  Bounds: TRectF;
  OriginalBounds: TRectF;
begin
  if PathLayer.Shadow.Enabled then Result := CreateShadowRaster(PathLayer,Bounds)
  else Result := CreatePathRasterPng(PathLayer, Bounds);
  AddText(Result, 'object type', 'image');
  AddWadaString(Result, 'object subtype', 'vector');
  AddImagePlacementMetadata(Result, Bounds,
    MifAlpha(PathLayer.Opacity), not PathLayer.Visible);
  AddWadaInteger(Result, 'vector closed', Ord(PathLayer.Closed));
  AddWadaInteger(Result, 'vector quality', Ord(PathLayer.AntiAlias));
  AddWadaInteger(Result, 'vector element type', 6);
  AddWadaInteger(Result, 'vector stroke style', Ord(PathLayer.StrokeStyle));
  AddWadaInteger(Result, 'vector stroke cap', Ord(PathLayer.LineCap));
  AddWadaInteger(Result, 'vector stroke join', Ord(PathLayer.LineJoin));
  if PathLayer.Closed then
  begin
    AddWadaInteger(Result, 'vector start stroke marker', 0);
    AddWadaInteger(Result, 'vector end stroke marker', 0);
  end
  else
  begin
    AddWadaInteger(Result, 'vector start stroke marker',
      LineMarkerToMif(PathLayer.StartMarker));
    AddWadaInteger(Result, 'vector end stroke marker',
      LineMarkerToMif(PathLayer.EndMarker));
  end;
  AddWadaInteger(Result, 'vector start marker size',
    MifLineMarkerSize(PathLayer.StartMarkerSize));
  AddWadaInteger(Result, 'vector end marker size',
    MifLineMarkerSize(PathLayer.EndMarkerSize));
  AddWadaDouble(Result, 'vector stroke width',
    MifPathStrokeWidth(PathLayer.StrokeWidth));
  AddWadaDouble(Result, 'vector matrix a', 1.0);
  AddWadaDouble(Result, 'vector matrix b', 0.0);
  AddWadaDouble(Result, 'vector matrix c', 0.0);
  AddWadaDouble(Result, 'vector matrix d', 1.0);
  AddWadaDouble(Result, 'vector matrix e', 0.0);
  AddWadaDouble(Result, 'vector matrix f', 0.0);
  OriginalBounds := PointsBounds(BuildPathDisplayPolyline(PathLayer.Points,
    PathLayer.Bezier, PathLayer.Closed, 16));
  AddWadaInteger(Result, 'vector original position1 x',
    Floor(OriginalBounds.Left));
  AddWadaInteger(Result, 'vector original position1 y',
    Floor(OriginalBounds.Top));
  AddWadaInteger(Result, 'vector original position2 x',
    Ceil(OriginalBounds.Right));
  AddWadaInteger(Result, 'vector original position2 y',
    Floor(OriginalBounds.Top));
  AddWadaInteger(Result, 'vector original position3 x',
    Ceil(OriginalBounds.Right));
  AddWadaInteger(Result, 'vector original position3 y',
    Ceil(OriginalBounds.Bottom));
  AddWadaInteger(Result, 'vector original position4 x',
    Floor(OriginalBounds.Left));
  AddWadaInteger(Result, 'vector original position4 y',
    Ceil(OriginalBounds.Bottom));
  AddWadaInteger(Result, 'vector enable stroke texture',
    Ord(PathLayer.StrokeWidth > 0));
  AddWadaInteger(Result, 'vector enable fill texture',
    Ord(MifPathFilled(PathLayer)));
  WriteMifShadow(Result,PathLayer.Shadow);
end;

function LineMarkerToMif(Value: TVectArtLineMarker): Integer;
begin
  case Value of
    vlmOpenArrow: Result := 1;
    vlmArrow: Result := 2;
    vlmWideArrow: Result := 3;
    vlmCircle: Result := 4;
    vlmDiamond: Result := 5;
    vlmConcaveArrow: Result := 6;
    vlmSmallArrow: Result := 7;
    vlmSlash: Result := 8;
    vlmStar: Result := 9;
  else
    Result := 0;
  end;
end;

function MifLineMarkerSize(Value: Single): Integer;
begin
  Result := EnsureRange(Round(Value), 1, 20);
end;

function CreateMifLineFromPath(PathLayer: TVectArtPathLayer):
  TVectArtLineLayer;
begin
  Result := TVectArtLineLayer.Create(PathLayer.Name, PathLayer.Points[0],
    PathLayer.Points[1]);
  Result.AntiAlias := PathLayer.AntiAlias;
  Result.EndMarker := PathLayer.EndMarker;
  Result.EndMarkerSize := PathLayer.EndMarkerSize;
  Result.LineCap := PathLayer.LineCap;
  Result.LineJoin := PathLayer.LineJoin;
  Result.Locked := PathLayer.Locked;
  Result.Opacity := PathLayer.Opacity;
  Result.StartMarker := PathLayer.StartMarker;
  Result.StartMarkerSize := PathLayer.StartMarkerSize;
  Result.StrokePaint := PathLayer.StrokePaint;
  Result.StrokeColor := PathLayer.StrokeColor;
  Result.StrokeStyle := PathLayer.StrokeStyle;
  Result.StrokeWidth := MifLineStrokeWidth(PathLayer.StrokeWidth);
  Result.Visible := PathLayer.Visible;
end;

procedure AnalyzeLineExport(Line: TVectArtLineLayer; LayerIndex,
  LineOrdinal: Integer; var Report: TMifExportReport);
var
  ExpectedName: string;
  StoredOpacity: Single;
begin
  ExpectedName := Format('Line %d', [LineOrdinal]);
  if Line.Name <> ExpectedName then
    Report.AddIssue(meikConversion, LayerIndex, Line.Name,
      Format('レイヤー名はMIFへ保持されず、再読込時に「%s」になります。',
      [ExpectedName]));
  if Line.Locked then
    Report.AddIssue(meikConversion, LayerIndex, Line.Name,
      '編集ロックはMIFへ保持されません。');
  StoredOpacity := MifAlpha(Line.Opacity) / 255.0;
  if not SameValue(Line.Opacity, StoredOpacity, 0.000001) then
    Report.AddIssue(meikConversion, LayerIndex, Line.Name,
      Format('不透明度はMIFの8bit値%dへ丸められます。',
      [MifAlpha(Line.Opacity)]));
  if not SameValue(Line.StartMarkerSize,
    MifLineMarkerSize(Line.StartMarkerSize), 0.000001) then
    Report.AddIssue(meikConversion, LayerIndex, Line.Name,
      Format('始点マーカーサイズはMIFの整数値%dへ変換されます。',
      [MifLineMarkerSize(Line.StartMarkerSize)]));
  if not SameValue(Line.EndMarkerSize,
    MifLineMarkerSize(Line.EndMarkerSize), 0.000001) then
    Report.AddIssue(meikConversion, LayerIndex, Line.Name,
      Format('終点マーカーサイズはMIFの整数値%dへ変換されます。',
      [MifLineMarkerSize(Line.EndMarkerSize)]));
  if not SameValue(Line.StrokeWidth,
    MifLineStrokeWidth(Line.StrokeWidth), 0.000001) then
    Report.AddIssue(meikConversion, LayerIndex, Line.Name,
      '0.1未満の線幅はMIFでは0.1へ変換されます。');
end;

function CreateLineImagePng(Line: TVectArtLineLayer): TBytes;
const
  ORIGINAL_LEFT = 848;
  ORIGINAL_TOP = 452;
  ORIGINAL_RIGHT = 1082;
  ORIGINAL_BOTTOM = 460;
var
  CenterY: Double;
  DirectionLength: Double;
  MatrixA: Double;
  MatrixB: Double;
  MatrixC: Double;
  MatrixD: Double;
  MatrixE: Double;
  MatrixF: Double;
  PlacementBounds: TRectF;
begin
  Result := CreateLineRasterPng(Line, PlacementBounds);
  AddText(Result, 'object type', 'image');
  AddWadaString(Result, 'object subtype', 'vector');
  AddImagePlacementMetadata(Result, PlacementBounds,
    MifAlpha(Line.Opacity), not Line.Visible);
  AddWadaInteger(Result, 'vector closed', 0);
  AddWadaInteger(Result, 'vector quality', Ord(Line.AntiAlias));
  AddWadaInteger(Result, 'vector element type', 6);
  AddWadaInteger(Result, 'vector stroke style', Ord(Line.StrokeStyle));
  AddWadaInteger(Result, 'vector stroke cap', Ord(Line.LineCap));
  AddWadaInteger(Result, 'vector stroke join', Ord(Line.LineJoin));
  AddWadaInteger(Result, 'vector start stroke marker',
    LineMarkerToMif(Line.StartMarker));
  AddWadaInteger(Result, 'vector end stroke marker',
    LineMarkerToMif(Line.EndMarker));
  AddWadaInteger(Result, 'vector start marker size',
    MifLineMarkerSize(Line.StartMarkerSize));
  AddWadaInteger(Result, 'vector end marker size',
    MifLineMarkerSize(Line.EndMarkerSize));
  AddWadaDouble(Result, 'vector stroke width',
    MifLineStrokeWidth(Line.StrokeWidth));
  MatrixA := (Line.EndPoint.X - Line.StartPoint.X) /
    (ORIGINAL_RIGHT - ORIGINAL_LEFT);
  MatrixB := (Line.EndPoint.Y - Line.StartPoint.Y) /
    (ORIGINAL_RIGHT - ORIGINAL_LEFT);
  DirectionLength := Hypot(MatrixA, MatrixB);
  if DirectionLength > 0 then
  begin
    MatrixC := -MatrixB / DirectionLength;
    MatrixD := MatrixA / DirectionLength;
  end
  else
  begin
    MatrixC := 0;
    MatrixD := 1;
  end;
  CenterY := (ORIGINAL_TOP + ORIGINAL_BOTTOM) * 0.5;
  MatrixE := Line.StartPoint.X - MatrixA * ORIGINAL_LEFT -
    MatrixC * CenterY;
  MatrixF := Line.StartPoint.Y - MatrixB * ORIGINAL_LEFT -
    MatrixD * CenterY;
  AddWadaDouble(Result, 'vector matrix a', MatrixA);
  AddWadaDouble(Result, 'vector matrix b', MatrixB);
  AddWadaDouble(Result, 'vector matrix c', MatrixC);
  AddWadaDouble(Result, 'vector matrix d', MatrixD);
  AddWadaDouble(Result, 'vector matrix e', MatrixE);
  AddWadaDouble(Result, 'vector matrix f', MatrixF);
  AddWadaInteger(Result, 'vector original position1 x', ORIGINAL_LEFT);
  AddWadaInteger(Result, 'vector original position1 y', ORIGINAL_TOP);
  AddWadaInteger(Result, 'vector original position2 x', ORIGINAL_RIGHT);
  AddWadaInteger(Result, 'vector original position2 y', ORIGINAL_TOP);
  AddWadaInteger(Result, 'vector original position3 x', ORIGINAL_RIGHT);
  AddWadaInteger(Result, 'vector original position3 y', ORIGINAL_BOTTOM);
  AddWadaInteger(Result, 'vector original position4 x', ORIGINAL_LEFT);
  AddWadaInteger(Result, 'vector original position4 y', ORIGINAL_BOTTOM);
  AddWadaInteger(Result, 'vector enable stroke texture', 1);
  AddWadaInteger(Result, 'vector enable fill texture', 0);
  AddWadaString(Result, 'vector effect object type', 'none');
end;

procedure CollectRectangleSources(Container: TVectArtMifContainer;
  Sources: TList<TRectangleMifSource>);
var
  Bottom: Int32;
  ElementType: Int32;
  I: Integer;
  Left: Int32;
  ObjectSubtype: string;
  ObjectType: string;
  Right: Int32;
  Source: TRectangleMifSource;
  StrokeEnabled: Int32;
  Top: Int32;
begin
  if (Container = nil) or (Sources = nil) then
    Exit;
  for I := 2 to Container.ChunkCount - 2 do
  begin
    if (Container[I].Tag <> 'IPNG') or
      not TryReadPngString(Container[I].Data, 'tEXt', 'object type',
        ObjectType) or not SameText(ObjectType, 'image') or
      not TryReadPngString(Container[I].Data, 'waDA', 'object subtype',
        ObjectSubtype) or not SameText(ObjectSubtype, 'vector') or
      not TryReadPngInteger(Container[I].Data, 'vector element type',
        ElementType) or not (ElementType in [2, 4]) then
      Continue;
    Source := Default(TRectangleMifSource);
    Source.ElementType := ElementType;
    StrokeEnabled := 0;
    TryReadPngInteger(Container[I].Data, 'vector enable stroke texture',
      StrokeEnabled);
    Source.StrokeEnabled := StrokeEnabled <> 0;
    Source.Valid := (I + 2 < Container.ChunkCount) and
      (Container[I + 2].Tag = 'IPNG') and IsPng(Container[I + 2].Data) and
      TryReadPngInteger(Container[I].Data, 'vector original position1 x',
        Left) and
      TryReadPngInteger(Container[I].Data, 'vector original position1 y',
        Top) and
      TryReadPngInteger(Container[I].Data, 'vector original position3 x',
        Right) and
      TryReadPngInteger(Container[I].Data, 'vector original position3 y',
        Bottom) and (Right <> Left) and (Bottom <> Top);
    if Source.Valid then
    begin
      Source.OriginalLeft := Left;
      Source.OriginalTop := Top;
      Source.OriginalRight := Right;
      Source.OriginalBottom := Bottom;
      Source.VectorPng := Copy(Container[I + 2].Data);
      if (I + 3 < Container.ChunkCount) and
        (Container[I + 3].Tag = 'IPNG') and IsPng(Container[I + 3].Data) then
        Source.StrokeTexturePng := Copy(Container[I + 3].Data);
    end;
    Sources.Add(Source);
  end;
end;

function IsDecodablePng(const Png: TBytes): Boolean;
var
  PngImage: TPngImage;
  Stream: TBytesStream;
begin
  Result := False;
  if not IsPng(Png) then
    Exit;
  PngImage := TPngImage.Create;
  Stream := TBytesStream.Create(Png);
  try
    try
      PngImage.LoadFromStream(Stream);
      Result := (PngImage.Width > 0) and (PngImage.Height > 0);
    except
      Result := False;
    end;
  finally
    Stream.Free;
    PngImage.Free;
  end;
end;

function TryPrepareImagePngForMif(ImageLayer: TVectArtImageLayer;
  LayerIndex, ImageOrdinal: Integer; var Report: TMifExportReport;
  out Png: TBytes): Boolean;
var
  ExpectedName: string;
  ExpectedObjectType: string;
  I: Integer;
  ObjectSubtype: string;
  StoredOpacity: Single;
begin
  Result := False;
  Png := nil;
  if not IsDecodablePng(ImageLayer.PngData) or
    (FindPngMetadataInsertOffset(ImageLayer.PngData) < 0) then
  begin
    Report.AddIssue(meikUnsupported, LayerIndex, ImageLayer.Name,
      'PNG本体が破損しているか、MIFへ格納できるPNG構造ではありません。');
    Exit;
  end;
  if ImageLayer.SourceKind = visLogo then
  begin
    ExpectedName := Format('Logo %d', [ImageOrdinal]);
    ExpectedObjectType := 'logo';
  end
  else
  begin
    ExpectedName := Format('Image %d', [ImageOrdinal]);
    ExpectedObjectType := 'image';
  end;
  if ImageLayer.Name <> ExpectedName then
    Report.AddIssue(meikConversion, LayerIndex, ImageLayer.Name,
      Format('レイヤー名はMIFへ保持されず、再読込時に「%s」になります。',
      [ExpectedName]));
  if ImageLayer.Locked then
    Report.AddIssue(meikConversion, LayerIndex, ImageLayer.Name,
      '編集ロックはMIFへ保持されません。');
  StoredOpacity := MifAlpha(ImageLayer.Opacity) / 255.0;
  if not SameValue(ImageLayer.Opacity, StoredOpacity, 0.000001) then
    Report.AddIssue(meikConversion, LayerIndex, ImageLayer.Name,
      Format('不透明度はMIFの8bit値%dへ丸められます。',
      [MifAlpha(ImageLayer.Opacity)]));
  for I := 0 to High(ImageLayer.Points) do
    if not SameValue(ImageLayer.Points[I].X,
      MifImageCoordinate(ImageLayer.Points[I].X), 0.000001) or
      not SameValue(ImageLayer.Points[I].Y,
      MifImageCoordinate(ImageLayer.Points[I].Y), 0.000001) then
    begin
      Report.AddIssue(meikConversion, LayerIndex, ImageLayer.Name,
        '画像の四隅はMIFの整数座標へ丸められます。');
      Break;
    end;
  Png := Copy(ImageLayer.PngData);
  Png := RemovePngMetadataKey(Png, 'tEXt', 'object type');
  AddText(Png, 'object type', ExpectedObjectType);
  ObjectSubtype := '';
  if TryReadPngString(Png, 'waDA', 'object subtype', ObjectSubtype) and
    SameText(ObjectSubtype, 'vector') then
    Png := RemovePngMetadataKey(Png, 'waDA', 'object subtype');
  UpdateImagePlacementMetadata(Png, ImageLayer.Points,
    MifAlpha(ImageLayer.Opacity), not ImageLayer.Visible);
  Result := True;
end;

function TryLoadVectArtDocumentFromMif(Container: TVectArtMifContainer;
  Document: TVectArtDocument; out ErrorMessage: string): Boolean;
var
  I: Integer;
  Json: string;
begin
  Result := False;
  ErrorMessage := '';
  if Container = nil then
  begin
    ErrorMessage := 'MIF container is not assigned';
    Exit;
  end;
  if Document = nil then
  begin
    ErrorMessage := 'Document is not assigned';
    Exit;
  end;
  for I := 0 to Container.ChunkCount - 1 do
    if (Container[I].Tag = 'IPNG') and
      TryReadTextValue(Container[I].Data, DOCUMENT_TEXT_KEY, Json) then
    begin
      Result := TryDeserializeVectArtDocument(Json, Document, ErrorMessage);
      if Result then
      Exit;
    end;
  Result := TryImportWebArtDocument(Container, Document, ErrorMessage);
  if Result then
end;

function AnalyzeVectArtMifExport(Document: TVectArtDocument;
  out Report: TMifExportReport; out PreparedImagePngs: TArray<TBytes>;
  out ErrorMessage: string): Boolean;
var
  Canvas: TVectArtCanvasLayer;
  I: Integer;
  ImageIndex: Integer;
  Layer: TVectArtLayer;
  LineIndex: Integer;
  PathExportShape: TMifPathExportShape;
  PathIndex: Integer;
  RectangleIndex: Integer;
  TextIndex: Integer;
begin
  Result := False;
  Report.Clear;
  PreparedImagePngs := nil;
  ErrorMessage := '';
  try
    if Document = nil then
      raise EArgumentNilException.Create('Document');
    Canvas := Document.CanvasLayer;
    if Canvas = nil then
      raise EInvalidOp.Create('Document canvas is missing');
    SetLength(PreparedImagePngs, Document.LayerCount);
    ImageIndex := 0;
    LineIndex := 0;
    PathIndex := 0;
    RectangleIndex := 0;
    TextIndex := 0;
    for I := 1 to Document.LayerCount - 1 do
    begin
      Layer := Document[I];
      if Layer is TVectArtTextLayer then
      begin
        Inc(TextIndex);
        if Layer.Name <> Format('Text %d', [TextIndex]) then
          Report.AddIssue(meikConversion, I, Layer.Name,
            Format('レイヤー名はMIFへ保持されず、再読込時に「Text %d」になります。',
              [TextIndex]));
        if Layer.Locked then
          Report.AddIssue(meikConversion, I, Layer.Name,
            '編集ロックはMIFへ保持されません。');
        if not SameValue(TVectArtTextLayer(Layer).LetterSpacingRatio,
          0.0) or not SameValue(
          TVectArtTextLayer(Layer).LineSpacingRatio, 0.0) then
          Report.AddIssue(meikConversion, I, Layer.Name,
            '字間と行間の割合はMIF文字属性へ保持されず、表示PNGへ反映して保存されます。');
        Continue;
      end;
      if Layer is TVectArtImageLayer then
      begin
        Inc(ImageIndex);
        if TVectArtImageLayer(Layer).SourceFileName <> '' then
          Report.AddIssue(meikConversion, I, Layer.Name,
            '取込元ファイル名はMIFへ保持されません。埋め込み画像データは保持されます。');
        TryPrepareImagePngForMif(TVectArtImageLayer(Layer), I, ImageIndex,
          Report, PreparedImagePngs[I]);
        Continue;
      end;
      if Layer is TVectArtLineLayer then
      begin
        AnalyzeLineExport(TVectArtLineLayer(Layer), I, LineIndex + 1,
          Report);
        Inc(LineIndex);
        Continue;
      end;
      if Layer is TVectArtPathLayer then
      begin
        PathExportShape := MifPathExportShape(TVectArtPathLayer(Layer));
        AnalyzePathExport(TVectArtPathLayer(Layer), I, PathIndex + 1,
          LineIndex + 1, Report);
        if PathExportShape = mpesLine then
          Inc(LineIndex)
        else if PathExportShape = mpesPath then
          Inc(PathIndex);
        Continue;
      end;
      if Layer is TVectArtRectangleLayer then
      begin
        AnalyzeRectangleExport(TVectArtRectangleLayer(Layer), I,
          RectangleIndex + 1, Report);
        Inc(RectangleIndex);
        Continue;
      end;
      Report.AddIssue(meikUnsupported, I, Layer.Name,
        'このレイヤー種類はMIF Writerが対応していません。');
    end;
    Result := True;
  except
    on E: Exception do
      ErrorMessage := E.Message;
  end;
end;

function TryAnalyzeVectArtMifExport(Document: TVectArtDocument;
  out Report: TMifExportReport; out ErrorMessage: string): Boolean;
var
  PreparedImagePngs: TArray<TBytes>;
begin
  Result := AnalyzeVectArtMifExport(Document, Report, PreparedImagePngs,
    ErrorMessage);
end;

function TryCreateVectArtMifFromDocument(Document: TVectArtDocument;
  out Container: TVectArtMifContainer; out ErrorMessage: string): Boolean;
begin
  Result := TryCreateVectArtMifFromDocument(Document, nil, Container,
    ErrorMessage);
end;

function TryCreateVectArtMifFromDocument(Document: TVectArtDocument;
  SourceContainer: TVectArtMifContainer; out Container: TVectArtMifContainer;
  out ErrorMessage: string): Boolean;
var
  Report: TMifExportReport;
begin
  Result := TryCreateVectArtMifFromDocument(Document, SourceContainer,
    Container, Report, ErrorMessage);
end;

function TryCreateVectArtMifFromDocument(Document: TVectArtDocument;
  SourceContainer: TVectArtMifContainer; out Container: TVectArtMifContainer;
  out Report: TMifExportReport; out ErrorMessage: string): Boolean;
var
  Candidate: TVectArtMifContainer;
  BackgroundAlpha: Integer;
  Canvas: TVectArtCanvasLayer;
  ConvertedLine: TVectArtLineLayer;
  Header: TBytes;
  I: Integer;
  ImagePng: TBytes;
  Layer: TVectArtLayer;
  Line: TVectArtLineLayer;
  ContentChunkCount: Integer;
  PathExportShape: TMifPathExportShape;
  PathLayer: TVectArtPathLayer;
  PreparedImagePngs: TArray<TBytes>;
  Rectangle: TVectArtRectangleLayer;
  RectangleIndex: Integer;
  RectangleSource: TRectangleMifSource;
  RectangleSources: TList<TRectangleMifSource>;
  TextLayer: TVectArtTextLayer;
begin
  Result := False;
  Container := nil;
  ErrorMessage := '';
  Candidate := nil;
  RectangleSources := TList<TRectangleMifSource>.Create;
  try
    try
      if not AnalyzeVectArtMifExport(Document, Report, PreparedImagePngs,
        ErrorMessage) then
        Exit;
      Canvas := Document.CanvasLayer;
      if Report.Compatibility = mecUnsupported then
      begin
        ErrorMessage := 'MIFへ書き出せない項目があります。';
        Exit;
      end;
      CollectRectangleSources(SourceContainer, RectangleSources);
      Candidate := TVectArtMifContainer.Create;
      ContentChunkCount := 0;
      for I := 1 to Document.LayerCount - 1 do
      begin
        if Document[I] is TVectArtImageLayer then
          Inc(ContentChunkCount, 2)
        else if Document[I] is TVectArtTextLayer then
          Inc(ContentChunkCount, 2)
        else if (Document[I] is TVectArtRectangleLayer) or
          (Document[I] is TVectArtLineLayer) or
          ((Document[I] is TVectArtPathLayer) and
          (MifPathExportShape(TVectArtPathLayer(Document[I])) <>
          mpesUnsupported)) then
          Inc(ContentChunkCount, 4);
      end;
      SetLength(Header, 4);
      // MHDRはヘッダーと終端を除く外側チャンク数を保持する。
      WriteUInt32BE(Header, 0, 2 + ContentChunkCount);
      Candidate.AddChunk('MHDR', Header);
      Candidate.AddChunk('IPNG', CreateCompositePng(Document));
      if Canvas.Transparent then
        BackgroundAlpha := 0
      else
        BackgroundAlpha := 255;
      Candidate.AddChunk('IPNG', CreateTexturePng(Canvas.BackgroundColor,
        BackgroundAlpha));
      RectangleIndex := 0;
      for I := 1 to Document.LayerCount - 1 do
      begin
        Layer := Document[I];
        if Layer is TVectArtTextLayer then
        begin
          TextLayer := TVectArtTextLayer(Layer);
          Candidate.AddChunk('IPNG', CreateTextImagePng(TextLayer));
          Candidate.AddChunk('IPNG', CreateFillTexturePng(TextLayer.TextColor,TextLayer.FillStyle,True));
          Continue;
        end;
        if Layer is TVectArtImageLayer then
        begin
          ImagePng := Copy(PreparedImagePngs[I]);
          Candidate.AddChunk('IPNG', ImagePng);
          Candidate.AddChunk('IPNG', CreateTexturePng(clWhite));
          Continue;
        end;
        if Layer is TVectArtLineLayer then
        begin
          Line := TVectArtLineLayer(Layer);
          Candidate.AddChunk('IPNG', CreateLineImagePng(Line));
          Candidate.AddChunk('IPNG', CreateTexturePng(clWhite));
          Candidate.AddChunk('IPNG', CreateLineVectorPng);
          Candidate.AddChunk('IPNG', CreateFillTexturePng(Line.StrokeColor,Line.StrokePaint,True));
          Continue;
        end;
        if Layer is TVectArtPathLayer then
        begin
          PathLayer := TVectArtPathLayer(Layer);
          PathExportShape := MifPathExportShape(PathLayer);
          if PathExportShape = mpesUnsupported then
            Continue;
          if PathExportShape = mpesLine then
          begin
            ConvertedLine := CreateMifLineFromPath(PathLayer);
            try
              Candidate.AddChunk('IPNG', CreateLineImagePng(ConvertedLine));
              Candidate.AddChunk('IPNG', CreateTexturePng(clWhite));
              Candidate.AddChunk('IPNG', CreateLineVectorPng);
              Candidate.AddChunk('IPNG',
                CreateFillTexturePng(ConvertedLine.StrokeColor,ConvertedLine.StrokePaint,True));
            finally
              ConvertedLine.Free;
            end;
            { Two-point Path is emitted with the Line chunk layout. }
          end
          else
          begin
            Candidate.AddChunk('IPNG', CreatePathImagePng(PathLayer));
            Candidate.AddChunk('IPNG',
              CreateFillTexturePng(PathLayer.FillColor,PathLayer.FillStyle));
            Candidate.AddChunk('IPNG', CreatePathVectorPng(PathLayer));
            Candidate.AddChunk('IPNG',
              CreateFillTexturePng(PathLayer.StrokeColor,PathLayer.StrokePaint,True));
            { Multi-point Path keeps the Path chunk layout. }
          end;
          Continue;
        end;
        if not (Layer is TVectArtRectangleLayer) then
          Continue;
        Rectangle := TVectArtRectangleLayer(Layer);
        RectangleSource := Default(TRectangleMifSource);
        if RectangleIndex < RectangleSources.Count then
          RectangleSource := RectangleSources[RectangleIndex];
        Candidate.AddChunk('IPNG', CreateRectangleImagePng(Rectangle,
          RectangleSource));
        Candidate.AddChunk('IPNG', CreateFillTexturePng(Rectangle.FillColor,Rectangle.FillStyle));
        Candidate.AddChunk('IPNG', CreateRectangleVectorPng(Rectangle,
          RectangleSource));
        Candidate.AddChunk('IPNG', CreateFillTexturePng(Rectangle.StrokeColor,Rectangle.StrokePaint,True));
        Inc(RectangleIndex);
      end;
      Candidate.AddChunk('MEND', nil);
      if Report.Compatibility = mecUnsupported then
      begin
        ErrorMessage := 'MIFへ書き出せない項目があります。';
        Exit;
      end;
      Container := Candidate;
      Candidate := nil;
      Result := True;
    except
      on E: Exception do
        ErrorMessage := E.Message;
    end;
  finally
    RectangleSources.Free;
    Candidate.Free;
  end;
end;

end.
