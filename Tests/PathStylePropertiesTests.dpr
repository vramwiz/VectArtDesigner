program PathStylePropertiesTests;

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  System.Types,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,
  VectArtDesignerDocument in 'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerGeometry in 'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerBezierGeometry in
    'Source\Editor\VectArtDesignerBezierGeometry.pas',
  VectArtDesignerEditorState in
    'Source\Core\VectArtDesignerEditorState.pas',
  VectArtDesignerEditCommands in
    'Source\Core\Commands\VectArtDesignerEditCommands.pas',
  VectArtDesignerEditHistory in
    'Source\Core\VectArtDesignerEditHistory.pas',
  VectArtDesignerLineStyleControls in
    'Source\Shell\VectArtDesignerLineStyleControls.pas',
  VectArtDesignerStrokeStyleCombo in
    'Source\ObjectProperties\VectArtDesignerStrokeStyleCombo.pas',
  VectArtDesignerObjectPropertiesControl in
    'Source\ObjectProperties\VectArtDesignerObjectPropertiesControl.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function FindCapButton(Parent: TWinControl;
  Value: TVectArtLineCap): TVectArtLineCapButton;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Parent.ControlCount - 1 do
    if (Parent.Controls[I] is TVectArtLineCapButton) and
      (TVectArtLineCapButton(Parent.Controls[I]).LineCap = Value) then
      Exit(TVectArtLineCapButton(Parent.Controls[I]));
end;

function FindJoinButton(Parent: TWinControl;
  Value: TVectArtLineJoin): TVectArtLineJoinButton;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Parent.ControlCount - 1 do
    if (Parent.Controls[I] is TVectArtLineJoinButton) and
      (TVectArtLineJoinButton(Parent.Controls[I]).LineJoin = Value) then
      Exit(TVectArtLineJoinButton(Parent.Controls[I]));
end;

function FindAntiAliasButton(
  Parent: TWinControl): TVectArtAntiAliasButton;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Parent.ControlCount - 1 do
    if Parent.Controls[I] is TVectArtAntiAliasButton then
      Exit(TVectArtAntiAliasButton(Parent.Controls[I]));
end;

var
  AntiAliasButton: TVectArtAntiAliasButton;
  CapButton: TVectArtLineCapButton;
  Data: TVectArtPathData;
  Document: TVectArtDocument;
  EditorState: TVectArtEditorState;
  History: TVectArtEditHistory;
  HostForm: TForm;
  JoinButton: TVectArtLineJoinButton;
  Path: TVectArtPathLayer;
  PropertiesControl: TVectArtObjectPropertiesControl;
begin
  Application.Initialize;
  HostForm := TForm.Create(nil);
  Document := TVectArtDocument.Create;
  EditorState := TVectArtEditorState.Create;
  History := TVectArtEditHistory.Create;
  try
    Data := Default(TVectArtPathData);
    Data.Name := 'Path 1';
    Data.Points := [PointF(20, 20), PointF(100, 20), PointF(100, 80)];
    Data.LineCap := vlcButt;
    Data.LineJoin := vljMiter;
    Data.AntiAlias := True;
    Data.EndMarker := vlmNone;
    Data.EndMarkerSize := 4.0;
    Data.Opacity := 1.0;
    Data.StrokeColor := clBlack;
    Data.StartMarker := vlmNone;
    Data.StartMarkerSize := 4.0;
    Data.StrokeWidth := 4.0;
    Data.Visible := True;
    Document.InsertPath(1, Data);
    Document.SelectedIndex := 1;
    PropertiesControl := TVectArtObjectPropertiesControl.Create(HostForm);
    PropertiesControl.Parent := HostForm;
    PropertiesControl.SetBounds(0, 0, 290, 480);
    PropertiesControl.EditHistory := History;
    PropertiesControl.EditorState := EditorState;
    PropertiesControl.Document := Document;
    CapButton := FindCapButton(PropertiesControl, vlcRound);
    JoinButton := FindJoinButton(PropertiesControl, vljBevel);
    AntiAliasButton := FindAntiAliasButton(PropertiesControl);
    Require((CapButton <> nil) and CapButton.Visible and
      (JoinButton <> nil) and JoinButton.Visible and
      (AntiAliasButton <> nil) and AntiAliasButton.Visible,
      'Path style buttons are not visible');
    CapButton.Click;
    Path := TVectArtPathLayer(Document[1]);
    Require((Path.LineCap = vlcRound) and
      (EditorState.PathLineCap = vlcRound),
      'Path line cap button did not apply the value');
    History.Undo;
    Require(Path.LineCap = vlcButt, 'Path line cap button undo differs');
    JoinButton.Click;
    Require((Path.LineJoin = vljBevel) and
      (EditorState.PathLineJoin = vljBevel),
      'Path line join button did not apply the value');
    History.Undo;
    Require(Path.LineJoin = vljMiter, 'Path line join button undo differs');
    AntiAliasButton.Click;
    Require(not Path.AntiAlias and not EditorState.PathAntiAlias,
      'Path anti-alias button did not apply the value');
    History.Undo;
    Require(Path.AntiAlias, 'Path anti-alias button undo differs');
    PropertiesControl.PathStartMarkerCombo.ItemIndex := 1;
    PropertiesControl.PathStartMarkerCombo.OnChange(
      PropertiesControl.PathStartMarkerCombo);
    Require((Path.StartMarker = vlmOpenArrow) and
      (EditorState.PathStartMarker = vlmOpenArrow),
      'Path start marker combo did not apply the value');
    History.Undo;
    Require(Path.StartMarker = vlmNone, 'Path start marker undo differs');
    PropertiesControl.PathEndMarkerCombo.ItemIndex := 9;
    PropertiesControl.PathEndMarkerCombo.OnChange(
      PropertiesControl.PathEndMarkerCombo);
    Require(Path.EndMarker = vlmStar,
      'Path end marker combo did not apply the value');
    PropertiesControl.PathEndMarkerSizeEdit.Text := '9';
    PropertiesControl.PathEndMarkerSizeEdit.OnExit(
      PropertiesControl.PathEndMarkerSizeEdit);
    Require(SameValue(Path.EndMarkerSize, 9.0) and
      SameValue(EditorState.PathEndMarkerSize, 9.0),
      'Path end marker size did not apply the value');
    History.Undo;
    Require(SameValue(Path.EndMarkerSize, 4.0),
      'Path end marker size undo differs');
    Path.Closed := True;
    PropertiesControl.RefreshFromDocument;
    Require(not PropertiesControl.PathStartMarkerCombo.Enabled and
      not PropertiesControl.PathStartMarkerSizeEdit.Enabled and
      not PropertiesControl.PathEndMarkerCombo.Enabled and
      not PropertiesControl.PathEndMarkerSizeEdit.Enabled,
      'Closed Path marker controls are enabled');
    Writeln('Path style properties tests: PASS');
  finally
    HostForm.Free;
    History.Free;
    EditorState.Free;
    Document.Free;
  end;
end.
