program LayerRendererCanvasHiddenTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerLayerRenderer in
    'Source\Layers\VectArtDesignerLayerRenderer.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function CenterY(const Bounds: TRect): Integer;
begin
  Result := Bounds.Top + Bounds.Height div 2;
end;

var
  Bounds: TRect;
  Data: TVectArtRectangleData;
  Document: TVectArtDocument;
  FirstRect: TRect;
  Renderer: TVectArtLayerRenderer;
  SecondRect: TRect;
begin
  Document := TVectArtDocument.Create;
  Renderer := TVectArtLayerRenderer.Create;
  try
    Bounds := Rect(0, 0, 320, 480);
    Renderer.Document := Document;
    Require(Renderer.LayerItemRect(Bounds, 0).IsEmpty,
      'Canvas layer still has a visible row');
    Require(Renderer.LayerIndexAt(Bounds, Bounds.Bottom - 10) = -1,
      'Empty document exposes the canvas layer');

    Data.Bounds := TRectF.Create(0, 0, 100, 100);
    Data.FillColor := clRed;
    Data.Locked := False;
    Data.Name := 'Rectangle 1';
    Data.Opacity := 1.0;
    Data.RotationDegrees := 0.0;
    Data.StrokeColor := clBlack;
    Data.StrokeStyle := vssSolid;
    Data.StrokeWidth := 0.0;
    Data.Visible := True;
    Document.InsertRectangle(Document.LayerCount, Data);
    Data.Name := 'Rectangle 2';
    Document.InsertRectangle(Document.LayerCount, Data);

    FirstRect := Renderer.LayerItemRect(Bounds, 1);
    SecondRect := Renderer.LayerItemRect(Bounds, 2);
    Require(FirstRect.Bottom = Bounds.Bottom - 8,
      'First object row did not replace the hidden canvas row');
    Require(Renderer.LayerIndexAt(Bounds, CenterY(FirstRect)) = 1,
      'First object row hit test failed');
    Require(Renderer.LayerIndexAt(Bounds, CenterY(SecondRect)) = 2,
      'Second object row hit test failed');
    Writeln('Layer renderer canvas-hidden tests: PASS');
  finally
    Renderer.Free;
    Document.Free;
  end;
end.
