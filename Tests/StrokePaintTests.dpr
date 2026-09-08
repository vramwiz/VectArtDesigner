// 線の塗りを図形全体で共有し、編集・保存・再描画で失わないことを検証する。
program StrokePaintTests;
{$APPTYPE CONSOLE}
uses System.Classes, Winapi.Windows, Vcl.Imaging.pngimage, System.SysUtils, System.Types, System.IOUtils, Vcl.Graphics,
  TextRendererSkiaBootstrap, TextRendererSkiaRuntime,
  VectArtDesignerDocument, VectArtDesignerFillCommand,
  VectArtDesignerRenderer, VectArtDesignerDocumentJson,
  VectArtDesignerMifContainer, VectArtDesignerMifDocument, VectArtDesignerSvgDocument;
procedure Check(Value: Boolean; const S: string);
begin if not Value then raise Exception.Create(S); end;
procedure CheckNativePixels(Original, Exported: TVectArtMifContainer);
var A,B: TPngImage; SA,SB: TBytesStream; P: TPoint; CA,CB: TColor;
begin
  A := TPngImage.Create; B := TPngImage.Create;
  SA := TBytesStream.Create(Original[3].Data); SB := TBytesStream.Create(Exported[3].Data);
  try
    A.LoadFromStream(SA); B.LoadFromStream(SB);
    Check((A.Width = B.Width) and (A.Height = B.Height),'WebArt PNG dimensions');
    // 枠の色領域で比較し、輪郭アンチエイリアスの差を混ぜない。
    for P in [Point(5,5),Point(A.Width div 2,5),Point(5,A.Height div 2),
      Point(A.Width-6,A.Height div 2),Point(A.Width div 2,A.Height-6)] do
    begin
      CA := A.Pixels[P.X,P.Y]; CB := B.Pixels[P.X,P.Y];
      Check((Abs(Integer(GetRValue(CA))-GetRValue(CB)) <= 1) and
        (Abs(Integer(GetGValue(CA))-GetGValue(CB)) <= 1) and
        (Abs(Integer(GetBValue(CA))-GetBValue(CB)) <= 1),'WebArt stroke RGB reference');
    end;
  finally SB.Free; SA.Free; B.Free; A.Free; end;
end;
var D,E: TVectArtDocument; R: TVectArtRectangleData; L: TVectArtLineData;
    P: TVectArtPathData; Style: TVectArtFillStyle; K: TVectArtFillKind;
    Cmd: TVectArtStrokePaintCommand; B: TVectArtRenderBuffer;
    Saved,Source: TVectArtMifContainer; Err,Svg,Root,Fixture: string; I: Integer;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  D := TVectArtDocument.Create; E := TVectArtDocument.Create;
  B := TVectArtRenderBuffer.Create; Saved := nil; Source := nil;
  Root := ExtractFilePath(ParamStr(0));
  try
    D.CanvasLayer.Width := 180; D.CanvasLayer.Height := 260;
    R := Default(TVectArtRectangleData); R.Bounds := RectF(5,5,175,100);
    R.Visible := True; R.Opacity := 1; R.Filled := True;
    R.FillColor := clWhite; R.StrokeColor := clRed; R.StrokeWidth := 10;
    D.InsertRectangle(1,R);
    L := Default(TVectArtLineData); L.StartPoint := PointF(10,130); L.EndPoint := PointF(160,130);
    L.Visible := True; L.Opacity := 1; L.StrokeColor := clRed; L.StrokeWidth := 12;
    D.InsertLine(2,L);
    P := Default(TVectArtPathData); P.Points := [PointF(10,160),PointF(160,160),PointF(160,240),PointF(10,240)];
    P.Visible := True; P.Opacity := 1; P.Closed := True; P.Filled := True;
    P.FillColor := clWhite; P.StrokeColor := clRed; P.StrokeWidth := 10;
    D.InsertPath(3,P);
    for K in [vfkSolid,vfkLinearHorizontal,vfkLinearVertical,vfkRadial,vfkCircle,vfkSquare,vfkWave,vfkSpectrum] do
    begin
      Style := Default(TVectArtFillStyle); Style.Kind := K; Style.Color2 := clBlue;
      Style.WaveCount := 5; Style.Angle := 45;
      for I := 1 to 3 do
      begin
        Cmd := TVectArtStrokePaintCommand.Create(D,I,clRed,Style);
        try
          Cmd.Execute;
          Check(D[I].StrokePaint.Kind = K,'Apply stroke');
          Cmd.Undo;
          Cmd.Execute;
        finally Cmd.Free; end;
      end;
      RenderVectArtDocument(D,B,180,260);
      Check((B.Pixels[50*180+90].R = 255) and (B.Pixels[50*180+90].B = 255),'Rectangle interior changed');
      Check((B.Pixels[200*180+90].R = 255) and (B.Pixels[200*180+90].B = 255),'Path interior changed');
      if K = vfkLinearHorizontal then
      begin
        Check(B.Pixels[5*180+10].R > B.Pixels[5*180+165].R,'Top edge shares gradient');
        Check(B.Pixels[95*180+165].B > B.Pixels[5*180+165].B,'Vertical edge shares gradient');
        Check(B.Pixels[130*180+12].R > 230,'Horizontal line start gradient');
        Check(B.Pixels[130*180+155].B > 230,'Horizontal line end gradient');
      end;
      Check(TryDeserializeVectArtDocument(SerializeVectArtDocument(D),E,Err),Err);
      for I := 1 to 3 do Check(E[I].StrokePaint.Kind = K,'JSON stroke paint');
      Check(TryCreateVectArtSvg(D,Svg,Err),Err);
      TFile.WriteAllText(Root+'stroke-test.svg',Svg,TEncoding.UTF8);
      Check(TryLoadVectArtDocumentFromSvgFile(Root+'stroke-test.svg',E,Err),Err);
      for I := 1 to 3 do Check(E[I].StrokePaint.Kind = K,'SVG stroke paint');
      FreeAndNil(Saved);
      Check(TryCreateVectArtMifFromDocument(D,Saved,Err),Err);
      Check(TryLoadVectArtDocumentFromMif(Saved,E,Err),Err);
      for I := 1 to 3 do Check(E[I].StrokePaint.Kind = K,'MIF stroke paint');
      Check(TVectArtRectangleLayer(E[1]).FillStyle.Kind = vfkSolid,'MIF interior style');
      Check(TVectArtRectangleLayer(E[1]).FillColor = clWhite,'MIF interior color');
      RenderVectArtFillThumbnail(D,2,B,90,50);
    end;
    Check(D.RemoveRectangle(1,R),'Remove rectangle');
    Check(R.StrokePaint.Kind = vfkSpectrum,'Deletion snapshot lost stroke');
    D.InsertRectangle(1,R);
    for Fixture in ['線形','円形','角形','放射状','波状','スペクトラム_45度'] do
    begin
      FreeAndNil(Source); FreeAndNil(Saved);
      Check(CreateVectArtMifContainerReader.TryReadFile('mif\四角枠_グラデーション_'+Fixture+'.mif',Source,Err),Err);
      Check(TryLoadVectArtDocumentFromMif(Source,E,Err),Err);
      if Fixture = '線形' then K := vfkLinearHorizontal
      else if Fixture = '円形' then K := vfkCircle
      else if Fixture = '角形' then K := vfkSquare
      else if Fixture = '放射状' then K := vfkRadial
      else if Fixture = '波状' then K := vfkWave
      else K := vfkSpectrum;
      Check(E[1].StrokePaint.Kind = K,'WebArt stroke import');
      Check(TVectArtRectangleLayer(E[1]).FillStyle.Kind = vfkSolid,'WebArt fill altered');
      Check(TryCreateVectArtMifFromDocument(E,Source,Saved,Err),Err);
      Check(CreateVectArtMifContainerWriter.TryWriteFile(Saved,Root+'stroke-'+Fixture+'-roundtrip.mif',Err),Err);
      CheckNativePixels(Source,Saved);
      Check(TryLoadVectArtDocumentFromMif(Saved,D,Err),Err);
      Check(D[1].StrokePaint.Kind = K,'WebArt stroke roundtrip');
    end;
    Writeln('PASS stroke paints: rendering, line, path, thumbnails, Undo, JSON/SVG/MIF and WebArt fixtures');
  finally Source.Free; Saved.Free; B.Free; E.Free; D.Free; TTextRendererSkiaRuntime.Release; end;
end.
