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
  Style: TVectArtStrokeStyle): TVectArtLineData;
begin
  Result.StartPoint := TPointF.Create(10, 10);
  Result.EndPoint := TPointF.Create(100, 100);
  Result.Locked := False;
  Result.LineCap := vlcButt;
  Result.AntiAlias := True;
  Result.EndMarker := vlmNone;
  Result.EndMarkerSize := 4.0;
  Result.StartMarker := vlmNone;
  Result.StartMarkerSize := 4.0;
  Result.LineJoin := vljMiter;
  Result.Name := Name;
  Result.Opacity := 1.0;
  Result.StrokeColor := clBlack;
  Result.StrokeStyle := Style;
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
      (Toolbar.StrokeStyleCombo.Parent = Toolbar.DetailsPanel) and
      Toolbar.LineCapButton(vlcButt).Selected and
      not Toolbar.LineCapButton(vlcSquare).Selected and
      not Toolbar.LineCapButton(vlcRound).Selected and
      Toolbar.LineJoinButton(vljMiter).Selected and
      not Toolbar.LineJoinButton(vljBevel).Selected and
      not Toolbar.LineJoinButton(vljRound).Selected and
      Toolbar.AntiAliasButton.Selected and
      Toolbar.EndMarkerCombo.PendingCommon and
      (Toolbar.EndMarkerCombo.PendingMarker = vlmNone) and
      Toolbar.StartMarkerCombo.PendingCommon and
      (Toolbar.StartMarkerCombo.PendingMarker = vlmNone) and
      (Toolbar.StartMarkerSizeTrackBar.Position = 4) and
      not Toolbar.StartMarkerSizeTrackBar.Enabled and
      (Toolbar.EndMarkerSizeTrackBar.Position = 4) and
      not Toolbar.EndMarkerSizeTrackBar.Enabled and
      (Toolbar.StrokeStyleCombo.PendingItemIndex = Ord(vssSolid)),
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
    Toolbar.StartMarkerCombo.SetFocus;
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
    Toolbar.ApplyStrokeStyle(vssLongDash);
    Require(SameValue(EditorState.LineStrokeWidth, 8.5) and
      (Toolbar.StrokeWidthTrackBar.Position = 90) and
      (EditorState.LineStrokeStyle = vssLongDash),
      'Creation defaults were not updated');

    Document.InsertLine(1, LineData('One', 2.0, vssSolid));
    Document.InsertLine(2, LineData('Two', 5.0, vssDotted));
    Document.SetLineCap(2, vlcSquare);
    Document.SetLineJoin(2, vljBevel);
    Document.SetLineAntiAlias(2, False);
    Document.SetSelectedLayers([1, 2]);
    Toolbar.RefreshState;
    Require((Toolbar.StrokeWidthEdit.Text = '') and
      (Toolbar.StrokeStyleCombo.PendingItemIndex = -1) and
      not Toolbar.LineCapButton(vlcButt).Selected and
      not Toolbar.LineCapButton(vlcSquare).Selected and
      not Toolbar.LineCapButton(vlcRound).Selected and
      not Toolbar.LineJoinButton(vljMiter).Selected and
      not Toolbar.LineJoinButton(vljBevel).Selected and
      not Toolbar.LineJoinButton(vljRound).Selected and
      not Toolbar.AntiAliasButton.Selected,
      'Mixed line values were not displayed');

    Toolbar.ApplyStrokeWidth(12.0);
    Toolbar.ApplyStrokeStyle(vssDashDot);
    Line1 := TVectArtLineLayer(Document[1]);
    Line2 := TVectArtLineLayer(Document[2]);
    Require(SameValue(Line1.StrokeWidth, 12.0) and
      SameValue(Line2.StrokeWidth, 12.0) and
      (Line1.StrokeStyle = vssDashDot) and
      (Line2.StrokeStyle = vssDashDot),
      'Multiple line style edit differs');
    History.Undo;
    Require((Line1.StrokeStyle = vssSolid) and
      (Line2.StrokeStyle = vssDotted),
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

    Toolbar.AntiAliasButton.Click;
    Require(Line1.AntiAlias and Line2.AntiAlias and
      Toolbar.AntiAliasButton.Selected,
      'Multiple line anti-alias edit differs');
    History.Undo;
    Require(Line1.AntiAlias and not Line2.AntiAlias,
      'Multiple line anti-alias undo differs');
    Toolbar.ApplyLineAntiAlias(False);
    Toolbar.EndMarkerCombo.ItemIndex := 9;
    Toolbar.EndMarkerCombo.OnChange(Toolbar.EndMarkerCombo);
    Require((Line1.EndMarker = vlmStar) and
      (Line2.EndMarker = vlmStar) and
      (Toolbar.EndMarkerCombo.PendingMarker = vlmStar),
      'Multiple line end marker edit differs');
    History.Undo;
    Require((Line1.EndMarker = vlmNone) and
      (Line2.EndMarker = vlmNone), 'Multiple line end marker undo differs');
    Toolbar.ApplyLineEndMarker(vlmStar);
    Toolbar.StartMarkerCombo.ItemIndex := 1;
    Toolbar.StartMarkerCombo.OnChange(Toolbar.StartMarkerCombo);
    Require((Line1.StartMarker = vlmOpenArrow) and
      (Line2.StartMarker = vlmOpenArrow) and
      (Toolbar.StartMarkerCombo.PendingMarker = vlmOpenArrow),
      'Multiple line start marker edit differs');
    History.Undo;
    Require((Line1.StartMarker = vlmNone) and
      (Line2.StartMarker = vlmNone), 'Multiple line start marker undo differs');
    Toolbar.ApplyLineStartMarker(vlmOpenArrow);

    Toolbar.StartMarkerSizeTrackBar.Position := 7;
    Toolbar.EndMarkerSizeTrackBar.Position := 10;
    Require(SameValue(Line1.StartMarkerSize, 7.0) and
      SameValue(Line2.StartMarkerSize, 7.0) and
      SameValue(Line1.EndMarkerSize, 10.0) and
      SameValue(Line2.EndMarkerSize, 10.0),
      'Multiple line marker size edit differs');
    History.Undo;
    Require(SameValue(Line1.EndMarkerSize, 4.0) and
      SameValue(Line2.EndMarkerSize, 4.0),
      'Multiple line end marker size undo differs');
    History.Undo;
    Require(SameValue(Line1.StartMarkerSize, 4.0) and
      SameValue(Line2.StartMarkerSize, 4.0),
      'Multiple line start marker size undo differs');
    Toolbar.ApplyLineStartMarkerSize(7.0);
    Toolbar.ApplyLineEndMarkerSize(10.0);

    Toolbar.ApplyStrokeWidth(37.5);
    Toolbar.ApplyStrokeStyle(vssLongDash);
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
      (MifLine.StrokeStyle = vssLongDash) and
      (MifLine.LineCap = vlcRound) and
      (MifLine.LineJoin = vljRound) and not MifLine.AntiAlias and
      (MifLine.EndMarker = vlmStar) and
      (MifLine.StartMarker = vlmOpenArrow) and
      SameValue(MifLine.EndMarkerSize, 10.0) and
      SameValue(MifLine.StartMarkerSize, 7.0),
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
