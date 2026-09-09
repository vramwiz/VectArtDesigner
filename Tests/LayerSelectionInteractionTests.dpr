program LayerSelectionInteractionTests;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,
  TextRendererSkiaBootstrap in
    'Lib\TextRenderer\TextRendererSkiaBootstrap.pas',
  TextRendererSkiaRuntime in
    'Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  VerticalScrollBarControl in
    'Lib\VerticalScrollBar\VerticalScrollBarControl.pas',
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerTextGeometry in
    'Source\Core\VectArtDesignerTextGeometry.pas',
  VectArtDesignerBezierGeometry in
    'Source\Editor\Geometry\VectArtDesignerBezierGeometry.pas',
  VectArtDesignerSelectionGeometry in
    'Source\Editor\Geometry\VectArtDesignerSelectionGeometry.pas',
  VectArtDesignerCanvasInteraction in
    'Source\Editor\VectArtDesignerCanvasInteraction.pas',
  VectArtDesignerSelectionOverlay in
    'Source\Editor\Rendering\VectArtDesignerSelectionOverlay.pas',
  VectArtDesignerEditCommands in
    'Source\Core\Commands\VectArtDesignerEditCommands.pas',
  VectArtDesignerEditHistory in
    'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerLayerFlipOperations in
    'Source\Core\Commands\Transform\VectArtDesignerLayerFlipOperations.pas',
  VectArtDesignerLayerRotationOperations in
    'Source\Core\Commands\Transform\VectArtDesignerLayerRotationOperations.pas',
  VectArtDesignerLayerVisibilityOperations in
    'Source\Core\Commands\Structure\VectArtDesignerLayerVisibilityOperations.pas',
  VectArtDesignerLayerGroupOperations in
    'Source\Core\Commands\Structure\VectArtDesignerLayerGroupOperations.pas',
  VectArtDesignerObjectContextMenu in
    'Source\Editor\Menus\VectArtDesignerObjectContextMenu.pas',
  VectArtDesignerLayerRenderer in
    'Source\Layers\VectArtDesignerLayerRenderer.pas',
  VectArtDesignerLayerList in
    'Source\Layers\VectArtDesignerLayerList.pas',
  VectArtDesignerRenderer in
    'Source\Rendering\VectArtDesignerRenderer.pas';

type
  TTestLayerList = class(TVectArtLayerListControl)
  public
    procedure ClickLayer(Index: Integer; Shift: TShiftState);
    function PrepareRightClick(Index: Integer): Boolean;
  end;

procedure TTestLayerList.ClickLayer(Index: Integer; Shift: TShiftState);
const
  LAYER_GAP = 6;
  LAYER_LIST_PADDING = 8;
  LAYER_ROW_HEIGHT = 82;
var
  ItemBottom: Integer;
begin
  ItemBottom := ClientHeight - LAYER_LIST_PADDING -
    (Index - 1) * (LAYER_ROW_HEIGHT + LAYER_GAP);
  MouseDown(mbLeft, Shift, 150, ItemBottom - LAYER_ROW_HEIGHT div 2);
end;

function TTestLayerList.PrepareRightClick(Index: Integer): Boolean;
begin
  Result := PrepareObjectContextSelection(Index);
end;

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function RectangleData(const Name: string): TVectArtRectangleData;
begin
  Result.Bounds := TRectF.Create(0, 0, 20, 20);
  Result.FillColor := clWhite;
  Result.Filled := True;
  Result.Locked := False;
  Result.Name := Name;
  Result.Opacity := 1.0;
  Result.RotationDegrees := 0.0;
  Result.StrokeColor := clBlack;
  Result.StrokeStyle := vssSolid;
  Result.StrokeWidth := 0.0;
  Result.Visible := True;
end;

var
  Document: TVectArtDocument;
  Form: TForm;
  Geometry: TVectArtSelectionGeometry;
  HandlePoint: TPoint;
  Interaction: TVectArtCanvasInteraction;
  LayerList: TTestLayerList;
  ScreenQuad: TVectArtScreenQuad;
  SelectionOverlay: TVectArtSelectionOverlay;
begin
  Document := TVectArtDocument.Create;
  Form := TForm.CreateNew(nil);
  Interaction := TVectArtCanvasInteraction.Create;
  LayerList := TTestLayerList.Create(Form);
  try
    Document.InsertRectangle(1, RectangleData('One'));
    Document.InsertRectangle(2, RectangleData('Two'));
    Document.InsertRectangle(3, RectangleData('Three'));
    LayerList.SetBounds(0, 0, 320, 400);
    LayerList.Parent := Form;
    // テストでは非表示フォームへフォーカスを移さず、選択分岐だけを呼ぶ。
    LayerList.Enabled := False;
    LayerList.Document := Document;

    LayerList.ClickLayer(1, []);
    Require((Document.SelectionCount = 1) and
      Document.IsLayerSelected(1), 'Plain click did not select one layer');
    LayerList.ClickLayer(3, [ssCtrl]);
    Require((Document.SelectionCount = 2) and
      Document.IsLayerSelected(1) and Document.IsLayerSelected(3),
      'Ctrl-click did not add a layer');
    LayerList.ClickLayer(2, [ssShift]);
    Require((Document.SelectionCount = 2) and
      Document.IsLayerSelected(2) and Document.IsLayerSelected(3),
      'Shift-click did not replace selection with anchored range');
    LayerList.ClickLayer(1, [ssCtrl, ssShift]);
    Require((Document.SelectionCount = 3) and
      Document.IsLayerSelected(1) and Document.IsLayerSelected(2) and
      Document.IsLayerSelected(3),
      'Ctrl+Shift-click did not add the anchored range');
    Require(LayerList.PrepareRightClick(2),
      'Selected layer rejected the context menu');
    Require(Document.SelectionCount = 3,
      'Right-click preparation discarded the existing multi-selection');
    Require(LayerList.PrepareRightClick(1),
      'Selected layer did not retain context-menu selection');
    Document.SetSelectedLayers([1, 2]);
    Require(LayerList.PrepareRightClick(3),
      'Unselected layer rejected the context menu');
    Require((Document.SelectionCount = 1) and
      Document.IsLayerSelected(3),
      'Right-click preparation did not select the clicked layer');
    Document.SetLayerVisible(3, False);
    Interaction.Configure(Document, Rect(100, 100, 300, 300), 1.0);
    ScreenQuad[0] := Point(100, 100);
    ScreenQuad[1] := Point(120, 100);
    ScreenQuad[2] := Point(120, 120);
    ScreenQuad[3] := Point(100, 120);
    Geometry := BuildRotatedSelectionGeometry(ScreenQuad,
      SelectionFrameOffset(0, 1.0));
    HandlePoint := Point(
      (Geometry.Handles[vshTopLeft].Left +
       Geometry.Handles[vshTopLeft].Right) div 2,
      (Geometry.Handles[vshTopLeft].Top +
       Geometry.Handles[vshTopLeft].Bottom) div 2);
    Require(Interaction.CursorAt(HandlePoint.X, HandlePoint.Y) =
      SelectionHandleCursor(vshTopLeft),
      'Hidden selected layer did not retain its selection frame');
    SelectionOverlay := BuildVectArtSelectionOverlay(Document, Interaction,
      Rect(100, 100, 300, 300), 1.0);
    Require(SelectionOverlay.Visible,
      'Hidden selected layer did not produce a canvas overlay');
    Writeln('Layer selection interaction tests: PASS');
  finally
    Interaction.Free;
    Form.Free;
    Document.Free;
  end;
end.
