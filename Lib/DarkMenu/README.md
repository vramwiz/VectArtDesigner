# DarkMenu

`VectArtDarkPopupMenu.pas`は、VCLのダーク表示用トップメニューとポップアップを提供する。
機能固有の処理は持たず、アプリケーションとプラグインのどちらからでも同じソースを利用できる。

## 新規メニュー

```pascal
Menu := TVectArtDarkPopupMenu.CreateForHosts(Owner, MainForm, MenuBar,
  '編集', 36, 36, 190, 96);
Menu.AddItem('項目', 0, ItemClick);
MenuGroup.RegisterMenu(Menu);
```

`CreateForHosts`で生成したトップボタン、ポップアップ、追加項目はMenuが所有する。
Menu自体は指定した`Owner`が所有する。

## DFM上の既存Controlを使う場合

```pascal
Menu := TVectArtDarkPopupMenu.CreateForControls(Owner, MainForm,
  ExistingButton, ExistingPopup);
MenuGroup.RegisterMenu(Menu);
```

既存Controlの所有権は変更されない。接続時にトップボタンの`OnClick`と`OnMouseEnter`を
メニュー用処理へ置き換えるため、機能処理はポップアップ内の各項目へ設定する。

## メニューグループ

`TVectArtDarkMenuGroup`へ同じ画面のMenuを登録すると、次の標準的な動作をまとめて処理する。

- 開いているメニューを隣のトップメニューへのホバーで切り替える。
- メニュー外のクリックで全メニューを閉じる。
- アプリケーションが非アクティブになったとき全メニューを閉じる。
- 新しいメニューを開く直前に、他のメニューを閉じる。

グループは登録したMenuを所有しない。Menuとグループは、同じFormなど十分に長い寿命を持つ
Ownerへ作成する。
