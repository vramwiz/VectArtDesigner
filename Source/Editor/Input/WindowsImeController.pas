// Preserves the Windows IME open state across canvas text-edit sessions.
// ユーザーのIME状態を編集終了後に戻し、アプリ操作で恒久的に変更しない。
unit WindowsImeController;

interface

uses
  Winapi.Windows;

type
  TWindowsImeState = record
    WasOpen: Boolean;
    Valid: Boolean;
  end;

procedure SuspendWindowsIme(WindowHandle: HWND; var State: TWindowsImeState);
procedure RestoreWindowsIme(WindowHandle: HWND; var State: TWindowsImeState);

implementation

uses
  Winapi.Imm;

procedure SuspendWindowsIme(WindowHandle: HWND; var State: TWindowsImeState);
var
  InputContext: HIMC;
begin
  State.Valid := False;
  if (WindowHandle = 0) or not IsWindow(WindowHandle) then
    Exit;
  InputContext := ImmGetContext(WindowHandle);
  if InputContext = 0 then
    Exit;
  try
    State.WasOpen := ImmGetOpenStatus(InputContext);
    State.Valid := True;
    if State.WasOpen then
      ImmSetOpenStatus(InputContext, False);
  finally
    ImmReleaseContext(WindowHandle, InputContext);
  end;
end;

procedure RestoreWindowsIme(WindowHandle: HWND; var State: TWindowsImeState);
var
  InputContext: HIMC;
begin
  if not State.Valid or (WindowHandle = 0) or not IsWindow(WindowHandle) then
    Exit;
  InputContext := ImmGetContext(WindowHandle);
  if InputContext = 0 then
    Exit;
  try
    ImmSetOpenStatus(InputContext, State.WasOpen);
    State.Valid := False;
  finally
    ImmReleaseContext(WindowHandle, InputContext);
  end;
end;

end.
