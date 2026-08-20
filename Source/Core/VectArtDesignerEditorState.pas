// 編集ツールなど、複数の編集UIが共有する一時状態を管理する。
unit VectArtDesignerEditorState;

interface

uses
  System.Classes, Vcl.Graphics;

type
  TVectArtEditorTool = (vetSelect, vetRectangle);

  TVectArtEditorState = class
  private
    FCurrentTool: TVectArtEditorTool;
    FOnChanged: TNotifyEvent;
    FRectangleFillColor: TColor;
    FRectangleOpacity: Single;
    procedure SetCurrentTool(const Value: TVectArtEditorTool);
    procedure SetRectangleFillColor(const Value: TColor);
    procedure SetRectangleOpacity(const Value: Single);
  public
    constructor Create;
    property CurrentTool: TVectArtEditorTool read FCurrentTool
      write SetCurrentTool;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
    property RectangleFillColor: TColor read FRectangleFillColor
      write SetRectangleFillColor;
    property RectangleOpacity: Single read FRectangleOpacity
      write SetRectangleOpacity;
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
  FRectangleFillColor := DEFAULT_RECTANGLE_COLOR;
  FRectangleOpacity := 1.0;
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
