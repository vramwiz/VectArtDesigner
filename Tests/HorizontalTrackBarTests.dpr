program HorizontalTrackBarTests;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  Vcl.Controls,
  Vcl.Forms,
  HorizontalTrackBarRenderer in
    'Lib\HorizontalTrackBar\HorizontalTrackBarRenderer.pas',
  HorizontalTrackBarControl in
    'Lib\HorizontalTrackBar\HorizontalTrackBarControl.pas';

type
  TTestHorizontalTrackBar = class(THorizontalTrackBarControl)
  public
    procedure SimulateClick(X: Integer);
    procedure SimulateDrag(X: Integer);
    function SimulateWheel(WheelDelta: Integer): Boolean;
  end;

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure TTestHorizontalTrackBar.SimulateClick(X: Integer);
begin
  MouseDown(mbLeft, [], X, Height div 2);
end;

procedure TTestHorizontalTrackBar.SimulateDrag(X: Integer);
begin
  MouseMove([ssLeft], X, Height div 2);
  MouseUp(mbLeft, [], X, Height div 2);
end;

function TTestHorizontalTrackBar.SimulateWheel(
  WheelDelta: Integer): Boolean;
begin
  Result := DoMouseWheel([], WheelDelta, Point(0, 0));
end;

var
  Form: TForm;
  TrackBar: TTestHorizontalTrackBar;
begin
  Form := TForm.CreateNew(nil);
  TrackBar := TTestHorizontalTrackBar.Create(Form);
  try
    TrackBar.Parent := Form;
    TrackBar.SetBounds(0, 0, 200, 40);
    TrackBar.SetRange(0, 100);
    TrackBar.SmallChange := 1;
    Form.Show;
    Application.ProcessMessages;

    TrackBar.SimulateClick(100);
    Require(TrackBar.Position = 50,
      'Track click did not move to the clicked position');
    TrackBar.SimulateDrag(192);
    Require(TrackBar.Position = 100,
      'Track drag did not follow the mouse position');
    Require(TrackBar.SimulateWheel(-120) and
      (TrackBar.Position = 99),
      'Mouse wheel did not move by SmallChange');
    Writeln('Horizontal track bar tests: PASS');
  finally
    TrackBar.Free;
    Form.Free;
  end;
end.
