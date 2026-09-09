// 埋込画像の実寸配置と、線・塗り・文字の編集可能な保存往復を検証する。
program TexturePaintTests;
{$APPTYPE CONSOLE}
uses System.Classes, System.SysUtils, System.Types, System.IOUtils, System.Skia,
  Winapi.Windows, Vcl.Graphics, Vcl.Imaging.pngimage,
  TextRendererSkiaBootstrap, TextRendererSkiaRuntime,
  VectArtDesignerDocument, VectArtDesignerFillCommand, VectArtDesignerFillPaint,
  VectArtDesignerRenderer, VectArtDesignerDocumentJson,
  VectArtDesignerMifContainer, VectArtDesignerMifDocument, VectArtDesignerMifPngMetadata,
  VectArtDesignerSvgDocument;
procedure Check(V: Boolean; const S: string);
begin if not V then raise Exception.Create(S); end;
function StyleOf(D: TVectArtDocument; Stroke: Boolean): TVectArtFillStyle;
begin
  if Stroke then Exit(D[1].StrokePaint);
  if D[1] is TVectArtTextLayer then Exit(TVectArtTextLayer(D[1]).FillStyle);
  Result := TVectArtRectangleLayer(D[1]).FillStyle;
end;
procedure CheckImage(const A,B: TBytes);
var X,Y: Integer; IA,IB: TPngImage; SA,SB: TBytesStream;
begin
  IA := TPngImage.Create; IB := TPngImage.Create;
  SA := TBytesStream.Create(A); SB := TBytesStream.Create(B);
  try
    IA.LoadFromStream(SA); IB.LoadFromStream(SB);
    Check((IA.Width=IB.Width) and (IA.Height=IB.Height),'Texture dimensions changed');
    for Y := 0 to IA.Height-1 do
      for X := 0 to IA.Width-1 do Check(IA.Pixels[X,Y]=IB.Pixels[X,Y],'Texture pixel changed');
  finally SB.Free; SA.Free; IB.Free; IA.Free; end;
end;
procedure CheckTilePixels(const FileName: string);
var Png: TPngImage;
begin
  Png := TPngImage.Create;
  try
    Png.LoadFromFile(FileName);
    Check(GetRValue(Png.Pixels[4,3])=255,'Texture origin red');
    Check(GetBValue(Png.Pixels[5,3])=255,'Texture adjacent blue');
    Check(Png.Pixels[4,3]=Png.Pixels[24,3],'Texture repeats horizontally');
    Check(Png.Pixels[4,3]=Png.Pixels[4,19],'Texture repeats vertically');
    Check(GetGValue(Png.Pixels[4,4])=255,'Texture second row');
    Check(Abs(Integer(Png.AlphaScanline[3]^[4])-128)<=1,'Texture opacity');
  finally Png.Free; end;
end;
procedure CheckObjectPixels(const A,B: TBytes; Stroke,Text: Boolean);
var X,Y,N: Integer; IA,IB: TPngImage; SA,SB: TBytesStream; CA,CB: TColor;
begin
  IA := TPngImage.Create; IB := TPngImage.Create;
  SA := TBytesStream.Create(A); SB := TBytesStream.Create(B);
  try
    IA.LoadFromStream(SA); IB.LoadFromStream(SB); N := 0;
    Check((IA.Width=IB.Width) and (IA.Height=IB.Height),'Object dimensions changed');
    for Y := 4 to IA.Height-5 do for X := 4 to IA.Width-5 do
    begin
      // 図形境界と字形アンチエイリアスは除き、実際に塗られた内部の色を確認する。
      if Stroke and (X>6) and (X<IA.Width-7) and (Y>6) and (Y<IA.Height-7) then Continue;
      if Text and ((IA.AlphaScanline[Y]^[X]<>255) or (IB.AlphaScanline[Y]^[X]<>255)) then Continue;
      CA := IA.Pixels[X,Y]; CB := IB.Pixels[X,Y];
      Check((Abs(Integer(GetRValue(CA))-GetRValue(CB))<=1) and
        (Abs(Integer(GetGValue(CA))-GetGValue(CB))<=1) and
        (Abs(Integer(GetBValue(CA))-GetBValue(CB))<=1),Format('Object RGB at %d,%d',[X,Y]));
      Inc(N);
    end;
    Check(N>100,'Insufficient native reference pixels');
  finally SB.Free; SA.Free; IB.Free; IA.Free; end;
end;
var D,E: TVectArtDocument; Source,Saved: TVectArtMifContainer;
  Style,Restored: TVectArtFillStyle; Fixture,Err,Root,Svg,Kind: string; Stroke: Boolean;
  FillCmd: TVectArtFillCommand; StrokeCmd: TVectArtStrokePaintCommand;
  Surface: ISkSurface; Paint: ISkPaint; B: TVectArtRenderBuffer;
  R: TVectArtRectangleData; L: TVectArtLineData; P: TVectArtPathData; I: Integer;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  D := TVectArtDocument.Create; E := TVectArtDocument.Create;
  Source := nil; Saved := nil; B := TVectArtRenderBuffer.Create;
  Root := ExtractFilePath(ParamStr(0));
  try
    for Fixture in ['四角','四角枠','文字'] do
    begin
      FreeAndNil(Source); FreeAndNil(Saved); Stroke := Fixture='四角枠';
      Check(CreateVectArtMifContainerReader.TryReadFile('mif\'+Fixture+'_テクスチャ.mif',Source,Err),Err);
      Check(TryLoadVectArtDocumentFromMif(Source,D,Err),Err);
      Style := StyleOf(D,Stroke); Check(Style.Kind=vfkTexture,'Native texture import');
      CheckImage(Style.TexturePng,Source[4+Ord(Stroke)*2].Data);
      Check(TryCreateVectArtMifFromDocument(D,Source,Saved,Err),Err);
      Check(TryReadPngString(Saved[4+Ord(Stroke)*2].Data,'waDA','texture object type',Kind) and
        (Kind='image'),'Native image attribute');
      CheckObjectPixels(Source[3].Data,Saved[3].Data,Stroke,Fixture='文字');
      Check(CreateVectArtMifContainerWriter.TryWriteFile(Saved,Root+Fixture+'-texture.mif',Err),Err);
      Check(TryLoadVectArtDocumentFromMif(Saved,E,Err),Err);
      Restored := StyleOf(E,Stroke); Check(Restored.Kind=vfkTexture,'MIF texture');
      CheckImage(Style.TexturePng,Restored.TexturePng);
      Check(TryDeserializeVectArtDocument(SerializeVectArtDocument(D),E,Err),Err);
      Restored := StyleOf(E,Stroke); Check(Restored.Kind=vfkTexture,'JSON texture');
      CheckImage(Style.TexturePng,Restored.TexturePng);
      Check(TryCreateVectArtSvg(D,Svg,Err),Err);
      Check(Pos('patternUnits="userSpaceOnUse"',Svg)>0,'SVG native size pattern');
      TFile.WriteAllText(Root+'texture.svg',Svg,TEncoding.UTF8);
      Check(TryLoadVectArtDocumentFromSvgFile(Root+'texture.svg',E,Err),Err);
      Restored := StyleOf(E,Stroke); Check(Restored.Kind=vfkTexture,'SVG texture');
      CheckImage(Style.TexturePng,Restored.TexturePng);
      if Stroke then
      begin
        StrokeCmd := TVectArtStrokePaintCommand.Create(D,1,clBlack,Default(TVectArtFillStyle));
        try StrokeCmd.Execute; Check(StyleOf(D,True).Kind=vfkSolid,'Stroke edit');
          StrokeCmd.Undo; Check(StyleOf(D,True).Kind=vfkTexture,'Stroke undo');
        finally StrokeCmd.Free; end;
      end
      else
      begin
        FillCmd := TVectArtFillCommand.Create(D,1,clBlack,Default(TVectArtFillStyle));
        try FillCmd.Execute; Check(StyleOf(D,False).Kind=vfkSolid,'Fill edit');
          FillCmd.Undo; Check(StyleOf(D,False).Kind=vfkTexture,'Fill undo');
        finally FillCmd.Free; end;
      end;
      RenderVectArtFillThumbnail(D,1,B,120,80);
      Writeln('PASS native texture ',Fixture);
    end;
    // 小画像が実寸で繰り返され、移動しても図形左上との対応を維持する。
    Surface := TSkSurface.MakeRaster(2,2); Surface.Canvas.Clear($FFFF0000);
    Paint := TSkPaint.Create; Paint.Color := $FF0000FF;
    Surface.Canvas.DrawRect(RectF(1,0,2,1),Paint);
    Paint.Color := $FF00FF00; Surface.Canvas.DrawRect(RectF(0,1,2,2),Paint);
    Surface.MakeImageSnapshot.EncodeToFile(Root+'small-texture.png');
    Style.Kind := vfkTexture; Style.TexturePng := TFile.ReadAllBytes(Root+'small-texture.png');
    Paint := TSkPaint.Create; Surface := TSkSurface.MakeRaster(30,20);
    SetFillPaint(Paint,clWhite,Style,RectF(4,3,24,18),0.5);
    Surface.Canvas.Clear(0); Surface.Canvas.DrawPaint(Paint);
    Surface.MakeImageSnapshot.EncodeToFile(Root+'texture-opacity.png');
    CheckTilePixels(Root+'texture-opacity.png');
    FreeAndNil(D); D := TVectArtDocument.Create;
    R := Default(TVectArtRectangleData); R.Bounds := RectF(5,5,105,65);
    R.Visible := True; R.Opacity := 1; R.Filled := True; R.FillStyle := Style;
    R.StrokePaint := Style; R.StrokeWidth := 4; D.InsertRectangle(1,R);
    R.Shape := vpsEllipse; D.InsertRectangle(2,R);
    L := Default(TVectArtLineData); L.Visible := True; L.Opacity := 1;
    L.StartPoint := PointF(10,90); L.EndPoint := PointF(110,90); L.StrokeWidth := 6;
    L.StrokePaint := Style; D.InsertLine(3,L);
    P := Default(TVectArtPathData); P.Visible := True; P.Opacity := 1;
    P.Points := [PointF(10,110),PointF(110,110),PointF(100,150)];
    P.Closed := True; P.Filled := True; P.FillStyle := Style;
    P.StrokePaint := Style; P.StrokeWidth := 4; D.InsertPath(4,P);
    FreeAndNil(Saved); Check(TryCreateVectArtMifFromDocument(D,Saved,Err),Err);
    Check(TryLoadVectArtDocumentFromMif(Saved,E,Err),Err);
    for I := 1 to 4 do Check(E[I].StrokePaint.Kind=vfkTexture,'Shape stroke texture');
    Check(TVectArtPathLayer(E[4]).FillStyle.Kind=vfkTexture,'Path fill texture');
    Check(D.RemoveRectangle(1,R),'Delete texture shape'); D.InsertRectangle(1,R);
    Check(TVectArtRectangleLayer(D[1]).FillStyle.Kind=vfkTexture,'Restore texture shape');
    RenderVectArtDocument(D,B,640,480);
    Writeln('PASS texture MIF/JSON/SVG, native pixels, Undo, thumbnails, Line/Ellipse/Path');
  finally Paint := nil; Surface := nil; B.Free; Saved.Free; Source.Free; E.Free; D.Free;
    TTextRendererSkiaRuntime.Release; end;
end.
