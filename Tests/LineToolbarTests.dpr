program LineToolbarTests;

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  System.Types,
  Winapi.Messages,
  Winapi.Windows,
  Vcl.Forms,
  Vcl.Graphics,
  HorizontalTrackBarRenderer in
    'Lib\HorizontalTrackBar\HorizontalTrackBarRenderer.pas',
  HorizontalTrackBarControl in
    'Lib\HorizontalTrackBar\HorizontalTrackBarControl.pas',
  TextRendererSkiaBootstrap in
    'Lib\TextRenderer\TextRendererSkiaBootstrap.pas',
  TextRendererSkiaRuntime in
    'Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerEditorState in
    'Source\Core\VectArtDesignerEditorState.pas',
  VectArtDesignerEditCommands in
    'Source\Core\Commands\VectArtDesignerEditCommands.pas',
  VectArtDesignerEditHistory in
    'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerDocumentJson in
    'Source\Persistence\VectArtDesignerDocumentJson.pas',
  VectArtDesignerRenderer in
    'Source\Rendering\VectArtDesignerRenderer.pas',
  VectArtDesignerMifContainer in
    'Source\Persistence\Mif\VectArtDesignerMifContainer.pas',
  VectArtDesignerMifDocument in
    'Source\Persistence\Mif\VectArtDesignerMifDocument.pas',
  VectArtDesignerStrokeStyleCombo in
    'Source\ObjectProperties\VectArtDesignerStrokeStyleCombo.pas',
  VectArtDesignerLineStyleControls in
    'Source\Shell\VectArtDesignerLineStyleControls.pas',
  VectArtDesignerLineToolbar in
    'Source\Shell\VectArtDesignerLineToolbar.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function LineData(const Name: string; Width: Single;
  Style: TVectArtMifStrokeStyle): TVectArtLineData;
begin
  Result.StartPoint := TPointF.Create(10, 10);
  Result.EndPoint := TPointF.Create(100, 100);
  Result.Locked := False;
  Result.LineCap := vlcButt;
  Result.MifAntiAlias := True;
  Result.MifEndMarker := vlmNone;
  Result.MifEndMarkerSize := 4.0;
  Result.MifStartMarker := vlmNone;
  Result.MifStartMarkerSize := 4.0;
  Result.LineJoin := vljMiter;
  Result.Name := Name;
  Result.Opacity := 1.0;
  Result.StrokeColor := clBlack;
  Result.MifStrokeStyle := Style;
  Result.StrokeWidth := Width;
  Result.Visible := True;
end;

var
  Container: TVectArtMifContainer;
  Document: TVectArtDocument;
  EditorState: TVectArtEditorState;
  Form: TForm;
  History: TVectArtEditHistory;
  Line1: TVectArtLineLayer;
  Line2: TVectArtLineLayer;
  MifLine: TVectArtLineLayer;
  MifMessage: string;
  MifDocument: TVectArtDocument;
  Toolbar: TVectArtLineToolbarControl;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  Container := nil;
  Document := TVectArtDocument.Create;
  EditorState := TVectArtEditorState.Create;
  Form := TForm.CreateNew(nil);
  History := TVectArtEditHistory.Create;
  MifDocument := TVectArtDocument.Create;
  Toolbar := TVectArtLineToolbarControl.CreateForHost(Form, Form);
  try
    Form.SetBounds(100, 100, 900, 500);
    Form.Show;
    Application.ProcessMessages;
    Toolbar.Document := Document;
    Toolbar.EditorState := EditorState;
    Toolbar.EditHistory := History;
    EditorState.CurrentTool := vetLine;
    Toolbar.RefreshState;
    Require(Toolbar.Visible and (Toolbar.StrokeWidthEdit.Text = '1') and
      (Toolbar.StrokeWidthTrackBar.Position = 10) and
      (Toolbar.StrokeWidthTrackBar.SmallChange = 10) and
      (Toolbar.DetailsButton <> nil) and
      (Length(Toolbar.DetailsButton.Caption) = 2) and
      (Ord(Toolbar.DetailsButton.Caption[1]) = $8A73) and
      (Ord(Toolbar.DetailsButton.Caption[2]) = $7D30) and
      (Toolbar.DetailsPanel <> nil) and
      (Toolbar.StrokeWidthTrackBar.Parent = Toolbar.DetailsPanel) and
      (Toolbar.StrokeWidthEdit.Parent = Toolbar.DetailsPanel) and
      (Toolbar.MifStrokeStyleCombo.Parent = Toolbar.DetailsPanel) and
      Toolbar.LineCapButton(vlcButt).Selected and
      not Toolbar.LineCapButton(vlcSquare).Selected and
      not Toolbar.LineCapButton(vlcRound).Selected and
      Toolbar.LineJoinButton(vljMiter).Selected and
      not Toolbar.LineJoinButton(vljBevel).Selected and
      not Toolbar.LineJoinButton(vljRound).Selected and
      Toolbar.MifAntiAliasButton.Selected and
      Toolbar.MifEndMarkerCombo.PendingCommon and
      (Toolbar.MifEndMarkerCombo.PendingMarker = vlmNone) and
      Toolbar.MifStartMarkerCombo.PendingCommon and
      (Toolbar.MifStartMarkerCombo.PendingMarker = vlmNone) and
      (Toolbar.MifStartMarkerSizeTrackBar.Position = 4) and
      not Toolbar.MifStartMarkerSizeTrackBar.Enabled and
      (Toolbar.MifEndMarkerSizeTrackBar.Position = 4) and
      not Toolbar.MifEndMarkerSizeTrackBar.Enabled and
      (Toolbar.MifStrokeStyleCombo.PendingItemIndex = Ord(vssSolid)),
      'Initial line toolbar state differs');
    Toolbar.DetailsButton.Perform(WM_LBUTTONDOWN, MK_LBUTTON,
      MakeLParam(4, 4));
    Toolbar.DetailsButton.Perform(WM_LBUTTONUP, 0, MakeLParam(4, 4));
    Require(Toolbar.DetailsPanel.Visible,
      'Mouse click did not open the line details panel exactly once');
    Toolbar.DetailsButton.Perform(WM_LBUTTONDOWN, MK_LBUTTON,
      MakeLParam(4, 4));
    Toolbar.DetailsButton.Perform(WM_LBUTTONUP, 0, MakeLParam(4, 4));
    Require(not Toolbar.DetailsPanel.Visible,
      'Mouse click did not close the line details panel exactly once');
    Toolbar.DetailsButton.Perform(WM_LBUTTONDOWN, MK_LBUTTON,
      MakeLParam(4, 4));
    Toolbar.DetailsButton.Perform(WM_LBUTTONUP, 0, MakeLParam(4, 4));
    Toolbar.MifStartMarkerCombo.SetFocus;
    Toolbar.UpdateDetailsPanelFocus;
    Require(Toolbar.DetailsPanel.Visible,
      'Details panel closed while a child control had focus');
    Toolbar.StrokeWidthEdit.SetFocus;
    Toolbar.UpdateDetailsPanelFocus;
    Require(Toolbar.DetailsPanel.Visible,
      'Details panel closed while the stroke width editor had focus');
    Form.ActiveControl := nil;
    Toolbar.UpdateDetailsPanelFocus;
    Require(not Toolbar.DetailsPanel.Visible,
      'Details panel remained open after focus left the panel');

    Toolbar.ApplyStrokeWidth(8.5);
    Toolbar.ApplyMifStrokeStyle(vssLongDash);
    Require(SameValue(EditorState.LineStrokeWidth, 8.5) and
      (Toolbar.StrokeWidthTrackBar.Position = 90) and
      (EditorState.LineMifStrokeStyle = vssLongDash),
      'Creation defaults were not updated');

    Document.InsertLine(1, LineData('One', 2.0, vssSolid));
    Document.InsertLine(2, LineData('Two', 5.0, vssDotted));
    Document.SetLineCap(2, vlcSquare);
    Document.SetLineJoin(2, vljBevel);
    Document.SetLineMifAntiAlias(2, False);
    Document.SetSelectedLayers([1, 2]);
    Toolbar.RefreshState;
    Require((Toolbar.StrokeWidthEdit.Text = '') and
      (Toolbar.MifStrokeStyleCombo.PendingItemIndex = -1) and
      not Toolbar.LineCapButton(vlcButt).Selected and
      not Toolbar.LineCapButton(vlcSquare).Selected and
      not Toolbar.LineCapButton(vlcRound).Selected and
      not Toolbar.LineJoinButton(vljMiter).Selected and
      not Toolbar.LineJoinButton(vljBevel).Selected and
      not Toolbar.LineJoinButton(vljRound).Selected and
      not Toolbar.MifAntiAliasButton.Selected,
      'Mixed line values were not displayed');

    Toolbar.ApplyStrokeWidth(12.0);
    Toolbar.ApplyMifStrokeStyle(vssDashDot);
    Line1 := TVectArtLineLayer(Document[1]);
    Line2 := TVectArtLineLayer(Document[2]);
    Require(SameValue(Line1.StrokeWidth, 12.0) and
      SameValue(Line2.StrokeWidth, 12.0) and
      (Line1.MifStrokeStyle = vssDashDot) and
      (Line2.MifStrokeStyle = vssDashDot),
      'Multiple line style edit differs');
    History.Undo;
    Require((Line1.MifStrokeStyle = vssSolid) and
      (Line2.MifStrokeStyle = vssDotted),
      'Multiple line style undo differs');
    History.Undo;
    Require(SameValue(Line1.StrokeWidth, 2.0) and
      SameValue(Line2.StrokeWidth, 5.0),
      'Multiple line width undo differs');

    Toolbar.StrokeWidthTrackBar.Position := 80;
    Require(SameValue(Line1.StrokeWidth, 8.0) and
      SameValue(Line2.StrokeWidth, 8.0) and
      (Toolbar.StrokeWidthEdit.Text = '8'),
      'Track bar did not update selected line widths');
    History.Undo;
    Require(SameValue(Line1.StrokeWidth, 2.0) and
      SameValue(Line2.StrokeWidth, 5.0),
      'Track bar line width undo differs');

    Toolbar.LineCapButton(vlcRound).Click;
    Require((Line1.LineCap = vlcRound) and (Line2.LineCap = vlcRound) and
      Toolbar.LineCapButton(vlcRound).Selected and
      not Toolbar.LineCapButton(vlcButt).Selected and
      not Toolbar.LineCapButton(vlcSquare).Selected,
      'Multiple line cap edit differs');
    History.Undo;
    Require((Line1.LineCap = vlcButt) and (Line2.LineCap = vlcSquare),
      'Multiple line cap undo differs');
    Toolbar.ApplyLineCap(vlcRound);

    Toolbar.LineJoinButton(vljRound).Click;
    Require((Line1.LineJoin = vljRound) and
      (Line2.LineJoin = vljRound) and
      Toolbar.LineJoinButton(vljRound).Selected and
      not Toolbar.LineJoinButton(vljMiter).Selected and
      not Toolbar.LineJoinButton(vljBevel).Selected,
      'Multiple line join edit differs');
    History.Undo;
    Require((Line1.LineJoin = vljMiter) and (Line2.LineJoin = vljBevel),
      'Multiple line join undo differs');
    Toolbar.ApplyLineJoin(vljRound);

    Toolbar.MifAntiAliasButton.Click;
    Require(Line1.MifAntiAlias and Line2.MifAntiAlias and
      Toolbar.MifAntiAliasButton.Selected,
      'Multiple line anti-alias edit differs');
    History.Undo;
    Require(Line1.MifAntiAlias and not Line2.MifAntiAlias,
      'Multiple line anti-alias undo differs');
    Toolbar.ApplyLineMifAntiAlias(False);
    Toolbar.MifEndMarkerCombo.ItemIndex := 9;
    Toolbar.MifEndMarkerCombo.OnChange(Toolbar.MifEndMarkerCombo);
    Require((Line1.MifEndMarker = vlmStar) and
      (Line2.MifEndMarker = vlmStar) and
      (Toolbar.MifEndMarkerCombo.PendingMarker = vlmStar),
      'Multiple line end marker edit differs');
    History.Undo;
    Require((Line1.MifEndMarker = vlmNone) and
      (Line2.MifEndMarker = vlmNone), 'Multiple line end marker undo differs');
    Toolbar.ApplyLineMifEndMarker(vlmStar);
    Toolbar.MifStartMarkerCombo.ItemIndex := 1;
    Toolbar.MifStartMarkerCombo.OnChange(Toolbar.MifStartMarkerCombo);
    Require((Line1.MifStartMarker = vlmOpenArrow) and
      (Line2.MifStartMarker = vlmOpenArrow) and
      (Toolbar.MifStartMarkerCombo.PendingMarker = vlmOpenArrow),
      'Multiple line start marker edit differs');
    History.Undo;
    Require((Line1.MifStartMarker = vlmNone) and
      (Line2.MifStartMarker = vlmNone), 'Multiple line start marker undo differs');
    Toolbar.ApplyLineMifStartMarker(vlmOpenArrow);

    Toolbar.MifStartMarkerSizeTrackBar.Position := 7;
    Toolbar.MifEndMarkerSizeTrackBar.Position := 10;
    Require(SameValue(Line1.MifStartMarkerSize, 7.0) and
      SameValue(Line2.MifStartMarkerSize, 7.0) and
      SameValue(Line1.MifEndMarkerSize, 10.0) and
      SameValue(Line2.MifEndMarkerSize, 10.0),
      'Multiple line marker size edit differs');
    History.Undo;
    Require(SameValue(Line1.MifEndMarkerSize, 4.0) and
      SameValue(Line2.MifEndMarkerSize, 4.0),
      'Multiple line end marker size undo differs');
    History.Undo;
    Require(SameValue(Line1.MifStartMarkerSize, 4.0) and
      SameValue(Line2.MifStartMarkerSize, 4.0),
      'Multiple line start marker size undo differs');
    Toolbar.ApplyLineMifStartMarkerSize(7.0);
    Toolbar.ApplyLineMifEndMarkerSize(10.0);

    Toolbar.ApplyStrokeWidth(37.5);
    Toolbar.ApplyMifStrokeStyle(vssLongDash);
    Require(TryCreateVectArtMifFromDocument(Document, Container,
      MifMessage), MifMessage);
    Require(TryLoadVectArtDocumentFromMif(Container, MifDocument,
      MifMessage), MifMessage);
    Require((MifDocument.LayerCount = 3) and
      (MifDocument[1] is TVectArtLineLayer) and
      (MifDocument[2] is TVectArtLineLayer),
      'Toolbar lines were not restored from MIF');
    MifLine := TVectArtLineLayer(MifDocument[1]);
    Require(SameValue(MifLine.StrokeWidth, 37.5, 0.000001) and
      (MifLine.MifStrokeStyle = vssLongDash) and
      (MifLine.LineCap = vlcRound) and
      (MifLine.LineJoin = vljRound) and not MifLine.MifAntiAlias and
      (MifLine.MifEndMarker = vlmStar) and
      (MifLine.MifStartMarker = vlmOpenArrow) and
      SameValue(MifLine.MifEndMarkerSize, 10.0) and
      SameValue(MifLine.MifStartMarkerSize, 7.0),
      'Toolbar line values differ after MIF round-trip');
    Writeln('Line toolbar tests: PASS');
  finally
    Toolbar.Free;
    History.Free;
    Form.Free;
    MifDocument.Free;
    EditorState.Free;
    Document.Free;
    Container.Free;
    TTextRendererSkiaRuntime.Release;
  end;
end.
