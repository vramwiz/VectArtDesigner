// 編集対象となる用紙とオブジェクトレイヤーを一元管理する。
// レイヤー配列の先頭を最背面、末尾を最前面とする。
unit VectArtDesignerDocument;

interface

uses
  System.Classes, System.Generics.Collections, System.SysUtils, System.Types,
  Vcl.Graphics;

type
  TVectArtFillKind = (vfkSolid, vfkLinearHorizontal, vfkLinearVertical, vfkRadial, vfkTexture, vfkCircle, vfkSquare, vfkWave, vfkSpectrum);
  TVectArtFillStyle = record
    Kind: TVectArtFillKind;
    Color2: TColor;
    // Absolute degrees for horizontal/angled linear fills; legacy vertical remains 90.
    Angle: Integer;
    // 中心から対角の端までの波の繰り返し数。MIFのtexture levelに対応する。
    WaveCount: Integer;
    TexturePng: TBytes;
  end;
  // MIF vector effectの影。位置とぼかしはドキュメント座標単位で保持する。
  TVectArtShadow = record
    Enabled: Boolean;
    Color: TColor;
    Blur: Integer;
    OffsetX, OffsetY: Integer;
  end;
  TVectArtLayerId = UInt64;
  TVectArtGroupId = UInt64;

  TVectArtLayerKind = (vlkCanvas, vlkRectangle, vlkLine, vlkPath, vlkImage,
    vlkText);
  TVectArtPrimitiveShape = (vpsRectangle, vpsEllipse);
  TVectArtImageSourceKind = (visImage, visLogo);
  TVectArtImagePoints = array[0..3] of TPointF;
  // WebArt Designerの線種コンボとMIF vector stroke style 0..8を同順で保持する。
  TVectArtStrokeStyle = (vssSolid, vssDotted, vssShortDash, vssDashDot,
    vssDashDotDot, vssSparseDotted, vssMediumDash, vssLongDashDot,
    vssLongDash);
  // MIFのvector stroke cap 0..2と同じ順序で保持する。
  TVectArtLineCap = (vlcButt, vlcSquare, vlcRound);
  // MIFのvector stroke join 0..2と同じ順序で保持する。
  TVectArtLineJoin = (vljMiter, vljBevel, vljRound);
  // WebArt DesignerのMIFマーカー値0..9を同順で保持する。
  // 既存JSONとの互換性のため、vlmArrowの序数1を変更しない。
  TVectArtLineMarker = (vlmNone, vlmArrow, vlmOpenArrow, vlmWideArrow,
    vlmCircle, vlmDiamond, vlmConcaveArrow, vlmSmallArrow, vlmSlash,
    vlmStar);

  TVectArtLayer = class
  private
    FShadow: TVectArtShadow;
    FStrokePaint: TVectArtFillStyle;
    FGroupId: TVectArtGroupId;
    FLayerId: TVectArtLayerId;
    FRevision: Int64;
    FKind: TVectArtLayerKind;
    FLocked: Boolean;
    FName: string;
    FOpacity: Single;
    FVisible: Boolean;
  protected
    constructor Create(AKind: TVectArtLayerKind; const AName: string);
  public
    property Shadow: TVectArtShadow read FShadow write FShadow;
    property StrokePaint: TVectArtFillStyle read FStrokePaint write FStrokePaint;
    property GroupId: TVectArtGroupId read FGroupId;
    property Kind: TVectArtLayerKind read FKind;
    property LayerId: TVectArtLayerId read FLayerId;
    property Locked: Boolean read FLocked write FLocked;
    property Name: string read FName write FName;
    property Opacity: Single read FOpacity write FOpacity;
    property Revision: Int64 read FRevision;
    property Visible: Boolean read FVisible write FVisible;
  end;

  TVectArtCanvasLayer = class(TVectArtLayer)
  private
    FBackgroundColor: TColor;
    FHeight: Integer;
    FTransparent: Boolean;
    FWidth: Integer;
  public
    constructor Create(AWidth, AHeight: Integer; AColor: TColor);
    property BackgroundColor: TColor read FBackgroundColor
      write FBackgroundColor;
    property Height: Integer read FHeight write FHeight;
    property Transparent: Boolean read FTransparent write FTransparent;
    property Width: Integer read FWidth write FWidth;
  end;

  TVectArtRectangleLayer = class(TVectArtLayer)
  private
    FBounds: TRectF;
    FFillColor: TColor;
    FFillStyle: TVectArtFillStyle;
    FFilled: Boolean;
    FRotationDegrees: Single;
    FShape: TVectArtPrimitiveShape;
    FStrokeColor: TColor;
    FStrokeStyle: TVectArtStrokeStyle;
    FStrokeWidth: Single;
  public
    constructor Create(const AName: string; const ABounds: TRectF;
      AFillColor: TColor);
    property Bounds: TRectF read FBounds write FBounds;
    property FillColor: TColor read FFillColor write FFillColor;
    property FillStyle: TVectArtFillStyle read FFillStyle write FFillStyle;
    property Filled: Boolean read FFilled write FFilled;
    property RotationDegrees: Single read FRotationDegrees
      write FRotationDegrees;
    property Shape: TVectArtPrimitiveShape read FShape write FShape;
    property StrokeColor: TColor read FStrokeColor write FStrokeColor;
    property StrokeStyle: TVectArtStrokeStyle read FStrokeStyle
      write FStrokeStyle;
    property StrokeWidth: Single read FStrokeWidth write FStrokeWidth;
  end;

  TVectArtRectangleData = record
    Shadow: TVectArtShadow;
    Bounds: TRectF;                         // 回転前の基本矩形。
    FillStyle: TVectArtFillStyle;
    FillColor: TColor;                      // 内部の塗り色。
    Filled: Boolean;                        // 内部を塗る状態。
    GroupId: TVectArtGroupId;               // フラットなグループ所属。0は未所属。
    Locked: Boolean;                        // 編集を禁止する状態。
    Name: string;                           // レイヤー一覧の表示名。
    Opacity: Single;                        // 0.0..1.0のレイヤー不透明度。
    RotationDegrees: Single;                // 中心回りの時計回り角度。
    Shape: TVectArtPrimitiveShape;           // 四角または楕円の描画形状。
    StrokePaint: TVectArtFillStyle;
    StrokeColor: TColor;                    // 枠線色。
    StrokeStyle: TVectArtStrokeStyle; // 枠線パターン。
    StrokeWidth: Single;                    // ドキュメント座標の枠線幅。
    Visible: Boolean;                       // 描画対象に含める状態。
  end;

  TVectArtLineLayer = class(TVectArtLayer)
  private
    FAntiAlias: Boolean;
    FEndPoint: TPointF;
    FEndMarker: TVectArtLineMarker;
    FEndMarkerSize: Single;
    FLineCap: TVectArtLineCap;
    FLineJoin: TVectArtLineJoin;
    FStartMarker: TVectArtLineMarker;
    FStartMarkerSize: Single;
    FStartPoint: TPointF;
    FStrokeColor: TColor;
    FStrokeStyle: TVectArtStrokeStyle;
    FStrokeWidth: Single;
  public
    constructor Create(const AName: string; const AStartPoint,
      AEndPoint: TPointF);
    property AntiAlias: Boolean read FAntiAlias write FAntiAlias;
    property EndPoint: TPointF read FEndPoint write FEndPoint;
    property EndMarker: TVectArtLineMarker read FEndMarker write FEndMarker;
    property EndMarkerSize: Single read FEndMarkerSize write FEndMarkerSize;
    property LineCap: TVectArtLineCap read FLineCap write FLineCap;
    property LineJoin: TVectArtLineJoin read FLineJoin write FLineJoin;
    property StartMarker: TVectArtLineMarker read FStartMarker
      write FStartMarker;
    property StartMarkerSize: Single read FStartMarkerSize write FStartMarkerSize;
    property StartPoint: TPointF read FStartPoint write FStartPoint;
    property StrokeColor: TColor read FStrokeColor write FStrokeColor;
    property StrokeStyle: TVectArtStrokeStyle read FStrokeStyle
      write FStrokeStyle;
    property StrokeWidth: Single read FStrokeWidth write FStrokeWidth;
  end;

  TVectArtLineData = record
    AntiAlias: Boolean;                  // MIF vector qualityに対応する品質値。
    EndPoint: TPointF;                      // 線の終点。
    EndMarker: TVectArtLineMarker;       // 終点マーカー。
    EndMarkerSize: Single;               // 終点マーカー倍率。
    LineCap: TVectArtLineCap;               // 共通の線端形状。
    LineJoin: TVectArtLineJoin;             // 共通の線結合形状。
    GroupId: TVectArtGroupId;               // フラットなグループ所属。0は未所属。
    Locked: Boolean;                        // 編集を禁止する状態。
    Name: string;                           // レイヤー一覧の表示名。
    Opacity: Single;                        // 0.0..1.0のレイヤー不透明度。
    StartPoint: TPointF;                    // 線の始点。
    StartMarker: TVectArtLineMarker;     // 始点マーカー。
    StartMarkerSize: Single;             // 始点マーカー倍率。
    StrokePaint: TVectArtFillStyle;
    StrokeColor: TColor;                    // 線色。
    StrokeStyle: TVectArtStrokeStyle;    // 線パターン。
    StrokeWidth: Single;                    // ドキュメント座標の線幅。
    Visible: Boolean;                       // 描画対象に含める状態。
  end;

  TVectArtPathLayer = class(TVectArtLayer)
  private
    FBezier: Boolean;
    FBoundsEditing: Boolean;
    FClosed: Boolean;
    FEndMarker: TVectArtLineMarker;
    FEndMarkerSize: Single;
    FFillColor: TColor;
    FFillStyle: TVectArtFillStyle;
    FFilled: Boolean;
    FLineCap: TVectArtLineCap;
    FLineJoin: TVectArtLineJoin;
    FAntiAlias: Boolean;
    FPoints: TArray<TPointF>;
    FStartMarker: TVectArtLineMarker;
    FStartMarkerSize: Single;
    FStrokeColor: TColor;
    FStrokeStyle: TVectArtStrokeStyle;
    FStrokeWidth: Single;
  public
    constructor Create(const AName: string; const APoints: TArray<TPointF>;
      AClosed: Boolean);
    property Bezier: Boolean read FBezier write FBezier;
    property BoundsEditing: Boolean read FBoundsEditing write FBoundsEditing;
    property Closed: Boolean read FClosed write FClosed;
    property EndMarker: TVectArtLineMarker read FEndMarker write FEndMarker;
    property EndMarkerSize: Single read FEndMarkerSize write FEndMarkerSize;
    property FillColor: TColor read FFillColor write FFillColor;
    property FillStyle: TVectArtFillStyle read FFillStyle write FFillStyle;
    property Filled: Boolean read FFilled write FFilled;
    property LineCap: TVectArtLineCap read FLineCap write FLineCap;
    property LineJoin: TVectArtLineJoin read FLineJoin write FLineJoin;
    property AntiAlias: Boolean read FAntiAlias write FAntiAlias;
    property Points: TArray<TPointF> read FPoints write FPoints;
    property StartMarker: TVectArtLineMarker read FStartMarker
      write FStartMarker;
    property StartMarkerSize: Single read FStartMarkerSize
      write FStartMarkerSize;
    property StrokeColor: TColor read FStrokeColor write FStrokeColor;
    property StrokeStyle: TVectArtStrokeStyle read FStrokeStyle
      write FStrokeStyle;
    property StrokeWidth: Single read FStrokeWidth write FStrokeWidth;
  end;

  TVectArtPathData = record
    Shadow: TVectArtShadow;
    Bezier: Boolean;                       // 頂点間を滑らかな3次ベジェで結ぶ。
    BoundsEditing: Boolean;                 // 頂点ではなく外接枠で変形する。
    Closed: Boolean;                        // 終点と始点を閉じる状態。
    EndMarker: TVectArtLineMarker;          // 開いたPathの終点マーカー。
    EndMarkerSize: Single;                  // 終点マーカー倍率。
    FillStyle: TVectArtFillStyle;
    FillColor: TColor;                      // 閉領域の塗り色。
    Filled: Boolean;                        // 閉領域を塗る状態。
    LineCap: TVectArtLineCap;               // 開いたPathの線端形状。
    LineJoin: TVectArtLineJoin;             // 頂点間の線結合形状。
    GroupId: TVectArtGroupId;               // フラットなグループ所属。0は未所属。
    AntiAlias: Boolean;                  // MIF vector qualityに対応する品質値。
    Locked: Boolean;                        // 編集を禁止する状態。
    Name: string;                           // レイヤー一覧の表示名。
    Opacity: Single;                        // 0.0..1.0のレイヤー不透明度。
    Points: TArray<TPointF>;                // 描画順に並ぶ頂点列。
    StartMarker: TVectArtLineMarker;        // 開いたPathの始点マーカー。
    StartMarkerSize: Single;                // 始点マーカー倍率。
    StrokePaint: TVectArtFillStyle;
    StrokeColor: TColor;                    // 輪郭線色。
    StrokeStyle: TVectArtStrokeStyle;    // 輪郭線パターン。
    StrokeWidth: Single;                    // ドキュメント座標の輪郭線幅。
    Visible: Boolean;                       // 描画対象に含める状態。
  end;

  TVectArtImageLayer = class(TVectArtLayer)
  private
    FPngData: TBytes;
    FPoints: TVectArtImagePoints;
    FSourceFileName: string;
    FSourceKind: TVectArtImageSourceKind;
  public
    constructor Create(const AName: string; const APngData: TBytes;
      const APoints: TVectArtImagePoints; ASourceKind: TVectArtImageSourceKind;
      const ASourceFileName: string = '');
    property PngData: TBytes read FPngData;
    property Points: TVectArtImagePoints read FPoints write FPoints;
    property SourceFileName: string read FSourceFileName;
    property SourceKind: TVectArtImageSourceKind read FSourceKind;
  end;

  TVectArtImageData = record
    GroupId: TVectArtGroupId;            // フラットなグループ所属。0は未所属。
    Locked: Boolean;                     // 編集を禁止する状態。
    Name: string;                        // レイヤー一覧の表示名。
    Opacity: Single;                     // 0.0..1.0のレイヤー不透明度。
    PngData: TBytes;                     // 埋め込みPNGの全バイト。
    Points: TVectArtImagePoints;         // 左上から時計回りの配置4頂点。
    SourceFileName: string;              // 取込元のフルパス。描画時は参照しない。
    SourceKind: TVectArtImageSourceKind; // MIF由来のimage／logo区分。
    Visible: Boolean;                    // 描画対象に含める状態。
  end;

  TVectArtTextLayer = class(TVectArtLayer)
  private
    FBounds: TRectF;
    FFlipHorizontal: Boolean;
    FFlipVertical: Boolean;
    FFontFamily: string;
    FFontSize: Single;
    FFontStyle: TFontStyles;
    FLetterSpacingRatio: Single;
    FLineSpacingRatio: Single;
    FRotationDegrees: Single;
    FText: string;
    FTextColor: TColor;
    FFillStyle: TVectArtFillStyle;
    FVertical: Boolean;
  public
    constructor Create(const AName: string; const ABounds: TRectF;
      const AText, AFontFamily: string; AFontSize: Single;
      ATextColor: TColor);
    property Bounds: TRectF read FBounds write FBounds;
    property FlipHorizontal: Boolean read FFlipHorizontal
      write FFlipHorizontal;
    property FlipVertical: Boolean read FFlipVertical write FFlipVertical;
    property FontFamily: string read FFontFamily write FFontFamily;
    property FontSize: Single read FFontSize write FFontSize;
    property FontStyle: TFontStyles read FFontStyle write FFontStyle;
    property LetterSpacingRatio: Single read FLetterSpacingRatio
      write FLetterSpacingRatio;
    property LineSpacingRatio: Single read FLineSpacingRatio
      write FLineSpacingRatio;
    property RotationDegrees: Single read FRotationDegrees
      write FRotationDegrees;
    property Text: string read FText write FText;
    property TextColor: TColor read FTextColor write FTextColor;
    property FillStyle: TVectArtFillStyle read FFillStyle write FFillStyle;
    property Vertical: Boolean read FVertical write FVertical;
  end;

  TVectArtTextData = record
    Bounds: TRectF;             // Unrotated text layout bounds.
    FlipHorizontal: Boolean;    // Mirror glyphs around the local vertical axis.
    FlipVertical: Boolean;      // Mirror glyphs around the local horizontal axis.
    FontFamily: string;
    FontSize: Single;
    FontStyle: TFontStyles;
    GroupId: TVectArtGroupId;     // フラットなグループ所属。0は未所属。
    LetterSpacingRatio: Single; // FontSizeに対する字間の割合。0が標準。
    LineSpacingRatio: Single;   // FontSizeに対する追加行間の割合。0が標準。
    Locked: Boolean;
    Name: string;
    Opacity: Single;
    RotationDegrees: Single;
    Text: string;               // Explicit line breaks are stored in-band.
    TextColor: TColor;
    FillStyle: TVectArtFillStyle;
    Vertical: Boolean;          // Trueなら改行単位の列を右から左へ縦組みする。
    Visible: Boolean;
  end;

  TVectArtDocument = class
  private
    FLayers: TObjectList<TVectArtLayer>;
    FChangePending: Boolean;
    FInteractiveChanged: Boolean;
    FInteractiveUpdateCount: Integer;
    FLayerIndexById: TDictionary<TVectArtLayerId, Integer>;
    FGroupMembersById: TObjectDictionary<TVectArtGroupId, TList<Integer>>;
    FLayerRelationsValid: Boolean;
    FLayerRelationRevision: Int64;
    FNextGroupId: TVectArtGroupId;
    FNextLayerId: TVectArtLayerId;
    FOnChanged: TNotifyEvent;
    FRevision: Int64;
    FSelectedIndex: Integer;
    FSelectedLayers: TList<Integer>;
    FUpdateCount: Integer;
    function GetCanvasLayer: TVectArtCanvasLayer;
    function GetLayer(Index: Integer): TVectArtLayer;
    function GetLayerCount: Integer;
    function GetIsInteractiveUpdate: Boolean;
    function GetSelectionCount: Integer;
    procedure DoChanged;
    procedure EnsureLayerIdentity(Layer: TVectArtLayer);
    procedure InvalidateLayerRelations;
    procedure RebuildLayerRelations;
    procedure SelectionChanged;
    procedure SetSelectedLayersCore(const Indices: array of Integer;
      Notify: Boolean);
    procedure SetSelectedIndex(const Value: Integer);
    procedure StructureChanged;
  public
    constructor Create;
    destructor Destroy; override;
    procedure BeginInteractiveUpdate;
    procedure BeginUpdate;
    procedure Changed;
    procedure ChangedLayer(Index: Integer);
    procedure EndInteractiveUpdate;
    procedure EndUpdate;
    function GetSelectedLayerIndices: TArray<Integer>;
    function AllocateGroupId: TVectArtGroupId;
    function GetGroupLayerIndices(GroupId: TVectArtGroupId): TArray<Integer>;
    function IndexOfLayerId(LayerId: TVectArtLayerId): Integer;
    function InsertRectangle(Index: Integer;
      const Data: TVectArtRectangleData): Integer;
    function InsertLine(Index: Integer; const Data: TVectArtLineData): Integer;
    function InsertPath(Index: Integer; const Data: TVectArtPathData): Integer;
    function InsertImage(Index: Integer; const Data: TVectArtImageData): Integer;
    function InsertText(Index: Integer; const Data: TVectArtTextData): Integer;
    function IsLayerSelected(Index: Integer): Boolean;
    procedure Reset(AWidth, AHeight: Integer);
    procedure SetCanvasSettings(AWidth, AHeight: Integer;
      ABackgroundColor: TColor; ATransparent: Boolean);
    procedure SetCanvasSize(AWidth, AHeight: Integer);
    procedure SetRectangleBounds(Index: Integer; const Value: TRectF);
    procedure SetRectangleFillColor(Index: Integer; Value: TColor);
    procedure SetRectangleRotation(Index: Integer; Value: Single);
    procedure SetRectangleStroke(Index: Integer; Color: TColor;
      Width: Single; Style: TVectArtStrokeStyle);
    procedure SetLinePoints(Index: Integer; const StartPoint,
      EndPoint: TPointF);
    procedure SetLineCap(Index: Integer; Value: TVectArtLineCap);
    procedure SetLineAntiAlias(Index: Integer; Value: Boolean);
    procedure SetLineEndMarker(Index: Integer; Value: TVectArtLineMarker);
    procedure SetLineEndMarkerSize(Index: Integer; Value: Single);
    procedure SetLineStartMarker(Index: Integer; Value: TVectArtLineMarker);
    procedure SetLineStartMarkerSize(Index: Integer; Value: Single);
    procedure SetLineJoin(Index: Integer; Value: TVectArtLineJoin);
    procedure SetLineStroke(Index: Integer; Color: TColor; Width: Single;
      Style: TVectArtStrokeStyle);
    procedure SetImagePoints(Index: Integer;
      const Points: TVectArtImagePoints);
    procedure SetPathFill(Index: Integer; Color: TColor; Filled: Boolean);
    procedure SetPathEndMarker(Index: Integer; Value: TVectArtLineMarker);
    procedure SetPathEndMarkerSize(Index: Integer; Value: Single);
    procedure SetPathLineCap(Index: Integer; Value: TVectArtLineCap);
    procedure SetPathLineJoin(Index: Integer; Value: TVectArtLineJoin);
    procedure SetPathAntiAlias(Index: Integer; Value: Boolean);
    procedure SetPathStartMarker(Index: Integer; Value: TVectArtLineMarker);
    procedure SetPathStartMarkerSize(Index: Integer; Value: Single);
    procedure SetLayerLocked(Index: Integer; Value: Boolean);
    procedure SetLayerGroup(Index: Integer; GroupId: TVectArtGroupId);
    procedure SetLayerOpacity(Index: Integer; Value: Single);
    procedure SetLayerVisible(Index: Integer; Value: Boolean);
    procedure MoveLayer(FromIndex, ToIndex: Integer);
    function RemoveRectangle(Index: Integer;
      out Data: TVectArtRectangleData): Boolean;
    function RemoveLine(Index: Integer; out Data: TVectArtLineData): Boolean;
    function RemovePath(Index: Integer; out Data: TVectArtPathData): Boolean;
    function RemoveImage(Index: Integer; out Data: TVectArtImageData): Boolean;
    function RemoveText(Index: Integer; out Data: TVectArtTextData): Boolean;
    procedure SetTextData(Index: Integer; const Data: TVectArtTextData);
    procedure SetPathPoints(Index: Integer; const Points: TArray<TPointF>);
    procedure SetPathStroke(Index: Integer; Color: TColor; Width: Single;
      Style: TVectArtStrokeStyle);
    procedure SelectLayerRange(AnchorIndex, TargetIndex: Integer;
      Additive: Boolean);
    procedure SetSelectedLayers(const Indices: array of Integer);
    procedure ToggleSelectedLayer(Index: Integer);
    property CanvasLayer: TVectArtCanvasLayer read GetCanvasLayer;
    property LayerCount: Integer read GetLayerCount;
    property Layers[Index: Integer]: TVectArtLayer read GetLayer; default;
    property IsInteractiveUpdate: Boolean read GetIsInteractiveUpdate;
    property LayerRelationRevision: Int64 read FLayerRelationRevision;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
    property Revision: Int64 read FRevision;
    property SelectedIndex: Integer read FSelectedIndex write SetSelectedIndex;
    property SelectionCount: Integer read GetSelectionCount;
  end;

const
  VECTART_NO_GROUP: TVectArtGroupId = 0;
  DEFAULT_CANVAS_WIDTH = 1920;
  DEFAULT_CANVAS_HEIGHT = 1080;
  // 旧実装名はMIF style 3（ダッシュ・ドット）として互換維持する。
  vssDashed: TVectArtStrokeStyle = vssDashDot;

function VectArtStrokeDashIntervals(Style: TVectArtStrokeStyle;
  Width: Single): TArray<Single>;
function VectArtStrokeUsesRoundCaps(Style: TVectArtStrokeStyle): Boolean;
function CaptureVectArtTextData(Layer: TVectArtTextLayer): TVectArtTextData;

implementation

uses
  System.Math, VectArtDesignerGeometry;

function VectArtStrokeDashIntervals(Style: TVectArtStrokeStyle;
  Width: Single): TArray<Single>;
begin
  Width := Max(Width, 0.1);
  case Style of
    vssDotted:
      Result := [Width, Width * 2];
    vssShortDash:
      Result := [Width * 3, Width * 3];
    vssDashDot:
      Result := [Width * 6, Width * 2, Width, Width * 2];
    vssDashDotDot:
      Result := [Width * 6, Width * 2, Width, Width * 2,
        Width, Width * 2];
    vssSparseDotted:
      Result := [Width, Width * 4];
    vssMediumDash:
      Result := [Width * 5, Width * 2];
    vssLongDashDot:
      Result := [Width * 9, Width * 2, Width, Width * 2];
    vssLongDash:
      Result := [Width * 9, Width * 3];
  else
    Result := nil;
  end;
end;

function VectArtStrokeUsesRoundCaps(Style: TVectArtStrokeStyle): Boolean;
begin
  Result := Style in [vssDotted, vssDashDot, vssDashDotDot,
    vssSparseDotted, vssLongDashDot];
end;

{ TVectArtLayer }

constructor TVectArtLayer.Create(AKind: TVectArtLayerKind;
  const AName: string);
begin
  inherited Create;
  FGroupId := VECTART_NO_GROUP;
  FKind := AKind;
  FLayerId := 0;
  FLocked := False;
  FName := AName;
  FOpacity := 1.0;
  FRevision := 0;
  FVisible := True;
end;

{ TVectArtCanvasLayer }

constructor TVectArtCanvasLayer.Create(AWidth, AHeight: Integer;
  AColor: TColor);
begin
  inherited Create(vlkCanvas, 'Canvas');
  FWidth := Max(AWidth, 1);
  FHeight := Max(AHeight, 1);
  FBackgroundColor := AColor;
  FTransparent := False;
end;

{ TVectArtRectangleLayer }

constructor TVectArtRectangleLayer.Create(const AName: string;
  const ABounds: TRectF; AFillColor: TColor);
begin
  inherited Create(vlkRectangle, AName);
  FBounds := ABounds;
  FFillColor := AFillColor;
  FFilled := True;
  FRotationDegrees := 0.0;
  FShape := vpsRectangle;
  FStrokeColor := clBlack;
  FStrokeStyle := vssSolid;
  // 作成状態を経由しない四角も、既定では枠＋塗りとする。
  FStrokeWidth := 1.0;
end;

{ TVectArtLineLayer }

constructor TVectArtLineLayer.Create(const AName: string;
  const AStartPoint, AEndPoint: TPointF);
begin
  inherited Create(vlkLine, AName);
  FAntiAlias := True;
  FEndMarker := vlmNone;
  FEndMarkerSize := 4.0;
  FStartPoint := AStartPoint;
  FEndPoint := AEndPoint;
  FLineCap := vlcButt;
  FLineJoin := vljMiter;
  FStartMarker := vlmNone;
  FStartMarkerSize := 4.0;
  FStrokeColor := clBlack;
  FStrokeStyle := vssSolid;
  FStrokeWidth := 1.0;
end;

{ TVectArtPathLayer }

constructor TVectArtPathLayer.Create(const AName: string;
  const APoints: TArray<TPointF>; AClosed: Boolean);
begin
  inherited Create(vlkPath, AName);
  FPoints := Copy(APoints);
  FBezier := False;
  FBoundsEditing := False;
  FClosed := AClosed;
  FEndMarker := vlmNone;
  FEndMarkerSize := 4.0;
  FFillColor := clWhite;
  FFilled := AClosed;
  FLineCap := vlcButt;
  FLineJoin := vljMiter;
  FAntiAlias := True;
  FStartMarker := vlmNone;
  FStartMarkerSize := 4.0;
  FStrokeColor := clBlack;
  FStrokeStyle := vssSolid;
  FStrokeWidth := 1.0;
end;

{ TVectArtImageLayer }

constructor TVectArtImageLayer.Create(const AName: string;
  const APngData: TBytes; const APoints: TVectArtImagePoints;
  ASourceKind: TVectArtImageSourceKind; const ASourceFileName: string);
begin
  inherited Create(vlkImage, AName);
  FPngData := Copy(APngData);
  FPoints := APoints;
  FSourceFileName := ASourceFileName;
  FSourceKind := ASourceKind;
end;

{ TVectArtTextLayer }

constructor TVectArtTextLayer.Create(const AName: string;
  const ABounds: TRectF; const AText, AFontFamily: string;
  AFontSize: Single; ATextColor: TColor);
begin
  inherited Create(vlkText, AName);
  FBounds := ABounds;
  FFlipHorizontal := False;
  FFlipVertical := False;
  FText := AText;
  FFontFamily := AFontFamily;
  FFontSize := Max(AFontSize, 1.0);
  FFontStyle := [];
  FLetterSpacingRatio := 0.0;
  FLineSpacingRatio := 0.0;
  FTextColor := ATextColor;
  FRotationDegrees := 0.0;
  FVertical := False;
end;

function CaptureVectArtTextData(Layer: TVectArtTextLayer): TVectArtTextData;
begin
  Result := Default(TVectArtTextData);
  if Layer = nil then
    Exit;
  Result.Bounds := Layer.Bounds;
  Result.FlipHorizontal := Layer.FlipHorizontal;
  Result.FlipVertical := Layer.FlipVertical;
  Result.FontFamily := Layer.FontFamily;
  Result.FontSize := Layer.FontSize;
  Result.FontStyle := Layer.FontStyle;
  Result.GroupId := Layer.GroupId;
  Result.LetterSpacingRatio := Layer.LetterSpacingRatio;
  Result.LineSpacingRatio := Layer.LineSpacingRatio;
  Result.Locked := Layer.Locked;
  Result.Name := Layer.Name;
  Result.Opacity := Layer.Opacity;
  Result.RotationDegrees := Layer.RotationDegrees;
  Result.Text := Layer.Text;
  Result.TextColor := Layer.TextColor;
  Result.FillStyle := Layer.FillStyle;
  Result.Vertical := Layer.Vertical;
  Result.Visible := Layer.Visible;
end;

{ TVectArtDocument }

constructor TVectArtDocument.Create;
begin
  inherited Create;
  FLayers := TObjectList<TVectArtLayer>.Create(True);
  FLayerIndexById := TDictionary<TVectArtLayerId, Integer>.Create;
  FGroupMembersById := TObjectDictionary<TVectArtGroupId,
    TList<Integer>>.Create([doOwnsValues]);
  FSelectedLayers := TList<Integer>.Create;
  FLayers.Add(TVectArtCanvasLayer.Create(DEFAULT_CANVAS_WIDTH,
    DEFAULT_CANVAS_HEIGHT, clWhite));
  FNextGroupId := 1;
  FNextLayerId := 1;
  EnsureLayerIdentity(FLayers[0]);
  FLayerRelationsValid := False;
  FSelectedIndex := -1;
end;

destructor TVectArtDocument.Destroy;
begin
  FSelectedLayers.Free;
  FGroupMembersById.Free;
  FLayerIndexById.Free;
  FLayers.Free;
  inherited Destroy;
end;

procedure TVectArtDocument.DoChanged;
begin
  if FUpdateCount > 0 then
  begin
    FChangePending := True;
    Exit;
  end;
  Inc(FRevision);
  if FInteractiveUpdateCount > 0 then
    FInteractiveChanged := True;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtDocument.Changed;
var
  Layer: TVectArtLayer;
begin
  // 呼び出し側が変更レイヤーを特定できない場合だけ全キャッシュを失効させる。
  for Layer in FLayers do
    Inc(Layer.FRevision);
  DoChanged;
end;

procedure TVectArtDocument.ChangedLayer(Index: Integer);
begin
  if (Index < 0) or (Index >= FLayers.Count) then
    Exit;
  Inc(FLayers[Index].FRevision);
  DoChanged;
end;

procedure TVectArtDocument.EnsureLayerIdentity(Layer: TVectArtLayer);
begin
  if Layer = nil then
    Exit;
  if Layer.FLayerId = 0 then
  begin
    Layer.FLayerId := FNextLayerId;
    Inc(FNextLayerId);
  end
  else if Layer.FLayerId >= FNextLayerId then
    FNextLayerId := Layer.FLayerId + 1;
end;

procedure TVectArtDocument.InvalidateLayerRelations;
begin
  FLayerRelationsValid := False;
  Inc(FLayerRelationRevision);
end;

procedure TVectArtDocument.RebuildLayerRelations;
var
  GroupMembers: TList<Integer>;
  I: Integer;
  Layer: TVectArtLayer;
begin
  if FLayerRelationsValid then
    Exit;
  FLayerIndexById.Clear;
  FGroupMembersById.Clear;
  for I := 0 to FLayers.Count - 1 do
  begin
    Layer := FLayers[I];
    EnsureLayerIdentity(Layer);
    FLayerIndexById.AddOrSetValue(Layer.LayerId, I);
    if Layer.GroupId = VECTART_NO_GROUP then
      Continue;
    if not FGroupMembersById.TryGetValue(Layer.GroupId, GroupMembers) then
    begin
      GroupMembers := TList<Integer>.Create;
      FGroupMembersById.Add(Layer.GroupId, GroupMembers);
    end;
    GroupMembers.Add(I);
  end;
  FLayerRelationsValid := True;
end;

procedure TVectArtDocument.StructureChanged;
begin
  InvalidateLayerRelations;
  // 並べ替えや追加・削除では既存レイヤーの描画内容自体は変わらない。
  DoChanged;
end;

procedure TVectArtDocument.BeginInteractiveUpdate;
begin
  Inc(FInteractiveUpdateCount);
end;

procedure TVectArtDocument.BeginUpdate;
begin
  Inc(FUpdateCount);
end;

procedure TVectArtDocument.EndInteractiveUpdate;
begin
  if FInteractiveUpdateCount <= 0 then
    Exit;
  Dec(FInteractiveUpdateCount);
  if (FInteractiveUpdateCount = 0) and FInteractiveChanged then
  begin
    FInteractiveChanged := False;
    if Assigned(FOnChanged) then
      FOnChanged(Self);
  end;
end;

procedure TVectArtDocument.EndUpdate;
begin
  if FUpdateCount <= 0 then
    Exit;
  Dec(FUpdateCount);
  if (FUpdateCount = 0) and FChangePending then
  begin
    FChangePending := False;
    DoChanged;
  end;
end;

procedure TVectArtDocument.SelectionChanged;
begin
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

function TVectArtDocument.GetSelectedLayerIndices: TArray<Integer>;
begin
  Result := FSelectedLayers.ToArray;
end;

function TVectArtDocument.AllocateGroupId: TVectArtGroupId;
begin
  Result := FNextGroupId;
  Inc(FNextGroupId);
end;

function TVectArtDocument.GetGroupLayerIndices(
  GroupId: TVectArtGroupId): TArray<Integer>;
var
  GroupMembers: TList<Integer>;
begin
  Result := nil;
  if GroupId = VECTART_NO_GROUP then
    Exit;
  RebuildLayerRelations;
  if FGroupMembersById.TryGetValue(GroupId, GroupMembers) then
    Result := GroupMembers.ToArray;
end;

function TVectArtDocument.IndexOfLayerId(LayerId: TVectArtLayerId): Integer;
begin
  Result := -1;
  if LayerId = 0 then
    Exit;
  RebuildLayerRelations;
  FLayerIndexById.TryGetValue(LayerId, Result);
end;

function TVectArtDocument.GetIsInteractiveUpdate: Boolean;
begin
  Result := FInteractiveUpdateCount > 0;
end;

function TVectArtDocument.InsertRectangle(Index: Integer;
  const Data: TVectArtRectangleData): Integer;
var
  I: Integer;
  RectangleLayer: TVectArtRectangleLayer;
begin
  Result := EnsureRange(Index, 1, FLayers.Count);
  RectangleLayer := TVectArtRectangleLayer.Create(Data.Name, Data.Bounds,
    Data.FillColor);
  RectangleLayer.FillStyle := Data.FillStyle;
  RectangleLayer.Filled := Data.Filled;
  RectangleLayer.FGroupId := Data.GroupId;
  if Data.GroupId >= FNextGroupId then
    FNextGroupId := Data.GroupId + 1;
  RectangleLayer.Locked := Data.Locked;
  RectangleLayer.Opacity := EnsureRange(Data.Opacity, 0.0, 1.0);
  RectangleLayer.RotationDegrees := NormalizeAngleDegrees(
    Data.RotationDegrees);
  if Data.Shape = vpsEllipse then
    RectangleLayer.Shape := vpsEllipse
  else
    RectangleLayer.Shape := vpsRectangle;
  RectangleLayer.Shadow := Data.Shadow;
  RectangleLayer.StrokePaint := Data.StrokePaint;
  RectangleLayer.StrokeColor := Data.StrokeColor;
  RectangleLayer.StrokeStyle := Data.StrokeStyle;
  RectangleLayer.StrokeWidth := Max(Data.StrokeWidth, 0.0);
  RectangleLayer.Visible := Data.Visible;
  EnsureLayerIdentity(RectangleLayer);
  FLayers.Insert(Result, RectangleLayer);
  for I := 0 to FSelectedLayers.Count - 1 do
    if FSelectedLayers[I] >= Result then
      FSelectedLayers[I] := FSelectedLayers[I] + 1;
  if FSelectedIndex >= Result then
    Inc(FSelectedIndex);
  StructureChanged;
end;

function TVectArtDocument.InsertLine(Index: Integer;
  const Data: TVectArtLineData): Integer;
var
  I: Integer;
  LineLayer: TVectArtLineLayer;
begin
  Result := EnsureRange(Index, 1, FLayers.Count);
  LineLayer := TVectArtLineLayer.Create(Data.Name, Data.StartPoint,
    Data.EndPoint);
  LineLayer.Locked := Data.Locked;
  LineLayer.FGroupId := Data.GroupId;
  if Data.GroupId >= FNextGroupId then
    FNextGroupId := Data.GroupId + 1;
  LineLayer.LineCap := Data.LineCap;
  LineLayer.AntiAlias := Data.AntiAlias;
  LineLayer.EndMarker := Data.EndMarker;
  LineLayer.EndMarkerSize := Max(Data.EndMarkerSize, 1.0);
  LineLayer.LineJoin := Data.LineJoin;
  LineLayer.StartMarker := Data.StartMarker;
  LineLayer.StartMarkerSize := Max(Data.StartMarkerSize, 1.0);
  LineLayer.Opacity := EnsureRange(Data.Opacity, 0.0, 1.0);
  LineLayer.StrokePaint := Data.StrokePaint;
  LineLayer.StrokeColor := Data.StrokeColor;
  LineLayer.StrokeStyle := Data.StrokeStyle;
  LineLayer.StrokeWidth := Max(Data.StrokeWidth, 0.1);
  LineLayer.Visible := Data.Visible;
  EnsureLayerIdentity(LineLayer);
  FLayers.Insert(Result, LineLayer);
  for I := 0 to FSelectedLayers.Count - 1 do
    if FSelectedLayers[I] >= Result then
      FSelectedLayers[I] := FSelectedLayers[I] + 1;
  if FSelectedIndex >= Result then
    Inc(FSelectedIndex);
  StructureChanged;
end;

function TVectArtDocument.InsertPath(Index: Integer;
  const Data: TVectArtPathData): Integer;
var
  I: Integer;
  PathLayer: TVectArtPathLayer;
begin
  Result := EnsureRange(Index, 1, FLayers.Count);
  PathLayer := TVectArtPathLayer.Create(Data.Name, Data.Points, Data.Closed);
  PathLayer.Bezier := Data.Bezier;
  PathLayer.BoundsEditing := Data.BoundsEditing;
  PathLayer.EndMarker := Data.EndMarker;
  PathLayer.EndMarkerSize := Max(Data.EndMarkerSize, 1.0);
  PathLayer.FillStyle := Data.FillStyle;
  PathLayer.FillColor := Data.FillColor;
  PathLayer.Filled := Data.Filled;
  PathLayer.LineCap := Data.LineCap;
  PathLayer.LineJoin := Data.LineJoin;
  PathLayer.FGroupId := Data.GroupId;
  if Data.GroupId >= FNextGroupId then
    FNextGroupId := Data.GroupId + 1;
  PathLayer.AntiAlias := Data.AntiAlias;
  PathLayer.Locked := Data.Locked;
  PathLayer.Opacity := EnsureRange(Data.Opacity, 0.0, 1.0);
  PathLayer.StartMarker := Data.StartMarker;
  PathLayer.StartMarkerSize := Max(Data.StartMarkerSize, 1.0);
  PathLayer.Shadow := Data.Shadow;
  PathLayer.StrokePaint := Data.StrokePaint;
  PathLayer.StrokeColor := Data.StrokeColor;
  PathLayer.StrokeStyle := Data.StrokeStyle;
  PathLayer.StrokeWidth := Max(Data.StrokeWidth, 0.0);
  PathLayer.Visible := Data.Visible;
  EnsureLayerIdentity(PathLayer);
  FLayers.Insert(Result, PathLayer);
  for I := 0 to FSelectedLayers.Count - 1 do
    if FSelectedLayers[I] >= Result then
      FSelectedLayers[I] := FSelectedLayers[I] + 1;
  if FSelectedIndex >= Result then
    Inc(FSelectedIndex);
  StructureChanged;
end;

function TVectArtDocument.InsertImage(Index: Integer;
  const Data: TVectArtImageData): Integer;
var
  I: Integer;
  ImageLayer: TVectArtImageLayer;
begin
  Result := EnsureRange(Index, 1, FLayers.Count);
  ImageLayer := TVectArtImageLayer.Create(Data.Name, Data.PngData,
    Data.Points, Data.SourceKind, Data.SourceFileName);
  ImageLayer.Locked := Data.Locked;
  ImageLayer.FGroupId := Data.GroupId;
  if Data.GroupId >= FNextGroupId then
    FNextGroupId := Data.GroupId + 1;
  ImageLayer.Opacity := EnsureRange(Data.Opacity, 0.0, 1.0);
  ImageLayer.Visible := Data.Visible;
  EnsureLayerIdentity(ImageLayer);
  FLayers.Insert(Result, ImageLayer);
  for I := 0 to FSelectedLayers.Count - 1 do
    if FSelectedLayers[I] >= Result then
      FSelectedLayers[I] := FSelectedLayers[I] + 1;
  if FSelectedIndex >= Result then
    Inc(FSelectedIndex);
  StructureChanged;
end;

function TVectArtDocument.InsertText(Index: Integer;
  const Data: TVectArtTextData): Integer;
var
  I: Integer;
  TextLayer: TVectArtTextLayer;
begin
  Result := EnsureRange(Index, 1, FLayers.Count);
  TextLayer := TVectArtTextLayer.Create(Data.Name, Data.Bounds, Data.Text,
    Data.FontFamily, Data.FontSize, Data.TextColor);
  TextLayer.FillStyle := Data.FillStyle;
  TextLayer.FlipHorizontal := Data.FlipHorizontal;
  TextLayer.FlipVertical := Data.FlipVertical;
  TextLayer.FontStyle := Data.FontStyle;
  TextLayer.FGroupId := Data.GroupId;
  if Data.GroupId >= FNextGroupId then
    FNextGroupId := Data.GroupId + 1;
  TextLayer.LetterSpacingRatio := Data.LetterSpacingRatio;
  TextLayer.LineSpacingRatio := Data.LineSpacingRatio;
  TextLayer.Locked := Data.Locked;
  TextLayer.Opacity := EnsureRange(Data.Opacity, 0.0, 1.0);
  TextLayer.RotationDegrees := NormalizeAngleDegrees(Data.RotationDegrees);
  TextLayer.Vertical := Data.Vertical;
  TextLayer.Visible := Data.Visible;
  EnsureLayerIdentity(TextLayer);
  FLayers.Insert(Result, TextLayer);
  for I := 0 to FSelectedLayers.Count - 1 do
    if FSelectedLayers[I] >= Result then
      FSelectedLayers[I] := FSelectedLayers[I] + 1;
  if FSelectedIndex >= Result then
    Inc(FSelectedIndex);
  StructureChanged;
end;

procedure TVectArtDocument.MoveLayer(FromIndex, ToIndex: Integer);
var
  I: Integer;
  Layer: TVectArtLayer;
  Selection: TArray<Integer>;
begin
  if (FromIndex <= 0) or (FromIndex >= FLayers.Count) then
    Exit;
  ToIndex := EnsureRange(ToIndex, 1, FLayers.Count - 1);
  if FromIndex = ToIndex then
    Exit;
  Selection := GetSelectedLayerIndices;
  Layer := FLayers.Extract(FLayers[FromIndex]);
  FLayers.Insert(ToIndex, Layer);
  for I := 0 to High(Selection) do
    if Selection[I] = FromIndex then
      Selection[I] := ToIndex
    else if (FromIndex < ToIndex) and (Selection[I] > FromIndex) and
      (Selection[I] <= ToIndex) then
      Dec(Selection[I])
    else if (FromIndex > ToIndex) and (Selection[I] >= ToIndex) and
      (Selection[I] < FromIndex) then
      Inc(Selection[I]);
  SetSelectedLayersCore(Selection, False);
  StructureChanged;
end;

function TVectArtDocument.RemoveRectangle(Index: Integer;
  out Data: TVectArtRectangleData): Boolean;
var
  I: Integer;
  RectangleLayer: TVectArtRectangleLayer;
  Selection: TList<Integer>;
begin
  Result := (Index > 0) and (Index < FLayers.Count) and
    (FLayers[Index] is TVectArtRectangleLayer);
  if not Result then
    Exit;
  RectangleLayer := TVectArtRectangleLayer(FLayers[Index]);
  Data.Bounds := RectangleLayer.Bounds;
  Data.FillStyle := RectangleLayer.FillStyle;
  Data.FillColor := RectangleLayer.FillColor;
  Data.Filled := RectangleLayer.Filled;
  Data.GroupId := RectangleLayer.GroupId;
  Data.Locked := RectangleLayer.Locked;
  Data.Name := RectangleLayer.Name;
  Data.Opacity := RectangleLayer.Opacity;
  Data.RotationDegrees := RectangleLayer.RotationDegrees;
  Data.Shape := RectangleLayer.Shape;
  Data.Shadow := RectangleLayer.Shadow;
  Data.StrokePaint := RectangleLayer.StrokePaint;
  Data.StrokeColor := RectangleLayer.StrokeColor;
  Data.StrokeStyle := RectangleLayer.StrokeStyle;
  Data.StrokeWidth := RectangleLayer.StrokeWidth;
  Data.Visible := RectangleLayer.Visible;
  FLayers.Delete(Index);
  Selection := TList<Integer>.Create;
  try
    for I := 0 to FSelectedLayers.Count - 1 do
      if FSelectedLayers[I] < Index then
        Selection.Add(FSelectedLayers[I])
      else if FSelectedLayers[I] > Index then
        Selection.Add(FSelectedLayers[I] - 1);
    if (Selection.Count = 0) and (FLayers.Count > 1) then
      Selection.Add(Min(Index, FLayers.Count - 1));
    SetSelectedLayersCore(Selection.ToArray, False);
  finally
    Selection.Free;
  end;
  StructureChanged;
end;

function TVectArtDocument.RemoveLine(Index: Integer;
  out Data: TVectArtLineData): Boolean;
var
  I: Integer;
  LineLayer: TVectArtLineLayer;
  Selection: TList<Integer>;
begin
  Result := (Index > 0) and (Index < FLayers.Count) and
    (FLayers[Index] is TVectArtLineLayer);
  if not Result then
    Exit;
  LineLayer := TVectArtLineLayer(FLayers[Index]);
  Data.EndPoint := LineLayer.EndPoint;
  Data.LineCap := LineLayer.LineCap;
  Data.AntiAlias := LineLayer.AntiAlias;
  Data.EndMarker := LineLayer.EndMarker;
  Data.EndMarkerSize := LineLayer.EndMarkerSize;
  Data.LineJoin := LineLayer.LineJoin;
  Data.GroupId := LineLayer.GroupId;
  Data.StartMarker := LineLayer.StartMarker;
  Data.StartMarkerSize := LineLayer.StartMarkerSize;
  Data.Locked := LineLayer.Locked;
  Data.Name := LineLayer.Name;
  Data.Opacity := LineLayer.Opacity;
  Data.StartPoint := LineLayer.StartPoint;
  Data.StrokePaint := LineLayer.StrokePaint;
  Data.StrokeColor := LineLayer.StrokeColor;
  Data.StrokeStyle := LineLayer.StrokeStyle;
  Data.StrokeWidth := LineLayer.StrokeWidth;
  Data.Visible := LineLayer.Visible;
  FLayers.Delete(Index);
  Selection := TList<Integer>.Create;
  try
    for I := 0 to FSelectedLayers.Count - 1 do
      if FSelectedLayers[I] < Index then
        Selection.Add(FSelectedLayers[I])
      else if FSelectedLayers[I] > Index then
        Selection.Add(FSelectedLayers[I] - 1);
    if (Selection.Count = 0) and (FLayers.Count > 1) then
      Selection.Add(Min(Index, FLayers.Count - 1));
    SetSelectedLayersCore(Selection.ToArray, False);
  finally
    Selection.Free;
  end;
  StructureChanged;
end;

function TVectArtDocument.RemovePath(Index: Integer;
  out Data: TVectArtPathData): Boolean;
var
  I: Integer;
  PathLayer: TVectArtPathLayer;
  Selection: TList<Integer>;
begin
  Result := (Index > 0) and (Index < FLayers.Count) and
    (FLayers[Index] is TVectArtPathLayer);
  if not Result then
    Exit;
  PathLayer := TVectArtPathLayer(FLayers[Index]);
  Data.Bezier := PathLayer.Bezier;
  Data.BoundsEditing := PathLayer.BoundsEditing;
  Data.Closed := PathLayer.Closed;
  Data.EndMarker := PathLayer.EndMarker;
  Data.EndMarkerSize := PathLayer.EndMarkerSize;
  Data.FillStyle := PathLayer.FillStyle;
  Data.FillColor := PathLayer.FillColor;
  Data.Filled := PathLayer.Filled;
  Data.LineCap := PathLayer.LineCap;
  Data.LineJoin := PathLayer.LineJoin;
  Data.AntiAlias := PathLayer.AntiAlias;
  Data.GroupId := PathLayer.GroupId;
  Data.Locked := PathLayer.Locked;
  Data.Name := PathLayer.Name;
  Data.Opacity := PathLayer.Opacity;
  Data.Points := Copy(PathLayer.Points);
  Data.StartMarker := PathLayer.StartMarker;
  Data.StartMarkerSize := PathLayer.StartMarkerSize;
  Data.Shadow := PathLayer.Shadow;
  Data.StrokePaint := PathLayer.StrokePaint;
  Data.StrokeColor := PathLayer.StrokeColor;
  Data.StrokeStyle := PathLayer.StrokeStyle;
  Data.StrokeWidth := PathLayer.StrokeWidth;
  Data.Visible := PathLayer.Visible;
  FLayers.Delete(Index);
  Selection := TList<Integer>.Create;
  try
    for I := 0 to FSelectedLayers.Count - 1 do
      if FSelectedLayers[I] < Index then
        Selection.Add(FSelectedLayers[I])
      else if FSelectedLayers[I] > Index then
        Selection.Add(FSelectedLayers[I] - 1);
    if (Selection.Count = 0) and (FLayers.Count > 1) then
      Selection.Add(Min(Index, FLayers.Count - 1));
    SetSelectedLayersCore(Selection.ToArray, False);
  finally
    Selection.Free;
  end;
  StructureChanged;
end;

function TVectArtDocument.RemoveImage(Index: Integer;
  out Data: TVectArtImageData): Boolean;
var
  I: Integer;
  ImageLayer: TVectArtImageLayer;
  Selection: TList<Integer>;
begin
  Result := (Index > 0) and (Index < FLayers.Count) and
    (FLayers[Index] is TVectArtImageLayer);
  if not Result then
    Exit;
  ImageLayer := TVectArtImageLayer(FLayers[Index]);
  Data.Locked := ImageLayer.Locked;
  Data.GroupId := ImageLayer.GroupId;
  Data.Name := ImageLayer.Name;
  Data.Opacity := ImageLayer.Opacity;
  Data.PngData := Copy(ImageLayer.PngData);
  Data.Points := ImageLayer.Points;
  Data.SourceFileName := ImageLayer.SourceFileName;
  Data.SourceKind := ImageLayer.SourceKind;
  Data.Visible := ImageLayer.Visible;
  FLayers.Delete(Index);
  Selection := TList<Integer>.Create;
  try
    for I := 0 to FSelectedLayers.Count - 1 do
      if FSelectedLayers[I] < Index then
        Selection.Add(FSelectedLayers[I])
      else if FSelectedLayers[I] > Index then
        Selection.Add(FSelectedLayers[I] - 1);
    if (Selection.Count = 0) and (FLayers.Count > 1) then
      Selection.Add(Min(Index, FLayers.Count - 1));
    SetSelectedLayersCore(Selection.ToArray, False);
  finally
    Selection.Free;
  end;
  StructureChanged;
end;

function TVectArtDocument.RemoveText(Index: Integer;
  out Data: TVectArtTextData): Boolean;
var
  I: Integer;
  Selection: TList<Integer>;
begin
  Result := (Index > 0) and (Index < FLayers.Count) and
    (FLayers[Index] is TVectArtTextLayer);
  if not Result then
    Exit;
  Data := CaptureVectArtTextData(TVectArtTextLayer(FLayers[Index]));
  FLayers.Delete(Index);
  Selection := TList<Integer>.Create;
  try
    for I := 0 to FSelectedLayers.Count - 1 do
      if FSelectedLayers[I] < Index then
        Selection.Add(FSelectedLayers[I])
      else if FSelectedLayers[I] > Index then
        Selection.Add(FSelectedLayers[I] - 1);
    if (Selection.Count = 0) and (FLayers.Count > 1) then
      Selection.Add(Min(Index, FLayers.Count - 1));
    SetSelectedLayersCore(Selection.ToArray, False);
  finally
    Selection.Free;
  end;
  StructureChanged;
end;

procedure TVectArtDocument.SetTextData(Index: Integer;
  const Data: TVectArtTextData);
var
  Layer: TVectArtTextLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtTextLayer) then
    Exit;
  Layer := TVectArtTextLayer(FLayers[Index]);
  Layer.Bounds := Data.Bounds;
  Layer.FlipHorizontal := Data.FlipHorizontal;
  Layer.FlipVertical := Data.FlipVertical;
  Layer.FontFamily := Data.FontFamily;
  Layer.FontSize := Max(Data.FontSize, 1.0);
  Layer.FontStyle := Data.FontStyle;
  if Layer.GroupId <> Data.GroupId then
  begin
    Layer.FGroupId := Data.GroupId;
    if Data.GroupId >= FNextGroupId then
      FNextGroupId := Data.GroupId + 1;
    InvalidateLayerRelations;
  end;
  Layer.LetterSpacingRatio := Data.LetterSpacingRatio;
  Layer.LineSpacingRatio := Data.LineSpacingRatio;
  Layer.Locked := Data.Locked;
  Layer.Name := Data.Name;
  Layer.Opacity := EnsureRange(Data.Opacity, 0.0, 1.0);
  Layer.RotationDegrees := NormalizeAngleDegrees(Data.RotationDegrees);
  Layer.Text := Data.Text;
  Layer.TextColor := Data.TextColor;
  Layer.FillStyle := Data.FillStyle;
  Layer.Vertical := Data.Vertical;
  Layer.Visible := Data.Visible;
  ChangedLayer(Index);
end;

function TVectArtDocument.GetCanvasLayer: TVectArtCanvasLayer;
begin
  if (FLayers.Count > 0) and (FLayers[0] is TVectArtCanvasLayer) then
    Result := TVectArtCanvasLayer(FLayers[0])
  else
    Result := nil;
end;

function TVectArtDocument.GetLayer(Index: Integer): TVectArtLayer;
begin
  Result := FLayers[Index];
end;

function TVectArtDocument.GetLayerCount: Integer;
begin
  Result := FLayers.Count;
end;

function TVectArtDocument.GetSelectionCount: Integer;
begin
  Result := FSelectedLayers.Count;
end;

function TVectArtDocument.IsLayerSelected(Index: Integer): Boolean;
begin
  Result := FSelectedLayers.Contains(Index);
end;

procedure TVectArtDocument.Reset(AWidth, AHeight: Integer);
begin
  AWidth := Max(AWidth, 1);
  AHeight := Max(AHeight, 1);
  BeginUpdate;
  try
    FSelectedLayers.Clear;
    FSelectedIndex := -1;
    FLayers.Clear;
    FNextGroupId := 1;
    FNextLayerId := 1;
    FLayers.Add(TVectArtCanvasLayer.Create(AWidth, AHeight, clWhite));
    EnsureLayerIdentity(FLayers[0]);
    InvalidateLayerRelations;
    StructureChanged;
  finally
    EndUpdate;
  end;
end;

procedure TVectArtDocument.SetCanvasSize(AWidth, AHeight: Integer);
var
  Canvas: TVectArtCanvasLayer;
begin
  Canvas := GetCanvasLayer;
  if Canvas = nil then
    Exit;
  SetCanvasSettings(AWidth, AHeight, Canvas.BackgroundColor,
    Canvas.Transparent);
end;

procedure TVectArtDocument.SetCanvasSettings(AWidth, AHeight: Integer;
  ABackgroundColor: TColor; ATransparent: Boolean);
var
  Canvas: TVectArtCanvasLayer;
begin
  Canvas := GetCanvasLayer;
  if Canvas = nil then
    Exit;
  AWidth := Max(AWidth, 1);
  AHeight := Max(AHeight, 1);
  ABackgroundColor := ColorToRGB(ABackgroundColor);
  if (Canvas.Width = AWidth) and (Canvas.Height = AHeight) and
    (ColorToRGB(Canvas.BackgroundColor) = ABackgroundColor) and
    (Canvas.Transparent = ATransparent) then
    Exit;
  Canvas.Width := AWidth;
  Canvas.Height := AHeight;
  Canvas.BackgroundColor := ABackgroundColor;
  Canvas.Transparent := ATransparent;
  ChangedLayer(0);
end;

procedure TVectArtDocument.SetSelectedIndex(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := EnsureRange(Value, -1, FLayers.Count - 1);
  if NewValue >= 0 then
    SetSelectedLayersCore([NewValue], True)
  else
    SetSelectedLayersCore([], True);
end;

procedure TVectArtDocument.SetSelectedLayers(const Indices: array of Integer);
begin
  SetSelectedLayersCore(Indices, True);
end;

procedure TVectArtDocument.SelectLayerRange(AnchorIndex,
  TargetIndex: Integer; Additive: Boolean);
var
  FirstIndex: Integer;
  I: Integer;
  LastIndex: Integer;
  Selection: TList<Integer>;
begin
  if FLayers.Count <= 1 then
    Exit;
  AnchorIndex := EnsureRange(AnchorIndex, 1, FLayers.Count - 1);
  TargetIndex := EnsureRange(TargetIndex, 1, FLayers.Count - 1);
  FirstIndex := Min(AnchorIndex, TargetIndex);
  LastIndex := Max(AnchorIndex, TargetIndex);
  Selection := TList<Integer>.Create;
  try
    if Additive then
      Selection.AddRange(FSelectedLayers);
    for I := FirstIndex to LastIndex do
      if not Selection.Contains(I) then
        Selection.Add(I);
    Selection.Sort;
    SetSelectedLayers(Selection.ToArray);
  finally
    Selection.Free;
  end;
end;

procedure TVectArtDocument.SetSelectedLayersCore(
  const Indices: array of Integer; Notify: Boolean);
var
  GroupId: TVectArtGroupId;
  GroupMembers: TArray<Integer>;
  I: Integer;
  Index: Integer;
  MemberIndex: Integer;
  RequestedCount: Integer;
  HasSelectionChanged: Boolean;
  ValidIndices: TList<Integer>;
begin
  ValidIndices := TList<Integer>.Create;
  try
    for Index in Indices do
      if (Index > 0) and (Index < FLayers.Count) and
        not ValidIndices.Contains(Index) then
        ValidIndices.Add(Index);
    // どの入口から選択しても、フラットグループは常に一体として扱う。
    RequestedCount := ValidIndices.Count;
    for I := 0 to RequestedCount - 1 do
    begin
      GroupId := FLayers[ValidIndices[I]].GroupId;
      if GroupId = VECTART_NO_GROUP then
        Continue;
      GroupMembers := GetGroupLayerIndices(GroupId);
      for MemberIndex in GroupMembers do
        if not ValidIndices.Contains(MemberIndex) then
          ValidIndices.Add(MemberIndex);
    end;
    ValidIndices.Sort;
    HasSelectionChanged := ValidIndices.Count <> FSelectedLayers.Count;
    if not HasSelectionChanged then
      for I := 0 to ValidIndices.Count - 1 do
        if ValidIndices[I] <> FSelectedLayers[I] then
        begin
          HasSelectionChanged := True;
          Break;
        end;
    if not HasSelectionChanged then
      Exit;
    FSelectedLayers.Clear;
    FSelectedLayers.AddRange(ValidIndices);
    if FSelectedLayers.Count > 0 then
      FSelectedIndex := FSelectedLayers[FSelectedLayers.Count - 1]
    else
      FSelectedIndex := -1;
  finally
    ValidIndices.Free;
  end;
  if Notify then
    SelectionChanged;
end;

procedure TVectArtDocument.ToggleSelectedLayer(Index: Integer);
var
  GroupId: TVectArtGroupId;
  GroupMembers: TArray<Integer>;
  MemberIndex: Integer;
  Selection: TList<Integer>;
begin
  if (Index <= 0) or (Index >= FLayers.Count) then
    Exit;
  Selection := TList<Integer>.Create;
  try
    Selection.AddRange(FSelectedLayers);
    GroupId := FLayers[Index].GroupId;
    if GroupId <> VECTART_NO_GROUP then
    begin
      GroupMembers := GetGroupLayerIndices(GroupId);
      if Selection.Contains(Index) then
        for MemberIndex in GroupMembers do
          Selection.Remove(MemberIndex)
      else
        for MemberIndex in GroupMembers do
          if not Selection.Contains(MemberIndex) then
            Selection.Add(MemberIndex);
    end
    else if Selection.Contains(Index) then
      Selection.Remove(Index)
    else
      Selection.Add(Index);
    Selection.Sort;
    SetSelectedLayers(Selection.ToArray);
  finally
    Selection.Free;
  end;
end;

procedure TVectArtDocument.SetRectangleBounds(Index: Integer;
  const Value: TRectF);
var
  CurrentBounds: TRectF;
  RectangleLayer: TVectArtRectangleLayer;
  TextLayer: TVectArtTextLayer;
begin
  RectangleLayer := nil;
  TextLayer := nil;
  if (Index <= 0) or (Index >= FLayers.Count) or
    not ((FLayers[Index] is TVectArtRectangleLayer) or
      (FLayers[Index] is TVectArtTextLayer)) then
    Exit;
  if FLayers[Index] is TVectArtTextLayer then
  begin
    TextLayer := TVectArtTextLayer(FLayers[Index]);
    CurrentBounds := TextLayer.Bounds;
  end
  else
  begin
    RectangleLayer := TVectArtRectangleLayer(FLayers[Index]);
    CurrentBounds := RectangleLayer.Bounds;
  end;
  if SameValue(CurrentBounds.Left, Value.Left) and
    SameValue(CurrentBounds.Top, Value.Top) and
    SameValue(CurrentBounds.Right, Value.Right) and
    SameValue(CurrentBounds.Bottom, Value.Bottom) then
    Exit;
  if FLayers[Index] is TVectArtTextLayer then
    TextLayer.Bounds := Value
  else
    RectangleLayer.Bounds := Value;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetRectangleFillColor(Index: Integer;
  Value: TColor);
var
  RectangleLayer: TVectArtRectangleLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtRectangleLayer) then
    Exit;
  RectangleLayer := TVectArtRectangleLayer(FLayers[Index]);
  if RectangleLayer.FillColor = Value then
    Exit;
  RectangleLayer.FillColor := Value;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetRectangleRotation(Index: Integer;
  Value: Single);
var
  NewValue: Single;
  RectangleLayer: TVectArtRectangleLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtRectangleLayer) then
    Exit;
  RectangleLayer := TVectArtRectangleLayer(FLayers[Index]);
  NewValue := NormalizeAngleDegrees(Value);
  if SameValue(RectangleLayer.RotationDegrees, NewValue) then
    Exit;
  RectangleLayer.RotationDegrees := NewValue;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetRectangleStroke(Index: Integer; Color: TColor;
  Width: Single; Style: TVectArtStrokeStyle);
var
  NewWidth: Single;
  RectangleLayer: TVectArtRectangleLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtRectangleLayer) then
    Exit;
  RectangleLayer := TVectArtRectangleLayer(FLayers[Index]);
  NewWidth := Max(Width, 0.0);
  if (RectangleLayer.StrokeColor = Color) and
    SameValue(RectangleLayer.StrokeWidth, NewWidth) and
    (RectangleLayer.StrokeStyle = Style) then
    Exit;
  RectangleLayer.StrokeColor := Color;
  RectangleLayer.StrokeWidth := NewWidth;
  RectangleLayer.StrokeStyle := Style;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetLinePoints(Index: Integer;
  const StartPoint, EndPoint: TPointF);
var
  LineLayer: TVectArtLineLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtLineLayer) then
    Exit;
  LineLayer := TVectArtLineLayer(FLayers[Index]);
  if SameValue(LineLayer.StartPoint.X, StartPoint.X) and
    SameValue(LineLayer.StartPoint.Y, StartPoint.Y) and
    SameValue(LineLayer.EndPoint.X, EndPoint.X) and
    SameValue(LineLayer.EndPoint.Y, EndPoint.Y) then
    Exit;
  LineLayer.StartPoint := StartPoint;
  LineLayer.EndPoint := EndPoint;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetLineCap(Index: Integer;
  Value: TVectArtLineCap);
var
  LineLayer: TVectArtLineLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtLineLayer) then
    Exit;
  LineLayer := TVectArtLineLayer(FLayers[Index]);
  if LineLayer.LineCap = Value then
    Exit;
  LineLayer.LineCap := Value;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetLineAntiAlias(Index: Integer; Value: Boolean);
var
  LineLayer: TVectArtLineLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtLineLayer) then
    Exit;
  LineLayer := TVectArtLineLayer(FLayers[Index]);
  if LineLayer.AntiAlias = Value then
    Exit;
  LineLayer.AntiAlias := Value;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetLineEndMarker(Index: Integer;
  Value: TVectArtLineMarker);
var
  LineLayer: TVectArtLineLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtLineLayer) then
    Exit;
  LineLayer := TVectArtLineLayer(FLayers[Index]);
  if LineLayer.EndMarker = Value then
    Exit;
  LineLayer.EndMarker := Value;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetLineEndMarkerSize(Index: Integer; Value: Single);
var
  LineLayer: TVectArtLineLayer;
  NewValue: Single;
begin
  if (Index < 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtLineLayer) then Exit;
  LineLayer := TVectArtLineLayer(FLayers[Index]);
  NewValue := Max(Value, 1.0);
  if SameValue(LineLayer.EndMarkerSize, NewValue) then Exit;
  LineLayer.EndMarkerSize := NewValue;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetLineStartMarker(Index: Integer;
  Value: TVectArtLineMarker);
var
  LineLayer: TVectArtLineLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtLineLayer) then
    Exit;
  LineLayer := TVectArtLineLayer(FLayers[Index]);
  if LineLayer.StartMarker = Value then
    Exit;
  LineLayer.StartMarker := Value;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetLineStartMarkerSize(Index: Integer; Value: Single);
var
  LineLayer: TVectArtLineLayer;
  NewValue: Single;
begin
  if (Index < 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtLineLayer) then Exit;
  LineLayer := TVectArtLineLayer(FLayers[Index]);
  NewValue := Max(Value, 1.0);
  if SameValue(LineLayer.StartMarkerSize, NewValue) then Exit;
  LineLayer.StartMarkerSize := NewValue;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetLineJoin(Index: Integer;
  Value: TVectArtLineJoin);
var
  LineLayer: TVectArtLineLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtLineLayer) then
    Exit;
  LineLayer := TVectArtLineLayer(FLayers[Index]);
  if LineLayer.LineJoin = Value then
    Exit;
  LineLayer.LineJoin := Value;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetLineStroke(Index: Integer; Color: TColor;
  Width: Single; Style: TVectArtStrokeStyle);
var
  LineLayer: TVectArtLineLayer;
  NewWidth: Single;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtLineLayer) then
    Exit;
  LineLayer := TVectArtLineLayer(FLayers[Index]);
  NewWidth := Max(Width, 0.1);
  if (LineLayer.StrokeColor = Color) and
    SameValue(LineLayer.StrokeWidth, NewWidth) and
    (LineLayer.StrokeStyle = Style) then
    Exit;
  LineLayer.StrokeColor := Color;
  LineLayer.StrokeWidth := NewWidth;
  LineLayer.StrokeStyle := Style;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetImagePoints(Index: Integer;
  const Points: TVectArtImagePoints);
var
  ImageLayer: TVectArtImageLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtImageLayer) then
    Exit;
  ImageLayer := TVectArtImageLayer(FLayers[Index]);
  ImageLayer.Points := Points;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetPathPoints(Index: Integer;
  const Points: TArray<TPointF>);
var
  I: Integer;
  PathLayer: TVectArtPathLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtPathLayer) then
    Exit;
  PathLayer := TVectArtPathLayer(FLayers[Index]);
  if Length(PathLayer.Points) = Length(Points) then
  begin
    if Length(Points) = 0 then
      Exit;
    for I := 0 to High(Points) do
      if not SameValue(PathLayer.Points[I].X, Points[I].X) or
        not SameValue(PathLayer.Points[I].Y, Points[I].Y) then
        Break;
    if I > High(Points) then
      Exit;
  end;
  PathLayer.Points := Copy(Points);
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetPathFill(Index: Integer; Color: TColor;
  Filled: Boolean);
var
  PathLayer: TVectArtPathLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtPathLayer) then
    Exit;
  PathLayer := TVectArtPathLayer(FLayers[Index]);
  Filled := Filled and PathLayer.Closed;
  if (PathLayer.FillColor = Color) and (PathLayer.Filled = Filled) then
    Exit;
  PathLayer.FillColor := Color;
  PathLayer.Filled := Filled;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetPathEndMarker(Index: Integer;
  Value: TVectArtLineMarker);
var
  PathLayer: TVectArtPathLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtPathLayer) then
    Exit;
  PathLayer := TVectArtPathLayer(FLayers[Index]);
  if PathLayer.EndMarker = Value then
    Exit;
  PathLayer.EndMarker := Value;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetPathEndMarkerSize(Index: Integer;
  Value: Single);
var
  NewValue: Single;
  PathLayer: TVectArtPathLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtPathLayer) then
    Exit;
  PathLayer := TVectArtPathLayer(FLayers[Index]);
  NewValue := Max(Value, 1.0);
  if SameValue(PathLayer.EndMarkerSize, NewValue) then
    Exit;
  PathLayer.EndMarkerSize := NewValue;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetPathLineCap(Index: Integer;
  Value: TVectArtLineCap);
var
  PathLayer: TVectArtPathLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtPathLayer) then
    Exit;
  PathLayer := TVectArtPathLayer(FLayers[Index]);
  if PathLayer.LineCap = Value then
    Exit;
  PathLayer.LineCap := Value;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetPathLineJoin(Index: Integer;
  Value: TVectArtLineJoin);
var
  PathLayer: TVectArtPathLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtPathLayer) then
    Exit;
  PathLayer := TVectArtPathLayer(FLayers[Index]);
  if PathLayer.LineJoin = Value then
    Exit;
  PathLayer.LineJoin := Value;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetPathAntiAlias(Index: Integer;
  Value: Boolean);
var
  PathLayer: TVectArtPathLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtPathLayer) then
    Exit;
  PathLayer := TVectArtPathLayer(FLayers[Index]);
  if PathLayer.AntiAlias = Value then
    Exit;
  PathLayer.AntiAlias := Value;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetPathStartMarker(Index: Integer;
  Value: TVectArtLineMarker);
var
  PathLayer: TVectArtPathLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtPathLayer) then
    Exit;
  PathLayer := TVectArtPathLayer(FLayers[Index]);
  if PathLayer.StartMarker = Value then
    Exit;
  PathLayer.StartMarker := Value;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetPathStartMarkerSize(Index: Integer;
  Value: Single);
var
  NewValue: Single;
  PathLayer: TVectArtPathLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtPathLayer) then
    Exit;
  PathLayer := TVectArtPathLayer(FLayers[Index]);
  NewValue := Max(Value, 1.0);
  if SameValue(PathLayer.StartMarkerSize, NewValue) then
    Exit;
  PathLayer.StartMarkerSize := NewValue;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetPathStroke(Index: Integer; Color: TColor;
  Width: Single; Style: TVectArtStrokeStyle);
var
  NewWidth: Single;
  PathLayer: TVectArtPathLayer;
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    not (FLayers[Index] is TVectArtPathLayer) then
    Exit;
  PathLayer := TVectArtPathLayer(FLayers[Index]);
  NewWidth := Max(Width, 0.0);
  if (PathLayer.StrokeColor = Color) and
    SameValue(PathLayer.StrokeWidth, NewWidth) and
    (PathLayer.StrokeStyle = Style) then
    Exit;
  PathLayer.StrokeColor := Color;
  PathLayer.StrokeWidth := NewWidth;
  PathLayer.StrokeStyle := Style;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetLayerLocked(Index: Integer; Value: Boolean);
begin
  if (Index < 0) or (Index >= FLayers.Count) or
    (FLayers[Index].Locked = Value) then
    Exit;
  FLayers[Index].Locked := Value;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetLayerGroup(Index: Integer;
  GroupId: TVectArtGroupId);
begin
  if (Index <= 0) or (Index >= FLayers.Count) or
    (FLayers[Index].GroupId = GroupId) then
    Exit;
  FLayers[Index].FGroupId := GroupId;
  if GroupId >= FNextGroupId then
    FNextGroupId := GroupId + 1;
  InvalidateLayerRelations;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetLayerOpacity(Index: Integer; Value: Single);
var
  NewValue: Single;
begin
  if (Index < 0) or (Index >= FLayers.Count) then
    Exit;
  NewValue := EnsureRange(Value, 0.0, 1.0);
  if SameValue(FLayers[Index].Opacity, NewValue) then
    Exit;
  FLayers[Index].Opacity := NewValue;
  ChangedLayer(Index);
end;

procedure TVectArtDocument.SetLayerVisible(Index: Integer; Value: Boolean);
begin
  if (Index < 0) or (Index >= FLayers.Count) or
    (FLayers[Index].Visible = Value) then
    Exit;
  FLayers[Index].Visible := Value;
  ChangedLayer(Index);
end;

end.
