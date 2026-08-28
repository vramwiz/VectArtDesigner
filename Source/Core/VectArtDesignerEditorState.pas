// 編集ツールなど、複数の編集UIが共有する一時状態を管理する。
unit VectArtDesignerEditorState;

interface

uses
  System.Classes, Vcl.Graphics, VectArtDesignerDocument;

type
  TVectArtEditorTool = (vetSelect, vetRectangle, vetLine, vetPath);

  TVectArtEditorState = class
  private
    FLineAntiAlias: Boolean;
    FLineEndMarker: TVectArtLineMarker;
    FLineEndMarkerSize: Single;
    FLineStartMarker: TVectArtLineMarker;
    FLineStartMarkerSize: Single;
    FCurrentTool: TVectArtEditorTool;
    FLineCap: TVectArtLineCap;
    FLineJoin: TVectArtLineJoin;
    FLineStrokeColor: TColor;
    FLineStrokeStyle: TVectArtStrokeStyle;
    FLineStrokeWidth: Single;
    FOnChanged: TNotifyEvent;
    FRectangleFillColor: TColor;
    FRectangleOpacity: Single;
    FRectangleStrokeColor: TColor;
    FRectangleStrokeStyle: TVectArtStrokeStyle;
    FRectangleStrokeWidth: Single;
    procedure SetCurrentTool(const Value: TVectArtEditorTool);
    procedure SetLineCap(const Value: TVectArtLineCap);
    procedure SetLineAntiAlias(const Value: Boolean);
    procedure SetLineEndMarker(const Value: TVectArtLineMarker);
    procedure SetLineEndMarkerSize(const Value: Single);
    procedure SetLineStartMarker(const Value: TVectArtLineMarker);
    procedure SetLineStartMarkerSize(const Value: Single);
    procedure SetLineJoin(const Value: TVectArtLineJoin);
    procedure SetLineStrokeColor(const Value: TColor);
    procedure SetLineStrokeStyle(const Value: TVectArtStrokeStyle);
    procedure SetLineStrokeWidth(const Value: Single);
    procedure SetRectangleFillColor(const Value: TColor);
    procedure SetRectangleOpacity(const Value: Single);
    procedure SetRectangleStrokeColor(const Value: TColor);
    procedure SetRectangleStrokeStyle(const Value: TVectArtStrokeStyle);
    procedure SetRectangleStrokeWidth(const Value: Single);
  public
    constructor Create;
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
    property LineStrokeColor: TColor read FLineStrokeColor
      write SetLineStrokeColor;
    property LineStrokeStyle: TVectArtStrokeStyle read FLineStrokeStyle
      write SetLineStrokeStyle;
    property LineStrokeWidth: Single read FLineStrokeWidth
      write SetLineStrokeWidth;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
    property RectangleFillColor: TColor read FRectangleFillColor
      write SetRectangleFillColor;
    property RectangleOpacity: Single read FRectangleOpacity
      write SetRectangleOpacity;
    property RectangleStrokeColor: TColor read FRectangleStrokeColor
      write SetRectangleStrokeColor;
    property RectangleStrokeStyle: TVectArtStrokeStyle
      read FRectangleStrokeStyle write SetRectangleStrokeStyle;
    property RectangleStrokeWidth: Single read FRectangleStrokeWidth
      write SetRectangleStrokeWidth;
  end;

implementation

uses
  System.Math;

const
  DEFAULT_RECTANGLE_COLOR = TColor($00E2904A);

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
  FLineStrokeColor := clBlack;
  FLineStrokeStyle := vssSolid;
  FLineStrokeWidth := 1.0;
  FRectangleFillColor := DEFAULT_RECTANGLE_COLOR;
  FRectangleOpacity := 1.0;
  FRectangleStrokeColor := clBlack;
  FRectangleStrokeStyle := vssSolid;
  FRectangleStrokeWidth := 0.0;
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

procedure TVectArtEditorState.SetLineStrokeColor(const Value: TColor);
begin
  if FLineStrokeColor = Value then
    Exit;
  FLineStrokeColor := Value;
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

procedure TVectArtEditorState.SetRectangleStrokeColor(const Value: TColor);
begin
  if FRectangleStrokeColor = Value then
    Exit;
  FRectangleStrokeColor := Value;
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

procedure TVectArtEditorState.SetRectangleFillColor(const Value: TColor);
begin
  if FRectangleFillColor = Value then
    Exit;
  FRectangleFillColor := Value;
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
