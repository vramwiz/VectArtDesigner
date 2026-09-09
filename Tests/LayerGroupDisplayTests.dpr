program LayerGroupDisplayTests;

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
  VectArtDesignerEditCommands in
    'Source\Core\Commands\VectArtDesignerEditCommands.pas',
  VectArtDesignerEditHistory in
    'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerBezierGeometry in
    'Source\Editor\Geometry\VectArtDesignerBezierGeometry.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerTextGeometry in
    'Source\Core\VectArtDesignerTextGeometry.pas',
  VectArtDesignerLayerFlipOperations in
    'Source\Core\Commands\Transform\VectArtDesignerLayerFlipOperations.pas',
  VectArtDesignerLayerGroupOperations in
    'Source\Core\Commands\Structure\VectArtDesignerLayerGroupOperations.pas',
  VectArtDesignerLayerRotationOperations in
    'Source\Core\Commands\Transform\VectArtDesignerLayerRotationOperations.pas',
  VectArtDesignerLayerVisibilityOperations in
    'Source\Core\Commands\Structure\VectArtDesignerLayerVisibilityOperations.pas',
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
    procedure ClickExpand(RowIndex: Integer);
    procedure DoubleClickRow(RowIndex: Integer);
    procedure ClickLock(RowIndex: Integer);
    procedure ClickVisibility(RowIndex: Integer);
    procedure ClickAt(Y: Integer);
    function FindScrollBar: TVerticalScrollBarControl;
    procedure Wheel(WheelDelta: Integer);
  end;

const
  LAYER_GAP = 6;
  LAYER_LIST_PADDING = 8;
  LAYER_ROW_HEIGHT = 82;

function RowTop(ControlHeight, RowIndex: Integer): Integer;
begin
  Result := ControlHeight - LAYER_LIST_PADDING -
    (RowIndex - 1) * (LAYER_ROW_HEIGHT + LAYER_GAP) - LAYER_ROW_HEIGHT;
end;

procedure TTestLayerList.DoubleClickRow(RowIndex: Integer);
begin
  MouseDown(mbLeft, [ssDouble], 160,
    RowTop(ClientHeight, RowIndex) + LAYER_ROW_HEIGHT div 2);
end;

procedure TTestLayerList.ClickExpand(RowIndex: Integer);
begin
  MouseDown(mbLeft, [], LAYER_LIST_PADDING + 35,
    RowTop(ClientHeight, RowIndex) + 39);
end;

procedure TTestLayerList.ClickVisibility(RowIndex: Integer);
begin
  MouseDown(mbLeft, [], LAYER_LIST_PADDING + 10,
    RowTop(ClientHeight, RowIndex) + 27);
end;

procedure TTestLayerList.ClickLock(RowIndex: Integer);
begin
  MouseDown(mbLeft, [], LAYER_LIST_PADDING + 10,
    RowTop(ClientHeight, RowIndex) + 55);
end;

procedure TTestLayerList.ClickAt(Y: Integer);
begin
  MouseDown(mbLeft, [], 160, Y);
end;

function TTestLayerList.FindScrollBar: TVerticalScrollBarControl;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to ControlCount - 1 do
    if Controls[I] is TVerticalScrollBarControl then
      Exit(TVerticalScrollBarControl(Controls[I]));
end;

procedure TTestLayerList.Wheel(WheelDelta: Integer);
begin
  DoMouseWheel([], WheelDelta, Point(0, 0));
end;

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function RectangleData(const Name: string): TVectArtRectangleData;
begin
  Result := Default(TVectArtRectangleData);
  Result.Bounds := RectF(0, 0, 20, 20);
  Result.FillColor := clWhite;
  Result.Filled := True;
  Result.Name := Name;
  Result.Opacity := 1;
  Result.Visible := True;
end;

var
  Document: TVectArtDocument;
  Form: TForm;
  FrameRect: TRect;
  GroupId: TVectArtGroupId;
  History: TVectArtEditHistory;
  LayerList: TTestLayerList;
  Renderer: TVectArtLayerRenderer;
  ScrollBar: TVerticalScrollBarControl;
begin
  Document := TVectArtDocument.Create;
  Form := TForm.CreateNew(nil);
  History := TVectArtEditHistory.Create;
  LayerList := TTestLayerList.Create(Form);
  Renderer := TVectArtLayerRenderer.Create;
  try
    Document.InsertRectangle(1, RectangleData('One'));
    Document.InsertRectangle(2, RectangleData('Two'));
    Document.InsertRectangle(3, RectangleData('Three'));
    GroupId := Document.AllocateGroupId;
    Document.SetLayerGroup(1, GroupId);
    Document.SetLayerGroup(3, GroupId);
    LayerList.SetBounds(0, 0, 320, 500);
    LayerList.Parent := Form;
    LayerList.Enabled := False;
    LayerList.Document := Document;
    LayerList.EditHistory := History;

    Require(LayerList.VisibleRowCount = 2,
      'Collapsed group did not occupy one row');
    Require(not LayerList.IsGroupExpanded(GroupId),
      'Group started expanded');
    LayerList.ClickExpand(1);
    Require(LayerList.IsGroupExpanded(GroupId) and
      (LayerList.VisibleRowCount = 4),
      'Plus button did not expand group');
    LayerList.ClickExpand(3);
    Require(not LayerList.IsGroupExpanded(GroupId) and
      (LayerList.VisibleRowCount = 2),
      'Minus button did not collapse group');
    LayerList.DoubleClickRow(1);
    Require(LayerList.IsGroupExpanded(GroupId),
      'Double-click did not expand group');
    Require(LayerList.VisibleRowCount = 4,
      'Expanded group did not show its two members');
    Renderer.Document := Document;
    Renderer.ToggleGroupExpanded(GroupId);
    Require(Renderer.EntryAt(1).IsGroupMember and
      Renderer.EntryAt(2).IsGroupMember and
      Renderer.EntryAt(3).IsGroupHeader,
      'Group members were not expanded below the group header');
    FrameRect := Renderer.ExpandedGroupFrameRect(Rect(0, 0, 320, 500),
      GroupId);
    Require(not FrameRect.IsEmpty and
      (FrameRect.Height > LAYER_ROW_HEIGHT * 3),
      'Expanded group range does not surround header and members');
    LayerList.DoubleClickRow(3);
    Require(not LayerList.IsGroupExpanded(GroupId),
      'Second double-click did not collapse group');
    Require(LayerList.VisibleRowCount = 2,
      'Collapsed group retained member rows');

    LayerList.ClickVisibility(1);
    Require(not Document[1].Visible and not Document[3].Visible,
      'Group-row visibility did not affect every member');
    History.Undo;
    Require(Document[1].Visible and Document[3].Visible,
      'Group-row visibility undo failed');
    LayerList.ClickLock(1);
    Require(Document[1].Locked and Document[3].Locked,
      'Group-row lock did not affect every member');
    History.Undo;
    Require(not Document[1].Locked and not Document[3].Locked,
      'Group-row lock undo failed');
    Document.InsertRectangle(4, RectangleData('Four'));
    Document.InsertRectangle(5, RectangleData('Five'));
    Document.InsertRectangle(6, RectangleData('Six'));
    Document.InsertRectangle(7, RectangleData('Seven'));
    LayerList.SetBounds(0, 0, 320, 180);
    LayerList.Wheel(240);
    ScrollBar := LayerList.FindScrollBar;
    Require((ScrollBar <> nil) and ScrollBar.Visible and
      (ScrollBar.Maximum > 0),
      'Overflowing layer rows did not show the custom scroll bar');
    Require(ScrollBar.Position = 0,
      'Mouse wheel did not scroll to the upper end of the layer list');
    LayerList.ClickAt(49);
    Require(Document.SelectedIndex = 7,
      'Scrolled row hit testing did not follow the visible layer');
    Writeln('PASS collapsed/expanded flat-group layer rows');
  finally
    Renderer.Free;
    LayerList.Free;
    History.Free;
    Form.Free;
    Document.Free;
  end;
end.
