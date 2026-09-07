program TextEditingTests;

{$APPTYPE CONSOLE}

// Verifies explicit line breaks, click-to-caret mapping, and UTF-16 insertion.

uses
  System.Math,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  TextRendererSkiaBootstrap in
    'Lib\TextRenderer\TextRendererSkiaBootstrap.pas',
  TextRendererSkiaRuntime in
    'Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  VectArtDesignerDocument in
    'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in
    'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerEditCommands in
    'Source\Core\Commands\VectArtDesignerEditCommands.pas',
  VectArtDesignerEditHistory in
    'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerLayerStructureCommands in
    'Source\Core\Commands\VectArtDesignerLayerStructureCommands.pas',
  VectArtDesignerTextGeometry in
    'Source\Core\VectArtDesignerTextGeometry.pas',
  VectArtDesignerTextEditing in
    'Source\Editor\Input\VectArtDesignerTextEditing.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  Buffer: string;
  CaretIndex: Integer;
  Data: TVectArtTextData;
  Document: TVectArtDocument;
  History: TVectArtEditHistory;
  Layout: TVectArtTextLayout;
  NewData: TVectArtTextData;
  SpacedLayout: TVectArtTextLayout;
  Text: string;
  VerticalLayout: TVectArtTextLayout;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Document := TVectArtDocument.Create;
  History := TVectArtEditHistory.Create;
  try
    Text := 'abc' + sLineBreak + 'def';
    Layout := BuildVectArtTextLayout(Text, 'Yu Gothic UI', 24, []);
    Require((Length(Layout.Lines) = 2) and
      (Layout.Lines[0] = 'abc') and (Layout.Lines[1] = 'def') and
      (Layout.Height > Layout.LineHeight),
      'Explicit multiline layout differs');
    SpacedLayout := BuildVectArtTextLayout(Text, 'Yu Gothic UI', 24, [],
      0.25, 0.5);
    Require((SpacedLayout.Width > Layout.Width) and
      (SpacedLayout.LineHeight > Layout.LineHeight),
      'Letter or line spacing did not change intrinsic layout');
    VerticalLayout := BuildVectArtTextLayout(Text, 'Yu Gothic UI', 24,
      [], 0.25, 0.5, True);
    Require(VerticalLayout.Vertical and
      (VerticalLayout.Width > VerticalLayout.BaseLineHeight) and
      (VerticalLayout.Height > VerticalLayout.BaseLineHeight),
      'Vertical text layout differs');
    Require(VectArtTextCaretIndexAtPoint(Text, 'Yu Gothic UI', 24,
      VerticalLayout.Width, 10000, [], 0.25, 0.5, True) = 3,
      'First vertical column trailing caret differs');
    Require(VectArtTextCaretIndexAtPoint(Text, 'Yu Gothic UI', 24,
      0, 0, [], 0.25, 0.5, True) = 5,
      'Second vertical column leading caret differs');
    Require(VectArtTextCaretIndexAtPoint(Text, 'Yu Gothic UI', 24,
      0, 0) = 0, 'First-line leading caret differs');
    Require(VectArtTextCaretIndexAtPoint(Text, 'Yu Gothic UI', 24,
      10000, 0) = 3, 'First-line trailing caret differs');
    Require(VectArtTextCaretIndexAtPoint(Text, 'Yu Gothic UI', 24,
      0, Layout.LineHeight + 1) = 5,
      'Second-line leading caret differs');

    Buffer := 'ab';
    CaretIndex := 1;
    InsertVectArtTextAtCaret(Buffer, CaretIndex, 'X' + sLineBreak);
    Require((Buffer = 'aX' + sLineBreak + 'b') and
      (CaretIndex = 1 + Length('X' + sLineBreak)),
      'Caret insertion differs');
    Text := string(Char($D83D)) + string(Char($DE00));
    Require(VectArtTextUnitLengthAt(Text, 1) = 2,
      'Surrogate pair was split');

    Data := Default(TVectArtTextData);
    Data.Bounds := TRectF.Create(10, 20, 110, 60);
    Data.FontFamily := 'Yu Gothic UI';
    Data.FontSize := 24;
    Data.Name := 'Text 1';
    Data.Opacity := 1;
    Data.Text := 'before';
    Data.TextColor := clBlack;
    Data.Visible := True;
    Document.InsertText(1, Data);
    Document.SetSelectedLayers([1]);
    History.AddApplied(TVectArtInsertTextCommand.Create(Document, 1,
      Data, [], [1]));
    History.Undo;
    Require(Document.LayerCount = 1, 'Text insertion undo differs');
    History.Redo;
    Require((Document.LayerCount = 2) and
      (TVectArtTextLayer(Document[1]).Text = 'before'),
      'Text insertion redo differs');
    Data := CaptureVectArtTextData(TVectArtTextLayer(Document[1]));
    NewData := Data;
    NewData.Text := 'after';
    Document.SetTextData(1, NewData);
    History.AddApplied(TVectArtTextDataCommand.Create(Document, 1,
      Data, NewData));
    History.Undo;
    Require(TVectArtTextLayer(Document[1]).Text = 'before',
      'Text edit undo differs');
    History.Redo;
    Require(TVectArtTextLayer(Document[1]).Text = 'after',
      'Text edit redo differs');
    Writeln('Text editing tests: PASS');
  finally
    History.Free;
    Document.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
