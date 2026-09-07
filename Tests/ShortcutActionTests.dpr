program ShortcutActionTests;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.SysUtils,
  VectArtDesignerGeometry in
    'Source\Core\VectArtDesignerGeometry.pas',
  VectArtDesignerDocument in
    'Source\Core\VectArtDesignerDocument.pas',
  VectArtDesignerEditorState in
    'Source\Core\VectArtDesignerEditorState.pas',
  ShortcutAction in 'Lib\ShortcutAction\ShortcutAction.pas';

type
  TGlobalGate = class
  public
    Allowed: Boolean;
    function CanExecute: Boolean;
  end;

function TGlobalGate.CanExecute: Boolean;
begin
  Result := Allowed;
end;

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  Action: TShortcutAction;
  AllowItem: Boolean;
  DuplicateRejected: Boolean;
  Fired: Integer;
  Gate: TGlobalGate;
  Key: Word;
  PressKey: Char;
  State: TVectArtEditorState;
begin
  Action := TShortcutAction.Create;
  Gate := TGlobalGate.Create;
  State := TVectArtEditorState.Create;
  try
    Fired := 0;
    AllowItem := False;
    Action.Add(Ord('A'), [ssCtrl],
      procedure
      begin
        Inc(Fired);
      end,
      function: Boolean
      begin
        Result := AllowItem;
      end);

    Key := Ord('A');
    Require(not Action.KeyDown(Key, [ssCtrl]),
      'Disabled item consumed its shortcut');
    Require((Key = Ord('A')) and (Fired = 0),
      'Disabled item changed state');

    AllowItem := True;
    Key := Ord('A');
    Require(Action.KeyDown(Key, [ssCtrl, ssLeft]),
      'Mouse modifier was not ignored');
    Require((Key = 0) and (Fired = 1),
      'Enabled shortcut was not executed and consumed');

    Action.Enabled := False;
    Key := Ord('A');
    Require(not Action.KeyDown(Key, [ssCtrl]),
      'Disabled shortcut manager consumed a key');
    Require((Key = Ord('A')) and (Fired = 1),
      'Disabled shortcut manager executed an action');
    Action.Enabled := True;

    Gate.Allowed := False;
    Action.OnCanExecute := Gate.CanExecute;
    Key := Ord('A');
    Require(not Action.KeyDown(Key, [ssCtrl]),
      'Global gate did not suppress the shortcut');
    Gate.Allowed := True;
    Action.Add('x',
      procedure
      begin
        Inc(Fired);
      end);
    PressKey := 'x';
    Require(Action.ProcessKeyPress(PressKey) and (PressKey = #0) and
      (Fired = 2), 'KeyPress shortcut was not executed and consumed');

    DuplicateRejected := False;
    try
      Action.Add(Ord('A'), [ssCtrl, ssRight],
        procedure
        begin
        end);
    except
      on EArgumentException do
        DuplicateRejected := True;
    end;
    Require(DuplicateRejected, 'Duplicate shortcut was accepted');

    Action.OnCanExecute := nil;
    Action.Add(Ord('S'), [],
      procedure
      begin
        State.CurrentTool := vetSelect;
      end);
    Action.Add(Ord('L'), [],
      procedure
      begin
        State.CurrentTool := vetLine;
      end);
    Action.Add(Ord('P'), [],
      procedure
      begin
        State.SelectPathToolGroup;
      end);
    Action.Add(Ord('B'), [],
      procedure
      begin
        State.SelectFreehandToolGroup;
      end);

    Key := Ord('P');
    Require(Action.KeyDown(Key, []) and (State.CurrentTool = vetPath),
      'P did not select the continuous-line tool');
    Key := Ord('P');
    Require(Action.KeyDown(Key, []) and (State.CurrentTool = vetBezier),
      'Repeated P did not select the continuous-Bezier tool');
    Key := Ord('P');
    Require(Action.KeyDown(Key, []) and (State.CurrentTool = vetPath),
      'Third P did not cycle back to the continuous-line tool');

    Key := Ord('B');
    Require(Action.KeyDown(Key, []) and
      (State.CurrentTool = vetFreehandLine),
      'B did not select the freehand-line tool');
    Key := Ord('B');
    Require(Action.KeyDown(Key, []) and
      (State.CurrentTool = vetFreehandBezier),
      'Repeated B did not select the freehand-Bezier tool');
    Key := Ord('B');
    Require(Action.KeyDown(Key, []) and
      (State.CurrentTool = vetFreehandLine),
      'Third B did not cycle back to the freehand-line tool');

    Key := Ord('L');
    Require(Action.KeyDown(Key, []) and (State.CurrentTool = vetLine),
      'L did not select the line tool');
    Key := Ord('S');
    Require(Action.KeyDown(Key, []) and (State.CurrentTool = vetSelect),
      'S did not select the selection tool');
    Writeln('Shortcut action tests: PASS');
  finally
    State.Free;
    Gate.Free;
    Action.Free;
  end;
end.
