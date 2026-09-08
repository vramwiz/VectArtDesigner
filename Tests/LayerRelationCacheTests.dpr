// Verifies flat group membership, cached layer lookup, and per-layer revisions.
program LayerRelationCacheTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas';

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function RectangleData(const Name: string; Left: Single): TVectArtRectangleData;
begin
  Result := Default(TVectArtRectangleData);
  Result.Name := Name;
  Result.Bounds := TRectF.Create(Left, 10, Left + 20, 30);
  Result.FillColor := clWhite;
  Result.Filled := True;
  Result.Opacity := 1;
  Result.StrokeColor := clBlack;
  Result.StrokeStyle := vssSolid;
  Result.Visible := True;
end;

var
  Document: TVectArtDocument;
  FirstId: TVectArtLayerId;
  FirstRevision: Int64;
  GroupId: TVectArtGroupId;
  GroupMembers: TArray<Integer>;
  RelationRevision: Int64;
  SecondId: TVectArtLayerId;
  SecondRevision: Int64;
begin
  Document := TVectArtDocument.Create;
  try
    Document.InsertRectangle(1, RectangleData('First', 10));
    Document.InsertRectangle(2, RectangleData('Second', 40));
    FirstId := Document[1].LayerId;
    SecondId := Document[2].LayerId;
    Check((FirstId <> 0) and (SecondId <> 0) and (FirstId <> SecondId),
      'Layer IDs are not unique');
    Check(Document.IndexOfLayerId(FirstId) = 1,
      'First layer lookup failed');
    Check(Document.IndexOfLayerId(SecondId) = 2,
      'Second layer lookup failed');

    GroupId := Document.AllocateGroupId;
    Document.SetLayerGroup(1, GroupId);
    RelationRevision := Document.LayerRelationRevision;
    Document.SetLayerGroup(2, GroupId);
    Check(Document.LayerRelationRevision > RelationRevision,
      'Group relation revision did not change');
    GroupMembers := Document.GetGroupLayerIndices(GroupId);
    Check((Length(GroupMembers) = 2) and (GroupMembers[0] = 1) and
      (GroupMembers[1] = 2), 'Flat group membership is wrong');

    FirstRevision := Document[1].Revision;
    SecondRevision := Document[2].Revision;
    Document.SetRectangleFillColor(1, clRed);
    Check(Document[1].Revision = FirstRevision + 1,
      'Edited layer revision did not change');
    Check(Document[2].Revision = SecondRevision,
      'Unedited layer revision changed');

    Document.MoveLayer(1, 2);
    Check(Document.IndexOfLayerId(FirstId) = 2,
      'Layer lookup was not rebuilt after reordering');
    GroupMembers := Document.GetGroupLayerIndices(GroupId);
    Check((Length(GroupMembers) = 2) and (GroupMembers[0] = 1) and
      (GroupMembers[1] = 2), 'Group order was not rebuilt');

    Document.SetLayerGroup(2, VECTART_NO_GROUP);
    GroupMembers := Document.GetGroupLayerIndices(GroupId);
    Check((Length(GroupMembers) = 1) and (GroupMembers[0] = 1),
      'Ungrouping did not update membership');
    Writeln('PASS flat layer relations and per-layer revisions');
  finally
    Document.Free;
  end;
end.
