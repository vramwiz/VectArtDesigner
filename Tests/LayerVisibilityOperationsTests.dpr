// Selection visibility toggle and undo/redo coverage.
program LayerVisibilityOperationsTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerBezierGeometry in 'Source\Editor\Geometry\VectArtDesignerBezierGeometry.pas',
  VectArtDesignerEditHistory in 'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerEditCommands in 'Source\Core\Commands\VectArtDesignerEditCommands.pas',
  VectArtDesignerLayerFlipOperations in 'Source\Core\Commands\VectArtDesignerLayerFlipOperations.pas',
  VectArtDesignerLayerRotationOperations in 'Source\Core\Commands\VectArtDesignerLayerRotationOperations.pas',
  VectArtDesignerLayerVisibilityOperations in 'Source\Core\Commands\VectArtDesignerLayerVisibilityOperations.pas',
  VectArtDesignerObjectContextMenu in 'Source\Editor\Menus\VectArtDesignerObjectContextMenu.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function RectangleData(const Name: string; Visible: Boolean):
  TVectArtRectangleData;
begin
  Result := Default(TVectArtRectangleData);
  Result.Bounds := RectF(10, 10, 30, 30);
  Result.FillColor := clWhite;
  Result.Filled := True;
  Result.Name := Name;
  Result.Opacity := 1;
  Result.Shape := vpsRectangle;
  Result.StrokeColor := clBlack;
  Result.StrokeStyle := vssSolid;
  Result.StrokeWidth := 1;
  Result.Visible := Visible;
end;

procedure Run;
var
  Document: TVectArtDocument;
  History: TVectArtEditHistory;
  Menu: TVectArtObjectContextMenu;
begin
  Document := TVectArtDocument.Create;
  History := TVectArtEditHistory.Create;
  Menu := TVectArtObjectContextMenu.Create(nil);
  try
    Document.InsertRectangle(Document.LayerCount,
      RectangleData('Visible', True));
    Document.InsertRectangle(Document.LayerCount,
      RectangleData('Hidden', False));
    Document.SetSelectedLayers([1, 2]);
    Require(not IsVectArtSelectionHidden(Document),
      'mixed selection should not be checked');

    ToggleVectArtSelectionHidden(Document, History);
    Require(not Document[1].Visible and not Document[2].Visible,
      'selected layers were not hidden together');
    Require(IsVectArtSelectionHidden(Document),
      'hidden selection should be checked');
    Require(History.CanUndo, 'visibility toggle was not added to history');

    History.Undo;
    Require(Document[1].Visible and not Document[2].Visible,
      'visibility undo did not restore mixed values');
    History.Redo;
    Require(not Document[1].Visible and not Document[2].Visible,
      'visibility redo failed');

    Menu.Document := Document;
    Menu.EditHistory := History;
    Menu.RefreshState;
    Require((Menu.Items.Count = 3) and
      (Menu.Items[0].Caption = '非表示(&H)') and Menu.Items[0].Checked,
      'shared context menu did not show the hidden check');
    Menu.Items[0].Click;
    Require(Document[1].Visible and Document[2].Visible,
      'shared context menu did not show the selection');
  finally
    Menu.Free;
    History.Free;
    Document.Free;
  end;
end;

begin
  try
    Run;
    Writeln('LayerVisibilityOperationsTests: OK');
  except
    on E: Exception do
    begin
      Writeln('LayerVisibilityOperationsTests: FAILED: ', E.Message);
      Halt(1);
    end;
  end;
end.
