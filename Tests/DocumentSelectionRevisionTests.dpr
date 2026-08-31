program DocumentSelectionRevisionTests;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas';

type
  TChangeCounter = class
  public
    Count: Integer;
    procedure Changed(Sender: TObject);
  end;

procedure TChangeCounter.Changed(Sender: TObject);
begin
  Inc(Count);
end;

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function RectangleData(const Name: string): TVectArtRectangleData;
begin
  Result.Bounds := TRectF.Create(10, 10, 30, 30);
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
  Data: TVectArtRectangleData;
  Changes: TChangeCounter;
  Document: TVectArtDocument;
  Revision: Int64;
begin
  Document := TVectArtDocument.Create;
  Changes := TChangeCounter.Create;
  try
    Require(Document.EditingMode = vemStandard,
      'New document did not use standard editing mode');
    Document.OnChanged := Changes.Changed;
    Document.InsertRectangle(1, RectangleData('One'));
    Document.InsertRectangle(2, RectangleData('Two'));
    Revision := Document.Revision;
    Document.SelectedIndex := 1;
    Require(Document.Revision = Revision,
      'Single selection changed the content revision');
    Require(Changes.Count = 3,
      'Single selection did not notify the UI');
    Document.SetSelectedLayers([1, 2]);
    Require(Document.Revision = Revision,
      'Multiple selection changed the content revision');
    Require(Changes.Count = 4,
      'Multiple selection did not notify the UI');
    Document.ToggleSelectedLayer(1);
    Require((Document.SelectionCount = 1) and
      Document.IsLayerSelected(2), 'Selection toggle did not remove a layer');
    Document.ToggleSelectedLayer(1);
    Require((Document.SelectionCount = 2) and
      Document.IsLayerSelected(1), 'Selection toggle did not add a layer');
    Document.SetSelectedLayers([1]);
    Document.SelectLayerRange(1, 2, False);
    Require((Document.SelectionCount = 2) and
      Document.IsLayerSelected(1) and Document.IsLayerSelected(2),
      'Selection range did not replace the selection');
    Require(Document.Revision = Revision,
      'Selection operations changed the content revision');
    Changes.Count := 0;
    Document.BeginUpdate;
    try
      Document.SetRectangleFillColor(1, clRed);
      Document.SetRectangleFillColor(2, clBlue);
    finally
      Document.EndUpdate;
    end;
    Require((Changes.Count = 1) and (Document.Revision = Revision + 1),
      'Batched content changes were not notified once');
    Revision := Document.Revision;
    Changes.Count := 0;
    Document.BeginInteractiveUpdate;
    Document.SetRectangleFillColor(1, clGreen);
    Require(Document.IsInteractiveUpdate and (Changes.Count = 1),
      'Interactive content change did not provide a live notification');
    Document.EndInteractiveUpdate;
    Require(not Document.IsInteractiveUpdate and (Changes.Count = 2) and
      (Document.Revision = Revision + 1),
      'Interactive update did not provide one final synchronization');
    Revision := Document.Revision;
    Document.MoveLayer(1, 2);
    Require(Document.Revision = Revision + 1,
      'Layer movement did not change the content revision');
    Revision := Document.Revision;
    Require(Document.RemoveRectangle(1, Data), 'Layer removal failed');
    Require(Document.Revision = Revision + 1,
      'Layer removal did not change the content revision');
    Writeln('Document selection revision tests: PASS');
  finally
    Document.OnChanged := nil;
    Changes.Free;
    Document.Free;
  end;
end.
