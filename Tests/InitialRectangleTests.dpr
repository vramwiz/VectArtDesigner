program InitialRectangleTests;
{$APPTYPE CONSOLE}
uses System.Classes, System.SysUtils, Winapi.Windows, Winapi.Messages, Vcl.Forms, Vcl.Controls,
 VectArtDesignerMainForm, VectArtDesignerToolPalette, VectArtDesignerCanvas,
 VectArtDesignerLayerOperations, Vcl.Graphics, System.Types, VectArtDesignerDocument, VectArtDesignerEditorState;
function FindControl(P:TWinControl; C:TClass):TControl;
var I:Integer;
begin
 Result:=nil;
 for I:=0 to P.ControlCount-1 do begin
  if P.Controls[I].InheritsFrom(C) then Exit(P.Controls[I]);
  if P.Controls[I] is TWinControl then begin Result:=FindControl(TWinControl(P.Controls[I]),C);if Result<>nil then Exit;end;
 end;
end;
var F:TMainForm; Canvas:TVectArtCanvasControl; Palette:TVectArtToolPaletteControl; R:TVectArtRectangleLayer;
 I,X,Y:Integer; Ops:TVectArtLayerOperations; D:TVectArtDocument; S:TVectArtEditorState;
begin
 Application.Initialize;
 R:=TVectArtRectangleLayer.Create('Default',RectF(0,0,100,100),clWhite);
 try if not R.Filled or (R.StrokeWidth<>1) then raise Exception.Create('Constructor default');finally R.Free;end;
 D:=TVectArtDocument.Create; Ops:=TVectArtLayerOperations.Create; S:=TVectArtEditorState.Create;
 try
  Ops.Document:=D; Ops.Execute(vlaAdd);
  R:=TVectArtRectangleLayer(D[1]);
  if not R.Filled or (R.StrokeWidth<>1) then raise Exception.Create('Add without EditorState');
  Ops.EditorState:=S; Ops.Execute(vlaAdd); R:=TVectArtRectangleLayer(D[2]);
  if not R.Filled or (R.StrokeWidth<>1) then raise Exception.Create('Add initial state');
  D.SetSelectedLayers([]);
  S.RectangleMode:=vrmFill; Ops.Execute(vlaAdd); R:=TVectArtRectangleLayer(D[3]);
  if not R.Filled or (R.StrokeWidth<>0) then raise Exception.Create('Explicit fill-only mode');
 finally Ops.Free; S.Free; D.Free;end;
 F:=TMainForm.Create(nil);
 try
  F.Show; Application.ProcessMessages;
  Palette:=nil; Canvas:=TVectArtCanvasControl(FindControl(F,TVectArtCanvasControl));
  for I:=0 to Screen.FormCount-1 do begin Palette:=TVectArtToolPaletteControl(FindControl(Screen.Forms[I],TVectArtToolPaletteControl));if Palette<>nil then Break;end;
  if Palette=nil then raise Exception.Create('Palette missing');
  Palette.EditorState.SelectRectangleToolGroup;
  X:=Canvas.CanvasBounds.Left+40;Y:=Canvas.CanvasBounds.Top+40;
  Canvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y));
  Canvas.Perform(WM_MOUSEMOVE,MK_LBUTTON,MakeLParam(X+100,Y+80));
  Canvas.Perform(WM_LBUTTONUP,0,MakeLParam(X+100,Y+80));
  Application.ProcessMessages;
  R:=TVectArtRectangleLayer(F.Document[1]);
  Writeln('Mode=',Ord(Palette.EditorState.RectangleMode),' Filled=',R.Filled,' Stroke=',R.StrokeWidth:0:2);
  if not R.Filled or (R.StrokeWidth<=0) then raise Exception.Create('Initial rectangle missing fill or stroke');
  Writeln('PASS initial rectangle in main form');
 finally F.Free;end;
end.
