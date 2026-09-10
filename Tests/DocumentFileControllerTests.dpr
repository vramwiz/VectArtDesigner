program DocumentFileControllerTests;

{$APPTYPE CONSOLE}

uses
  System.IOUtils, System.SysUtils, System.Types, Vcl.Graphics,
  TextRendererSkiaBootstrap, TextRendererSkiaRuntime,
  VectArtDesignerDocument, VectArtDesignerDocumentFileController,
  VectArtDesignerEditHistory;

procedure Require(Value: Boolean; const MessageText: string);
begin
  if not Value then
    raise Exception.Create(MessageText);
end;

var
  Controller: TVectArtDocumentFileController;
  Document: TVectArtDocument;
  History: TVectArtEditHistory;
  RectangleData: TVectArtRectangleData;
  StatusText: string;
  SvgFileName: string;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Document := TVectArtDocument.Create;
  History := TVectArtEditHistory.Create;
  Controller := TVectArtDocumentFileController.Create(Document, History);
  SvgFileName := TPath.Combine(TPath.GetTempPath,
    'VectArtDesignerDocumentFileController.svg');
  try
    RectangleData := Default(TVectArtRectangleData);
    RectangleData.Name := 'Rectangle';
    RectangleData.Bounds := RectF(10, 20, 210, 120);
    RectangleData.Visible := True;
    RectangleData.Filled := True;
    RectangleData.FillColor := clRed;
    RectangleData.Opacity := 1;
    RectangleData.StrokeColor := clBlack;
    RectangleData.StrokeWidth := 2;
    Document.InsertRectangle(1, RectangleData);

    Require(Controller.SaveFile(0, SvgFileName, StatusText, False),
      'SVG save: ' + StatusText);
    Document.Reset(320, 240);
    Require(Controller.OpenFile(0, SvgFileName, StatusText, False) and
      (Document.LayerCount = 2), 'SVG open: ' + StatusText);

    Writeln('PASS document file controller SVG save and open');
  finally
    if TFile.Exists(SvgFileName) then
      TFile.Delete(SvgFileName);
    Controller.Free;
    History.Free;
    Document.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
