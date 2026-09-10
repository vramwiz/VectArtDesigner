// 選択図形の位置、サイズとMIFで扱える装飾を表示・編集するControlを提供する。
// 複数選択では共通値だけを示し、ロックを含む選択への変更を許可しない。
unit VectArtDesignerObjectPropertiesControl;

interface

uses
  VectArtDesignerNumericSlider, VectArtDesignerSettingsSections, VectArtDesignerShadowSettings, System.Classes, System.Types, Vcl.Controls, Vcl.StdCtrls,  Vcl.Forms, Vcl.Graphics, VectArtDesignerColorSwatch, VectArtDesignerPaintPopup,
  VectArtDesignerDocument, VectArtDesignerColorHistory,
  VectArtDesignerEditCommands,
  VectArtDesignerEditHistory, VectArtDesignerEditorState,
  VectArtDesignerLineStyleControls, VectArtDesignerStrokeStyleCombo;

type
  TVectArtObjectPropertiesControl = class(TCustomControl)
  private
    FSections: TVectArtSettingsSections;
    FInfoPanel, FTextPanel, FLinePanel, FFillPanel, FStrokePanel: TVectArtSettingsPanel;
    FShadowPanel, FOutlinePanel, FEffectsPanel: TVectArtSettingsPanel;
    FShadowSettings: TVectArtShadowSettings;
    FFillSwatch, FStrokeSwatch: TVectArtColorSwatch;
    FTextMemo: TMemo;
    FFontCombo: TComboBox;
    FFontSize: TEdit;
    FFontChecks: array[0..3] of TCheckBox;
    FAspectCheck: TCheckBox;
    FAppearanceMode: TComboBox;
    FTypeLabel: TStaticText;
    FPopupStroke: Boolean;
    FPopupSelection: TArray<Integer>;
    FColorEdit: TEdit;
    FDocument: TVectArtDocument;
    FColorHistory: TVectArtColorHistory;
    FEditHistory: TVectArtEditHistory;
    FEditorState: TVectArtEditorState;
    FHeightEdit: TEdit;
    FLetterSpacingEdit: TEdit;
    FLineSpacingEdit: TEdit;
    FVerticalTextCheck: TCheckBox;
    FOpacityEdit: TEdit;
    FTransparencySlider, FStrokeWidthSlider: TVectArtNumericSlider;
    FStrokeColorEdit: TEdit;
    FStrokeStyleCombo: TVectArtStrokeStyleCombo;
    FPathLineCapButtons: array[TVectArtLineCap] of TVectArtLineCapButton;
    FPathLineJoinButtons: array[TVectArtLineJoin] of TVectArtLineJoinButton;
    FPathAntiAliasButton: TVectArtAntiAliasButton;
    FPathEndMarkerCombo: TVectArtLineMarkerCombo;
    FPathEndMarkerSizeEdit: TEdit;
    FPathStartMarkerCombo: TVectArtLineMarkerCombo;
    FPathStartMarkerSizeEdit: TEdit;
    FStrokeWidthEdit: TEdit;
    FUpdating: Boolean;
    FBuildingSettings: Boolean;
    FWidthEdit: TEdit;
    FXEdit: TEdit;
    FYEdit: TEdit;
    procedure NumericSettingChanged(Sender: TObject);
    procedure ApplySelectedLineCap(Sender: TObject);
    procedure ApplySelectedLineJoin(Sender: TObject);
    procedure ApplySelectedLineAntiAlias(Sender: TObject);
    procedure ApplySelectedLineEndMarker(Sender: TObject);
    procedure ApplySelectedLineStartMarker(Sender: TObject);
    procedure ApplySelectedLineMarkerSize(StartMarker: Boolean);
    procedure AppearanceChanged(Sender: TObject);
    procedure LayoutSettings(Sender: TObject);
    procedure BuildSettingsUI;
    procedure RefreshSettingsUI;
    procedure OpenColor(Sender: TObject);
    procedure PopupColorChanged(Sender: TObject; Color: TColor);
    procedure PopupFillChanged(Sender: TObject; Color: TColor; const Fill: TVectArtFillStyle);
    procedure TextSettingsChanged(Sender: TObject);
    procedure ApplyColor;
    procedure ApplyGeometry;
    procedure ApplyOpacity;
    procedure PopupStrokePaintChanged(Sender: TObject; Color: TColor; const Fill: TVectArtFillStyle);
    procedure ApplyStrokeColor;
    procedure ApplyStrokeStyle(Sender: TObject);
    procedure ApplyPathLineCap(Sender: TObject);
    procedure ApplyPathLineJoin(Sender: TObject);
    procedure ApplyPathAntiAlias(Sender: TObject);
    procedure ApplyPathEndMarker(Sender: TObject);
    procedure ApplyPathMarkerSize(StartMarker: Boolean);
    procedure ApplyPathStartMarker(Sender: TObject);
    procedure ApplyStrokeWidth;
    procedure ApplyTextSpacing;
    procedure ApplyVerticalText(Sender: TObject);
    procedure ClearEditValue(Edit: TEdit);
    procedure EditExit(Sender: TObject);
    procedure PixelKeyPress(Sender: TObject; var Key: Char);
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
    procedure SetPathStyleControlsVisible(Value: Boolean);
    procedure SetTextSpacingControlsVisible(Value: Boolean);
  protected
    procedure CreateWnd; override;
    procedure SetParent(AParent: TWinControl); override;
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure RefreshFromDocument;
    property Document: TVectArtDocument read FDocument write SetDocument;
    property ColorHistory: TVectArtColorHistory read FColorHistory
      write FColorHistory;
    property EditHistory: TVectArtEditHistory read FEditHistory
      write FEditHistory;
    property EditorState: TVectArtEditorState read FEditorState
      write FEditorState;
    property PathEndMarkerCombo: TVectArtLineMarkerCombo
      read FPathEndMarkerCombo;
    property PathEndMarkerSizeEdit: TEdit read FPathEndMarkerSizeEdit;
    property PathStartMarkerCombo: TVectArtLineMarkerCombo
      read FPathStartMarkerCombo;
    property PathStartMarkerSizeEdit: TEdit read FPathStartMarkerSizeEdit;
    property TextLetterSpacingEdit: TEdit read FLetterSpacingEdit;
    property TextLineSpacingEdit: TEdit read FLineSpacingEdit;
    property VerticalTextCheck: TCheckBox read FVerticalTextCheck;
  end;

implementation

uses VectArtDesignerSettingsFont,
  VectArtDesignerSettingsSelection, VectArtDesignerSettingsGeometry, System.Math, System.SysUtils, Winapi.Windows,
  VectArtDesignerFillCommand, VectArtDesignerAppearanceModeCommand, VectArtDesignerSettingsDrafts, VectArtDesignerBezierGeometry, VectArtDesignerGeometry,
  VectArtDesignerTextGeometry;

const
  COLOR_BACKGROUND = TColor($00212121);
  COLOR_EDIT = TColor($00303030);
  COLOR_LABEL = TColor($00BDBDBD);
  COLOR_TEXT = TColor($00EEEEEE);
  EDIT_HEIGHT = 25;

constructor TVectArtObjectPropertiesControl.Create(AOwner: TComponent);
var
  LineCap: TVectArtLineCap;
  LineJoin: TVectArtLineJoin;
begin
  inherited Create(AOwner);
  Color := COLOR_BACKGROUND;
  ParentBackground := False;
  ParentDoubleBuffered := False;
  DoubleBuffered := False;
  Font.Color := COLOR_TEXT;
  Font.Name := VECTART_SETTINGS_FONT_NAME;
  Font.Height := VECTART_SETTINGS_FONT_HEIGHT;
  FXEdit := NewDarkEdit;
  FYEdit := NewDarkEdit;
  FWidthEdit := NewDarkEdit;
  FHeightEdit := NewDarkEdit;
  FColorEdit := NewDarkEdit;
  FStrokeColorEdit := NewDarkEdit;
  FStrokeWidthEdit := NewDarkEdit;
  FStrokeStyleCombo := NewDarkCombo;
  FOpacityEdit := NewDarkEdit;
  FLetterSpacingEdit := NewDarkEdit;
  FLineSpacingEdit := NewDarkEdit;
  FVerticalTextCheck := TCheckBox.Create(Self);
  FVerticalTextCheck.Parent := Self;
  FVerticalTextCheck.Caption := 'Vertical writing';
  FVerticalTextCheck.Font.Color := COLOR_TEXT;
  FVerticalTextCheck.ParentColor := True;
  FVerticalTextCheck.OnClick := ApplyVerticalText;
  for LineCap := Low(TVectArtLineCap) to High(TVectArtLineCap) do
  begin
    FPathLineCapButtons[LineCap] := TVectArtLineCapButton.Create(Self);
    FPathLineCapButtons[LineCap].Parent := Self;
    FPathLineCapButtons[LineCap].LineCap := LineCap;
    FPathLineCapButtons[LineCap].OnClick := ApplyPathLineCap;
  end;
  for LineJoin := Low(TVectArtLineJoin) to High(TVectArtLineJoin) do
  begin
    FPathLineJoinButtons[LineJoin] := TVectArtLineJoinButton.Create(Self);
    FPathLineJoinButtons[LineJoin].Parent := Self;
    FPathLineJoinButtons[LineJoin].LineJoin := LineJoin;
    FPathLineJoinButtons[LineJoin].OnClick := ApplyPathLineJoin;
  end;
  FPathAntiAliasButton := TVectArtAntiAliasButton.Create(Self);
  FPathAntiAliasButton.Parent := Self;
  FPathAntiAliasButton.Caption := 'AA';
  FPathAntiAliasButton.OnClick := ApplyPathAntiAlias;
  FPathStartMarkerCombo := TVectArtLineMarkerCombo.Create(Self);
  FPathStartMarkerCombo.Parent := Self;
  FPathStartMarkerCombo.Style := csOwnerDrawFixed;
  FPathStartMarkerCombo.ItemHeight := 19;
  FPathStartMarkerCombo.DropDownCount := 10;
  FPathStartMarkerCombo.Color := COLOR_EDIT;
  FPathStartMarkerCombo.Font.Color := COLOR_TEXT;
  FPathStartMarkerCombo.OnChange := ApplyPathStartMarker;
  FPathStartMarkerSizeEdit := NewDarkEdit;
  FPathEndMarkerCombo := TVectArtLineMarkerCombo.Create(Self);
  FPathEndMarkerCombo.Parent := Self;
  FPathEndMarkerCombo.Style := csOwnerDrawFixed;
  FPathEndMarkerCombo.ItemHeight := 19;
  FPathEndMarkerCombo.DropDownCount := 10;
  FPathEndMarkerCombo.Color := COLOR_EDIT;
  FPathEndMarkerCombo.Font.Color := COLOR_TEXT;
  FPathEndMarkerCombo.OnChange := ApplyPathEndMarker;
  FPathEndMarkerSizeEdit := NewDarkEdit;
  SetEditorsEnabled(False);
  SetPathStyleControlsVisible(False);
  SetTextSpacingControlsVisible(False);
end;

procedure TVectArtObjectPropertiesControl.ApplyPathEndMarker(Sender: TObject);
var
  NewValue: TVectArtLineMarker;
  OldValue: TVectArtLineMarker;
  PathLayer: TVectArtPathLayer;
begin
  if (FDocument <> nil) and (FDocument.SelectionCount = 1) and
    (FDocument[FDocument.SelectedIndex] is TVectArtLineLayer) then
  begin
    ApplySelectedLineEndMarker(Sender);
    Exit;
  end;
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount <> 1) or SelectedLayersHaveLock or
    not (FDocument[FDocument.SelectedIndex] is TVectArtPathLayer) then
    Exit;
  PathLayer := TVectArtPathLayer(FDocument[FDocument.SelectedIndex]);
  if PathLayer.Closed then
    Exit;
  OldValue := PathLayer.EndMarker;
  NewValue := FPathEndMarkerCombo.SelectedMarker;
  if OldValue = NewValue then
    Exit;
  FDocument.SetPathEndMarker(FDocument.SelectedIndex, NewValue);
  if FEditHistory <> nil then
    FEditHistory.AddApplied(TVectArtPathEndMarkerCommand.Create(FDocument,
      FDocument.SelectedIndex, OldValue, NewValue));
  if FEditorState <> nil then
    FEditorState.PathEndMarker := NewValue;
end;

procedure TVectArtObjectPropertiesControl.ApplySelectedLineEndMarker(Sender: TObject);
var
  NewValue: TVectArtLineMarker;
  OldValue: TVectArtLineMarker;
  LineLayer: TVectArtLineLayer;
begin
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount <> 1) or SelectedLayersHaveLock or
    not (FDocument[FDocument.SelectedIndex] is TVectArtLineLayer) then
    Exit;
  LineLayer := TVectArtLineLayer(FDocument[FDocument.SelectedIndex]);
  OldValue := LineLayer.EndMarker;
  NewValue := FPathEndMarkerCombo.SelectedMarker;
  if OldValue = NewValue then
    Exit;
  FDocument.SetLineEndMarker(FDocument.SelectedIndex, NewValue);
  if FEditHistory <> nil then
    FEditHistory.AddApplied(TVectArtLineEndMarkerCommand.Create(FDocument,
      FDocument.SelectedIndex, OldValue, NewValue));
  if FEditorState <> nil then
    FEditorState.LineEndMarker := NewValue;
end;

procedure TVectArtObjectPropertiesControl.ApplyPathMarkerSize(
  StartMarker: Boolean);
var
  NewValue: Double;
  OldValue: Single;
  PathLayer: TVectArtPathLayer;
begin
  if (FDocument <> nil) and (FDocument.SelectionCount = 1) and
    (FDocument[FDocument.SelectedIndex] is TVectArtLineLayer) then
  begin
    ApplySelectedLineMarkerSize(StartMarker);
    Exit;
  end;
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount <> 1) or SelectedLayersHaveLock or
    not (FDocument[FDocument.SelectedIndex] is TVectArtPathLayer) then
    Exit;
  PathLayer := TVectArtPathLayer(FDocument[FDocument.SelectedIndex]);
  if PathLayer.Closed then
    Exit;
  if StartMarker then
  begin
    if not TryStrToFloat(Trim(FPathStartMarkerSizeEdit.Text), NewValue) then
    begin
      RefreshFromDocument;
      Exit;
    end;
    OldValue := PathLayer.StartMarkerSize;
    NewValue := Max(NewValue, 1.0);
    FDocument.SetPathStartMarkerSize(FDocument.SelectedIndex, NewValue);
    if FEditorState <> nil then
      FEditorState.PathStartMarkerSize := NewValue;
  end
  else
  begin
    if not TryStrToFloat(Trim(FPathEndMarkerSizeEdit.Text), NewValue) then
    begin
      RefreshFromDocument;
      Exit;
    end;
    OldValue := PathLayer.EndMarkerSize;
    NewValue := Max(NewValue, 1.0);
    FDocument.SetPathEndMarkerSize(FDocument.SelectedIndex, NewValue);
    if FEditorState <> nil then
      FEditorState.PathEndMarkerSize := NewValue;
  end;
  if (FEditHistory <> nil) and not SameValue(OldValue, NewValue) then
    FEditHistory.AddApplied(TVectArtPathMarkerSizeCommand.Create(FDocument,
      FDocument.SelectedIndex, StartMarker, OldValue, NewValue));
end;

procedure TVectArtObjectPropertiesControl.ApplySelectedLineMarkerSize(
  StartMarker: Boolean);
var
  NewValue: Double;
  OldValue: Single;
  LineLayer: TVectArtLineLayer;
begin
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount <> 1) or SelectedLayersHaveLock or
    not (FDocument[FDocument.SelectedIndex] is TVectArtLineLayer) then
    Exit;
  LineLayer := TVectArtLineLayer(FDocument[FDocument.SelectedIndex]);
  if StartMarker then
  begin
    if not TryStrToFloat(Trim(FPathStartMarkerSizeEdit.Text), NewValue) then
    begin
      RefreshFromDocument;
      Exit;
    end;
    OldValue := LineLayer.StartMarkerSize;
    NewValue := Max(NewValue, 1.0);
    FDocument.SetLineStartMarkerSize(FDocument.SelectedIndex, NewValue);
    if FEditorState <> nil then
      FEditorState.LineStartMarkerSize := NewValue;
  end
  else
  begin
    if not TryStrToFloat(Trim(FPathEndMarkerSizeEdit.Text), NewValue) then
    begin
      RefreshFromDocument;
      Exit;
    end;
    OldValue := LineLayer.EndMarkerSize;
    NewValue := Max(NewValue, 1.0);
    FDocument.SetLineEndMarkerSize(FDocument.SelectedIndex, NewValue);
    if FEditorState <> nil then
      FEditorState.LineEndMarkerSize := NewValue;
  end;
  if (FEditHistory <> nil) and not SameValue(OldValue, NewValue) then
    FEditHistory.AddApplied(TVectArtLineMarkerSizeCommand.Create(FDocument,
      FDocument.SelectedIndex, StartMarker, OldValue, NewValue));
end;

procedure TVectArtObjectPropertiesControl.ApplyPathStartMarker(
  Sender: TObject);
var
  NewValue: TVectArtLineMarker;
  OldValue: TVectArtLineMarker;
  PathLayer: TVectArtPathLayer;
begin
  if (FDocument <> nil) and (FDocument.SelectionCount = 1) and
    (FDocument[FDocument.SelectedIndex] is TVectArtLineLayer) then
  begin
    ApplySelectedLineStartMarker(Sender);
    Exit;
  end;
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount <> 1) or SelectedLayersHaveLock or
    not (FDocument[FDocument.SelectedIndex] is TVectArtPathLayer) then
    Exit;
  PathLayer := TVectArtPathLayer(FDocument[FDocument.SelectedIndex]);
  if PathLayer.Closed then
    Exit;
  OldValue := PathLayer.StartMarker;
  NewValue := FPathStartMarkerCombo.SelectedMarker;
  if OldValue = NewValue then
    Exit;
  FDocument.SetPathStartMarker(FDocument.SelectedIndex, NewValue);
  if FEditHistory <> nil then
    FEditHistory.AddApplied(TVectArtPathStartMarkerCommand.Create(FDocument,
      FDocument.SelectedIndex, OldValue, NewValue));
  if FEditorState <> nil then
    FEditorState.PathStartMarker := NewValue;
end;

procedure TVectArtObjectPropertiesControl.ApplySelectedLineStartMarker(
  Sender: TObject);
var
  NewValue: TVectArtLineMarker;
  OldValue: TVectArtLineMarker;
  LineLayer: TVectArtLineLayer;
begin
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount <> 1) or SelectedLayersHaveLock or
    not (FDocument[FDocument.SelectedIndex] is TVectArtLineLayer) then
    Exit;
  LineLayer := TVectArtLineLayer(FDocument[FDocument.SelectedIndex]);
  OldValue := LineLayer.StartMarker;
  NewValue := FPathStartMarkerCombo.SelectedMarker;
  if OldValue = NewValue then
    Exit;
  FDocument.SetLineStartMarker(FDocument.SelectedIndex, NewValue);
  if FEditHistory <> nil then
    FEditHistory.AddApplied(TVectArtLineStartMarkerCommand.Create(FDocument,
      FDocument.SelectedIndex, OldValue, NewValue));
  if FEditorState <> nil then
    FEditorState.LineStartMarker := NewValue;
end;

procedure TVectArtObjectPropertiesControl.ApplyPathAntiAlias(
  Sender: TObject);
var
  NewValue: Boolean;
  OldValue: Boolean;
  PathLayer: TVectArtPathLayer;
begin
  if (FDocument <> nil) and (FDocument.SelectionCount = 1) and
    (FDocument[FDocument.SelectedIndex] is TVectArtLineLayer) then
  begin
    ApplySelectedLineAntiAlias(Sender);
    Exit;
  end;
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount <> 1) or SelectedLayersHaveLock or
    not (FDocument[FDocument.SelectedIndex] is TVectArtPathLayer) then
    Exit;
  PathLayer := TVectArtPathLayer(FDocument[FDocument.SelectedIndex]);
  OldValue := PathLayer.AntiAlias;
  NewValue := not OldValue;
  FDocument.SetPathAntiAlias(FDocument.SelectedIndex, NewValue);
  if FEditHistory <> nil then
    FEditHistory.AddApplied(TVectArtPathAntiAliasCommand.Create(FDocument,
      FDocument.SelectedIndex, OldValue, NewValue));
  if FEditorState <> nil then
    FEditorState.PathAntiAlias := NewValue;
end;

procedure TVectArtObjectPropertiesControl.ApplySelectedLineAntiAlias(
  Sender: TObject);
var
  NewValue: Boolean;
  OldValue: Boolean;
  LineLayer: TVectArtLineLayer;
begin
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount <> 1) or SelectedLayersHaveLock or
    not (FDocument[FDocument.SelectedIndex] is TVectArtLineLayer) then
    Exit;
  LineLayer := TVectArtLineLayer(FDocument[FDocument.SelectedIndex]);
  OldValue := LineLayer.AntiAlias;
  NewValue := not OldValue;
  FDocument.SetLineAntiAlias(FDocument.SelectedIndex, NewValue);
  if FEditHistory <> nil then
    FEditHistory.AddApplied(TVectArtLineAntiAliasCommand.Create(FDocument,
      FDocument.SelectedIndex, OldValue, NewValue));
  if FEditorState <> nil then
    FEditorState.LineAntiAlias := NewValue;
end;

procedure TVectArtObjectPropertiesControl.ApplyPathLineCap(Sender: TObject);
var
  NewValue: TVectArtLineCap;
  OldValue: TVectArtLineCap;
  PathLayer: TVectArtPathLayer;
begin
  if (FDocument <> nil) and (FDocument.SelectionCount = 1) and
    (FDocument[FDocument.SelectedIndex] is TVectArtLineLayer) then
  begin
    ApplySelectedLineCap(Sender);
    Exit;
  end;
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount <> 1) or SelectedLayersHaveLock or
    not (FDocument[FDocument.SelectedIndex] is TVectArtPathLayer) or
    not (Sender is TVectArtLineCapButton) then
    Exit;
  PathLayer := TVectArtPathLayer(FDocument[FDocument.SelectedIndex]);
  OldValue := PathLayer.LineCap;
  NewValue := TVectArtLineCapButton(Sender).LineCap;
  if OldValue = NewValue then
    Exit;
  FDocument.SetPathLineCap(FDocument.SelectedIndex, NewValue);
  if FEditHistory <> nil then
    FEditHistory.AddApplied(TVectArtPathLineCapCommand.Create(FDocument,
      FDocument.SelectedIndex, OldValue, NewValue));
  if FEditorState <> nil then
    FEditorState.PathLineCap := NewValue;
end;

procedure TVectArtObjectPropertiesControl.ApplySelectedLineCap(Sender: TObject);
var
  NewValue: TVectArtLineCap;
  OldValue: TVectArtLineCap;
  LineLayer: TVectArtLineLayer;
begin
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount <> 1) or SelectedLayersHaveLock or
    not (FDocument[FDocument.SelectedIndex] is TVectArtLineLayer) or
    not (Sender is TVectArtLineCapButton) then
    Exit;
  LineLayer := TVectArtLineLayer(FDocument[FDocument.SelectedIndex]);
  OldValue := LineLayer.LineCap;
  NewValue := TVectArtLineCapButton(Sender).LineCap;
  if OldValue = NewValue then
    Exit;
  FDocument.SetLineCap(FDocument.SelectedIndex, NewValue);
  if FEditHistory <> nil then
    FEditHistory.AddApplied(TVectArtLineCapCommand.Create(FDocument,
      FDocument.SelectedIndex, OldValue, NewValue));
  if FEditorState <> nil then
    FEditorState.LineCap := NewValue;
end;

procedure TVectArtObjectPropertiesControl.ApplyPathLineJoin(Sender: TObject);
var
  NewValue: TVectArtLineJoin;
  OldValue: TVectArtLineJoin;
  PathLayer: TVectArtPathLayer;
begin
  if (FDocument <> nil) and (FDocument.SelectionCount = 1) and
    (FDocument[FDocument.SelectedIndex] is TVectArtLineLayer) then
  begin
    ApplySelectedLineJoin(Sender);
    Exit;
  end;
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount <> 1) or SelectedLayersHaveLock or
    not (FDocument[FDocument.SelectedIndex] is TVectArtPathLayer) or
    not (Sender is TVectArtLineJoinButton) then
    Exit;
  PathLayer := TVectArtPathLayer(FDocument[FDocument.SelectedIndex]);
  OldValue := PathLayer.LineJoin;
  NewValue := TVectArtLineJoinButton(Sender).LineJoin;
  if OldValue = NewValue then
    Exit;
  FDocument.SetPathLineJoin(FDocument.SelectedIndex, NewValue);
  if FEditHistory <> nil then
    FEditHistory.AddApplied(TVectArtPathLineJoinCommand.Create(FDocument,
      FDocument.SelectedIndex, OldValue, NewValue));
  if FEditorState <> nil then
    FEditorState.PathLineJoin := NewValue;
end;

procedure TVectArtObjectPropertiesControl.ApplySelectedLineJoin(Sender: TObject);
var
  NewValue: TVectArtLineJoin;
  OldValue: TVectArtLineJoin;
  LineLayer: TVectArtLineLayer;
begin
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount <> 1) or SelectedLayersHaveLock or
    not (FDocument[FDocument.SelectedIndex] is TVectArtLineLayer) or
    not (Sender is TVectArtLineJoinButton) then
    Exit;
  LineLayer := TVectArtLineLayer(FDocument[FDocument.SelectedIndex]);
  OldValue := LineLayer.LineJoin;
  NewValue := TVectArtLineJoinButton(Sender).LineJoin;
  if OldValue = NewValue then
    Exit;
  FDocument.SetLineJoin(FDocument.SelectedIndex, NewValue);
  if FEditHistory <> nil then
    FEditHistory.AddApplied(TVectArtLineJoinCommand.Create(FDocument,
      FDocument.SelectedIndex, OldValue, NewValue));
  if FEditorState <> nil then
    FEditorState.LineJoin := NewValue;
end;

procedure TVectArtObjectPropertiesControl.ApplyStrokeColor;
var
  Blue: Integer;
  Command: TVectArtCompoundCommand;
  Green: Integer;
  I: Integer;
  LayerIndex: Integer;
  LayerIndices: TArray<Integer>;

  NewColor: TColor;
  OldColor: TColor;

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

  Command := nil;
  if FEditHistory <> nil then
    Command := TVectArtCompoundCommand.Create;
  for I := 0 to High(LayerIndices) do
  begin
    LayerIndex := LayerIndices[I];
    if FDocument[LayerIndex] is TVectArtLineLayer then
    begin

      OldColor := TVectArtLineLayer(FDocument[LayerIndex]).StrokeColor;
      FDocument.SetLineStroke(LayerIndex, NewColor,
        TVectArtLineLayer(FDocument[LayerIndex]).StrokeWidth,
        TVectArtLineLayer(FDocument[LayerIndex]).StrokeStyle);
      RectangleLayer := nil;
    end
    else if FDocument[LayerIndex] is TVectArtPathLayer then
    begin

      PathLayer := TVectArtPathLayer(FDocument[LayerIndex]);
      OldColor := PathLayer.StrokeColor;
      FDocument.SetPathStroke(LayerIndex, NewColor, PathLayer.StrokeWidth,
        PathLayer.StrokeStyle);
      RectangleLayer := nil;
    end
    else
    begin

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
  // 線を消す操作は「枠と塗り潰し」の塗りのみモードへ限定する。
  // 線幅の直接入力とスライダーは、描画可能な最小1pxを維持する。
  NewWidth := Max(NewWidth, 1.0);
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
  NewTextData: TVectArtTextData;
  OldTextData: TVectArtTextData;
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
    if FDocument[LayerIndex] is TVectArtTextLayer then
    begin
      OldTextData := CaptureVectArtTextData(
        TVectArtTextLayer(FDocument[LayerIndex]));
      NewTextData := OldTextData;
      NewTextData.TextColor := NewColor;
      FDocument.SetTextData(LayerIndex, NewTextData);
      OldColor := OldTextData.TextColor;
      if (Command <> nil) and (OldColor <> NewColor) then
        Command.Add(TVectArtTextDataCommand.Create(FDocument, LayerIndex,
          OldTextData, NewTextData));
      Continue;
    end
    else if FDocument[LayerIndex] is TVectArtPathLayer then
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
end;

procedure TVectArtObjectPropertiesControl.ApplyGeometry;
var XValue, YValue, WidthValue, HeightValue: Double;
begin
  if FUpdating then Exit;
  if not TryStrToFloat(Trim(FXEdit.Text), XValue) or
    not TryStrToFloat(Trim(FYEdit.Text), YValue) or
    not TryStrToFloat(Trim(FWidthEdit.Text), WidthValue) or
    not TryStrToFloat(Trim(FHeightEdit.Text), HeightValue) then
  begin RefreshFromDocument; Exit; end;
  ApplyVectArtSettingsGeometry(FDocument,FEditHistory,XValue,YValue,WidthValue,HeightValue);
  RefreshFromDocument;
end;

function TVectArtObjectPropertiesControl.GetSelectedFillIndices:
  TArray<Integer>;
begin
  Result := VectArtDesignerSettingsSelection.GetSelectedFillIndices(FDocument);
end;

function TVectArtObjectPropertiesControl.GetSelectedOpacityIndices:
  TArray<Integer>;
begin
  Result := VectArtDesignerSettingsSelection.GetSelectedOpacityIndices(FDocument);
end;

procedure TVectArtObjectPropertiesControl.ApplyTextSpacing;
var
  LetterPercent: Double;
  LinePercent: Double;
  NewData: TVectArtTextData;
  NewLayout: TVectArtTextLayout;
  OldData: TVectArtTextData;
  OldLayout: TVectArtTextLayout;
  ScaleX: Single;
  ScaleY: Single;
begin
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount <> 1) or SelectedLayersHaveLock or
    not (FDocument[FDocument.SelectedIndex] is TVectArtTextLayer) then
    Exit;
  if not TryStrToFloat(Trim(FLetterSpacingEdit.Text), LetterPercent) or
    not TryStrToFloat(Trim(FLineSpacingEdit.Text), LinePercent) then
  begin
    RefreshFromDocument;
    Exit;
  end;
  LetterPercent := EnsureRange(LetterPercent, -100.0, 1000.0);
  LinePercent := EnsureRange(LinePercent, -100.0, 1000.0);
  OldData := CaptureVectArtTextData(
    TVectArtTextLayer(FDocument[FDocument.SelectedIndex]));
  NewData := OldData;
  NewData.LetterSpacingRatio := LetterPercent / 100.0;
  NewData.LineSpacingRatio := LinePercent / 100.0;
  if SameValue(OldData.LetterSpacingRatio, NewData.LetterSpacingRatio) and
    SameValue(OldData.LineSpacingRatio, NewData.LineSpacingRatio) then
    Exit;
  OldLayout := BuildVectArtTextLayout(OldData.Text, OldData.FontFamily,
    OldData.FontSize, OldData.FontStyle, OldData.LetterSpacingRatio,
    OldData.LineSpacingRatio, OldData.Vertical);
  ScaleX := OldData.Bounds.Width / Max(OldLayout.Width, 1.0);
  ScaleY := OldData.Bounds.Height / Max(OldLayout.Height, 1.0);
  NewLayout := BuildVectArtTextLayout(NewData.Text, NewData.FontFamily,
    NewData.FontSize, NewData.FontStyle, NewData.LetterSpacingRatio,
    NewData.LineSpacingRatio, NewData.Vertical);
  NewData.Bounds.Right := NewData.Bounds.Left +
    Max(NewLayout.Width * ScaleX, 1.0);
  NewData.Bounds.Bottom := NewData.Bounds.Top +
    Max(NewLayout.Height * ScaleY, 1.0);
  FDocument.SetTextData(FDocument.SelectedIndex, NewData);
  if FEditHistory <> nil then
    FEditHistory.AddApplied(TVectArtTextDataCommand.Create(FDocument,
      FDocument.SelectedIndex, OldData, NewData));
end;

procedure TVectArtObjectPropertiesControl.ApplyVerticalText(Sender: TObject);
var
  NewData: TVectArtTextData;
  NewLayout: TVectArtTextLayout;
  OldData: TVectArtTextData;
  OldLayout: TVectArtTextLayout;
  ScaleX: Single;
  ScaleY: Single;
begin
  if FUpdating or (FDocument = nil) or
    (FDocument.SelectionCount <> 1) or SelectedLayersHaveLock or
    not (FDocument[FDocument.SelectedIndex] is TVectArtTextLayer) then
    Exit;
  OldData := CaptureVectArtTextData(
    TVectArtTextLayer(FDocument[FDocument.SelectedIndex]));
  if OldData.Vertical = FVerticalTextCheck.Checked then
    Exit;
  OldLayout := BuildVectArtTextLayout(OldData.Text, OldData.FontFamily,
    OldData.FontSize, OldData.FontStyle, OldData.LetterSpacingRatio,
    OldData.LineSpacingRatio, OldData.Vertical);
  ScaleX := OldData.Bounds.Width / Max(OldLayout.Width, 1.0);
  ScaleY := OldData.Bounds.Height / Max(OldLayout.Height, 1.0);
  NewData := OldData;
  NewData.Vertical := FVerticalTextCheck.Checked;
  NewLayout := BuildVectArtTextLayout(NewData.Text, NewData.FontFamily,
    NewData.FontSize, NewData.FontStyle, NewData.LetterSpacingRatio,
    NewData.LineSpacingRatio, NewData.Vertical);
  NewData.Bounds.Right := NewData.Bounds.Left +
    Max(NewLayout.Width * ScaleX, 1.0);
  NewData.Bounds.Bottom := NewData.Bounds.Top +
    Max(NewLayout.Height * ScaleY, 1.0);
  FDocument.SetTextData(FDocument.SelectedIndex, NewData);
  if FEditHistory <> nil then
    FEditHistory.AddApplied(TVectArtTextDataCommand.Create(FDocument,
      FDocument.SelectedIndex, OldData, NewData));
end;

procedure TVectArtObjectPropertiesControl.NumericSettingChanged(Sender: TObject);
begin
  if FUpdating then Exit;
  if Sender = FStrokeWidthSlider then ApplyStrokeWidth
  else if Sender = FTransparencySlider then ApplyOpacity;
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
  // モデルの不透明度は維持し、UIの透明度だけ反転して変換する。
  NewValue := 1.0 - EnsureRange(NewValue, 0.0, 100.0) / 100.0;
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

procedure TVectArtObjectPropertiesControl.PixelKeyPress(Sender: TObject; var Key: Char);
begin
  if (Sender = FXEdit) or (Sender = FYEdit) or (Sender = FWidthEdit) or
    (Sender = FHeightEdit) or (Sender = FStrokeWidthEdit) or
    (Sender = FPathStartMarkerSizeEdit) or (Sender = FPathEndMarkerSizeEdit) then
    if (Key >= #32) and not CharInSet(Key, ['0'..'9', '-']) then Key := #0;
end;

procedure TVectArtObjectPropertiesControl.EditExit(Sender: TObject);
var Bounds: TRectF; Value: Double; IntegerValue: Integer;
begin
  if ((Sender = FXEdit) or (Sender = FYEdit) or (Sender = FWidthEdit) or
    (Sender = FHeightEdit) or (Sender = FStrokeWidthEdit) or
    (Sender = FPathStartMarkerSizeEdit) or (Sender = FPathEndMarkerSizeEdit)) and
    not TryStrToInt(Trim(TEdit(Sender).Text), IntegerValue) then
  begin
    RefreshFromDocument;
    Exit;
  end;
  if (FAspectCheck <> nil) and FAspectCheck.Checked and
    ((Sender = FWidthEdit) or (Sender = FHeightEdit)) and
    (FDocument <> nil) and (FDocument.SelectionCount = 1) then
  begin
    if FDocument[FDocument.SelectedIndex] is TVectArtRectangleLayer then
      Bounds := TVectArtRectangleLayer(FDocument[FDocument.SelectedIndex]).Bounds
    else if FDocument[FDocument.SelectedIndex] is TVectArtTextLayer then
      Bounds := TVectArtTextLayer(FDocument[FDocument.SelectedIndex]).Bounds
    else
      Bounds := TRectF.Empty;
    if (Bounds.Width > 0) and (Bounds.Height > 0) and TryStrToFloat(TEdit(Sender).Text, Value) then
      if Sender = FWidthEdit then FHeightEdit.Text := FormatFloat('0', Value * Bounds.Height / Bounds.Width)
      else FWidthEdit.Text := FormatFloat('0', Value * Bounds.Width / Bounds.Height);
  end;
  if Sender = FPathStartMarkerSizeEdit then
    ApplyPathMarkerSize(True)
  else if Sender = FPathEndMarkerSizeEdit then
    ApplyPathMarkerSize(False)
  else if Sender = FColorEdit then
    ApplyColor
  else if Sender = FStrokeColorEdit then
    ApplyStrokeColor
  else if Sender = FStrokeWidthEdit then
    ApplyStrokeWidth
  else if Sender = FOpacityEdit then
    ApplyOpacity
  else if (Sender = FLetterSpacingEdit) or
    (Sender = FLineSpacingEdit) then
    ApplyTextSpacing
  else
    ApplyGeometry;
end;

function TVectArtObjectPropertiesControl.NewDarkCombo:
  TVectArtStrokeStyleCombo;
begin
  Result := TVectArtStrokeStyleCombo.Create(Self);
  Result.Parent := Self;
  Result.Style := csOwnerDrawFixed;
  Result.ItemHeight := 19;
  Result.DropDownCount := 9;
  Result.Color := COLOR_EDIT;
  Result.Font.Name := VECTART_SETTINGS_FONT_NAME;
  Result.Font.Height := VECTART_SETTINGS_FONT_HEIGHT;
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
  Result.Font.Name := VECTART_SETTINGS_FONT_NAME;
  Result.Font.Height := VECTART_SETTINGS_FONT_HEIGHT;
  Result.Font.Color := COLOR_TEXT;
  Result.ParentColor := False;
  Result.ParentFont := False;
  Result.OnExit := EditExit;
  Result.OnKeyPress := PixelKeyPress;
  Result.OnKeyDown := EditKeyDown;
end;

function TVectArtObjectPropertiesControl.GetSelectedRectangleIndices:
  TArray<Integer>;
begin
  Result := VectArtDesignerSettingsSelection.GetSelectedRectangleIndices(FDocument);
end;

function TVectArtObjectPropertiesControl.GetSelectedStrokeIndices:
  TArray<Integer>;
begin
  Result := VectArtDesignerSettingsSelection.GetSelectedStrokeIndices(FDocument);
end;

function TVectArtObjectPropertiesControl.SelectedLayersHaveLock: Boolean;
begin
  Result := VectArtDesignerSettingsSelection.SelectedLayersHaveLock(FDocument);
end;

procedure TVectArtObjectPropertiesControl.CreateWnd;
begin
  inherited;
  if FSections = nil then
  begin
    BuildSettingsUI;
    RefreshFromDocument;
  end;
end;

procedure TVectArtObjectPropertiesControl.SetParent(AParent: TWinControl);
begin
  inherited;
  if (AParent <> nil) and (GetParentForm(Self) <> nil) and (FSections = nil) then BuildSettingsUI;
end;

procedure TVectArtObjectPropertiesControl.Paint;
var Title: string;
begin
  Canvas.Brush.Color := COLOR_BACKGROUND;
  Canvas.FillRect(Rect(0,0,ClientWidth,Min(34,ClientHeight)));
  Canvas.Font.Color := COLOR_TEXT;
  if (FDocument = nil) or (FDocument.SelectionCount = 0) then Title := 'オブジェクトを選択'
  else if FDocument.SelectionCount = 1 then Title := FDocument[FDocument.SelectedIndex].Name
  else Title := Format('%d 個のオブジェクト', [FDocument.SelectionCount]);
  Canvas.TextRect(Rect(12, 0, ClientWidth - 12, 32), 12, 10, Title);
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
  TextLayer: TVectArtTextLayer;
  SliderValue: Double;
begin
  if FBuildingSettings then Exit;
  FUpdating := True;
  try
    SetPathStyleControlsVisible(False);
    SetTextSpacingControlsVisible(False);
    if (FDocument <> nil) and (FDocument.SelectionCount = 1) and
      (FDocument[FDocument.SelectedIndex] is TVectArtRectangleLayer) then
    begin
      RectangleLayer := TVectArtRectangleLayer(
        FDocument[FDocument.SelectedIndex]);
      Bounds := RectangleLayer.Bounds;
      FXEdit.Text := FormatFloat('0', Bounds.Left);
      FYEdit.Text := FormatFloat('0', Bounds.Top);
      FWidthEdit.Text := FormatFloat('0', Bounds.Width);
      FHeightEdit.Text := FormatFloat('0', Bounds.Height);
      ColorValue := ColorToRGB(RectangleLayer.FillColor);
      FColorEdit.Text := Format('#%.2x%.2x%.2x', [GetRValue(ColorValue),
        GetGValue(ColorValue), GetBValue(ColorValue)]);
      FOpacityEdit.Text := FormatFloat('0.##', (1 - RectangleLayer.Opacity) * 100);
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
      (FDocument[FDocument.SelectedIndex] is TVectArtTextLayer) then
    begin
      TextLayer := TVectArtTextLayer(FDocument[FDocument.SelectedIndex]);
      Bounds := TextLayer.Bounds;
      FXEdit.Text := FormatFloat('0', Bounds.Left);
      FYEdit.Text := FormatFloat('0', Bounds.Top);
      FWidthEdit.Text := FormatFloat('0', Bounds.Width);
      FHeightEdit.Text := FormatFloat('0', Bounds.Height);
      ColorValue := ColorToRGB(TextLayer.TextColor);
      FColorEdit.Text := Format('#%.2x%.2x%.2x', [GetRValue(ColorValue),
        GetGValue(ColorValue), GetBValue(ColorValue)]);
      FOpacityEdit.Text := FormatFloat('0.##', (1 - TextLayer.Opacity) * 100);
      ClearEditValue(FStrokeColorEdit);
      ClearEditValue(FStrokeWidthEdit);
      FStrokeStyleCombo.SetPendingItemIndex(-1);
      SetEditorsEnabled(True);
      FStrokeColorEdit.Enabled := False;
      FStrokeWidthEdit.Enabled := False;
      FStrokeStyleCombo.Enabled := False;
      FLetterSpacingEdit.Text := FormatFloat('0.##',
        TextLayer.LetterSpacingRatio * 100);
      FLineSpacingEdit.Text := FormatFloat('0.##',
        TextLayer.LineSpacingRatio * 100);
      FVerticalTextCheck.Checked := TextLayer.Vertical;
      SetTextSpacingControlsVisible(True);
      if TextLayer.Locked then
      begin
        FXEdit.Enabled := False;
        FYEdit.Enabled := False;
        FWidthEdit.Enabled := False;
        FHeightEdit.Enabled := False;
        FColorEdit.Enabled := False;
        FOpacityEdit.Enabled := False;
        FLetterSpacingEdit.Enabled := False;
        FLineSpacingEdit.Enabled := False;
        FVerticalTextCheck.Enabled := False;
      end;
    end
    else if (FDocument <> nil) and (FDocument.SelectionCount = 1) and
      (FDocument[FDocument.SelectedIndex] is TVectArtImageLayer) then
    begin
      ImageLayer := TVectArtImageLayer(FDocument[FDocument.SelectedIndex]);
      FXEdit.Text := FormatFloat('0', ImageLayer.Points[0].X);
      FYEdit.Text := FormatFloat('0', ImageLayer.Points[0].Y);
      FWidthEdit.Text := FormatFloat('0', Hypot(
        ImageLayer.Points[1].X - ImageLayer.Points[0].X,
        ImageLayer.Points[1].Y - ImageLayer.Points[0].Y));
      FHeightEdit.Text := FormatFloat('0', Hypot(
        ImageLayer.Points[3].X - ImageLayer.Points[0].X,
        ImageLayer.Points[3].Y - ImageLayer.Points[0].Y));
      ClearEditValue(FColorEdit);
      ClearEditValue(FStrokeColorEdit);
      ClearEditValue(FStrokeWidthEdit);
      FStrokeStyleCombo.SetPendingItemIndex(-1);
      FOpacityEdit.Text := FormatFloat('0.##', (1 - ImageLayer.Opacity) * 100);
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
      Bounds := PointsBounds(BuildPathDisplayPolyline(PathLayer.Points,
        PathLayer.Bezier, PathLayer.Closed, 16));
      FXEdit.Text := FormatFloat('0', Bounds.Left);
      FYEdit.Text := FormatFloat('0', Bounds.Top);
      FWidthEdit.Text := FormatFloat('0', Bounds.Width);
      FHeightEdit.Text := FormatFloat('0', Bounds.Height);
      ColorValue := ColorToRGB(PathLayer.FillColor);
      FColorEdit.Text := Format('#%.2x%.2x%.2x', [GetRValue(ColorValue),
        GetGValue(ColorValue), GetBValue(ColorValue)]);
      FOpacityEdit.Text := FormatFloat('0.##', (1 - PathLayer.Opacity) * 100);
      StrokeColorValue := ColorToRGB(PathLayer.StrokeColor);
      FStrokeColorEdit.Text := Format('#%.2x%.2x%.2x',
        [GetRValue(StrokeColorValue), GetGValue(StrokeColorValue),
         GetBValue(StrokeColorValue)]);
      FStrokeWidthEdit.Text := FormatFloat('0.##', PathLayer.StrokeWidth);
      FStrokeStyleCombo.SetPendingItemIndex(Ord(PathLayer.StrokeStyle));
      SetPathStyleControlsVisible(True);
      FPathLineCapButtons[vlcButt].Selected := PathLayer.LineCap = vlcButt;
      FPathLineCapButtons[vlcSquare].Selected := PathLayer.LineCap = vlcSquare;
      FPathLineCapButtons[vlcRound].Selected := PathLayer.LineCap = vlcRound;
      FPathLineJoinButtons[vljMiter].Selected := PathLayer.LineJoin = vljMiter;
      FPathLineJoinButtons[vljBevel].Selected := PathLayer.LineJoin = vljBevel;
      FPathLineJoinButtons[vljRound].Selected := PathLayer.LineJoin = vljRound;
      FPathAntiAliasButton.Selected := PathLayer.AntiAlias;
      FPathStartMarkerCombo.SetPendingMarker(PathLayer.StartMarker, True);
      FPathStartMarkerSizeEdit.Text := FormatFloat('0',
        PathLayer.StartMarkerSize);
      FPathEndMarkerCombo.SetPendingMarker(PathLayer.EndMarker, True);
      FPathEndMarkerSizeEdit.Text := FormatFloat('0',
        PathLayer.EndMarkerSize);
      SetEditorsEnabled(True);
      FPathStartMarkerCombo.Enabled := not PathLayer.Closed;
      FPathEndMarkerCombo.Enabled := not PathLayer.Closed;
      FPathStartMarkerSizeEdit.Enabled := not PathLayer.Closed and
        (PathLayer.StartMarker <> vlmNone);
      FPathEndMarkerSizeEdit.Enabled := not PathLayer.Closed and
        (PathLayer.EndMarker <> vlmNone);
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
        FPathLineCapButtons[vlcButt].Enabled := False;
        FPathLineCapButtons[vlcSquare].Enabled := False;
        FPathLineCapButtons[vlcRound].Enabled := False;
        FPathLineJoinButtons[vljMiter].Enabled := False;
        FPathLineJoinButtons[vljBevel].Enabled := False;
        FPathLineJoinButtons[vljRound].Enabled := False;
        FPathAntiAliasButton.Enabled := False;
        FPathStartMarkerCombo.Enabled := False;
        FPathStartMarkerSizeEdit.Enabled := False;
        FPathEndMarkerCombo.Enabled := False;
        FPathEndMarkerSizeEdit.Enabled := False;
      end;
    end
    else if (FDocument <> nil) and (FDocument.SelectionCount = 1) and
      (FDocument[FDocument.SelectedIndex] is TVectArtLineLayer) then
    begin
      LineLayer := TVectArtLineLayer(FDocument[FDocument.SelectedIndex]);
      FXEdit.Text := FormatFloat('0', LineLayer.StartPoint.X);
      FYEdit.Text := FormatFloat('0', LineLayer.StartPoint.Y);
      FWidthEdit.Text := FormatFloat('0', LineLayer.EndPoint.X);
      FHeightEdit.Text := FormatFloat('0', LineLayer.EndPoint.Y);
      ClearEditValue(FColorEdit);
      FOpacityEdit.Text := FormatFloat('0.##', (1 - LineLayer.Opacity) * 100);
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
      SetPathStyleControlsVisible(True);
      FPathLineCapButtons[vlcButt].Selected := LineLayer.LineCap = vlcButt;
      FPathLineCapButtons[vlcSquare].Selected := LineLayer.LineCap = vlcSquare;
      FPathLineCapButtons[vlcRound].Selected := LineLayer.LineCap = vlcRound;
      FPathLineJoinButtons[vljMiter].Selected := LineLayer.LineJoin = vljMiter;
      FPathLineJoinButtons[vljBevel].Selected := LineLayer.LineJoin = vljBevel;
      FPathLineJoinButtons[vljRound].Selected := LineLayer.LineJoin = vljRound;
      FPathAntiAliasButton.Selected := LineLayer.AntiAlias;
      FPathStartMarkerCombo.SetPendingMarker(LineLayer.StartMarker, True);
      FPathEndMarkerCombo.SetPendingMarker(LineLayer.EndMarker, True);
      FPathStartMarkerSizeEdit.Text := FormatFloat('0', LineLayer.StartMarkerSize);
      FPathEndMarkerSizeEdit.Text := FormatFloat('0', LineLayer.EndMarkerSize);
      FPathStartMarkerSizeEdit.Enabled := not LineLayer.Locked and (LineLayer.StartMarker <> vlmNone);
      FPathEndMarkerSizeEdit.Enabled := not LineLayer.Locked and (LineLayer.EndMarker <> vlmNone);
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
      FXEdit.Text := FormatFloat('0', Bounds.Left);
      FYEdit.Text := FormatFloat('0', Bounds.Top);
      FWidthEdit.Text := FormatFloat('0', Bounds.Width);
      FHeightEdit.Text := FormatFloat('0', Bounds.Height);
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
        FOpacityEdit.Text := FormatFloat('0.##', (1 - OpacityValue) * 100)
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
  // 編集欄の共通値・混在状態とロック状態をスライダーにも反映する。
  if (FStrokeWidthSlider = nil) or (FTransparencySlider = nil) then Exit;
  FStrokeWidthSlider.Enabled := FStrokeWidthEdit.Enabled;
  FTransparencySlider.Enabled := FOpacityEdit.Enabled;
  if TryStrToFloat(FStrokeWidthEdit.Text, SliderValue) then
    FStrokeWidthSlider.SetDisplay(SliderValue)
  else FStrokeWidthSlider.SetDisplay(0,True);
  if TryStrToFloat(FOpacityEdit.Text, SliderValue) then
    FTransparencySlider.SetDisplay(SliderValue)
  else FTransparencySlider.SetDisplay(0,True);
  RefreshSettingsUI;
  // 選択変更では配置が同じでも子の背景が消去されるため、入力欄とラベルも無効化する。
  // 値・有効状態の更新がすべて終わってから要求し、通常の描画処理にまとめて任せる。
  if FSections <> nil then
    for I := 0 to FSections.SectionCount - 1 do
      if (FSections.Sections[I] <> nil) and
        FSections.Sections[I].Visible and
        FSections.Sections[I].HandleAllocated then
        RedrawWindow(FSections.Sections[I].Handle, nil, 0,
          RDW_INVALIDATE or RDW_ERASE or RDW_ALLCHILDREN);
  Invalidate;
end;

function TVectArtObjectPropertiesControl.SelectedBounds(
  out Bounds: TRectF): Boolean;
begin
  Result := VectArtDesignerSettingsSelection.SelectedBounds(FDocument, Bounds);
end;

procedure TVectArtObjectPropertiesControl.Resize;
begin
  inherited;
  if FSections <> nil then
  begin
    FSections.SetBounds(0, 34, ClientWidth, Max(0, ClientHeight - 34));
    LayoutSettings(nil);
  end;
end;
procedure TVectArtObjectPropertiesControl.SetDocument(
  const Value: TVectArtDocument);
begin
  if FDocument = Value then
    Exit;
  CloseVectArtColorPopup(Self);
  FPopupSelection := nil;
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

procedure TVectArtObjectPropertiesControl.SetPathStyleControlsVisible(
  Value: Boolean);
var
  LineCap: TVectArtLineCap;
  LineJoin: TVectArtLineJoin;
begin
  for LineCap := Low(TVectArtLineCap) to High(TVectArtLineCap) do
  begin
    FPathLineCapButtons[LineCap].Visible := Value;
    FPathLineCapButtons[LineCap].Enabled := Value;
  end;
  for LineJoin := Low(TVectArtLineJoin) to High(TVectArtLineJoin) do
  begin
    FPathLineJoinButtons[LineJoin].Visible := Value;
    FPathLineJoinButtons[LineJoin].Enabled := Value;
  end;
  FPathAntiAliasButton.Visible := Value;
  FPathAntiAliasButton.Enabled := Value;
  FPathStartMarkerCombo.Visible := Value;
  FPathStartMarkerCombo.Enabled := Value;
  FPathStartMarkerSizeEdit.Visible := Value;
  FPathStartMarkerSizeEdit.Enabled := Value;
  FPathEndMarkerCombo.Visible := Value;
  FPathEndMarkerCombo.Enabled := Value;
  FPathEndMarkerSizeEdit.Visible := Value;
  FPathEndMarkerSizeEdit.Enabled := Value;
end;

procedure TVectArtObjectPropertiesControl.SetTextSpacingControlsVisible(
  Value: Boolean);
begin
  FLetterSpacingEdit.Visible := Value;
  FLetterSpacingEdit.Enabled := Value;
  FLineSpacingEdit.Visible := Value;
  FLineSpacingEdit.Enabled := Value;
  FVerticalTextCheck.Visible := Value;
  FVerticalTextCheck.Enabled := Value;
end;

{$I VectArtDesignerObjectSettingsUI.inc}

end.
