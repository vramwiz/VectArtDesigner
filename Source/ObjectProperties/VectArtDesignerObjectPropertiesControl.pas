// 選択Rectangleの位置、サイズ、塗り色を表示・編集するダークテーマ用Controlを提供する。
unit VectArtDesignerObjectPropertiesControl;

interface

uses
  System.Classes, System.Types, Vcl.Controls, Vcl.StdCtrls,
  VectArtDesignerDocument, VectArtDesignerEditCommands,
  VectArtDesignerEditHistory, VectArtDesignerEditorState,
  VectArtDesignerStrokeStyleCombo;

type
  TVectArtObjectPropertiesControl = class(TCustomControl)
  private
    FColorEdit: TEdit;
    FDocument: TVectArtDocument;
    FEditHistory: TVectArtEditHistory;
    FEditorState: TVectArtEditorState;
    FHeightEdit: TEdit;
    FOpacityEdit: TEdit;
    FStrokeColorEdit: TEdit;
    FStrokeStyleCombo: TVectArtStrokeStyleCombo;
    FStrokeWidthEdit: TEdit;
    FUpdating: Boolean;
    FWidthEdit: TEdit;
    FXEdit: TEdit;
    FYEdit: TEdit;
    procedure ApplyColor;
    procedure ApplyGeometry;
    procedure ApplyOpacity;
    procedure ApplyStrokeColor;
    procedure ApplyStrokeStyle(Sender: TObject);
    procedure ApplyStrokeWidth;
    procedure ClearEditValue(Edit: TEdit);
    procedure EditExit(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    function GetSelectedFillIndices: TArray<Integer>;
    function GetSelectedOpacityIndices: TArray<Integer>;
    function GetSelectedRectangleIndices: TArray<Integer>;
    function GetSelectedStrokeIndices: TArray<Integer>;
    function SelectedLayersHaveLock: Boolean;
    function NewDarkEdit: TEdit;
    function NewDarkCombo: TVectArtStrokeStyleCombo;
    function SelectedBounds(out Bounds: TRectF): Boolean;
    procedure SetDocument(const Value: TVectArtDocument);
    procedure SetEditorsEnabled(Value: Boolean);
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure RefreshFromDocument;
    property Document: TVectArtDocument read FDocument write SetDocument;
    property EditHistory: TVectArtEditHistory read FEditHistory
      write FEditHistory;
    property EditorState: TVectArtEditorState read FEditorState
      write FEditorState;
  end;

implementation

uses
  System.Generics.Collections, System.Math, System.SysUtils, Winapi.Windows,
  Vcl.Graphics, VectArtDesignerGeometry;

const
  COLOR_BACKGROUND = TColor($00212121);
  COLOR_EDIT = TColor($00303030);
  COLOR_LABEL = TColor($00BDBDBD);
  COLOR_TEXT = TColor($00EEEEEE);
  EDIT_HEIGHT = 25;
  MIN_OBJECT_SIZE = 1.0;

constructor TVectArtObjectPropertiesControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Color := COLOR_BACKGROUND;
  ParentBackground := False;
  DoubleBuffered := True;
  FXEdit := NewDarkEdit;
  FYEdit := NewDarkEdit;
  FWidthEdit := NewDarkEdit;
  FHeightEdit := NewDarkEdit;
  FColorEdit := NewDarkEdit;
  FStrokeColorEdit := NewDarkEdit;
  FStrokeWidthEdit := NewDarkEdit;
  FStrokeStyleCombo := NewDarkCombo;
  FOpacityEdit := NewDarkEdit;
  SetEditorsEnabled(False);
end;

procedure TVectArtObjectPropertiesControl.ApplyStrokeColor;
var
  Blue: Integer;
  Command: TVectArtCompoundCommand;
  Green: Integer;
  I: Integer;
  LayerIndex: Integer;
  LayerIndices: TArray<Integer>;
  LinesIncluded: Boolean;
  NewColor: TColor;
  OldColor: TColor;
  OtherStrokesIncluded: Boolean;
  PathLayer: TVectArtPathLayer;
  RectangleLayer: TVectArtRectangleLayer;
  Red: Integer;
  Value: Integer;
begin
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount = 0) or SelectedLayersHaveLock then
    Exit;
  if not TryStrToInt('$' + StringReplace(Trim(FStrokeColorEdit.Text), '#', '', []),
    Value) or (Value < 0) or (Value > $FFFFFF) then
  begin
    RefreshFromDocument;
    Exit;
  end;
  Red := (Value shr 16) and $FF;
  Green := (Value shr 8) and $FF;
  Blue := Value and $FF;
  NewColor := RGB(Red, Green, Blue);
  LayerIndices := GetSelectedStrokeIndices;
  LinesIncluded := False;
  OtherStrokesIncluded := False;
  Command := nil;
  if FEditHistory <> nil then
    Command := TVectArtCompoundCommand.Create;
  for I := 0 to High(LayerIndices) do
  begin
    LayerIndex := LayerIndices[I];
    if FDocument[LayerIndex] is TVectArtLineLayer then
    begin
      LinesIncluded := True;
      OldColor := TVectArtLineLayer(FDocument[LayerIndex]).StrokeColor;
      FDocument.SetLineStroke(LayerIndex, NewColor,
        TVectArtLineLayer(FDocument[LayerIndex]).StrokeWidth,
        TVectArtLineLayer(FDocument[LayerIndex]).StrokeStyle);
      RectangleLayer := nil;
    end
    else if FDocument[LayerIndex] is TVectArtPathLayer then
    begin
      OtherStrokesIncluded := True;
      PathLayer := TVectArtPathLayer(FDocument[LayerIndex]);
      OldColor := PathLayer.StrokeColor;
      FDocument.SetPathStroke(LayerIndex, NewColor, PathLayer.StrokeWidth,
        PathLayer.StrokeStyle);
      RectangleLayer := nil;
    end
    else
    begin
      OtherStrokesIncluded := True;
      RectangleLayer := TVectArtRectangleLayer(FDocument[LayerIndex]);
      OldColor := RectangleLayer.StrokeColor;
      FDocument.SetRectangleStroke(LayerIndex, NewColor,
        RectangleLayer.StrokeWidth, RectangleLayer.StrokeStyle);
    end;
    if (Command <> nil) and (OldColor <> NewColor) then
      if FDocument[LayerIndex] is TVectArtLineLayer then
        Command.Add(TVectArtStrokeCommand.Create(FDocument, LayerIndex,
          OldColor, TVectArtLineLayer(FDocument[LayerIndex]).StrokeWidth,
          TVectArtLineLayer(FDocument[LayerIndex]).StrokeStyle, NewColor,
          TVectArtLineLayer(FDocument[LayerIndex]).StrokeWidth,
          TVectArtLineLayer(FDocument[LayerIndex]).StrokeStyle))
      else if FDocument[LayerIndex] is TVectArtPathLayer then
        Command.Add(TVectArtStrokeCommand.Create(FDocument, LayerIndex,
          OldColor, TVectArtPathLayer(FDocument[LayerIndex]).StrokeWidth,
          TVectArtPathLayer(FDocument[LayerIndex]).StrokeStyle, NewColor,
          TVectArtPathLayer(FDocument[LayerIndex]).StrokeWidth,
          TVectArtPathLayer(FDocument[LayerIndex]).StrokeStyle))
      else
        Command.Add(TVectArtStrokeCommand.Create(FDocument, LayerIndex,
          OldColor, RectangleLayer.StrokeWidth, RectangleLayer.StrokeStyle,
          NewColor, RectangleLayer.StrokeWidth, RectangleLayer.StrokeStyle));
  end;
  if (Command <> nil) and (Command.Count > 0) then
    FEditHistory.AddApplied(Command)
  else
    Command.Free;
  if FEditorState <> nil then
  begin
    if OtherStrokesIncluded then
      FEditorState.RectangleStrokeColor := NewColor;
    if LinesIncluded then
      FEditorState.LineStrokeColor := NewColor;
  end;
end;

procedure TVectArtObjectPropertiesControl.ApplyStrokeStyle(Sender: TObject);
var
  Command: TVectArtCompoundCommand;
  I: Integer;
  LayerIndex: Integer;
  LayerIndices: TArray<Integer>;
  LinesIncluded: Boolean;
  NewStyle: TVectArtStrokeStyle;
  OldStyle: TVectArtStrokeStyle;
  OtherStrokesIncluded: Boolean;
  PathLayer: TVectArtPathLayer;
  RectangleLayer: TVectArtRectangleLayer;
begin
  if FUpdating or (FDocument = nil) or (FDocument.SelectionCount = 0) or
    SelectedLayersHaveLock or (FStrokeStyleCombo.ItemIndex < 0) then
    Exit;
  if not InRange(FStrokeStyleCombo.ItemIndex,
    Ord(Low(TVectArtStrokeStyle)), Ord(High(TVectArtStrokeStyle))) then
    Exit;
  NewStyle := TVectArtStrokeStyle(FStrokeStyleCombo.ItemIndex);
  LayerIndices := GetSelectedStrokeIndices;
  LinesIncluded := False;
  OtherStrokesIncluded := False;
  Command := nil;
  if FEditHistory <> nil then
    Command := TVectArtCompoundCommand.Create;
  for I := 0 to High(LayerIndices) do
  begin
    LayerIndex := LayerIndices[I];
    if FDocument[LayerIndex] is TVectArtLineLayer then
    begin
      LinesIncluded := True;
      OldStyle := TVectArtLineLayer(FDocument[LayerIndex]).StrokeStyle;
      FDocument.SetLineStroke(LayerIndex,
        TVectArtLineLayer(FDocument[LayerIndex]).StrokeColor,
        TVectArtLineLayer(FDocument[LayerIndex]).StrokeWidth, NewStyle);
      RectangleLayer := nil;
    end
    else if FDocument[LayerIndex] is TVectArtPathLayer then
    begin
      OtherStrokesIncluded := True;
      PathLayer := TVectArtPathLayer(FDocument[LayerIndex]);
      OldStyle := PathLayer.StrokeStyle;
      FDocument.SetPathStroke(LayerIndex, PathLayer.StrokeColor,
        PathLayer.StrokeWidth, NewStyle);
      RectangleLayer := nil;
    end
    else
    begin
      OtherStrokesIncluded := True;
      RectangleLayer := TVectArtRectangleLayer(FDocument[LayerIndex]);
      OldStyle := RectangleLayer.StrokeStyle;
      FDocument.SetRectangleStroke(LayerIndex, RectangleLayer.StrokeColor,
        RectangleLayer.StrokeWidth, NewStyle);
    end;
    if (Command <> nil) and (OldStyle <> NewStyle) then
      if FDocument[LayerIndex] is TVectArtLineLayer then
        Command.Add(TVectArtStrokeCommand.Create(FDocument, LayerIndex,
          TVectArtLineLayer(FDocument[LayerIndex]).StrokeColor,
          TVectArtLineLayer(FDocument[LayerIndex]).StrokeWidth, OldStyle,
          TVectArtLineLayer(FDocument[LayerIndex]).StrokeColor,
          TVectArtLineLayer(FDocument[LayerIndex]).StrokeWidth, NewStyle))
      else if FDocument[LayerIndex] is TVectArtPathLayer then
        Command.Add(TVectArtStrokeCommand.Create(FDocument, LayerIndex,
          TVectArtPathLayer(FDocument[LayerIndex]).StrokeColor,
          TVectArtPathLayer(FDocument[LayerIndex]).StrokeWidth, OldStyle,
          TVectArtPathLayer(FDocument[LayerIndex]).StrokeColor,
          TVectArtPathLayer(FDocument[LayerIndex]).StrokeWidth, NewStyle))
      else
        Command.Add(TVectArtStrokeCommand.Create(FDocument, LayerIndex,
          RectangleLayer.StrokeColor, RectangleLayer.StrokeWidth, OldStyle,
          RectangleLayer.StrokeColor, RectangleLayer.StrokeWidth, NewStyle));
  end;
  if (Command <> nil) and (Command.Count > 0) then
    FEditHistory.AddApplied(Command)
  else
    Command.Free;
  if FEditorState <> nil then
  begin
    if OtherStrokesIncluded then
      FEditorState.RectangleStrokeStyle := NewStyle;
    if LinesIncluded then
      FEditorState.LineStrokeStyle := NewStyle;
  end;
end;

procedure TVectArtObjectPropertiesControl.ApplyStrokeWidth;
var
  Command: TVectArtCompoundCommand;
  I: Integer;
  LayerIndex: Integer;
  LayerIndices: TArray<Integer>;
  LinesIncluded: Boolean;
  NewWidth: Double;
  OldWidth: Single;
  OtherStrokesIncluded: Boolean;
  PathLayer: TVectArtPathLayer;
  RectangleLayer: TVectArtRectangleLayer;
begin
  if FUpdating or (FDocument = nil) or (FDocument.SelectionCount = 0) or
    SelectedLayersHaveLock then
    Exit;
  if not TryStrToFloat(Trim(FStrokeWidthEdit.Text), NewWidth) then
  begin
    RefreshFromDocument;
    Exit;
  end;
  NewWidth := Max(NewWidth, 0.0);
  LayerIndices := GetSelectedStrokeIndices;
  LinesIncluded := False;
  OtherStrokesIncluded := False;
  Command := nil;
  if FEditHistory <> nil then
    Command := TVectArtCompoundCommand.Create;
  for I := 0 to High(LayerIndices) do
  begin
    LayerIndex := LayerIndices[I];
    if FDocument[LayerIndex] is TVectArtLineLayer then
    begin
      LinesIncluded := True;
      OldWidth := TVectArtLineLayer(FDocument[LayerIndex]).StrokeWidth;
      FDocument.SetLineStroke(LayerIndex,
        TVectArtLineLayer(FDocument[LayerIndex]).StrokeColor, NewWidth,
        TVectArtLineLayer(FDocument[LayerIndex]).StrokeStyle);
      RectangleLayer := nil;
    end
    else if FDocument[LayerIndex] is TVectArtPathLayer then
    begin
      OtherStrokesIncluded := True;
      PathLayer := TVectArtPathLayer(FDocument[LayerIndex]);
      OldWidth := PathLayer.StrokeWidth;
      FDocument.SetPathStroke(LayerIndex, PathLayer.StrokeColor, NewWidth,
        PathLayer.StrokeStyle);
      RectangleLayer := nil;
    end
    else
    begin
      OtherStrokesIncluded := True;
      RectangleLayer := TVectArtRectangleLayer(FDocument[LayerIndex]);
      OldWidth := RectangleLayer.StrokeWidth;
      FDocument.SetRectangleStroke(LayerIndex, RectangleLayer.StrokeColor,
        NewWidth, RectangleLayer.StrokeStyle);
    end;
    if (Command <> nil) and not SameValue(OldWidth, NewWidth) then
      if FDocument[LayerIndex] is TVectArtLineLayer then
        Command.Add(TVectArtStrokeCommand.Create(FDocument, LayerIndex,
          TVectArtLineLayer(FDocument[LayerIndex]).StrokeColor, OldWidth,
          TVectArtLineLayer(FDocument[LayerIndex]).StrokeStyle,
          TVectArtLineLayer(FDocument[LayerIndex]).StrokeColor, NewWidth,
          TVectArtLineLayer(FDocument[LayerIndex]).StrokeStyle))
      else if FDocument[LayerIndex] is TVectArtPathLayer then
        Command.Add(TVectArtStrokeCommand.Create(FDocument, LayerIndex,
          TVectArtPathLayer(FDocument[LayerIndex]).StrokeColor, OldWidth,
          TVectArtPathLayer(FDocument[LayerIndex]).StrokeStyle,
          TVectArtPathLayer(FDocument[LayerIndex]).StrokeColor, NewWidth,
          TVectArtPathLayer(FDocument[LayerIndex]).StrokeStyle))
      else
        Command.Add(TVectArtStrokeCommand.Create(FDocument, LayerIndex,
          RectangleLayer.StrokeColor, OldWidth, RectangleLayer.StrokeStyle,
          RectangleLayer.StrokeColor, NewWidth, RectangleLayer.StrokeStyle));
  end;
  if (Command <> nil) and (Command.Count > 0) then
    FEditHistory.AddApplied(Command)
  else
    Command.Free;
  if FEditorState <> nil then
  begin
    if OtherStrokesIncluded then
      FEditorState.RectangleStrokeWidth := NewWidth;
    if LinesIncluded then
      FEditorState.LineStrokeWidth := NewWidth;
  end;
end;

procedure TVectArtObjectPropertiesControl.ClearEditValue(Edit: TEdit);
begin
  // TCustomEdit.ClearはHandleNeededを呼ぶ。フォーム接続前の初期更新では
  // 親ウィンドウがまだないため、既定で空のEditはそのままにする。
  if (Edit <> nil) and Edit.HandleAllocated then
    Edit.Clear;
end;

procedure TVectArtObjectPropertiesControl.ApplyColor;
var
  Blue: Integer;
  Command: TVectArtCompoundCommand;
  Green: Integer;
  I: Integer;
  LayerIndex: Integer;
  LayerIndices: TArray<Integer>;
  Red: Integer;
  NewColor: TColor;
  OldColor: TColor;
  PathLayer: TVectArtPathLayer;
  Value: Integer;
begin
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount = 0) or SelectedLayersHaveLock then
    Exit;
  if not TryStrToInt('$' + StringReplace(Trim(FColorEdit.Text), '#', '', []),
    Value) or (Value < 0) or (Value > $FFFFFF) then
  begin
    RefreshFromDocument;
    Exit;
  end;
  Red := (Value shr 16) and $FF;
  Green := (Value shr 8) and $FF;
  Blue := Value and $FF;
  NewColor := RGB(Red, Green, Blue);
  LayerIndices := GetSelectedFillIndices;
  Command := nil;
  if FEditHistory <> nil then
    Command := TVectArtCompoundCommand.Create;
  for I := 0 to High(LayerIndices) do
  begin
    LayerIndex := LayerIndices[I];
    if FDocument[LayerIndex] is TVectArtPathLayer then
    begin
      PathLayer := TVectArtPathLayer(FDocument[LayerIndex]);
      OldColor := PathLayer.FillColor;
      FDocument.SetPathFill(LayerIndex, NewColor, PathLayer.Filled);
    end
    else
    begin
      OldColor := TVectArtRectangleLayer(FDocument[LayerIndex]).FillColor;
      FDocument.SetRectangleFillColor(LayerIndex, NewColor);
    end;
    if (Command <> nil) and (OldColor <> NewColor) then
      Command.Add(TVectArtFillColorCommand.Create(FDocument, LayerIndex,
        OldColor, NewColor));
  end;
  if (Command <> nil) and (Command.Count > 0) then
    FEditHistory.AddApplied(Command)
  else
    Command.Free;
  if FEditorState <> nil then
    FEditorState.RectangleFillColor := NewColor;
end;

procedure TVectArtObjectPropertiesControl.ApplyGeometry;
var
  Bounds: TRectF;
  HeightValue: Double;
  I: Integer;
  LayerIndices: TArray<Integer>;
  NewBounds: TArray<TRectF>;
  NewImagePoints: TVectArtImagePoints;
  NewSelectionBounds: TRectF;
  OldBounds: TArray<TRectF>;
  OldPoints: TArray<TPointF>;
  OldImagePoints: TVectArtImagePoints;
  OldSelectionBounds: TRectF;
  PathLayer: TVectArtPathLayer;
  ImageLayer: TVectArtImageLayer;
  PathPoints: TArray<TPointF>;
  PointIndex: Integer;
  ScaleX: Single;
  ScaleY: Single;
  WidthValue: Double;
  ULength: Single;
  VLength: Single;
  XValue: Double;
  YValue: Double;
begin
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount = 0) or SelectedLayersHaveLock then
    Exit;
  if not TryStrToFloat(Trim(FXEdit.Text), XValue) or
    not TryStrToFloat(Trim(FYEdit.Text), YValue) or
    not TryStrToFloat(Trim(FWidthEdit.Text), WidthValue) or
    not TryStrToFloat(Trim(FHeightEdit.Text), HeightValue) then
  begin
    RefreshFromDocument;
    Exit;
  end;
  WidthValue := Max(WidthValue, MIN_OBJECT_SIZE);
  HeightValue := Max(HeightValue, MIN_OBJECT_SIZE);
  if (FDocument.SelectionCount = 1) and
    (FDocument[FDocument.SelectedIndex] is TVectArtImageLayer) then
  begin
    ImageLayer := TVectArtImageLayer(FDocument[FDocument.SelectedIndex]);
    OldImagePoints := ImageLayer.Points;
    ULength := Hypot(OldImagePoints[1].X - OldImagePoints[0].X,
      OldImagePoints[1].Y - OldImagePoints[0].Y);
    VLength := Hypot(OldImagePoints[3].X - OldImagePoints[0].X,
      OldImagePoints[3].Y - OldImagePoints[0].Y);
    if (ULength <= 0) or (VLength <= 0) then
    begin
      RefreshFromDocument;
      Exit;
    end;
    NewImagePoints[0] := TPointF.Create(XValue, YValue);
    NewImagePoints[1] := TPointF.Create(XValue +
      (OldImagePoints[1].X - OldImagePoints[0].X) / ULength * WidthValue,
      YValue + (OldImagePoints[1].Y - OldImagePoints[0].Y) / ULength *
        WidthValue);
    NewImagePoints[3] := TPointF.Create(XValue +
      (OldImagePoints[3].X - OldImagePoints[0].X) / VLength * HeightValue,
      YValue + (OldImagePoints[3].Y - OldImagePoints[0].Y) / VLength *
        HeightValue);
    NewImagePoints[2] := TPointF.Create(NewImagePoints[1].X +
      NewImagePoints[3].X - NewImagePoints[0].X,
      NewImagePoints[1].Y + NewImagePoints[3].Y - NewImagePoints[0].Y);
    FDocument.SetImagePoints(FDocument.SelectedIndex, NewImagePoints);
    if FEditHistory <> nil then
      FEditHistory.AddApplied(TVectArtImagePointsCommand.Create(FDocument,
        FDocument.SelectedIndex, OldImagePoints, NewImagePoints));
    Exit;
  end;
  if (FDocument.SelectionCount = 1) and
    (FDocument[FDocument.SelectedIndex] is TVectArtPathLayer) then
  begin
    PathLayer := TVectArtPathLayer(FDocument[FDocument.SelectedIndex]);
    OldPoints := Copy(PathLayer.Points);
    OldSelectionBounds := PointsBounds(OldPoints);
    if SameValue(OldSelectionBounds.Width, 0.0) or
      SameValue(OldSelectionBounds.Height, 0.0) then
    begin
      RefreshFromDocument;
      Exit;
    end;
    ScaleX := WidthValue / OldSelectionBounds.Width;
    ScaleY := HeightValue / OldSelectionBounds.Height;
    SetLength(PathPoints, Length(OldPoints));
    for PointIndex := 0 to High(OldPoints) do
      PathPoints[PointIndex] := TPointF.Create(
        XValue + (OldPoints[PointIndex].X - OldSelectionBounds.Left) * ScaleX,
        YValue + (OldPoints[PointIndex].Y - OldSelectionBounds.Top) * ScaleY);
    FDocument.SetPathPoints(FDocument.SelectedIndex, PathPoints);
    if FEditHistory <> nil then
      FEditHistory.AddApplied(TVectArtPathPointsCommand.Create(FDocument,
        FDocument.SelectedIndex, OldPoints, PathPoints));
    Exit;
  end;
  if not SelectedBounds(OldSelectionBounds) then
    Exit;
  NewSelectionBounds := TRectF.Create(XValue, YValue, XValue + WidthValue,
    YValue + HeightValue);
  ScaleX := NewSelectionBounds.Width / OldSelectionBounds.Width;
  ScaleY := NewSelectionBounds.Height / OldSelectionBounds.Height;
  LayerIndices := GetSelectedRectangleIndices;
  SetLength(OldBounds, Length(LayerIndices));
  SetLength(NewBounds, Length(LayerIndices));
  for I := 0 to High(LayerIndices) do
  begin
    OldBounds[I] := TVectArtRectangleLayer(
      FDocument[LayerIndices[I]]).Bounds;
    Bounds := OldBounds[I];
    NewBounds[I].Left := NewSelectionBounds.Left +
      (Bounds.Left - OldSelectionBounds.Left) * ScaleX;
    NewBounds[I].Right := NewSelectionBounds.Left +
      (Bounds.Right - OldSelectionBounds.Left) * ScaleX;
    NewBounds[I].Top := NewSelectionBounds.Top +
      (Bounds.Top - OldSelectionBounds.Top) * ScaleY;
    NewBounds[I].Bottom := NewSelectionBounds.Top +
      (Bounds.Bottom - OldSelectionBounds.Top) * ScaleY;
    FDocument.SetRectangleBounds(LayerIndices[I], NewBounds[I]);
  end;
  if (FEditHistory <> nil) and
    (not SameValue(OldSelectionBounds.Left, NewSelectionBounds.Left) or
     not SameValue(OldSelectionBounds.Top, NewSelectionBounds.Top) or
     not SameValue(OldSelectionBounds.Right, NewSelectionBounds.Right) or
     not SameValue(OldSelectionBounds.Bottom, NewSelectionBounds.Bottom)) then
    FEditHistory.AddApplied(TVectArtBoundsCommand.Create(FDocument,
      LayerIndices, OldBounds, NewBounds));
end;

function TVectArtObjectPropertiesControl.GetSelectedFillIndices:
  TArray<Integer>;
var
  I: Integer;
  Indices: TList<Integer>;
begin
  Indices := TList<Integer>.Create;
  try
    if FDocument <> nil then
      for I := 1 to FDocument.LayerCount - 1 do
        if FDocument.IsLayerSelected(I) and
          ((FDocument[I] is TVectArtRectangleLayer) or
           (FDocument[I] is TVectArtPathLayer)) then
          Indices.Add(I);
    Result := Indices.ToArray;
  finally
    Indices.Free;
  end;
end;

function TVectArtObjectPropertiesControl.GetSelectedOpacityIndices:
  TArray<Integer>;
var
  I: Integer;
  Indices: TList<Integer>;
begin
  Indices := TList<Integer>.Create;
  try
    if FDocument <> nil then
      for I := 1 to FDocument.LayerCount - 1 do
        if FDocument.IsLayerSelected(I) and
          ((FDocument[I] is TVectArtRectangleLayer) or
           (FDocument[I] is TVectArtLineLayer) or
           (FDocument[I] is TVectArtPathLayer) or
           (FDocument[I] is TVectArtImageLayer)) then
          Indices.Add(I);
    Result := Indices.ToArray;
  finally
    Indices.Free;
  end;
end;

procedure TVectArtObjectPropertiesControl.ApplyOpacity;
var
  Command: TVectArtCompoundCommand;
  I: Integer;
  LayerIndex: Integer;
  LayerIndices: TArray<Integer>;
  NewValue: Double;
  OldValue: Single;
begin
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount = 0) then
    Exit;
  if not TryStrToFloat(Trim(FOpacityEdit.Text), NewValue) then
  begin
    RefreshFromDocument;
    Exit;
  end;
  NewValue := EnsureRange(NewValue, 0.0, 100.0) / 100.0;
  LayerIndices := GetSelectedOpacityIndices;
  Command := nil;
  if FEditHistory <> nil then
    Command := TVectArtCompoundCommand.Create;
  for I := 0 to High(LayerIndices) do
  begin
    LayerIndex := LayerIndices[I];
    OldValue := FDocument[LayerIndex].Opacity;
    FDocument.SetLayerOpacity(LayerIndex, NewValue);
    if (Command <> nil) and not SameValue(OldValue, NewValue) then
      Command.Add(TVectArtLayerOpacityCommand.Create(FDocument, LayerIndex,
        OldValue, NewValue));
  end;
  if (Command <> nil) and (Command.Count > 0) then
    FEditHistory.AddApplied(Command)
  else
    Command.Free;
  if FEditorState <> nil then
    FEditorState.RectangleOpacity := NewValue;
end;

procedure TVectArtObjectPropertiesControl.EditExit(Sender: TObject);
begin
  if Sender = FColorEdit then
    ApplyColor
  else if Sender = FStrokeColorEdit then
    ApplyStrokeColor
  else if Sender = FStrokeWidthEdit then
    ApplyStrokeWidth
  else if Sender = FOpacityEdit then
    ApplyOpacity
  else
    ApplyGeometry;
end;

function TVectArtObjectPropertiesControl.NewDarkCombo:
  TVectArtStrokeStyleCombo;
begin
  Result := TVectArtStrokeStyleCombo.Create(Self);
  Result.Parent := Self;
  Result.Style := csOwnerDrawFixed;
  Result.ItemHeight := 22;
  Result.DropDownCount := 9;
  Result.Color := COLOR_EDIT;
  Result.Font.Name := 'Segoe UI';
  Result.Font.Height := -12;
  Result.Font.Color := COLOR_TEXT;
  Result.ParentColor := False;
  Result.ParentFont := False;
  Result.OnChange := ApplyStrokeStyle;
end;

procedure TVectArtObjectPropertiesControl.EditKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    EditExit(Sender);
    Key := 0;
  end
  else if Key = VK_ESCAPE then
  begin
    RefreshFromDocument;
    Key := 0;
  end;
end;

function TVectArtObjectPropertiesControl.NewDarkEdit: TEdit;
begin
  Result := TEdit.Create(Self);
  Result.Parent := Self;
  Result.AutoSize := False;
  Result.Height := EDIT_HEIGHT;
  Result.Color := COLOR_EDIT;
  Result.Font.Name := 'Segoe UI';
  Result.Font.Height := -12;
  Result.Font.Color := COLOR_TEXT;
  Result.ParentColor := False;
  Result.ParentFont := False;
  Result.OnExit := EditExit;
  Result.OnKeyDown := EditKeyDown;
end;

function TVectArtObjectPropertiesControl.GetSelectedRectangleIndices:
  TArray<Integer>;
var
  I: Integer;
  Indices: TList<Integer>;
begin
  Indices := TList<Integer>.Create;
  try
    if FDocument <> nil then
      for I := 1 to FDocument.LayerCount - 1 do
        if FDocument.IsLayerSelected(I) and
          (FDocument[I] is TVectArtRectangleLayer) then
          Indices.Add(I);
    Result := Indices.ToArray;
  finally
    Indices.Free;
  end;
end;

function TVectArtObjectPropertiesControl.GetSelectedStrokeIndices:
  TArray<Integer>;
var
  I: Integer;
  Indices: TList<Integer>;
begin
  Indices := TList<Integer>.Create;
  try
    if FDocument <> nil then
      for I := 1 to FDocument.LayerCount - 1 do
        if FDocument.IsLayerSelected(I) and
          ((FDocument[I] is TVectArtRectangleLayer) or
           (FDocument[I] is TVectArtLineLayer) or
           (FDocument[I] is TVectArtPathLayer)) then
          Indices.Add(I);
    Result := Indices.ToArray;
  finally
    Indices.Free;
  end;
end;

function TVectArtObjectPropertiesControl.SelectedLayersHaveLock: Boolean;
var
  I: Integer;
begin
  Result := False;
  if FDocument = nil then
    Exit;
  for I := 1 to FDocument.LayerCount - 1 do
    if FDocument.IsLayerSelected(I) and FDocument[I].Locked then
      Exit(True);
end;

procedure TVectArtObjectPropertiesControl.Paint;
var
  ColorValue: TColor;
  HeaderText: string;
  HexValue: Integer;
  SwatchRect: TRect;
begin
  Canvas.Brush.Color := COLOR_BACKGROUND;
  Canvas.FillRect(ClientRect);
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Height := -12;
  Canvas.Font.Color := COLOR_LABEL;
  if (FDocument = nil) or (FDocument.SelectionCount = 0) then
    HeaderText := 'No selection'
  else if FDocument.SelectionCount = 1 then
    HeaderText := FDocument[FDocument.SelectedIndex].Name
  else
    HeaderText := Format('%d objects selected', [FDocument.SelectionCount]);
  Canvas.Font.Color := COLOR_TEXT;
  Canvas.TextOut(12, 12, HeaderText);
  Canvas.Font.Color := COLOR_LABEL;
  Canvas.TextOut(12, 43, 'X');
  Canvas.TextOut((ClientWidth div 2) + 4, 43, 'Y');
  Canvas.TextOut(12, 91, 'Width');
  Canvas.TextOut((ClientWidth div 2) + 4, 91, 'Height');
  Canvas.TextOut(12, 139, 'Fill color');
  Canvas.TextOut(12, 190, 'Stroke color');
  Canvas.TextOut(12, 239, 'Stroke width (0 = none)');
  Canvas.TextOut((ClientWidth div 2) + 4, 239, 'Stroke style');
  Canvas.TextOut(12, 288, 'Opacity (%)');
  SwatchRect := Rect(ClientWidth - 42, 158, ClientWidth - 12, 183);
  ColorValue := COLOR_EDIT;
  if TryStrToInt('$' + StringReplace(Trim(FColorEdit.Text), '#', '', []),
    HexValue) and (HexValue >= 0) and (HexValue <= $FFFFFF) then
    ColorValue := RGB((HexValue shr 16) and $FF,
      (HexValue shr 8) and $FF, HexValue and $FF);
  Canvas.Brush.Color := ColorValue;
  Canvas.FillRect(SwatchRect);
  Canvas.Brush.Color := COLOR_LABEL;
  Canvas.FrameRect(SwatchRect);
  SwatchRect := Rect(ClientWidth - 42, 207, ClientWidth - 12, 232);
  ColorValue := COLOR_EDIT;
  if TryStrToInt('$' + StringReplace(Trim(FStrokeColorEdit.Text), '#', '', []),
    HexValue) and (HexValue >= 0) and (HexValue <= $FFFFFF) then
    ColorValue := RGB((HexValue shr 16) and $FF,
      (HexValue shr 8) and $FF, HexValue and $FF);
  Canvas.Brush.Color := ColorValue;
  Canvas.FillRect(SwatchRect);
  Canvas.Brush.Color := COLOR_LABEL;
  Canvas.FrameRect(SwatchRect);
end;

procedure TVectArtObjectPropertiesControl.RefreshFromDocument;
var
  Bounds: TRectF;
  ColorValue: TColor;
  CommonColor: Boolean;
  CommonOpacity: Boolean;
  CommonStrokeColor: Boolean;
  CommonStrokeStyle: Boolean;
  CommonStrokeWidth: Boolean;
  I: Integer;
  ImageLayer: TVectArtImageLayer;
  LayerIndices: TArray<Integer>;
  LineLayer: TVectArtLineLayer;
  OpacityValue: Single;
  PathLayer: TVectArtPathLayer;
  RectangleLayer: TVectArtRectangleLayer;
  StrokeColorValue: TColor;
  StrokeStyleValue: TVectArtStrokeStyle;
  StrokeWidthValue: Single;
begin
  FUpdating := True;
  try
    if (FDocument <> nil) and (FDocument.SelectionCount = 1) and
      (FDocument[FDocument.SelectedIndex] is TVectArtRectangleLayer) then
    begin
      RectangleLayer := TVectArtRectangleLayer(
        FDocument[FDocument.SelectedIndex]);
      Bounds := RectangleLayer.Bounds;
      FXEdit.Text := FormatFloat('0.##', Bounds.Left);
      FYEdit.Text := FormatFloat('0.##', Bounds.Top);
      FWidthEdit.Text := FormatFloat('0.##', Bounds.Width);
      FHeightEdit.Text := FormatFloat('0.##', Bounds.Height);
      ColorValue := ColorToRGB(RectangleLayer.FillColor);
      FColorEdit.Text := Format('#%.2x%.2x%.2x', [GetRValue(ColorValue),
        GetGValue(ColorValue), GetBValue(ColorValue)]);
      FOpacityEdit.Text := FormatFloat('0.##', RectangleLayer.Opacity * 100);
      StrokeColorValue := ColorToRGB(RectangleLayer.StrokeColor);
      FStrokeColorEdit.Text := Format('#%.2x%.2x%.2x',
        [GetRValue(StrokeColorValue), GetGValue(StrokeColorValue),
         GetBValue(StrokeColorValue)]);
      FStrokeWidthEdit.Text := FormatFloat('0.##', RectangleLayer.StrokeWidth);
      FStrokeStyleCombo.SetPendingItemIndex(
        Ord(RectangleLayer.StrokeStyle));
      SetEditorsEnabled(True);
      if RectangleLayer.Locked then
      begin
        FXEdit.Enabled := False;
        FYEdit.Enabled := False;
        FWidthEdit.Enabled := False;
        FHeightEdit.Enabled := False;
        FColorEdit.Enabled := False;
        FStrokeColorEdit.Enabled := False;
        FStrokeWidthEdit.Enabled := False;
        FStrokeStyleCombo.Enabled := False;
      end;
    end
    else if (FDocument <> nil) and (FDocument.SelectionCount = 1) and
      (FDocument[FDocument.SelectedIndex] is TVectArtImageLayer) then
    begin
      ImageLayer := TVectArtImageLayer(FDocument[FDocument.SelectedIndex]);
      FXEdit.Text := FormatFloat('0.##', ImageLayer.Points[0].X);
      FYEdit.Text := FormatFloat('0.##', ImageLayer.Points[0].Y);
      FWidthEdit.Text := FormatFloat('0.##', Hypot(
        ImageLayer.Points[1].X - ImageLayer.Points[0].X,
        ImageLayer.Points[1].Y - ImageLayer.Points[0].Y));
      FHeightEdit.Text := FormatFloat('0.##', Hypot(
        ImageLayer.Points[3].X - ImageLayer.Points[0].X,
        ImageLayer.Points[3].Y - ImageLayer.Points[0].Y));
      ClearEditValue(FColorEdit);
      ClearEditValue(FStrokeColorEdit);
      ClearEditValue(FStrokeWidthEdit);
      FStrokeStyleCombo.SetPendingItemIndex(-1);
      FOpacityEdit.Text := FormatFloat('0.##', ImageLayer.Opacity * 100);
      SetEditorsEnabled(True);
      FColorEdit.Enabled := False;
      FStrokeColorEdit.Enabled := False;
      FStrokeWidthEdit.Enabled := False;
      FStrokeStyleCombo.Enabled := False;
      if ImageLayer.Locked then
      begin
        FXEdit.Enabled := False;
        FYEdit.Enabled := False;
        FWidthEdit.Enabled := False;
        FHeightEdit.Enabled := False;
        FOpacityEdit.Enabled := False;
      end;
    end
    else if (FDocument <> nil) and (FDocument.SelectionCount = 1) and
      (FDocument[FDocument.SelectedIndex] is TVectArtPathLayer) then
    begin
      PathLayer := TVectArtPathLayer(FDocument[FDocument.SelectedIndex]);
      Bounds := PointsBounds(PathLayer.Points);
      FXEdit.Text := FormatFloat('0.##', Bounds.Left);
      FYEdit.Text := FormatFloat('0.##', Bounds.Top);
      FWidthEdit.Text := FormatFloat('0.##', Bounds.Width);
      FHeightEdit.Text := FormatFloat('0.##', Bounds.Height);
      ColorValue := ColorToRGB(PathLayer.FillColor);
      FColorEdit.Text := Format('#%.2x%.2x%.2x', [GetRValue(ColorValue),
        GetGValue(ColorValue), GetBValue(ColorValue)]);
      FOpacityEdit.Text := FormatFloat('0.##', PathLayer.Opacity * 100);
      StrokeColorValue := ColorToRGB(PathLayer.StrokeColor);
      FStrokeColorEdit.Text := Format('#%.2x%.2x%.2x',
        [GetRValue(StrokeColorValue), GetGValue(StrokeColorValue),
         GetBValue(StrokeColorValue)]);
      FStrokeWidthEdit.Text := FormatFloat('0.##', PathLayer.StrokeWidth);
      FStrokeStyleCombo.SetPendingItemIndex(Ord(PathLayer.StrokeStyle));
      SetEditorsEnabled(True);
      if PathLayer.Locked then
      begin
        FXEdit.Enabled := False;
        FYEdit.Enabled := False;
        FWidthEdit.Enabled := False;
        FHeightEdit.Enabled := False;
        FColorEdit.Enabled := False;
        FStrokeColorEdit.Enabled := False;
        FStrokeWidthEdit.Enabled := False;
        FStrokeStyleCombo.Enabled := False;
      end;
    end
    else if (FDocument <> nil) and (FDocument.SelectionCount = 1) and
      (FDocument[FDocument.SelectedIndex] is TVectArtLineLayer) then
    begin
      LineLayer := TVectArtLineLayer(FDocument[FDocument.SelectedIndex]);
      FXEdit.Text := FormatFloat('0.##', LineLayer.StartPoint.X);
      FYEdit.Text := FormatFloat('0.##', LineLayer.StartPoint.Y);
      FWidthEdit.Text := FormatFloat('0.##', LineLayer.EndPoint.X);
      FHeightEdit.Text := FormatFloat('0.##', LineLayer.EndPoint.Y);
      ClearEditValue(FColorEdit);
      FOpacityEdit.Text := FormatFloat('0.##', LineLayer.Opacity * 100);
      StrokeColorValue := ColorToRGB(LineLayer.StrokeColor);
      FStrokeColorEdit.Text := Format('#%.2x%.2x%.2x',
        [GetRValue(StrokeColorValue), GetGValue(StrokeColorValue),
         GetBValue(StrokeColorValue)]);
      FStrokeWidthEdit.Text := FormatFloat('0.##', LineLayer.StrokeWidth);
      FStrokeStyleCombo.SetPendingItemIndex(Ord(LineLayer.StrokeStyle));
      SetEditorsEnabled(True);
      FXEdit.Enabled := False;
      FYEdit.Enabled := False;
      FWidthEdit.Enabled := False;
      FHeightEdit.Enabled := False;
      FColorEdit.Enabled := False;
      FOpacityEdit.Enabled := False;
      if LineLayer.Locked then
      begin
        FStrokeColorEdit.Enabled := False;
        FStrokeWidthEdit.Enabled := False;
        FStrokeStyleCombo.Enabled := False;
      end;
    end
    else if (FDocument <> nil) and (FDocument.SelectionCount > 1) and
      SelectedBounds(Bounds) then
    begin
      FXEdit.Text := FormatFloat('0.##', Bounds.Left);
      FYEdit.Text := FormatFloat('0.##', Bounds.Top);
      FWidthEdit.Text := FormatFloat('0.##', Bounds.Width);
      FHeightEdit.Text := FormatFloat('0.##', Bounds.Height);
      LayerIndices := GetSelectedRectangleIndices;
      RectangleLayer := TVectArtRectangleLayer(FDocument[LayerIndices[0]]);
      ColorValue := RectangleLayer.FillColor;
      OpacityValue := RectangleLayer.Opacity;
      StrokeColorValue := RectangleLayer.StrokeColor;
      StrokeStyleValue := RectangleLayer.StrokeStyle;
      StrokeWidthValue := RectangleLayer.StrokeWidth;
      CommonColor := True;
      CommonOpacity := True;
      CommonStrokeColor := True;
      CommonStrokeStyle := True;
      CommonStrokeWidth := True;
      for I := 1 to High(LayerIndices) do
      begin
        RectangleLayer := TVectArtRectangleLayer(FDocument[LayerIndices[I]]);
        CommonColor := CommonColor and
          (RectangleLayer.FillColor = ColorValue);
        CommonOpacity := CommonOpacity and
          SameValue(RectangleLayer.Opacity, OpacityValue);
        CommonStrokeColor := CommonStrokeColor and
          (RectangleLayer.StrokeColor = StrokeColorValue);
        CommonStrokeStyle := CommonStrokeStyle and
          (RectangleLayer.StrokeStyle = StrokeStyleValue);
        CommonStrokeWidth := CommonStrokeWidth and
          SameValue(RectangleLayer.StrokeWidth, StrokeWidthValue);
      end;
      if CommonColor then
      begin
        ColorValue := ColorToRGB(ColorValue);
        FColorEdit.Text := Format('#%.2x%.2x%.2x', [GetRValue(ColorValue),
          GetGValue(ColorValue), GetBValue(ColorValue)]);
      end
      else
        ClearEditValue(FColorEdit);
      if CommonOpacity then
        FOpacityEdit.Text := FormatFloat('0.##', OpacityValue * 100)
      else
        ClearEditValue(FOpacityEdit);
      if CommonStrokeColor then
      begin
        StrokeColorValue := ColorToRGB(StrokeColorValue);
        FStrokeColorEdit.Text := Format('#%.2x%.2x%.2x',
          [GetRValue(StrokeColorValue), GetGValue(StrokeColorValue),
           GetBValue(StrokeColorValue)]);
      end
      else
        ClearEditValue(FStrokeColorEdit);
      if CommonStrokeWidth then
        FStrokeWidthEdit.Text := FormatFloat('0.##', StrokeWidthValue)
      else
        ClearEditValue(FStrokeWidthEdit);
      if CommonStrokeStyle then
      begin
        FStrokeStyleCombo.SetPendingItemIndex(Ord(StrokeStyleValue));
      end
      else
        FStrokeStyleCombo.SetPendingItemIndex(-1);
      SetEditorsEnabled(True);
      if SelectedLayersHaveLock then
      begin
        FXEdit.Enabled := False;
        FYEdit.Enabled := False;
        FWidthEdit.Enabled := False;
        FHeightEdit.Enabled := False;
        FColorEdit.Enabled := False;
        FStrokeColorEdit.Enabled := False;
        FStrokeWidthEdit.Enabled := False;
        FStrokeStyleCombo.Enabled := False;
      end;
    end
    else
    begin
      ClearEditValue(FXEdit);
      ClearEditValue(FYEdit);
      ClearEditValue(FWidthEdit);
      ClearEditValue(FHeightEdit);
      ClearEditValue(FColorEdit);
      ClearEditValue(FStrokeColorEdit);
      ClearEditValue(FStrokeWidthEdit);
      FStrokeStyleCombo.SetPendingItemIndex(-1);
      ClearEditValue(FOpacityEdit);
      SetEditorsEnabled(False);
    end;
  finally
    FUpdating := False;
  end;
  Invalidate;
end;

function TVectArtObjectPropertiesControl.SelectedBounds(
  out Bounds: TRectF): Boolean;
var
  I: Integer;
  LayerBounds: TRectF;
begin
  Bounds := TRectF.Empty;
  Result := False;
  if FDocument = nil then
    Exit;
  for I := 1 to FDocument.LayerCount - 1 do
    if FDocument.IsLayerSelected(I) and
      (FDocument[I] is TVectArtRectangleLayer) then
    begin
      LayerBounds := TVectArtRectangleLayer(FDocument[I]).Bounds;
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

procedure TVectArtObjectPropertiesControl.Resize;
var
  ColumnWidth: Integer;
begin
  inherited Resize;
  ColumnWidth := Max((ClientWidth - 36) div 2, 48);
  FXEdit.SetBounds(12, 59, ColumnWidth, EDIT_HEIGHT);
  FYEdit.SetBounds((ClientWidth div 2) + 4, 59, ColumnWidth, EDIT_HEIGHT);
  FWidthEdit.SetBounds(12, 107, ColumnWidth, EDIT_HEIGHT);
  FHeightEdit.SetBounds((ClientWidth div 2) + 4, 107, ColumnWidth,
    EDIT_HEIGHT);
  FColorEdit.SetBounds(12, 158, Max(ClientWidth - 66, 48), EDIT_HEIGHT);
  FStrokeColorEdit.SetBounds(12, 207, Max(ClientWidth - 66, 48), EDIT_HEIGHT);
  FStrokeWidthEdit.SetBounds(12, 256, ColumnWidth, EDIT_HEIGHT);
  FStrokeStyleCombo.SetBounds((ClientWidth div 2) + 4, 256, ColumnWidth,
    EDIT_HEIGHT);
  FOpacityEdit.SetBounds(12, 305, Max(ClientWidth - 24, 48), EDIT_HEIGHT);
end;

procedure TVectArtObjectPropertiesControl.SetDocument(
  const Value: TVectArtDocument);
begin
  if FDocument = Value then
    Exit;
  FDocument := Value;
  RefreshFromDocument;
end;

procedure TVectArtObjectPropertiesControl.SetEditorsEnabled(Value: Boolean);
begin
  FXEdit.Enabled := Value;
  FYEdit.Enabled := Value;
  FWidthEdit.Enabled := Value;
  FHeightEdit.Enabled := Value;
  FColorEdit.Enabled := Value;
  FStrokeColorEdit.Enabled := Value;
  FStrokeWidthEdit.Enabled := Value;
  FStrokeStyleCombo.Enabled := Value;
  FOpacityEdit.Enabled := Value;
end;

end.
