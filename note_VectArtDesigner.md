# VectArtDesigner 固有作業ノート

単独配置編集アプリ`VectArtDesigner`固有の現在状況、設定、MIF互換処理、ビルド方法を扱う。
3プロジェクト共通の設計と規約は [note.md](note.md)、完了済み作業は [HISTORY.md](HISTORY.md) を参照する。

## プロジェクト

- 製品名とDelphiプロジェクト名は`VectArtDesigner`とする。
- 作業フォルダーは`D:\DelphiProg\test\VectArtDesigner`とする。このフォルダーは今後3プロジェクトのルートとなる。
- `VectArtDesigner.dpr`と`VectArtDesigner.dproj`はルートへ置いたままとする。
- `WRT2646\Client`のVCLプロジェクト設定を基にしたWin64プロジェクトを使用している。

## 現在の段階

- 中央編集、レイヤー、編集ツール、オブジェクト設定の4つのFrameを共通Contextへ接続済み。
- Rectangleの作成、選択、複数選択、移動、拡大縮小、レイヤー操作、Undo／Redoを実装済み。
- MIF外側コンテナーのReader／Writerを実装し、調査用MIF全12ファイルで完全一致の無変更保存を確認済み。
- Fileメニュー、標準ファイルダイアログ、ツールバー、キーボードからMIFを開く／保存するGUIを接続済み。
- MIF読込後のDocument展開とキャンバス表示は未実装。現在はコンテナーを保持して再保存できる段階。
- MIFの調査結果と確度は [mif_analysis.md](mif_analysis.md) を参照する。

## 単独アプリの外枠

- `TMainForm`はDocumentの生成、共通Frameの接続、単独アプリ用メニューとライフサイクルを担当する。
- Windowsの非クライアント領域へDWMのダークタイトルバー属性を適用する。
- 起動時にSkiaランタイムを取得し、終了時に解放する。
- 論理キャンバスは当面1920×1080固定とし、編集領域へ全体が収まる倍率で中央表示する。
- 100%未満で表示しても論理座標と出力サイズは1920×1080を維持する。
- FileメニューにOpen、Save、Save Asを置き、`Ctrl+O`、`Ctrl+S`、`Ctrl+Shift+S`へ接続する。
- MIF未読込時はSaveとSave Asを無効にする。
- MIF読込後はファイル名とチャンク数、およびDocument展開が未実装であることをステータスへ表示する。

## 単独アプリの設定保存

- 設定ルートは`TPath.GetDocumentsPath`から取得した`VectArtDesigner`フォルダーとする。
- メインフォーム位置とツール配置は`Documents\VectArtDesigner\MainForm.ini`へ保存する。
- `MainForm.ini`には形式バージョン、通常時座標・サイズ、最大化状態、各ツールの表示状態、ドック側、
  順序、ドック／フローティング状態、フローティング座標・サイズを記録する。
- 保存座標を現在のモニター作業領域へ補正し、画面外へ取り残されたフォームを起動時に戻す。
- 将来追加する各ツール固有設定は`Documents\VectArtDesigner\<ToolId>\Settings.ini`へ分離する。
- INIのセクション名には表示文字列ではなく、変更しない内部IDを使用する。

## MIF固有方針

- 調査用`.mif`ファイルはGit同期対象とし、バイナリーファイルとして扱う。
- MIFコンテナーではMIMGシグネチャ、MHDR、IPNG、MENDを境界検査付きで読み書きする。
- 未解釈の外側チャンクとIPNGは、互換保存のため元のバイト列と順序を保持する。
- MIF保存は同じフォルダーの一時ファイルへ出力し、成功後に対象ファイルを置き換える。
- MIFのtexture互換は配置／グラフプラグインの共通シリアライズへ持ち込まない。

## VectArtDesignerビルド

Debug:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\VectArtDesigner\VectArtDesigner.dproj"" /t:Build /p:Config=Debug /p:Platform=Win64"
```

Release:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\VectArtDesigner\VectArtDesigner.dproj"" /t:Build /p:Config=Release /p:Platform=Win64"
```

## 次の作業

1. MIFの各IPNG内にあるPNGチャンクを解析し、`tEXt`と独自`waDA`メタデータを型付きで取得する。
2. 先頭の合成画像、背景texture、編集対象image、補助texture／vectorの関連付けを確認する。
3. 未知IPNGを保持したまま、既知オブジェクトをDocumentへ読み込んで再保存する境界を設計する。
4. Rectangle作成前スタイルUI、キーボード履歴統合、レイヤー名編集は保存・読込の基盤確認後に再開する。
