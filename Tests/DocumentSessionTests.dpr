program DocumentSessionTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Types, Vcl.Graphics,
  VectArtDesignerDocument, VectArtDesignerDocumentSession;

procedure Require(Value: Boolean; const MessageText: string);
begin
  if not Value then
    raise Exception.Create(MessageText);
end;

var
  Document: TVectArtDocument;
  RectangleData: TVectArtRectangleData;
  Session: TVectArtDocumentSession;
begin
  Document := TVectArtDocument.Create;
  Session := TVectArtDocumentSession.Create(Document);
  try
    Require(not Session.Dirty and
      (Session.Caption = 'VectArtDesigner - 新規キャンバス'),
      'Initial session state');
    Document.SetSelectedLayers([]);
    Session.ObserveDocumentChange;
    Require(not Session.Dirty, 'Selection-only change marked document dirty');

    RectangleData := Default(TVectArtRectangleData);
    RectangleData.Name := 'Rectangle';
    RectangleData.Bounds := RectF(10, 10, 100, 100);
    RectangleData.Visible := True;
    RectangleData.Filled := True;
    RectangleData.FillColor := clRed;
    RectangleData.Opacity := 1;
    Document.InsertRectangle(1, RectangleData);
    Session.ObserveDocumentChange;
    Require(Session.Dirty and
      (Session.Caption = 'VectArtDesigner - 新規キャンバス *'),
      'Content change did not mark session dirty');

    Session.MarkClean('sample.mif');
    Require(not Session.Dirty and
      (Session.Caption = 'VectArtDesigner - sample.mif'),
      'Saved session state');
    Document.SelectedIndex := 1;
    Session.ObserveDocumentChange;
    Require(not Session.Dirty, 'Selection changed saved session state');
    Document.SetCanvasSize(800, 600);
    Session.ObserveDocumentChange;
    Require(Session.Dirty and
      (Session.Caption = 'VectArtDesigner - sample.mif *'),
      'Canvas change did not mark session dirty');

    Writeln('PASS document session dirty state and caption');
  finally
    Session.Free;
    Document.Free;
  end;
end.
