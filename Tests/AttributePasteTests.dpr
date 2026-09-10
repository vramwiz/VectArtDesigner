program AttributePasteTests;

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  TextRendererSkiaBootstrap,
  TextRendererSkiaRuntime,
  VectArtDesignerDocument in
    'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerEditHistory in
    'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerAttributePasteOperations in
    'Source\Editor\Clipboard\VectArtDesignerAttributePasteOperations.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function RectangleData(const Bounds: TRectF; FillColor,
  StrokeColor: TColor; Filled: Boolean): TVectArtRectangleData;
begin
  Result := Default(TVectArtRectangleData);
  Result.Bounds := Bounds;
  Result.FillColor := FillColor;
  Result.Filled := Filled;
  Result.Name := 'rectangle';
  Result.Opacity := 1;
  Result.Shape := vpsRectangle;
  Result.StrokeColor := StrokeColor;
  Result.StrokeWidth := 7;
  Result.Visible := True;
end;

function TextData(const Bounds: TRectF; const Text,
  FontFamily: string): TVectArtTextData;
begin
  Result := Default(TVectArtTextData);
  Result.Bounds := Bounds;
  Result.FontFamily := FontFamily;
  Result.FontSize := 18;
  Result.Name := 'text';
  Result.Opacity := 1;
  Result.Text := Text;
  Result.TextColor := clBlack;
  Result.Visible := True;
end;

var
  Available: TVectArtAttributePasteKinds;
  Document: TVectArtDocument;
  History: TVectArtEditHistory;
  SourceRectangle: TVectArtRectangleLayer;
  SourceText: TVectArtTextLayer;
  TargetBounds: TRectF;
begin
  try
    TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
    Document := TVectArtDocument.Create;
    History := TVectArtEditHistory.Create;
    SourceRectangle := TVectArtRectangleLayer.Create('source',
      RectF(0, 0, 40, 20), clYellow);
    SourceText := TVectArtTextLayer.Create('source text',
      RectF(0, 0, 90, 30), 'copied text', 'Consolas', 24, clRed);
  try
    SourceRectangle.StrokeColor := clRed;
    Document.InsertRectangle(1, RectangleData(RectF(100, 100, 110, 160),
      clGreen, clBlue, False));
    Document.InsertRectangle(2, RectangleData(RectF(200, 200, 220, 220),
      clAqua, clNavy, True));
    Document.SetSelectedLayers([1, 2]);

    Available := AvailableVectArtAttributePastesFromSource(Document,
      SourceRectangle);
    Require(vapkColor in Available, 'shape color should be available');
    Require(vapkSize in Available, 'size should be available');
    Require(PasteVectArtAttributeFromSource(Document, History,
      SourceRectangle, vapkColor), 'shape color paste failed');
    Require(TVectArtRectangleLayer(Document[1]).FillColor = clYellow,
      'fill color was not copied');
    Require(TVectArtRectangleLayer(Document[1]).StrokeColor = clRed,
      'stroke color was not copied');
    Require(not TVectArtRectangleLayer(Document[1]).Filled,
      'filled state must be preserved');
    Require(SameValue(TVectArtRectangleLayer(Document[1]).StrokeWidth, 7.0),
      'stroke width must be preserved');
    Require(TVectArtRectangleLayer(Document[2]).FillColor = clYellow,
      'multi-selection color paste failed');
    History.Undo;
    Require(TVectArtRectangleLayer(Document[1]).FillColor = clGreen,
      'color undo failed');
    History.Redo;
    Require(TVectArtRectangleLayer(Document[1]).FillColor = clYellow,
      'color redo failed');

    TargetBounds := TVectArtRectangleLayer(Document[1]).Bounds;
    Require(PasteVectArtAttributeFromSource(Document, History,
      SourceRectangle, vapkSize), 'size paste failed');
    Require(SameValue(TVectArtRectangleLayer(Document[1]).Bounds.Width, 40.0),
      'width was not copied');
    Require(SameValue(TVectArtRectangleLayer(Document[1]).Bounds.Height, 20.0),
      'height was not copied');
    Require(SameValue(TVectArtRectangleLayer(Document[1]).Bounds.CenterPoint.X,
      TargetBounds.CenterPoint.X), 'horizontal center was not preserved');
    Require(SameValue(TVectArtRectangleLayer(Document[1]).Bounds.CenterPoint.Y,
      TargetBounds.CenterPoint.Y), 'vertical center was not preserved');
    History.Undo;
    Require(SameValue(TVectArtRectangleLayer(Document[1]).Bounds.Width,
      TargetBounds.Width), 'size undo failed');

    Document.InsertText(3, TextData(RectF(20, 20, 140, 60),
      'target text', 'Arial'));
    Document.SetSelectedLayers([3]);
    Available := AvailableVectArtAttributePastesFromSource(Document,
      SourceText);
    Require((vapkText in Available) and (vapkFontFamily in Available),
      'text attributes should be available');
    TargetBounds := TVectArtTextLayer(Document[3]).Bounds;
    Require(PasteVectArtAttributeFromSource(Document, History,
      SourceText, vapkText), 'text paste failed');
    Require(TVectArtTextLayer(Document[3]).Text = 'copied text',
      'text content was not copied');
    Require(TVectArtTextLayer(Document[3]).FontFamily = 'Arial',
      'text paste changed the font');
    Require(TVectArtTextLayer(Document[3]).Bounds = TargetBounds,
      'text paste changed bounds');
    Require(PasteVectArtAttributeFromSource(Document, History,
      SourceText, vapkFontFamily), 'font paste failed');
    Require(TVectArtTextLayer(Document[3]).FontFamily = 'Consolas',
      'font family was not copied');
    Require(SameValue(TVectArtTextLayer(Document[3]).FontSize, 18.0),
      'font size must be preserved');
    History.Undo;
    Require(TVectArtTextLayer(Document[3]).FontFamily = 'Arial',
      'font undo failed');

    Document[3].Locked := True;
    Require(AvailableVectArtAttributePastesFromSource(Document,
      SourceText) = [], 'locked selection should disable attribute paste');
    Writeln('PASS attribute paste: color, size, text, font, multi-select, undo');
    finally
      SourceText.Free;
      SourceRectangle.Free;
      History.Free;
      Document.Free;
      TTextRendererSkiaRuntime.Release;
    end;
  except
    on E: Exception do
    begin
      Writeln('FAIL ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
