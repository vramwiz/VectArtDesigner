// 色ポップアップのキャッシュ画像と方向矢印の描画を担当する。
// キャッシュ寿命と更新判定は呼出し側が管理し、DocumentやUndoへは接続しない。
unit VectArtDesignerPaintPreview;
interface
uses Vcl.ExtCtrls, Vcl.Graphics;
procedure DrawPaintPreview(Preview: TPaintBox; Bitmap: Vcl.Graphics.TBitmap;
  var Dirty: Boolean; Mode,Gradient,Angle,WaveCount: Integer; Color1,Color2: TColor; Texture: TPicture);
implementation
uses System.SysUtils, System.Types, System.Math, System.UITypes, System.Skia,
  VectArtDesignerDocument, VectArtDesignerFillPaint;
procedure DrawPaintPreview(Preview: TPaintBox; Bitmap: Vcl.Graphics.TBitmap;
  var Dirty: Boolean; Mode,Gradient,Angle,WaveCount: Integer; Color1,Color2: TColor; Texture: TPicture);
var
  Surface: ISkSurface;
  Paint: ISkPaint;
  Info: TSkImageInfo;
  Fill: TVectArtFillStyle;
  W, H, X, Y: Integer;
  DX,DY,L: Double;
  Tail,Tip,Wing1,Wing2: TPoint;
  procedure ArrowStroke(Color: TColor; Width: Integer);
  begin
    Preview.Canvas.Pen.Color := Color; Preview.Canvas.Pen.Width := Width;
    Preview.Canvas.MoveTo(Tail.X,Tail.Y); Preview.Canvas.LineTo(Tip.X,Tip.Y);
    Preview.Canvas.Polyline([Wing1,Tip,Wing2]);
  end;
begin
  W := Preview.Width; H := Preview.Height;
  if (W <= 0) or (H <= 0) then Exit;
  if (Bitmap.Width <> W) or (Bitmap.Height <> H) then
  begin
    Bitmap.SetSize(W,H);
    Dirty := True;
  end;
  if Dirty then
  begin
    if (Mode = 2) and (Texture.Graphic <> nil) then
    begin
      Bitmap.Canvas.Brush.Color := Color1;
      Bitmap.Canvas.FillRect(Rect(0,0,W,H));
      // 本描画と同じ実寸のタイルを表示する。
      if (Texture.Width > 0) and (Texture.Height > 0) then
      begin
        Y := 0;
        while Y < H do
        begin
          X := 0;
          while X < W do
          begin Bitmap.Canvas.Draw(X,Y,Texture.Graphic); Inc(X,Texture.Width); end;
          Inc(Y,Texture.Height);
        end;
      end;
    end
    else if Mode <> 1 then
    begin
      Bitmap.Canvas.Brush.Color := Color1;
      Bitmap.Canvas.FillRect(Rect(0,0,W,H));
    end
    else
    begin
      // SkiaへBGRAバッファを直接渡し、画素単位のGDI呼出しを避ける。
      // VCLの下から上への行順を、塗りの上から下への座標へ補正する。
      Info := TSkImageInfo.Create(W,H,TSkColorType.BGRA8888,TSkAlphaType.Premul);
      Surface := TSkSurface.MakeRasterDirect(Info,Bitmap.ScanLine[H-1],W*4);
      if Surface = nil then raise EInvalidOp.Create('Cannot create paint preview surface');
      Surface.Canvas.Translate(0,H);
      Surface.Canvas.Scale(1,-1);
      Paint := TSkPaint.Create;
      Fill := Default(TVectArtFillStyle);
      if Gradient = 5 then Fill.Kind := vfkSpectrum
      else if Gradient = 4 then Fill.Kind := vfkWave
      else if Gradient = 3 then Fill.Kind := vfkSquare
      else if Gradient = 2 then Fill.Kind := vfkCircle
      else if Gradient = 1 then Fill.Kind := vfkRadial
      else if Angle = 90 then Fill.Kind := vfkLinearVertical
      else Fill.Kind := vfkLinearHorizontal;
      Fill.Color2 := Color2; Fill.Angle := Angle; Fill.WaveCount := WaveCount;
      SetFillPaint(Paint,Color1,Fill,RectF(0,0,W,H),1);
      Surface.Canvas.DrawPaint(Paint);
      Surface := nil;
    end;
    Dirty := False;
  end;
  Preview.Canvas.Draw(0,0,Bitmap);
  // 方向矢印は表示面だけへ重ね、保存用の塗り画像に混入させない。
  if (Mode = 1) and (Gradient in [0,5]) then
  begin
    DX := Cos(DegToRad(Angle)); DY := Sin(DegToRad(Angle));
    L := Min(W,H)*0.32;
    Tail := Point(Round(W/2-DX*L),Round(H/2-DY*L));
    Tip := Point(Round(W/2+DX*L),Round(H/2+DY*L));
    Wing1 := Point(Round(Tip.X-DX*9-DY*5),Round(Tip.Y-DY*9+DX*5));
    Wing2 := Point(Round(Tip.X-DX*9+DY*5),Round(Tip.Y-DY*9-DX*5));
    ArrowStroke(clBlack,5); ArrowStroke(clWhite,2);
    Preview.Canvas.Pen.Width := 1;
  end;
end;
end.
