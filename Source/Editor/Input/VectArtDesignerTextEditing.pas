// Receives committed Windows/IME text while the canvas owns the editable text buffer.
// IMEの未確定文字列はDocumentへ直接書かず、確定通知だけを編集処理へ渡す。
unit VectArtDesignerTextEditing;

interface

uses
  Winapi.Messages, Vcl.StdCtrls;

type
  TVectArtCommittedTextEvent = procedure(Sender: TObject;
    const Text: string) of object;
  TVectArtCompositionEvent = procedure(Sender: TObject; const Text: string;
    CursorPosition: Integer; Active: Boolean) of object;

  TVectArtImeEdit = class(TEdit)
  private
    FOnCommittedText: TVectArtCommittedTextEvent;
    FOnComposition: TVectArtCompositionEvent;
    procedure WMChar(var Message: TWMChar); message WM_CHAR;
    procedure WMImeComposition(var Message: TMessage);
      message WM_IME_COMPOSITION;
    procedure WMImeEndComposition(var Message: TMessage);
      message WM_IME_ENDCOMPOSITION;
    procedure WMImeStartComposition(var Message: TMessage);
      message WM_IME_STARTCOMPOSITION;
  public
    property OnCommittedText: TVectArtCommittedTextEvent
      read FOnCommittedText write FOnCommittedText;
    property OnComposition: TVectArtCompositionEvent
      read FOnComposition write FOnComposition;
  end;

procedure InsertVectArtTextAtCaret(var Buffer: string; var CaretIndex: Integer;
  const Text: string);

implementation

uses
  Winapi.Imm;

procedure InsertVectArtTextAtCaret(var Buffer: string; var CaretIndex: Integer;
  const Text: string);
begin
  if Text = '' then
    Exit;
  Insert(Text, Buffer, CaretIndex + 1);
  Inc(CaretIndex, Length(Text));
end;

procedure TVectArtImeEdit.WMChar(var Message: TWMChar);
begin
  if (Message.CharCode >= 32) and Assigned(FOnCommittedText) then
    FOnCommittedText(Self, string(WideChar(Message.CharCode)));
  Message.Result := 0;
end;

procedure TVectArtImeEdit.WMImeComposition(var Message: TMessage);
var
  ByteCount: Integer;
  CursorPosition: Integer;
  InputContext: HIMC;
  Text: string;
begin
  Text := '';
  CursorPosition := 0;
  InputContext := ImmGetContext(Handle);
  if InputContext <> 0 then
  try
    ByteCount := ImmGetCompositionStringW(InputContext, GCS_COMPSTR, nil, 0);
    if ByteCount > 0 then
    begin
      SetLength(Text, ByteCount div SizeOf(Char));
      ImmGetCompositionStringW(InputContext, GCS_COMPSTR, PChar(Text),
        ByteCount);
    end;
    CursorPosition := ImmGetCompositionStringW(InputContext,
      GCS_CURSORPOS, nil, 0);
    if CursorPosition < 0 then
      CursorPosition := 0;
  finally
    ImmReleaseContext(Handle, InputContext);
  end;
  inherited;
  if Assigned(FOnComposition) then
    FOnComposition(Self, Text, CursorPosition, True);
end;

procedure TVectArtImeEdit.WMImeEndComposition(var Message: TMessage);
begin
  inherited;
  if Assigned(FOnComposition) then
    FOnComposition(Self, '', 0, False);
end;

procedure TVectArtImeEdit.WMImeStartComposition(var Message: TMessage);
begin
  inherited;
  if Assigned(FOnComposition) then
    FOnComposition(Self, '', 0, True);
end;

end.
