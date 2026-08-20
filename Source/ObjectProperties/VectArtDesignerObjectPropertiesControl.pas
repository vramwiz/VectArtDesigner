// 選択Rectangleの位置、サイズ、塗り色を表示・編集するダークテーマ用Controlを提供する。
unit VectArtDesignerObjectPropertiesControl;

interface

uses
  System.Classes, System.Types, Vcl.Controls, Vcl.StdCtrls,
  VectArtDesignerDocument, VectArtDesignerEditCommands,
  VectArtDesignerEditHistory, VectArtDesignerEditorState;

type
  TVectArtObjectPropertiesControl = class(TCustomControl)
  private
    FColorEdit: TEdit;
    FDocument: TVectArtDocument;
    FEditHistory: TVectArtEditHistory;
    FEditorState: TVectArtEditorState;
    FHeightEdit: TEdit;
    FOpacityEdit: TEdit;
    FUpdating: Boolean;
    FWidthEdit: TEdit;
    FXEdit: TEdit;
    FYEdit: TEdit;
    procedure ApplyColor;
    procedure ApplyGeometry;
    procedure ApplyOpacity;
    procedure EditExit(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    function GetSelectedRectangleIndices: TArray<Integer>;
    function SelectedLayersHaveLock: Boolean;
    function NewDarkEdit: TEdit;
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
  Vcl.Graphics;

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
  FOpacityEdit := NewDarkEdit;
  SetEditorsEnabled(False);
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
  LayerIndices := GetSelectedRectangleIndices;
  Command := nil;
  if FEditHistory <> nil then
    Command := TVectArtCompoundCommand.Create;
  for I := 0 to High(LayerIndices) do
  begin
    LayerIndex := LayerIndices[I];
    OldColor := TVectArtRectangleLayer(FDocument[LayerIndex]).FillColor;
    FDocument.SetRectangleFillColor(LayerIndex, NewColor);
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
  NewSelectionBounds: TRectF;
  OldBounds: TArray<TRectF>;
  OldSelectionBounds: TRectF;
  ScaleX: Single;
  ScaleY: Single;
  WidthValue: Double;
  XValue: Double;
  YValue: Double;
begin
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount = 0) or SelectedLayersHaveLock or
    not SelectedBounds(OldSelectionBounds) then
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
  LayerIndices := GetSelectedRectangleIndices;
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
  else if Sender = FOpacityEdit then
    ApplyOpacity
  else
    ApplyGeometry;
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
  Canvas.TextOut(12, 190, 'Opacity (%)');
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
end;

procedure TVectArtObjectPropertiesControl.RefreshFromDocument;
var
  Bounds: TRectF;
  ColorValue: TColor;
  CommonColor: Boolean;
  CommonOpacity: Boolean;
  I: Integer;
  LayerIndices: TArray<Integer>;
  OpacityValue: Single;
  RectangleLayer: TVectArtRectangleLayer;
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
      SetEditorsEnabled(True);
      if RectangleLayer.Locked then
      begin
        FXEdit.Enabled := False;
        FYEdit.Enabled := False;
        FWidthEdit.Enabled := False;
        FHeightEdit.Enabled := False;
        FColorEdit.Enabled := False;
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
      CommonColor := True;
      CommonOpacity := True;
      for I := 1 to High(LayerIndices) do
      begin
        RectangleLayer := TVectArtRectangleLayer(FDocument[LayerIndices[I]]);
        CommonColor := CommonColor and
          (RectangleLayer.FillColor = ColorValue);
        CommonOpacity := CommonOpacity and
          SameValue(RectangleLayer.Opacity, OpacityValue);
      end;
      if CommonColor then
      begin
        ColorValue := ColorToRGB(ColorValue);
        FColorEdit.Text := Format('#%.2x%.2x%.2x', [GetRValue(ColorValue),
          GetGValue(ColorValue), GetBValue(ColorValue)]);
      end
      else
        FColorEdit.Clear;
      if CommonOpacity then
        FOpacityEdit.Text := FormatFloat('0.##', OpacityValue * 100)
      else
        FOpacityEdit.Clear;
      SetEditorsEnabled(True);
      if SelectedLayersHaveLock then
      begin
        FXEdit.Enabled := False;
        FYEdit.Enabled := False;
        FWidthEdit.Enabled := False;
        FHeightEdit.Enabled := False;
        FColorEdit.Enabled := False;
      end;
    end
    else
    begin
      FXEdit.Clear;
      FYEdit.Clear;
      FWidthEdit.Clear;
      FHeightEdit.Clear;
      FColorEdit.Clear;
      FOpacityEdit.Clear;
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
  FOpacityEdit.SetBounds(12, 207, Max(ClientWidth - 24, 48), EDIT_HEIGHT);
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
  FOpacityEdit.Enabled := Value;
end;

end.
