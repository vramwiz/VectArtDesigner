// 編集ツールなど、複数の編集UIが共有する一時状態を管理する。
// 作成色は起動ごとに黒・白へ戻し、Documentや設定ファイルには保存しない。
unit VectArtDesignerEditorState;

interface

uses
  System.Classes, Vcl.Graphics, VectArtDesignerDocument;

type
  TVectArtEditorTool = (vetSelect, vetRectangle, vetEllipse,
    vetRoundedRectangle, vetClosedPath, vetClosedBezier, vetLine, vetPath,
    vetBezier, vetFreehandLine, vetFreehandBezier, vetText, vetTemplate);
  TVectArtRectangleMode = (vrmOutline, vrmFill, vrmFillAndOutline);

  TVectArtEditorState = class
  private
    FLineAntiAlias: Boolean;
    FLineEndMarker: TVectArtLineMarker;
    FLineEndMarkerSize: Single;
    FLineStartMarker: TVectArtLineMarker;
    FLineStartMarkerSize: Single;
    FCurrentTool: TVectArtEditorTool;
    FTemplateIndex: Integer;
    FLineCap: TVectArtLineCap;
    FLineJoin: TVectArtLineJoin;
    FLineStrokeStyle: TVectArtStrokeStyle;
    FLineStrokeWidth: Single;
    FOnChanged: TNotifyEvent;
    FPathLineCap: TVectArtLineCap;
    FPathLineJoin: TVectArtLineJoin;
    FPathAntiAlias: Boolean;
    FPathEndMarker: TVectArtLineMarker;
    FPathEndMarkerSize: Single;
    FPathStartMarker: TVectArtLineMarker;
    FPathStartMarkerSize: Single;
    FColor2: TColor;
    FRectangleMode: TVectArtRectangleMode;
    FRectangleOpacity: Single;
    FColor1: TColor;
    FRectangleStrokeStyle: TVectArtStrokeStyle;
    FRectangleStrokeWidth: Single;
    procedure CycleRectangleMode;
    procedure SetRectangleMode(Value: TVectArtRectangleMode);
    procedure SetCurrentTool(const Value: TVectArtEditorTool);
    procedure SetLineCap(const Value: TVectArtLineCap);
    procedure SetLineAntiAlias(const Value: Boolean);
    procedure SetLineEndMarker(const Value: TVectArtLineMarker);
    procedure SetLineEndMarkerSize(const Value: Single);
    procedure SetLineStartMarker(const Value: TVectArtLineMarker);
    procedure SetLineStartMarkerSize(const Value: Single);
    procedure SetLineJoin(const Value: TVectArtLineJoin);
    procedure SetLineStrokeStyle(const Value: TVectArtStrokeStyle);
    procedure SetLineStrokeWidth(const Value: Single);
    procedure SetPathLineCap(const Value: TVectArtLineCap);
    procedure SetPathLineJoin(const Value: TVectArtLineJoin);
    procedure SetPathAntiAlias(const Value: Boolean);
    procedure SetPathEndMarker(const Value: TVectArtLineMarker);
    procedure SetPathEndMarkerSize(const Value: Single);
    procedure SetPathStartMarker(const Value: TVectArtLineMarker);
    procedure SetPathStartMarkerSize(const Value: Single);
    procedure SetColor2(const Value: TColor);
    procedure SetRectangleOpacity(const Value: Single);
    procedure SetColor1(const Value: TColor);
    procedure SetRectangleStrokeStyle(const Value: TVectArtStrokeStyle);
    procedure SetRectangleStrokeWidth(const Value: Single);
  public
    constructor Create;
    procedure SwapColors;
    procedure SelectClosedBezierToolGroup;
    procedure SelectClosedPathToolGroup;
    procedure SelectFreehandToolGroup;
    procedure SelectEllipseToolGroup;
    procedure SelectPathToolGroup;
    procedure SelectRectangleToolGroup;
    procedure SelectRoundedRectangleToolGroup;
    property CurrentTool: TVectArtEditorTool read FCurrentTool
      write SetCurrentTool;
    property LineCap: TVectArtLineCap read FLineCap write SetLineCap;
    property LineAntiAlias: Boolean read FLineAntiAlias write SetLineAntiAlias;
    property LineEndMarker: TVectArtLineMarker read FLineEndMarker
      write SetLineEndMarker;
    property LineEndMarkerSize: Single read FLineEndMarkerSize
      write SetLineEndMarkerSize;
    property LineStartMarker: TVectArtLineMarker read FLineStartMarker
      write SetLineStartMarker;
    property LineStartMarkerSize: Single read FLineStartMarkerSize
      write SetLineStartMarkerSize;
    property LineJoin: TVectArtLineJoin read FLineJoin write SetLineJoin;
    property LineStrokeStyle: TVectArtStrokeStyle read FLineStrokeStyle
      write SetLineStrokeStyle;
    property LineStrokeWidth: Single read FLineStrokeWidth
      write SetLineStrokeWidth;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
    property PathLineCap: TVectArtLineCap read FPathLineCap write SetPathLineCap;
    property PathLineJoin: TVectArtLineJoin read FPathLineJoin write SetPathLineJoin;
    property PathAntiAlias: Boolean read FPathAntiAlias
      write SetPathAntiAlias;
    property PathEndMarker: TVectArtLineMarker read FPathEndMarker
      write SetPathEndMarker;
    property PathEndMarkerSize: Single read FPathEndMarkerSize
      write SetPathEndMarkerSize;
    property PathStartMarker: TVectArtLineMarker read FPathStartMarker
      write SetPathStartMarker;
    property PathStartMarkerSize: Single read FPathStartMarkerSize
      write SetPathStartMarkerSize;
    property Color2: TColor read FColor2
      write SetColor2;
    property TemplateIndex: Integer read FTemplateIndex write FTemplateIndex;
    property RectangleMode: TVectArtRectangleMode read FRectangleMode write SetRectangleMode;
    property RectangleOpacity: Single read FRectangleOpacity
      write SetRectangleOpacity;
    property Color1: TColor read FColor1
      write SetColor1;
    property RectangleStrokeStyle: TVectArtStrokeStyle
      read FRectangleStrokeStyle write SetRectangleStrokeStyle;
    property RectangleStrokeWidth: Single read FRectangleStrokeWidth
      write SetRectangleStrokeWidth;
  end;

function VectArtRectangleModeHasFill(Mode: TVectArtRectangleMode): Boolean;
function VectArtRectangleModeHasStroke(Mode: TVectArtRectangleMode): Boolean;

implementation

uses System.Math;

procedure TVectArtEditorState.SetRectangleMode(Value: TVectArtRectangleMode);
begin
  if FRectangleMode = Value then Exit;
  FRectangleMode := Value;
  if Assigned(FOnChanged) then FOnChanged(Self);
end;


function VectArtRectangleModeHasFill(Mode: TVectArtRectangleMode): Boolean;
begin
  Result := Mode in [vrmFill, vrmFillAndOutline];
end;

function VectArtRectangleModeHasStroke(Mode: TVectArtRectangleMode): Boolean;
begin
  Result := Mode in [vrmOutline, vrmFillAndOutline];
end;

constructor TVectArtEditorState.Create;
begin
  inherited Create;
  FCurrentTool := vetSelect;
  FLineAntiAlias := True;
  FLineEndMarker := vlmNone;
  FLineEndMarkerSize := 4.0;
  FLineStartMarker := vlmNone;
  FLineStartMarkerSize := 4.0;
  FLineCap := vlcButt;
  FLineJoin := vljMiter;
  FLineStrokeStyle := vssSolid;
  FLineStrokeWidth := 1.0;
  FPathLineCap := vlcButt;
  FPathLineJoin := vljMiter;
  FPathAntiAlias := True;
  FPathEndMarker := vlmNone;
  FPathEndMarkerSize := 4.0;
  FPathStartMarker := vlmNone;
  FPathStartMarkerSize := 4.0;
  FColor2 := clWhite;
  FRectangleMode := vrmFillAndOutline;
  FRectangleOpacity := 1.0;
  FColor1 := clBlack;
  FRectangleStrokeStyle := vssSolid;
  FRectangleStrokeWidth := 1.0;
end;

procedure TVectArtEditorState.SelectRectangleToolGroup;
begin
  if FCurrentTool <> vetRectangle then
  begin
    CurrentTool := vetRectangle;
    Exit;
  end;
  CycleRectangleMode;
end;

procedure TVectArtEditorState.SelectEllipseToolGroup;
begin
  if FCurrentTool <> vetEllipse then
  begin
    CurrentTool := vetEllipse;
    Exit;
  end;
  CycleRectangleMode;
end;

procedure TVectArtEditorState.SelectRoundedRectangleToolGroup;
begin
  if FCurrentTool <> vetRoundedRectangle then
  begin
    CurrentTool := vetRoundedRectangle;
    Exit;
  end;
  CycleRectangleMode;
end;

procedure TVectArtEditorState.SelectClosedPathToolGroup;
begin
  if FCurrentTool <> vetClosedPath then
  begin
    CurrentTool := vetClosedPath;
    Exit;
  end;
  CycleRectangleMode;
end;

procedure TVectArtEditorState.SelectClosedBezierToolGroup;
begin
  if FCurrentTool <> vetClosedBezier then
  begin
    CurrentTool := vetClosedBezier;
    Exit;
  end;
  CycleRectangleMode;
end;

procedure TVectArtEditorState.CycleRectangleMode;
begin
  // 面を持つ作成ツール間で同じ初期スタイルを引き継げるよう、モードは共有する。
  case FRectangleMode of
    vrmOutline: FRectangleMode := vrmFill;
    vrmFill: FRectangleMode := vrmFillAndOutline;
  else
    FRectangleMode := vrmOutline;
  end;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SelectFreehandToolGroup;
begin
  if FCurrentTool = vetFreehandLine then
    CurrentTool := vetFreehandBezier
  else
    CurrentTool := vetFreehandLine;
end;

procedure TVectArtEditorState.SelectPathToolGroup;
begin
  if FCurrentTool = vetPath then
    CurrentTool := vetBezier
  else
    CurrentTool := vetPath;
end;

procedure TVectArtEditorState.SetPathLineCap(const Value: TVectArtLineCap);
begin
  if FPathLineCap = Value then
    Exit;
  FPathLineCap := Value;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SetPathLineJoin(const Value: TVectArtLineJoin);
begin
  if FPathLineJoin = Value then
    Exit;
  FPathLineJoin := Value;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SetPathAntiAlias(const Value: Boolean);
begin
  if FPathAntiAlias = Value then
    Exit;
  FPathAntiAlias := Value;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SetPathEndMarker(
  const Value: TVectArtLineMarker);
begin
  if FPathEndMarker = Value then
    Exit;
  FPathEndMarker := Value;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SetPathEndMarkerSize(const Value: Single);
var
  NewValue: Single;
begin
  NewValue := Max(Value, 1.0);
  if SameValue(FPathEndMarkerSize, NewValue) then
    Exit;
  FPathEndMarkerSize := NewValue;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SetPathStartMarker(
  const Value: TVectArtLineMarker);
begin
  if FPathStartMarker = Value then
    Exit;
  FPathStartMarker := Value;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SetPathStartMarkerSize(const Value: Single);
var
  NewValue: Single;
begin
  NewValue := Max(Value, 1.0);
  if SameValue(FPathStartMarkerSize, NewValue) then
    Exit;
  FPathStartMarkerSize := NewValue;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SetLineCap(const Value: TVectArtLineCap);
begin
  if FLineCap = Value then
    Exit;
  FLineCap := Value;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SetLineAntiAlias(const Value: Boolean);
begin
  if FLineAntiAlias = Value then
    Exit;
  FLineAntiAlias := Value;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SetLineEndMarker(
  const Value: TVectArtLineMarker);
begin
  if FLineEndMarker = Value then
    Exit;
  FLineEndMarker := Value;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SetLineEndMarkerSize(const Value: Single);
var
  NewValue: Single;
begin
  NewValue := Max(Value, 1.0);
  if SameValue(FLineEndMarkerSize, NewValue) then Exit;
  FLineEndMarkerSize := NewValue;
  if Assigned(FOnChanged) then FOnChanged(Self);
end;

procedure TVectArtEditorState.SetLineStartMarker(
  const Value: TVectArtLineMarker);
begin
  if FLineStartMarker = Value then
    Exit;
  FLineStartMarker := Value;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SetLineStartMarkerSize(const Value: Single);
var
  NewValue: Single;
begin
  NewValue := Max(Value, 1.0);
  if SameValue(FLineStartMarkerSize, NewValue) then Exit;
  FLineStartMarkerSize := NewValue;
  if Assigned(FOnChanged) then FOnChanged(Self);
end;

procedure TVectArtEditorState.SetLineJoin(const Value: TVectArtLineJoin);
begin
  if FLineJoin = Value then
    Exit;
  FLineJoin := Value;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SetLineStrokeStyle(
  const Value: TVectArtStrokeStyle);
begin
  if FLineStrokeStyle = Value then
    Exit;
  FLineStrokeStyle := Value;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SetLineStrokeWidth(const Value: Single);
var
  NewValue: Single;
begin
  NewValue := Max(Value, 0.1);
  if SameValue(FLineStrokeWidth, NewValue) then
    Exit;
  FLineStrokeWidth := NewValue;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SwapColors;
var Previous: TColor;
begin
  // 2色を揃えてから一度だけ通知し、途中の同色状態を他のUIへ見せない。
  Previous := FColor1; FColor1 := FColor2; FColor2 := Previous;
  if Assigned(FOnChanged) then FOnChanged(Self);
end;

procedure TVectArtEditorState.SetColor1(const Value: TColor);
begin
  if FColor1 = Value then
    Exit;
  FColor1 := Value;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SetRectangleStrokeStyle(
  const Value: TVectArtStrokeStyle);
begin
  if FRectangleStrokeStyle = Value then
    Exit;
  FRectangleStrokeStyle := Value;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SetRectangleStrokeWidth(const Value: Single);
var
  NewValue: Single;
begin
  NewValue := Max(Value, 0.0);
  if SameValue(FRectangleStrokeWidth, NewValue) then
    Exit;
  FRectangleStrokeWidth := NewValue;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SetCurrentTool(const Value: TVectArtEditorTool);
begin
  if FCurrentTool = Value then
    Exit;
  FCurrentTool := Value;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SetColor2(const Value: TColor);
begin
  if FColor2 = Value then
    Exit;
  FColor2 := Value;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TVectArtEditorState.SetRectangleOpacity(const Value: Single);
var
  NewValue: Single;
begin
  NewValue := EnsureRange(Value, 0.0, 1.0);
  if SameValue(FRectangleOpacity, NewValue) then
    Exit;
  FRectangleOpacity := NewValue;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

end.
