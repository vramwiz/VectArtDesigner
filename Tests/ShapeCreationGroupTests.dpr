// 作成データの未初期化によりグループ所属が混入しないことを、複数ツールとUndoで確認する。
program ShapeCreationGroupTests;
{$APPTYPE CONSOLE}
uses System.Classes, System.SysUtils, System.Types, Vcl.Controls,
  VectArtDesignerDocument, VectArtDesignerEditorState, VectArtDesignerEditHistory,
  VectArtDesignerShapeCreation;
procedure Check(V: Boolean; const MessageText: string);
begin if not V then raise Exception.Create(MessageText); end;
var D: TVectArtDocument; S: TVectArtEditorState; H: TVectArtEditHistory;
  C: TVectArtShapeCreation; R: TVectArtRectangleData; Tool: TVectArtEditorTool;
  Group: TVectArtGroupId; Pass,N: Integer;
begin
  D := TVectArtDocument.Create; S := TVectArtEditorState.Create;
  H := TVectArtEditHistory.Create; C := TVectArtShapeCreation.Create;
  try
    R := Default(TVectArtRectangleData); R.Bounds := RectF(200,200,240,240);
    R.Visible := True; R.Opacity := 1; R.Filled := True;
    Group := D.AllocateGroupId; R.GroupId := Group;
    D.InsertRectangle(1,R); D.InsertRectangle(2,R);
    C.Configure(D,H,S,Rect(0,0,800,600),1);
    for Pass := 1 to 12 do
      for Tool in [vetRectangle,vetEllipse,vetLine,vetRoundedRectangle,vetTemplate,
        vetPath,vetBezier,vetClosedPath,vetClosedBezier] do
      begin
        D.SetSelectedLayers([1,2]); S.CurrentTool := Tool;
        N := D.LayerCount;
        Check(C.MouseDown(mbLeft,[],20,20),'Creation start');
        C.MouseMove([ssLeft],100,80);
        if Tool in [vetPath,vetBezier,vetClosedPath,vetClosedBezier] then
        begin
          C.MouseDown(mbLeft,[],100,80); C.MouseMove([],20,100);
          C.MouseDown(mbLeft,[],20,100);
          Check(C.FinishPath(Tool in [vetClosedPath,vetClosedBezier]),'Path finish');
        end
        else C.MouseUp(mbLeft,[],100,80);
        Check(D.LayerCount=N+1,'New layer count');
        Check(D[N].GroupId=VECTART_NO_GROUP,'New layer unexpectedly grouped');
        Check((D.SelectionCount=1) and D.IsLayerSelected(N),'New selection expanded to a group');
        Check((D[1].GroupId=Group) and (D[2].GroupId=Group),'Existing group changed');
        H.Undo; Check(D.LayerCount=N,'Undo creation');
        H.Redo; Check((D.LayerCount=N+1) and (D[N].GroupId=VECTART_NO_GROUP),'Redo restored a spurious group');
      end;
    Writeln('PASS 108 creations: ungrouped creation, selected existing group, Undo/Redo');
  finally C.Free; H.Free; S.Free; D.Free; end;
end.
