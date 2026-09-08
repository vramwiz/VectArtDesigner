program FillIntegrationTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Types, System.IOUtils, Vcl.Graphics,
  TextRendererSkiaBootstrap, TextRendererSkiaRuntime,
  VectArtDesignerDocument, VectArtDesignerFillCommand,
  VectArtDesignerRenderer, VectArtDesignerDocumentJson,
  VectArtDesignerMifContainer, VectArtDesignerMifDocument, VectArtDesignerSvgDocument;
procedure Check(Value: Boolean; const S: string);
begin if not Value then raise Exception.Create(S); end;
var PathData: TVectArtPathData; Report: TMifExportReport;
    D,E: TVectArtDocument; R: TVectArtRectangleData; Fill: TVectArtFillStyle;
    Cmd: TVectArtFillCommand; B: TVectArtRenderBuffer; K: TVectArtFillKind;
    C, Saved: TVectArtMifContainer; Reader: IVectArtMifContainerReader;
    Err,Svg,FileName: string; TestAngle: Integer;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  D := TVectArtDocument.Create; E := TVectArtDocument.Create;
  B := TVectArtRenderBuffer.Create; C := nil; Saved := nil;
  try
    R := Default(TVectArtRectangleData);
    R.Bounds := RectF(0,0,100,100); R.FillColor := clRed;
    R.Filled := True; R.Visible := True; R.Opacity := 1;
    D.CanvasLayer.Width := 100; D.CanvasLayer.Height := 100;
    D.InsertRectangle(1,R);
    for K := vfkLinearHorizontal to vfkRadial do
    begin
      Fill := Default(TVectArtFillStyle); Fill.Kind := K; Fill.Color2 := clBlue;
      Cmd := TVectArtFillCommand.Create(D,1,clRed,Fill);
      try
        Cmd.Execute;
        RenderVectArtDocument(D,B,100,100);
        if K = vfkLinearHorizontal then
        begin Check(B.Pixels[50*100+1].R > 240,'Horizontal left color'); Check(B.Pixels[50*100+98].B > 240,'Horizontal right color'); end;
        if K = vfkLinearVertical then
        begin Check(B.Pixels[1*100+50].R > 240,'Vertical top color'); Check(B.Pixels[98*100+50].B > 240,'Vertical bottom color'); end;
        if K = vfkRadial then
        begin Check(B.Pixels[50*100+50].R > 240,'Radial center'); Check(B.Pixels[0].B > 240,'Radial corner'); end;
        Check(TryDeserializeVectArtDocument(SerializeVectArtDocument(D),E,Err),Err);
        Check(TVectArtRectangleLayer(E[1]).FillStyle.Kind = K,'JSON kind');
        Check(TryCreateVectArtSvg(D,Svg,Err),Err);
        FileName := ExtractFilePath(ParamStr(0))+'fill-test.svg';
        TFile.WriteAllText(FileName,Svg,TEncoding.UTF8);
        Check(TryLoadVectArtDocumentFromSvgFile(FileName,E,Err),Err);
        Check(TVectArtRectangleLayer(E[1]).FillStyle.Kind = K,'SVG kind');
        if K <> vfkRadial then
        begin
          Check(TryCreateVectArtMifFromDocument(D,Saved,Err),Err);
          Check(TryLoadVectArtDocumentFromMif(Saved,E,Err),Err);
          Check(TVectArtRectangleLayer(E[1]).FillStyle.Kind = K,'MIF kind');
          Check(TVectArtRectangleLayer(E[1]).FillStyle.Color2 = clBlue,'MIF color2');
          FreeAndNil(Saved);
        end;
        Cmd.Undo; Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkSolid,'Undo fill');
        Cmd.Execute; Cmd.Undo;
      finally Cmd.Free; end;
    end;
    for TestAngle in [45,135,180,270,315] do
    begin
      Fill := Default(TVectArtFillStyle); Fill.Kind := vfkLinearHorizontal;
      Fill.Angle := TestAngle; Fill.Color2 := clBlue;
      Cmd := TVectArtFillCommand.Create(D,1,clRed,Fill);
      try
        Cmd.Execute;
        RenderVectArtDocument(D,B,100,100);
        if TestAngle = 45 then
        begin Check(B.Pixels[0].R > 240,'45 top left'); Check(B.Pixels[9999].B > 240,'45 bottom right'); end;
        Check(TryDeserializeVectArtDocument(SerializeVectArtDocument(D),E,Err),Err);
        Check(TVectArtRectangleLayer(E[1]).FillStyle.Angle = TestAngle,'JSON angle');
        Check(TryCreateVectArtSvg(D,Svg,Err),Err);
        TFile.WriteAllText(FileName,Svg,TEncoding.UTF8);
        Check(TryLoadVectArtDocumentFromSvgFile(FileName,E,Err),Err);
        Check(TVectArtRectangleLayer(E[1]).FillStyle.Angle = TestAngle,'SVG angle');
        Check(TryCreateVectArtMifFromDocument(D,Saved,Err),Err);
        Check(TryLoadVectArtDocumentFromMif(Saved,E,Err),Err);
        Check(TVectArtRectangleLayer(E[1]).FillStyle.Angle = TestAngle,'MIF angle');
        FreeAndNil(Saved);
        Cmd.Undo;
        Check(TVectArtRectangleLayer(D[1]).FillStyle.Angle = 0,'Undo angle');
        Cmd.Execute;
        Check(TVectArtRectangleLayer(D[1]).FillStyle.Angle = TestAngle,'Redo angle');
        Cmd.Undo;
      finally Cmd.Free; end;
    end;
    PathData := Default(TVectArtPathData);
    PathData.Points := [PointF(0,0),PointF(100,0),PointF(100,100),PointF(0,100)];
    PathData.Closed := True; PathData.Filled := True; PathData.Visible := True; PathData.Opacity := 1;
    PathData.FillColor := clRed; PathData.FillStyle.Kind := vfkLinearVertical;
    PathData.FillStyle.Color2 := clBlue;
    D.InsertPath(2,PathData);
    RenderVectArtDocument(D,B,100,100);
    Check(B.Pixels[50].R > 240,'Path gradient top');
    Check(B.Pixels[99*100+50].B > 240,'Path gradient bottom');
    Check(TryCreateVectArtMifFromDocument(D,Saved,Err),Err);
    Check(TryLoadVectArtDocumentFromMif(Saved,E,Err),Err);
    Check(TVectArtPathLayer(E[2]).FillStyle.Kind = vfkLinearVertical,'Path MIF fill');
    FreeAndNil(Saved);
    Check(D.RemovePath(2,PathData),'Remove path');
    Check(PathData.FillStyle.Kind = vfkLinearVertical,'Removed path fill snapshot');
    Fill := Default(TVectArtFillStyle); Fill.Kind := vfkTexture;
    Reader := CreateVectArtMifContainerReader;
    Check(Reader.TryReadFile('mif\四角_グラデーション_線形_45度.mif',C,Err),Err);
    Fill.TexturePng := Copy(C[4].Data);
    FreeAndNil(C);
    Cmd := TVectArtFillCommand.Create(D,1,clWhite,Fill);
    try
      Cmd.Execute;
      RenderVectArtDocument(D,B,100,100);
      Check(Length(Fill.TexturePng) > 0,'Texture fixture bytes');
      Check(TryCreateVectArtSvg(D,Svg,Err),Err);
      TFile.WriteAllText(FileName,Svg,TEncoding.UTF8);
      Check(TryLoadVectArtDocumentFromSvgFile(FileName,E,Err),Err);
      Check(TVectArtRectangleLayer(E[1]).FillStyle.Kind = vfkTexture,'Texture SVG kind');
      Check(Length(TVectArtRectangleLayer(E[1]).FillStyle.TexturePng) = Length(Fill.TexturePng),'Texture bytes');
      Check(TryAnalyzeVectArtMifExport(D,Report,Err),Err);
      Check(Report.Compatibility = mecUnsupported,'Unverified texture MIF must not silently lose fill');
      Cmd.Undo;
    finally Cmd.Free; end;
    Reader := CreateVectArtMifContainerReader;
    Check(Reader.TryReadFile('mif\四角_グラデーション_線形_45度.mif',C,Err),Err);
    Check(TryLoadVectArtDocumentFromMif(C,E,Err),Err);
    Check(TVectArtRectangleLayer(E[1]).FillStyle.Angle = 45,'WebArt gradient import');
    Check(TVectArtRectangleLayer(E[1]).FillStyle.Color2 = clBlue,'WebArt gradient color');
    Check(TryCreateVectArtMifFromDocument(E,C,Saved,Err),Err);
    Check(TryLoadVectArtDocumentFromMif(Saved,D,Err),Err);
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Angle = 45,'WebArt gradient roundtrip');
    Writeln('PASS gradient pixels, Undo, JSON/SVG/MIF roundtrips and WebArt fixture');
  finally Saved.Free; C.Free; B.Free; E.Free; D.Free; TTextRendererSkiaRuntime.Release; end;
end.