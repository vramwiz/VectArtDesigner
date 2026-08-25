program DarkPopupMenuTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Vcl.ExtCtrls,
  Vcl.Forms,
  VectArtDarkPopupMenu in 'Lib\DarkMenu\VectArtDarkPopupMenu.pas';

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  Form: TForm;
  Group: TVectArtDarkMenuGroup;
  Item: TPanel;
  MenuBar: TPanel;
  MenuOne: TVectArtDarkPopupMenu;
  MenuTwo: TVectArtDarkPopupMenu;
begin
  Form := TForm.CreateNew(nil);
  try
    Form.SetBounds(100, 100, 640, 480);
    MenuBar := TPanel.Create(Form);
    MenuBar.Parent := Form;
    MenuBar.SetBounds(0, 0, 640, 30);
    MenuOne := TVectArtDarkPopupMenu.CreateForHosts(Form, Form, MenuBar,
      'One', 0, 40, 160, 64);
    MenuTwo := TVectArtDarkPopupMenu.CreateForHosts(Form, Form, MenuBar,
      'Two', 40, 40, 160, 64);
    Group := TVectArtDarkMenuGroup.Create(Form);
    Group.RegisterMenu(MenuOne);
    Group.RegisterMenu(MenuTwo);
    Item := MenuOne.AddItem('Item', 0, nil);

    MenuOne.Open;
    Require(MenuOne.Visible and not MenuTwo.Visible,
      'First menu did not open exclusively');
    Require(MenuOne.OwnsControl(Item), 'Menu item ownership test failed');
    MenuTwo.Button.OnMouseEnter(MenuTwo.Button);
    Require(MenuTwo.Visible and not MenuOne.Visible,
      'Hover did not switch the open menu');
    Group.CloseAll;
    Require(not MenuOne.Visible and not MenuTwo.Visible,
      'Menu group did not close all menus');
    Writeln('Dark popup menu tests: PASS');
  finally
    Form.Free;
  end;
end.
