program RectangleStrokeTests;

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerEditCommands in
    'Source\Core\Commands\VectArtDesignerEditCommands.pas',
  VectArtDesignerEditHistory in
    'Source\Core\VectArtDesignerEditHistory.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  Command: TVectArtStrokeCommand;
  Data: TVectArtRectangleData;
  Document: TVectArtDocument;
  History: TVectArtEditHistory;
  Rectangle: TVectArtRectangleLayer;
begin
  Document := TVectArtDocument.Create;
  History := TVectArtEditHistory.Create;
  try
    Data.Bounds := TRectF.Create(10, 20, 110, 80);
    Data.FillColor := clWhite;
    Data.Locked := False;
    Data.Name := 'Rectangle 1';
    Data.Opacity := 1.0;
    Data.RotationDegrees := 0.0;
    Data.StrokeColor := clBlack;
    Data.MifStrokeStyle := vssSolid;
    Data.StrokeWidth := 0.0;
    Data.Visible := True;
    Document.InsertRectangle(1, Data);

    Command := TVectArtStrokeCommand.Create(Document, 1, clBlack, 0.0,
      vssSolid, clRed, 4.5, vssDashed);
    Command.Execute;
    History.AddApplied(Command);
    Rectangle := TVectArtRectangleLayer(Document[1]);
    Require((Rectangle.StrokeColor = clRed) and
      SameValue(Rectangle.StrokeWidth, 4.5) and
      (Rectangle.MifStrokeStyle = vssDashed), 'Stroke command differs');
    History.Undo;
    Require((Rectangle.StrokeColor = clBlack) and
      SameValue(Rectangle.StrokeWidth, 0.0) and
      (Rectangle.MifStrokeStyle = vssSolid), 'Stroke undo differs');
    History.Redo;
    Require((Rectangle.StrokeColor = clRed) and
      SameValue(Rectangle.StrokeWidth, 4.5) and
      (Rectangle.MifStrokeStyle = vssDashed), 'Stroke redo differs');
    Writeln('Rectangle stroke: PASS');
  finally
    History.Free;
    Document.Free;
  end;
end.
