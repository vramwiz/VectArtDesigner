program LayerSelectionInteractionTests;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerEditCommands in
    'Source\Core\Commands\VectArtDesignerEditCommands.pas',
  VectArtDesignerEditHistory in
    'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerLayerRenderer in
    'Source\Layers\VectArtDesignerLayerRenderer.pas',
  VectArtDesignerLayerList in
    'Source\Layers\VectArtDesignerLayerList.pas';

type
  TTestLayerList = class(TVectArtLayerListControl)
  public
    procedure ClickLayer(Index: Integer; Shift: TShiftState);
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

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function RectangleData(const Name: string): TVectArtRectangleData;
begin
  Result.Bounds := TRectF.Create(0, 0, 20, 20);
  Result.FillColor := clWhite;
  Result.Locked := False;
  Result.Name := Name;
  Result.Opacity := 1.0;
  Result.RotationDegrees := 0.0;
  Result.StrokeColor := clBlack;
  Result.MifStrokeStyle := vssSolid;
  Result.StrokeWidth := 0.0;
  Result.Visible := True;
end;

var
  Document: TVectArtDocument;
  Form: TForm;
  LayerList: TTestLayerList;
begin
  Document := TVectArtDocument.Create;
  Form := TForm.CreateNew(nil);
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
    Writeln('Layer selection interaction tests: PASS');
  finally
    Form.Free;
    Document.Free;
  end;
end.
