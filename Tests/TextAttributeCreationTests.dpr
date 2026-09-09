// 文字入力UIからの作成と確定・Undoで、文字属性だけが引き継がれることを確認する。
program TextAttributeCreationTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Types, System.Classes, Vcl.Forms, Vcl.Controls,
  Vcl.Graphics, Winapi.Windows, Winapi.Messages, VectArtDesignerCanvas,
  VectArtDesignerTextEditing, VectArtDesignerDocument, VectArtDesignerEditorState,
  VectArtDesignerEditHistory, TextRendererSkiaBootstrap, TextRendererSkiaRuntime;
procedure Check(Value: Boolean; const Msg: string);
begin if not Value then raise Exception.Create(Msg); end;
var
  F: TForm; C: TVectArtCanvasControl; E: TVectArtImeEdit;
  D: TVectArtDocument; S: TVectArtEditorState; H: TVectArtEditHistory;
  T: TVectArtTextData; R: TVectArtRectangleData;
  L: TVectArtTextLayer; I, N, Mode: Integer;
begin
  Application.Initialize;
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  D:=TVectArtDocument.Create; S:=TVectArtEditorState.Create;
  H:=TVectArtEditHistory.Create; F:=TForm.Create(nil);
  try
    T:=Default(TVectArtTextData); T.Text:='Source'; T.FontFamily:='Arial';
    T.FontSize:=36; T.FontStyle:=[fsBold]; T.TextColor:=clRed;
    T.FillStyle.Kind:=vfkWave; T.FillStyle.Color2:=clBlue; T.FillStyle.WaveCount:=3;
    T.Bounds:=RectF(300,300,450,350); T.Opacity:=0.75; T.Visible:=True;
    T.LetterSpacingRatio:=0.2; T.LineSpacingRatio:=0.3; T.Vertical:=True;
    D.InsertText(1,T); R:=Default(TVectArtRectangleData);
    R.Bounds:=RectF(500,300,550,350); R.FillColor:=clGreen;
    R.Opacity:=1; R.Visible:=True; D.InsertRectangle(2,R);
    F.ClientWidth:=640; F.ClientHeight:=480;
    C:=TVectArtCanvasControl.Create(F); C.Parent:=F; C.Align:=alClient;
    C.Document:=D; C.EditorState:=S; C.EditHistory:=H;
    F.Show; Application.ProcessMessages; S.CurrentTool:=vetText;
    E:=nil;
    for I:=0 to C.ControlCount-1 do
      if C.Controls[I] is TVectArtImeEdit then E:=TVectArtImeEdit(C.Controls[I]);
    Check(E<>nil,'IME control');
    for Mode:=0 to 3 do
    begin
      case Mode of
        0:D.SetSelectedLayers([1]);
        1:D.SetSelectedLayers([]);
        2:D.SetSelectedLayers([2]);
        3:D.SetSelectedLayers([1,2]);
      end;
      N:=D.LayerCount;
      C.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(C.CanvasBounds.Left+20+Mode*60,C.CanvasBounds.Top+20));
      Check(D.LayerCount=N+1,'Text inserted'); L:=TVectArtTextLayer(D[N]);
      Writeln('Mode=',Mode,' text=',L.Text,' left=',L.Bounds.Left:0:2);
      Check((L.Text='') and (Abs(L.Bounds.Left-(20+Mode*60)/C.Zoom)<0.01) and (L.GroupId=0),'Text content or position copied');
      if Mode=0 then
        Check((L.FontFamily='Arial') and (L.FontSize=36) and (L.FontStyle=[fsBold]) and
          (L.TextColor=clRed) and (L.FillStyle.Kind=vfkWave) and L.Vertical,'Text attributes missing')
      else Check((L.TextColor=clBlack) and (L.FillStyle.Kind=vfkSolid) and not L.Vertical,'Fallback text');
      E.OnCommittedText(E,'New');
      C.SetFocus;
      Check(TVectArtTextLayer(D[N]).Text='New','New content');
      H.Undo; Check(D.LayerCount=N,'Undo text'); H.Redo;
      L:=TVectArtTextLayer(D[N]);
      Check((L.Text='New') and ((Mode<>0) or (L.FillStyle.Kind=vfkWave)),'Redo text');
    end;
    Writeln('PASS text UI: same category, defaults, content, Undo/Redo');
  finally F.Free; H.Free; S.Free; D.Free; TTextRendererSkiaRuntime.Release; end;
end.
