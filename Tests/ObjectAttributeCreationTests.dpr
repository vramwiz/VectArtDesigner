// 分類間の引継ぎ境界、配置保持、開始時スナップショットとUndoを実際の作成操作で検証する。
program ObjectAttributeCreationTests;
{$APPTYPE CONSOLE}
uses System.Classes, System.SysUtils, System.Types, System.IOUtils, Vcl.Graphics, Vcl.Controls,
  VectArtDesignerDocument, VectArtDesignerEditorState, VectArtDesignerEditHistory,
  VectArtDesignerShapeCreation, VectArtDesignerObjectAttributes,
  VectArtDesignerLayerOperations;
procedure Check(Value: Boolean; const Msg: string);
begin if not Value then raise Exception.Create(Msg); end;
var
  D: TVectArtDocument;
  S: TVectArtEditorState;
  H: TVectArtEditHistory;
  C: TVectArtShapeCreation;
  Ops: TVectArtLayerOperations;
  R: TVectArtRectangleData;
  L: TVectArtLineData;
  P: TVectArtPathData;
  T: TVectArtTextData;
  A, B: TVectArtObjectAttributes;
  Tool: TVectArtEditorTool;
  Source, N, Cases: Integer;
  Expected: TVectArtAttributeCategory;
begin
  D := TVectArtDocument.Create; S := TVectArtEditorState.Create;
  H := TVectArtEditHistory.Create; C := TVectArtShapeCreation.Create;
  Ops := TVectArtLayerOperations.Create;
  try
    R := Default(TVectArtRectangleData);
    R.Bounds := RectF(300,300,400,400); R.Filled := True;
    R.FillColor := clRed; R.StrokeColor := clBlue; R.StrokeWidth := 7;
    R.StrokeStyle := vssLongDash; R.Opacity := 0.6; R.Visible := True;
    R.RotationDegrees := 30; R.Name := 'Source rectangle';
    R.FillStyle.Kind := vfkTexture;
    R.FillStyle.TexturePng := TFile.ReadAllBytes('Icon/icon.png');
    R.StrokePaint.Kind := vfkWave; R.StrokePaint.Angle := 37;
    R.StrokePaint.Color2 := clYellow; R.StrokePaint.WaveCount := 4;
    D.InsertRectangle(1,R);
    A := CaptureVectArtObjectAttributes(D[1]);
    P := Default(TVectArtPathData); P.Closed := True;
    P.Points := [PointF(300,300),PointF(400,300),PointF(350,400)];
    P.LineJoin := vljRound; P.AntiAlias := True; P.Visible := True;
    ApplyVectArtObjectAttributes(A,P); D.InsertPath(2,P);
    L := Default(TVectArtLineData); L.StartPoint := PointF(300,300);
    L.EndPoint := PointF(400,400); L.StrokeColor := clGreen; L.StrokeWidth := 9;
    L.StrokeStyle := vssDotted; L.LineCap := vlcRound; L.LineJoin := vljBevel;
    L.AntiAlias := True; L.StartMarker := vlmCircle; L.EndMarker := vlmArrow;
    L.StartMarkerSize := 3; L.EndMarkerSize := 6; L.Opacity := 0.7;
    L.StrokePaint := R.FillStyle; L.Visible := True; D.InsertLine(3,L);
    P.Closed := False; ApplyVectArtObjectAttributes(CaptureVectArtObjectAttributes(D[3]),P);
    D.InsertPath(4,P);
    T := Default(TVectArtTextData); T.Bounds := RectF(300,300,400,400);
    T.Text := 'source content'; T.FontFamily := 'Arial'; T.FontSize := 36;
    T.FontStyle := [fsBold,fsItalic]; T.TextColor := clFuchsia;
    T.FillStyle := R.StrokePaint; T.Opacity := 0.8;
    T.LetterSpacingRatio := 0.2; T.LineSpacingRatio := 0.4; T.Vertical := True;
    T.Visible := True; D.InsertText(5,T);
    C.Configure(D,H,S,Rect(0,0,800,600),1); Cases := 0;
    for Source := 0 to 6 do
      for Tool in [vetRectangle,vetEllipse,vetRoundedRectangle,vetTemplate,
        vetClosedPath,vetClosedBezier,vetLine,vetPath,vetBezier,
        vetFreehandLine,vetFreehandBezier] do
      begin
        if Source = 0 then D.SetSelectedLayers([])
        else if Source = 6 then D.SetSelectedLayers([1,2])
        else D.SetSelectedLayers([Source]);
        A := CaptureVectArtSelectedAttributes(D);
        S.CurrentTool := Tool;
        if Tool in [vetLine,vetPath,vetBezier,vetFreehandLine,vetFreehandBezier] then Expected := vacLine
        else Expected := vacShape;
        N := D.LayerCount;
        Check(C.MouseDown(mbLeft,[ssAlt],20,20),'Start');
        // 作成途中の選択変更でも、開始時の参照元を失わない。
        D.SetSelectedLayers([]);
        C.MouseMove([ssLeft,ssAlt],100,80);
        if Tool in [vetPath,vetBezier,vetClosedPath,vetClosedBezier] then
        begin
          C.MouseDown(mbLeft,[ssAlt],100,80);
          C.MouseMove([ssAlt],20,100); C.MouseDown(mbLeft,[ssAlt],20,100);
          Check(C.FinishPath(Expected=vacShape),'Finish path');
        end
        else C.MouseUp(mbLeft,[ssAlt],100,80);
        Check(D.LayerCount=N+1,'Inserted');
        B := CaptureVectArtObjectAttributes(D[N]);
        Check(B.Category=Expected,'Target category');
        if A.Category=Expected then
        begin
          Check((B.StrokeColor=A.StrokeColor) and (B.StrokeWidth=A.StrokeWidth) and
            (B.StrokeStyle=A.StrokeStyle) and (B.Opacity=A.Opacity),'Copied stroke');
          Check((B.StrokePaint.Kind=A.StrokePaint.Kind) and
            (B.StrokePaint.Angle=A.StrokePaint.Angle),'Copied stroke paint');
          if Expected=vacShape then
            Check((B.FillColor=A.FillColor) and (B.FillStyle.Kind=vfkTexture) and
              (Length(B.FillStyle.TexturePng)=Length(R.FillStyle.TexturePng)),'Copied fill')
          else Check((B.EndMarker=vlmArrow) and (B.StartMarker=vlmCircle) and
            (B.EndMarkerSize=6) and (B.LineCap=vlcRound) and B.AntiAlias,'Copied line details');
        end
        else Check((B.StrokeColor=clBlack) and (B.StrokeWidth=1) and
          (B.StrokePaint.Kind=vfkSolid),'Fallback defaults');
        Check((D[N].GroupId=0) and not D[N].Locked and D[N].Visible,'Excluded identity');
        if D[N] is TVectArtRectangleLayer then
          Check((TVectArtRectangleLayer(D[N]).Bounds.Left<100) and
            (TVectArtRectangleLayer(D[N]).RotationDegrees=0),'Excluded geometry');
        H.Undo; Check(D.LayerCount=N,'Undo'); H.Redo;
        Check(CaptureVectArtObjectAttributes(D[N]).StrokeWidth=B.StrokeWidth,'Redo snapshot');
        Inc(Cases);
      end;
    // 既存データへの適用でも文字内容・配置・所属などを変更しない。
    A := CaptureVectArtObjectAttributes(D[5]);
    T := Default(TVectArtTextData); T.Text := 'target content'; T.Name := 'target';
    T.Bounds := RectF(1,2,31,42); T.GroupId := 73; T.Locked := True;
    T.RotationDegrees := 50; T.FlipHorizontal := True;
    ApplyVectArtObjectAttributes(A,T);
    Check((T.Text='target content') and (T.Bounds.Left=1) and (T.Name='target') and
      (T.GroupId=73) and T.Locked and (T.RotationDegrees=50) and T.FlipHorizontal,'Text geometry preservation');
    Check((T.FontFamily='Arial') and (T.FontSize=36) and (T.FontStyle=[fsBold,fsItalic]) and
      (T.TextColor=clFuchsia) and T.Vertical and (T.FillStyle.Kind=vfkWave) and
      (Abs(T.LetterSpacingRatio-0.2)<0.001),'Text attributes');
    ApplyVectArtObjectAttributes(CaptureVectArtObjectAttributes(D[1]),T);
    Check(T.TextColor=clFuchsia,'Category mismatch changed text');
    // 枠のみ／塗りのみも属性なので、同分類では配置ツールのモードより優先する。
    A := CaptureVectArtObjectAttributes(D[1]); A.Filled := False;
    R.Filled := True; ApplyVectArtObjectAttributes(A,R);
    Check(not R.Filled and (R.StrokeWidth=7),'Outline mode inheritance');
    A.Filled := True; A.StrokeWidth := 0;
    P.Closed := True; P.StrokeWidth := 9; ApplyVectArtObjectAttributes(A,P);
    Check(P.Filled and (P.StrokeWidth=0),'Fill mode inheritance');
    // テクスチャのスナップショットと貼付け先のバイト所有権を確認する。
    A := CaptureVectArtObjectAttributes(D[1]);
    ApplyVectArtObjectAttributes(A,R); R.FillStyle.TexturePng[0] := 0;
    Check((A.FillStyle.TexturePng[0]<>0) and
      (TVectArtRectangleLayer(D[1]).FillStyle.TexturePng[0]<>0),'Texture alias');
    Ops.Document:=D; Ops.EditorState:=S; Ops.EditHistory:=H;
    D.SetSelectedLayers([1]); N:=D.LayerCount; Ops.Execute(vlaAdd);
    Check(TVectArtRectangleLayer(D[N]).FillStyle.Kind=vfkTexture,'Layer bar attributes');
    Check((S.Color1=clBlack) and (S.Color2=clWhite),'Defaults mutated');
    Writeln('PASS ',Cases,' creation cases, text application, texture ownership, Undo/Redo');
  finally Ops.Free; C.Free; H.Free; S.Free; D.Free; end;
end.
