// 提供MIFの影を編集可能に復元し、描画・保存・履歴・作成引継ぎの接続を確認する。
program ShapeShadowTests;
{$APPTYPE CONSOLE}
uses VectArtDesignerNumericSlider, System.Classes, System.SysUtils, System.Types, System.IOUtils, Vcl.Graphics,
  Winapi.Windows, Vcl.Forms, Vcl.StdCtrls, Vcl.Controls,
  TextRendererSkiaBootstrap, TextRendererSkiaRuntime,
  VectArtDesignerDocument, VectArtDesignerRenderer, VectArtDesignerDocumentJson,
  VectArtDesignerMifContainer, VectArtDesignerMifDocument, VectArtDesignerMifRaster,
  VectArtDesignerMifPngMetadata, VectArtDesignerShadowCommand, VectArtDesignerEditHistory,
  VectArtDesignerLayerRenderer, VectArtDesignerObjectAttributes, VectArtDesignerShadowSettings, VectArtDesignerSvgDocument;
procedure Check(Value: Boolean; const Msg: string);
begin if not Value then raise Exception.Create(Msg); end;
procedure SameShadow(const A,B: TVectArtShadow);
begin Check((A.Enabled=B.Enabled) and (A.Color=B.Color) and (A.Blur=B.Blur) and
  (A.OffsetX=B.OffsetX) and (A.OffsetY=B.OffsetY),'Shadow roundtrip'); end;
var
  D,E: TVectArtDocument; Source,Saved: TVectArtMifContainer; B: TVectArtRenderBuffer;
  Err,Svg: string; V: TVectArtShadow; R: TVectArtRectangleLayer; P: TVectArtPathData;
  Command: TVectArtShadowCommand; H: TVectArtEditHistory; F: TForm;
  UI: TVectArtShadowSettings; Edit: TEdit; CheckBox: TCheckBox;
  DC: HDC; Bitmap: Vcl.Graphics.TBitmap; Layers: TVectArtLayerRenderer;
  X,Y,Count,I: Integer; Pixel: TVectArtRgbaPixel; Bytes: TBytes;
begin
  Application.Initialize; TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  D:=TVectArtDocument.Create; E:=TVectArtDocument.Create; B:=TVectArtRenderBuffer.Create;
  Source:=nil; Saved:=nil; H:=TVectArtEditHistory.Create; F:=TForm.Create(nil);
  try
    Check(CreateVectArtMifContainerReader.TryReadFile('mif/四角_影_赤.mif',Source,Err),Err);
    Check(TryLoadVectArtDocumentFromMif(Source,D,Err),Err);
    Check(D.LayerCount=2,'Native layer count');
    Check(D[1].GroupId=0,'Native source unexpectedly grouped'); R:=TVectArtRectangleLayer(D[1]); V:=R.Shadow;
    Check(V.Enabled and (V.Color=clRed) and (V.Blur=1) and (V.OffsetX=1) and (V.OffsetY=1),'Native shadow fields');
    Check((R.Bounds.Left=115) and (R.Bounds.Top=115) and (R.Bounds.Width=195) and (R.Bounds.Height=95),'Shadow expanded native geometry');
    RenderVectArtDocument(D,B,D.CanvasLayer.Width,D.CanvasLayer.Height);
    TFile.WriteAllBytes('TestOutput/shadow-render.png',EncodeRgba(B.Data,B.Width,B.Height));
    Count:=0;
    for Y:=210 to 215 do for X:=130 to 280 do
    begin Pixel:=B.Pixels[Y*B.Width+X]; if (Pixel.A>0) and (Pixel.R>Pixel.G+100) then Inc(Count); end;
    Check(Count>100,'Red shadow missing outside shape');
    Check(TryCreateVectArtMifFromDocument(D,Source,Saved,Err),Err);
    Check(TryLoadVectArtDocumentFromMif(Saved,E,Err),Err);
    SameShadow(V,E[1].Shadow); Check(E[1].GroupId=0,'Roundtrip unexpectedly grouped');
    Check(Abs(TVectArtRectangleLayer(E[1]).Bounds.Width-R.Bounds.Width)<0.01,'MIF grew body');
    Check(TryDeserializeVectArtDocument(SerializeVectArtDocument(D),E,Err),Err); SameShadow(V,E[1].Shadow);
    Check(TryCreateVectArtSvg(D,Svg,Err),Err); Check(Pos('feDropShadow',Svg)>0,'SVG filter absent');
    TFile.WriteAllText('TestOutput/shadow.svg',Svg,TEncoding.UTF8);
    Check(TryLoadVectArtDocumentFromSvgFile('TestOutput/shadow.svg',E,Err),Err); SameShadow(V,E[1].Shadow);
    P:=Default(TVectArtPathData); P.Points:=[PointF(20,20),PointF(100,20),PointF(100,80)];
    P.Closed:=True; P.Visible:=True; ApplyVectArtObjectAttributes(CaptureVectArtObjectAttributes(R),P);
    SameShadow(V,P.Shadow); D.InsertPath(2,P);
    FreeAndNil(Saved); Check(TryCreateVectArtMifFromDocument(D,Saved,Err),Err);
    Check(TryLoadVectArtDocumentFromMif(Saved,E,Err),Err); SameShadow(V,E[2].Shadow);
    Check(TryCreateVectArtSvg(D,Svg,Err),Err);
    TFile.WriteAllText('TestOutput/shadow-path.svg',Svg,TEncoding.UTF8);
    Check(TryLoadVectArtDocumentFromSvgFile('TestOutput/shadow-path.svg',E,Err),Err); SameShadow(V,E[2].Shadow);
    R.RotationDegrees:=30;
    FreeAndNil(Saved); Check(TryCreateVectArtMifFromDocument(D,Saved,Err),Err);
    Check(TryLoadVectArtDocumentFromMif(Saved,E,Err),Err);
    Check((Abs(TVectArtRectangleLayer(E[1]).Bounds.Left-R.Bounds.Left)<0.01) and
      (Abs(TVectArtRectangleLayer(E[1]).RotationDegrees-30)<0.01),'Rotated shadow geometry');
    R.RotationDegrees:=0;
    // 変更通知とUndoが別レイヤーの影を変更しないことを確認する。
    V.OffsetX:=-12; V.OffsetY:=14; V.Blur:=5;
    Command:=TVectArtShadowCommand.Create(D,1,V); Command.Execute; H.AddApplied(Command);
    H.Undo; Check(D[1].Shadow.OffsetX=1,'Undo shadow'); H.Redo; SameShadow(V,D[1].Shadow);
    Check(D[2].Shadow.OffsetX=1,'Other layer changed');
    RenderVectArtDocument(D,B,D.CanvasLayer.Width,D.CanvasLayer.Height);
    Pixel:=B.Pixels[170*B.Width+108]; Check((Pixel.A>0) and (Pixel.R>Pixel.G),'Negative offset shadow');
    V.Enabled:=False; R.Shadow:=V;
    RenderVectArtDocument(D,B,D.CanvasLayer.Width,D.CanvasLayer.Height);
    Check(B.Pixels[170*B.Width+108].A=0,'Disabled shadow still visible');
    V.Enabled:=True; R.Shadow:=V;
    D.SetSelectedLayers([1]); UI:=TVectArtShadowSettings.CreateForParent(F,F); UI.Parent:=F; UI.Align:=alClient;
    F.ClientWidth:=300; F.ClientHeight:=400; UI.Configure(D,H); F.Show; Application.ProcessMessages;
    Bitmap:=Vcl.Graphics.TBitmap.Create; Layers:=TVectArtLayerRenderer.Create;
    try
      Bitmap.SetSize(F.ClientWidth,F.ClientHeight); F.Repaint; Application.ProcessMessages;
      DC:=GetDC(F.Handle);
      try BitBlt(Bitmap.Canvas.Handle,0,0,F.ClientWidth,F.ClientHeight,DC,0,0,SRCCOPY);
      finally ReleaseDC(F.Handle,DC); end;
      Bitmap.SaveToFile('TestOutput/shadow-settings.bmp');
      Bitmap.SetSize(320,240); Layers.Document:=D;
      Layers.DrawLayers(Bitmap.Canvas,Rect(0,0,320,240));
      Bitmap.SaveToFile('TestOutput/shadow-thumbnails.bmp');
    finally Layers.Free; Bitmap.Free; end;
    Edit:=TVectArtNumericSlider(UI.FindComponent('ShadowOffsetX')).Edit; Edit.Text:='23'; Edit.OnExit(Edit);
    Check(D[1].Shadow.OffsetX=23,'UI offset'); H.Undo; Check(D[1].Shadow.OffsetX=-12,'UI undo');
    UI.Configure(D,H); CheckBox:=TCheckBox(UI.FindComponent('ShadowEnabled'));
    CheckBox.Checked:=False; Check(not D[1].Shadow.Enabled,'UI disable'); H.Undo;
    D.SetLayerLocked(1,True); UI.Configure(D,H); Check(not UI.Enabled,'Locked shadow editable');
    D.SetLayerLocked(1,False); D.SetSelectedLayers([1,2]); UI.Configure(D,H); Check(not UI.Enabled,'Multiple selection editable');
    // MIFに独自の影キーを追加せず、ネイティブの属性だけで保持する。
    for I:=0 to Saved.ChunkCount-1 do
    begin Bytes:=Saved[I].Data; Check(Pos('shadowEnabled',TEncoding.ASCII.GetString(Bytes))=0,'Custom MIF shadow key'); end;
    Writeln('PASS native red shadow, geometry, PNG, MIF/SVG/JSON, path inheritance, UI and Undo');
  finally F.Free; H.Free; Saved.Free; Source.Free; B.Free; E.Free; D.Free;
    TTextRendererSkiaRuntime.Release; end;
end.
