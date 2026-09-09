program FillIntegrationTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Types, System.IOUtils, Vcl.Graphics,
  TextRendererSkiaBootstrap, TextRendererSkiaRuntime,
  VectArtDesignerDocument, VectArtDesignerFillCommand,
  VectArtDesignerRenderer, VectArtDesignerDocumentJson,
  VectArtDesignerMifPngMetadata, VectArtDesignerMifContainer, VectArtDesignerMifDocument, VectArtDesignerSvgDocument;
procedure Check(Value: Boolean; const S: string);
begin if not Value then raise Exception.Create(S); end;
var PathData: TVectArtPathData; Report: TMifExportReport;
    D,E: TVectArtDocument; R: TVectArtRectangleData; Fill: TVectArtFillStyle;
    Cmd: TVectArtFillCommand; B: TVectArtRenderBuffer; K: TVectArtFillKind;
    C, Saved: TVectArtMifContainer; Reader: IVectArtMifContainerReader;
    Err,Svg,FileName,TextureKind: string; TestAngle: Integer;
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
    for K in [vfkLinearHorizontal,vfkLinearVertical,vfkRadial,vfkCircle,vfkSquare,vfkWave,vfkSpectrum] do
    begin
      Fill := Default(TVectArtFillStyle); Fill.Kind := K; Fill.Color2 := clBlue;
      if K = vfkWave then Fill.WaveCount := 5;
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
        if K = vfkCircle then
        begin
          Check(B.Pixels[50*100+50].B = 255,'Circle center color2');
          Check(B.Pixels[50*100+1].R > 250,'Circle left color1');
          Check(B.Pixels[50*100+98].B > 250,'Circle right color2');
          Check(Abs(Integer(B.Pixels[1*100+50].R)-127) <= 3,'Circle top midpoint');
        end;
        Check(TryDeserializeVectArtDocument(SerializeVectArtDocument(D),E,Err),Err);
        Check(TVectArtRectangleLayer(E[1]).FillStyle.Kind = K,'JSON kind');
        Check(TryCreateVectArtSvg(D,Svg,Err),Err);
        FileName := ExtractFilePath(ParamStr(0))+'fill-test.svg';
        TFile.WriteAllText(FileName,Svg,TEncoding.UTF8);
        Check(TryLoadVectArtDocumentFromSvgFile(FileName,E,Err),Err);
        Check(TVectArtRectangleLayer(E[1]).FillStyle.Kind = K,'SVG kind');
        // 放射状も編集可能なネイティブMIFとして往復する。
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
    for K in [vfkLinearVertical,vfkRadial,vfkCircle,vfkSquare,vfkWave,vfkSpectrum] do
    begin
    PathData.FillColor := clRed; PathData.FillStyle.Kind := K;
    PathData.FillStyle.Color2 := clBlue;
    if K = vfkWave then PathData.FillStyle.WaveCount := 5;
    D.InsertPath(2,PathData);
    RenderVectArtDocument(D,B,100,100);
    if K = vfkSpectrum then
    begin
      Check(B.Pixels[5050].G = 255,'Path spectrum center green');
      Check(B.Pixels[5050].B = 255,'Path spectrum center blue');
    end
    else if K = vfkWave then
    begin
      Check(B.Pixels[5050].R = 255,'Path wave center');
      Check(B.Pixels[50*100+43].B > 250,'Path wave first ring');
    end
    else if K = vfkCircle then
    begin
      Check(B.Pixels[50*100+1].R > 250,'Path circle left');
      Check(B.Pixels[50*100+98].B > 250,'Path circle right');
    end
    else if K in [vfkRadial,vfkSquare] then
    begin
      Check(B.Pixels[5050].R > 240,'Path radial center');
      Check(B.Pixels[0].B > 240,'Path radial corner');
    end
    else
    begin
      Check(B.Pixels[50].R > 240,'Path gradient top');
      Check(B.Pixels[9950].B > 240,'Path gradient bottom');
    end;
    Check(TryCreateVectArtMifFromDocument(D,Saved,Err),Err);
    Check(TryLoadVectArtDocumentFromMif(Saved,E,Err),Err);
    Check(TVectArtPathLayer(E[2]).FillStyle.Kind = K,'Path MIF fill');
    FreeAndNil(Saved);
    Check(D.RemovePath(2,PathData),'Remove path');
    Check(PathData.FillStyle.Kind = K,'Removed path fill snapshot');
    end;
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
      Check(Report.Compatibility <> mecUnsupported,'Embedded texture MIF is supported');
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
    FreeAndNil(C); FreeAndNil(Saved);
    Check(Reader.TryReadFile('mif\四角_グラデーション_放射状.mif',C,Err),Err);
    Check(TryLoadVectArtDocumentFromMif(C,E,Err),Err);
    Check(TVectArtRectangleLayer(E[1]).FillStyle.Kind = vfkRadial,'WebArt radial import');
    Check(TVectArtRectangleLayer(E[1]).FillColor = clRed,'WebArt radial color1');
    Check(TVectArtRectangleLayer(E[1]).FillStyle.Color2 = clBlue,'WebArt radial color2');
    Check(TryCreateVectArtMifFromDocument(E,C,Saved,Err),Err);
    Check(TryLoadVectArtDocumentFromMif(Saved,D,Err),Err);
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkRadial,'WebArt radial roundtrip');
    Check(TryReadPngString(Saved[4].Data,'waDA','texture object type',TextureKind) and
      (TextureKind = 'gradation radiate'),'Native radial attribute');
    Check(CreateVectArtMifContainerWriter.TryWriteFile(Saved,
      ExtractFilePath(ParamStr(0))+'radial-webart-roundtrip.mif',Err),Err);
    FreeAndNil(Saved);
    // 元アプリの180x100サンプル。上辺中央と左辺中央は同じ色にならない。
    R.Bounds := RectF(0,0,180,100); R.FillStyle.Kind := vfkRadial;
    R.FillStyle.Color2 := clBlue;
    FreeAndNil(D); D := TVectArtDocument.Create; D.InsertRectangle(1,R);
    D.CanvasLayer.Width := 180; D.CanvasLayer.Height := 100;
    RenderVectArtDocument(D,B,180,100);
    Check(Abs(Integer(B.Pixels[1*180+90].R)-133) <= 4,'WebArt radial top reference');
    Check(Abs(Integer(B.Pixels[50*180+1].R)-34) <= 4,'WebArt radial left reference');
    Check(Abs(Integer(B.Pixels[50*180+45].R)-143) <= 4,'WebArt radial quarter reference');
    Check(TryCreateVectArtSvg(D,Svg,Err),Err);
    Check(Pos('gradientUnits="userSpaceOnUse"',Svg)>0,'SVG circular coordinates');
    R.Shape := vpsEllipse; R.Bounds := RectF(0,0,160,80);
    R.FillStyle.Kind := vfkRadial; R.FillStyle.Color2 := clBlue;
    FreeAndNil(D); D := TVectArtDocument.Create; D.InsertRectangle(1,R);
    Check(TryCreateVectArtMifFromDocument(D,Saved,Err),Err);
    Check(TryLoadVectArtDocumentFromMif(Saved,E,Err),Err);
    Check(TVectArtRectangleLayer(E[1]).Shape = vpsEllipse,'Radial ellipse shape');
    Check(TVectArtRectangleLayer(E[1]).FillStyle.Kind = vfkRadial,'Radial ellipse fill');
    FreeAndNil(C); FreeAndNil(Saved);
    Check(Reader.TryReadFile('mif\四角_グラデーション_円形.mif',C,Err),Err);
    Check(TryLoadVectArtDocumentFromMif(C,E,Err),Err);
    Check(TVectArtRectangleLayer(E[1]).FillStyle.Kind = vfkCircle,'WebArt circle import');
    Check(TVectArtRectangleLayer(E[1]).FillColor = clRed,'Circle color1');
    Check(TVectArtRectangleLayer(E[1]).FillStyle.Color2 = clBlue,'Circle color2');
    Check(TryCreateVectArtMifFromDocument(E,C,Saved,Err),Err);
    Check(TryReadPngString(Saved[4].Data,'waDA','texture object type',TextureKind) and
      (TextureKind = 'gradation circle'),'Native circle attribute');
    Check(CreateVectArtMifContainerWriter.TryWriteFile(Saved,
      ExtractFilePath(ParamStr(0))+'circle-webart-roundtrip.mif',Err),Err);
    Check(TryLoadVectArtDocumentFromMif(Saved,D,Err),Err);
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkCircle,'Circle saved kind');
    R.Shape := vpsRectangle; R.Bounds := RectF(0,0,180,100);
    R.FillStyle.Kind := vfkCircle;
    FreeAndNil(D); D := TVectArtDocument.Create; D.InsertRectangle(1,R);
    D.CanvasLayer.Width := 180; D.CanvasLayer.Height := 100;
    RenderVectArtDocument(D,B,180,100);
    Check(Abs(Integer(B.Pixels[181].R)-214) <= 3,'WebArt circle top-left reference');
    Check(Abs(Integer(B.Pixels[270].R)-127) <= 3,'WebArt circle top-center reference');
    Check(B.Pixels[50*180+1].R > 250,'WebArt circle left reference');
    FreeAndNil(C); FreeAndNil(Saved);
    Check(Reader.TryReadFile('mif\四角_グラデーション_角形.mif',C,Err),Err);
    Check(TryLoadVectArtDocumentFromMif(C,E,Err),Err);
    Check(TVectArtRectangleLayer(E[1]).FillStyle.Kind = vfkSquare,'WebArt square import');
    Check(TVectArtRectangleLayer(E[1]).FillColor = clRed,'Square color1');
    Check(TVectArtRectangleLayer(E[1]).FillStyle.Color2 = clBlue,'Square color2');
    Check(TryCreateVectArtMifFromDocument(E,C,Saved,Err),Err);
    Check(TryReadPngString(Saved[4].Data,'waDA','texture object type',TextureKind) and
      (TextureKind = 'gradation square'),'Native square attribute');
    Check(CreateVectArtMifContainerWriter.TryWriteFile(Saved,
      ExtractFilePath(ParamStr(0))+'square-webart-roundtrip.mif',Err),Err);
    Check(TryLoadVectArtDocumentFromMif(Saved,D,Err),Err);
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkSquare,'Square saved kind');
    R.Shape := vpsRectangle; R.Bounds := RectF(0,0,180,100);
    R.FillStyle.Kind := vfkSquare;
    FreeAndNil(D); D := TVectArtDocument.Create; D.InsertRectangle(1,R);
    D.CanvasLayer.Width := 180; D.CanvasLayer.Height := 100;
    RenderVectArtDocument(D,B,180,100);
    Check(Abs(Integer(B.Pixels[181].R)-2) <= 3,'WebArt square top-left reference');
    Check(Abs(Integer(B.Pixels[270].R)-5) <= 3,'WebArt square top-center reference');
    Check(B.Pixels[50*180+90].R = 255,'WebArt square center reference');
    FreeAndNil(C); FreeAndNil(Saved);
    Check(Reader.TryReadFile('mif\四角_グラデーション_波状_5.mif',C,Err),Err);
    Check(TryLoadVectArtDocumentFromMif(C,E,Err),Err);
    Check(TVectArtRectangleLayer(E[1]).FillStyle.Kind = vfkWave,'WebArt wave import');
    Check(TVectArtRectangleLayer(E[1]).FillColor = clRed,'Wave color1');
    Check(TVectArtRectangleLayer(E[1]).FillStyle.Color2 = clBlue,'Wave color2');
    Check(TryCreateVectArtMifFromDocument(E,C,Saved,Err),Err);
    Check(TryReadPngString(Saved[4].Data,'waDA','texture object type',TextureKind) and
      (TextureKind = 'gradation wave'),'Native wave attribute');
    Check(CreateVectArtMifContainerWriter.TryWriteFile(Saved,
      ExtractFilePath(ParamStr(0))+'wave-webart-roundtrip.mif',Err),Err);
    Check(TryLoadVectArtDocumentFromMif(Saved,D,Err),Err);
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkWave,'Wave saved kind');
    Check(TVectArtRectangleLayer(D[1]).FillStyle.WaveCount = 5,'Wave saved count');
    R.Shape := vpsRectangle; R.Bounds := RectF(0,0,180,100);
    R.FillStyle.Kind := vfkWave; R.FillStyle.WaveCount := 5;
    FreeAndNil(D); D := TVectArtDocument.Create; D.InsertRectangle(1,R);
    D.CanvasLayer.Width := 180; D.CanvasLayer.Height := 100;
    RenderVectArtDocument(D,B,180,100);
    Check(Abs(Integer(B.Pixels[181].R)-244) <= 3,'WebArt wave top-left reference');
    Check(Abs(Integer(B.Pixels[270].R)-34) <= 3,'WebArt wave top-center reference');
    Check(B.Pixels[50*180+90].R = 255,'WebArt wave center reference');
    for TestAngle in [0,1,3,5,10] do
    begin
      Fill := Default(TVectArtFillStyle); Fill.Kind := vfkWave;
      Fill.Color2 := clBlue; Fill.WaveCount := TestAngle;
      Cmd := TVectArtFillCommand.Create(D,1,clRed,Fill);
      try
        Cmd.Execute;
        Check(TryDeserializeVectArtDocument(SerializeVectArtDocument(D),E,Err),Err);
        Check(TVectArtRectangleLayer(E[1]).FillStyle.WaveCount = TestAngle,'JSON wave count');
        Check(TryCreateVectArtSvg(D,Svg,Err),Err);
        TFile.WriteAllText(FileName,Svg,TEncoding.UTF8);
        Check(TryLoadVectArtDocumentFromSvgFile(FileName,E,Err),Err);
        Check(TVectArtRectangleLayer(E[1]).FillStyle.WaveCount = TestAngle,'SVG wave count');
        FreeAndNil(Saved);
        Check(TryCreateVectArtMifFromDocument(D,Saved,Err),Err);
        Check(TryLoadVectArtDocumentFromMif(Saved,E,Err),Err);
        Check(TVectArtRectangleLayer(E[1]).FillStyle.WaveCount = TestAngle,'MIF wave count');
        Cmd.Undo;
        Check(TVectArtRectangleLayer(D[1]).FillStyle.WaveCount = 5,'Undo wave count');
        Cmd.Execute; Cmd.Undo;
      finally Cmd.Free; end;
    end;
    FreeAndNil(C); FreeAndNil(Saved);
    Check(Reader.TryReadFile('mif\四角_グラデーション_スペクトル_赤.mif',C,Err),Err);
    Check(TryLoadVectArtDocumentFromMif(C,E,Err),Err);
    Check(TVectArtRectangleLayer(E[1]).FillStyle.Kind = vfkSpectrum,'Spectrum import kind');
    Check(TVectArtRectangleLayer(E[1]).FillStyle.Angle = 45,'Spectrum import angle');
    Check(TVectArtRectangleLayer(E[1]).FillColor = clRed,'Spectrum import start color');
    Check(TryCreateVectArtMifFromDocument(E,C,Saved,Err),Err);
    Check(TryReadPngString(Saved[4].Data,'waDA','texture object type',TextureKind) and
      (TextureKind = 'spectrum linear'),'Native spectrum attribute');
    Check(CreateVectArtMifContainerWriter.TryWriteFile(Saved,
      ExtractFilePath(ParamStr(0))+'spectrum-webart-roundtrip.mif',Err),Err);
    Check(TryLoadVectArtDocumentFromMif(Saved,D,Err),Err);
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind = vfkSpectrum,'Spectrum saved kind');
    R.Shape := vpsRectangle; R.Bounds := RectF(0,0,180,100);
    R.FillStyle.Kind := vfkSpectrum; R.FillStyle.Angle := 45;
    FreeAndNil(D); D := TVectArtDocument.Create; D.InsertRectangle(1,R);
    D.CanvasLayer.Width := 180; D.CanvasLayer.Height := 100;
    RenderVectArtDocument(D,B,180,100);
    Check(Abs(Integer(B.Pixels[181].G)-10) <= 2,'Spectrum top-left reference');
    Check(Abs(Integer(B.Pixels[270].R)-12) <= 2,'Spectrum top-center reference');
    Check(Abs(Integer(B.Pixels[50*180+1].R)-231) <= 2,'Spectrum left reference');
    for TestAngle in [0,45,90,135,180,270,315] do
    begin
      Fill := Default(TVectArtFillStyle); Fill.Kind := vfkSpectrum; Fill.Angle := TestAngle;
      Cmd := TVectArtFillCommand.Create(D,1,clRed,Fill);
      try
        Cmd.Execute;
        Check(TryCreateVectArtSvg(D,Svg,Err),Err);
        Check(Pos('<linearGradient',Svg)>0,'Spectrum SVG native gradient');
        Check(Pos('<pattern',Svg)=0,'Spectrum SVG should stay vector');
        TFile.WriteAllText(FileName,Svg,TEncoding.UTF8);
        Check(TryLoadVectArtDocumentFromSvgFile(FileName,E,Err),Err);
        Check(TVectArtRectangleLayer(E[1]).FillStyle.Kind = vfkSpectrum,'SVG spectrum kind');
        Check(TVectArtRectangleLayer(E[1]).FillStyle.Angle = TestAngle,'SVG spectrum angle');
        FreeAndNil(Saved);
        Check(TryCreateVectArtMifFromDocument(D,Saved,Err),Err);
        Check(TryLoadVectArtDocumentFromMif(Saved,E,Err),Err);
        Check(TVectArtRectangleLayer(E[1]).FillStyle.Angle = TestAngle,'MIF spectrum angle');
        Cmd.Undo;
        Check(TVectArtRectangleLayer(D[1]).FillStyle.Angle = 45,'Spectrum angle Undo');
      finally Cmd.Free; end;
    end;
    Writeln('PASS gradient pixels, Undo, JSON/SVG/MIF roundtrips and WebArt fixture');
  finally Saved.Free; C.Free; B.Free; E.Free; D.Free; TTextRendererSkiaRuntime.Release; end;
end.
