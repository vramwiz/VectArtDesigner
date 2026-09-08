// 文字全体の色配置、Undo、保存往復と元MIFの色場を検証する。
program TextPaintTests;
{$APPTYPE CONSOLE}
uses System.Classes, Winapi.Windows, Vcl.Imaging.pngimage, Vcl.Graphics, System.SysUtils, System.Types, System.IOUtils, System.Skia, System.Math,
  TextRendererSkiaBootstrap, TextRendererSkiaRuntime,
  VectArtDesignerDocument, VectArtDesignerFillCommand, VectArtDesignerFillPaint,
  VectArtDesignerRenderer, VectArtDesignerDocumentJson,
  VectArtDesignerMifContainer, VectArtDesignerMifDocument, VectArtDesignerSvgDocument;
procedure Check(V: Boolean; const S: string);
begin if not V then raise Exception.Create(S); end;
procedure CheckNativeField(const NativePng: TBytes; const FieldFile: string; Tolerance: Integer; OpaqueOnly: Boolean = False);
var A,B: TPngImage; Stream: TBytesStream; X,Y: Integer; CA,CB: TColor;
begin
  A := TPngImage.Create; B := TPngImage.Create; Stream := TBytesStream.Create(NativePng);
  try
    A.LoadFromStream(Stream); B.LoadFromFile(FieldFile);
    Check((A.Width=B.Width) and (A.Height=B.Height),'Native field dimensions');
    // RGBは透明領域にも保存されているため、字形のラスタライザー差を混ぜず全画素を照合する。
    for Y := 0 to A.Height-1 do for X := 0 to A.Width-1 do
    begin
      if OpaqueOnly and (B.AlphaScanline[Y]^[X] <> 255) then Continue;
      CA := A.Pixels[X,Y]; CB := B.Pixels[X,Y];
      Check((Abs(Integer(GetRValue(CA))-GetRValue(CB))<=Tolerance) and
        (Abs(Integer(GetGValue(CA))-GetGValue(CB))<=Tolerance) and
        (Abs(Integer(GetBValue(CA))-GetBValue(CB))<=Tolerance),'Native text field RGB');
    end;
  finally Stream.Free; B.Free; A.Free; end;
end;
var D,E: TVectArtDocument; Source,Saved: TVectArtMifContainer;
  B: TVectArtRenderBuffer; Layer: TVectArtTextLayer; Data: TVectArtTextData;
  Style: TVectArtFillStyle; Cmd: TVectArtFillCommand;
  FileName,Root,Err,Svg: string; Surface: ISkSurface; Paint: ISkPaint;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  D := TVectArtDocument.Create; E := TVectArtDocument.Create;
  Source := nil; Saved := nil; B := TVectArtRenderBuffer.Create;
  Root := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  try
    for FileName in TDirectory.GetFiles('mif','文字*グラデーション*.mif') do
    begin
      FreeAndNil(Source); FreeAndNil(Saved);
      Check(CreateVectArtMifContainerReader.TryReadFile(FileName,Source,Err),Err);
      Check(TryLoadVectArtDocumentFromMif(Source,D,Err),Err);
      Check(D[1] is TVectArtTextLayer,'Native text import');
      Layer := TVectArtTextLayer(D[1]); Style := Layer.FillStyle;
      Check(Style.Kind <> vfkSolid,'Native text gradient');
      Surface := TSkSurface.MakeRaster(175,85); Paint := TSkPaint.Create;
      SetTextPaint(Paint,Layer.TextColor,Style,175,85,175,85,1);
      Surface.Canvas.DrawRect(RectF(0,0,175,85),Paint);
      Surface.MakeImageSnapshot.EncodeToFile(Root+TPath.GetFileNameWithoutExtension(FileName)+'-field.png');
      CheckNativeField(Source[3].Data,Root+TPath.GetFileNameWithoutExtension(FileName)+'-field.png',
        IfThen(Style.Kind=vfkSquare,2,1));
      Check(Layer.Text='文字','Native terminal newline is not an empty line');
      Check(TryCreateVectArtMifFromDocument(D,Source,Saved,Err),Err);
      Check(CreateVectArtMifContainerWriter.TryWriteFile(Saved,Root+TPath.GetFileName(FileName),Err),Err);
      TFile.WriteAllBytes(Root+'text-export-pixels.png',Saved[3].Data);
      CheckNativeField(Source[3].Data,Root+'text-export-pixels.png',
        IfThen(Style.Kind=vfkSquare,2,1),True);
      Check(TryLoadVectArtDocumentFromMif(Saved,E,Err),Err);
      Check(TVectArtTextLayer(E[1]).FillStyle.Kind=Style.Kind,'MIF text paint');
      Check(TryDeserializeVectArtDocument(SerializeVectArtDocument(D),E,Err),Err);
      Check(TVectArtTextLayer(E[1]).FillStyle.Kind=Style.Kind,'JSON text paint');
      Check(TryCreateVectArtSvg(D,Svg,Err),Err);
      TFile.WriteAllText(Root+'text-paint.svg',Svg,TEncoding.UTF8);
      Check(TryLoadVectArtDocumentFromSvgFile(Root+'text-paint.svg',E,Err),Err);
      Check(TVectArtTextLayer(E[1]).FillStyle.Kind=Style.Kind,'SVG text paint');
      Check(TVectArtTextLayer(E[1]).FillStyle.Color2=Style.Color2,'SVG second color');
      RenderVectArtFillThumbnail(D,1,B,100,60);
      Data := CaptureVectArtTextData(Layer); Data.Text := 'ABC'; D.SetTextData(1,Data);
      Check(Layer.FillStyle.Kind=Style.Kind,'Text edit retains paint');
      Cmd := TVectArtFillCommand.Create(D,1,0,Default(TVectArtFillStyle));
      try Cmd.Execute; Check(Layer.FillStyle.Kind=vfkSolid,'Solid edit');
        Cmd.Undo; Check(Layer.FillStyle.Kind=Style.Kind,'Undo text paint');
      finally Cmd.Free; end;
      Check(D.RemoveText(1,Data),'Delete text'); D.InsertText(1,Data);
      Check(TVectArtTextLayer(D[1]).FillStyle.Kind=Style.Kind,'Restore text paint');
    end;
    Writeln('PASS text paint: native import, render, Undo, text edits, delete, MIF/JSON/SVG');
  finally Paint := nil; Surface := nil; B.Free; Saved.Free; Source.Free; E.Free; D.Free;
    TTextRendererSkiaRuntime.Release; end;
end.
