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
- Rectangle Documentから合成プレビュー、背景texture、imageオブジェクトを持つMIFを新規生成できる。
- 合成PNGの標準`tEXt`へ編集用Document JSONを保持し、自身が保存したMIFは再び編集状態へ読み込める。
- 元アプリ由来で編集用JSONを持たないMIFも、WebArt Designerの`element type=4`をRectangleとして
  キャンバス寸法、包含座標、塗りtexture、透明度、表示状態とともにDocumentへ読み込める。
- Rectangleは未回転Boundsと中心回りの回転角を保持し、回転MIFの4頂点と変換行列を読み書きできる。
- 編集画面では回転後の四辺に選択枠を表示し、各頂点の外側にある4つの回転マーカーから
  図形中心を基準に回転できる。ホバー中は円弧矢印カーソルを表示し、操作はUndo／Redo対象とする。
- キャンバスまたはレイヤー一覧にフォーカスがある場合、Deleteキーで選択オブジェクトを削除する。
- ファイルを開くダイアログではMIF／SVGを同じ対応ファイル一覧へ表示し、拡張子ごとのReaderへ振り分ける。
- Rectangleは塗り色と独立した線色、線幅、元アプリと同順の9線種を保持し、線幅0を線なしとして扱う。
  線設定はオブジェクト設定、作成時既定値、Undo／Redo、Skia描画、JSON／SVG／MIFへ接続済み。
- 直線レイヤーを追加し、作成、選択、移動、両端点編集、削除、線設定、Skia描画、JSON／SVG／MIFの
  基本往復へ対応した。MIFでは`vector element type=6`を使用する。
- 複数頂点を持つPathレイヤーを追加し、元アプリ製の連続直線と多角形MIFからvector PNGの
  頂点コマンド列を復元できる。Skia描画、本体選択、移動、削除、Undo／Redoまで接続済み。
  現段階ではPathの頂点編集、作成、プロパティ編集、保存は未実装。
- MIFの調査結果と確度は [mif_analysis.md](mif_analysis.md) を参照する。

## 単独アプリの外枠

- `TMainForm`はDocumentの生成、共通Frameの接続、単独アプリ用メニューとライフサイクルを担当する。
- Windowsの非クライアント領域へDWMのダークタイトルバー属性を適用する。
- 起動時にSkiaランタイムを取得し、終了時に解放する。
- 論理キャンバスは当面1920×1080固定とし、編集領域へ全体が収まる倍率で中央表示する。
- 100%未満で表示しても論理座標と出力サイズは1920×1080を維持する。
- FileメニューにOpen、Save、Save Asを置き、`Ctrl+O`、`Ctrl+S`、`Ctrl+Shift+S`へ接続する。
- 新規DocumentでもSave Asを使用でき、保存先確定後はSaveで同じファイルへ上書きする。
- 自身のMIFはDocumentへ展開し、元アプリ由来のMIFは編集データがないことをステータスへ表示する。
- Debug版でMIFを開くと、対象ファイルの隣に`<MIF名>.open.log`を生成する。外側チャンク、PNG寸法、
  CRC、`tEXt`、`waDA`、Document変換結果を記録し、Release版ではログを生成しない。

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
- Reader単体では診断と安全な読込のため未解釈チャンクを保持するが、Documentへ読み込んだ後の保存では
  未対応オブジェクト、未知メタデータ、元のチャンク順序が失われてもよい。
- アプリのMIF保存は元コンテナーの部分更新ではなく、現在のDocumentから新しいMIFを生成する。
- MIF保存は同じフォルダーの一時ファイルへ出力し、成功後に対象ファイルを置き換える。
- 新規MIFはRectangleをPNG化した`image`オブジェクトとして保存し、配置、透明度、表示状態を
  `waDAimage`メタデータへ記録する。
- Rectangle保存は`image`、塗りtexture、vector IPNG、線textureの4ブロックを生成し、
  subtype、element type、変換行列、元座標、texture有効状態を別アプリ製MIFに合わせる。
- 選択枠は画面上で各辺から基本8px離し、さらに`線幅 × ズーム ÷ 2`を加える。
  回転図形もローカル2軸へ同量を加えて、縦横比によらず各辺との間隔を揃える。
- 単一選択中の本体クリックで、標準の回転追従枠と旧アプリ型の外接枠を交互に切り替える。
  外接枠変形も当面はRectangleと回転角を維持し、台形・平行四辺形を生むアフィン変形は次段階とする。
- 旧アプリで回転後に外接枠から拡大縮小すると、結果は長方形ではなく台形になることを実機確認した。
  この互換挙動には四隅座標または一般アフィン変換を編集状態として保持する必要があるため、現在は保留する。
  VectArtDesignerでは当面、外接枠変形後も長方形と回転角を維持する。
- PNGの`pHYs`、`tEXt`、`waDA`は別アプリと同様に`IDAT`より前へ配置する。
- VectArtDesigner固有の編集情報は、元アプリが無視できるPNGの`tEXt`チャンクへJSONで記録する。
- MIFのtexture互換は配置／グラフプラグインの共通シリアライズへ持ち込まない。
- 元アプリ製`線.mif`は始点マーカー1、終点マーカー9、マーカーサイズ11を持つが、現段階では
  マーカーを読み飛ばして線本体だけを取り込む。新規直線MIFは両端マーカー0で保存する。
- 直線の選択表示は選択枠を描かず、始点と終点の外側へ6px空けた四角ハンドル2個だけを描く。
  ハンドル位置は画面座標基準とし、ズーム率にかかわらず見た目の間隔を一定にする。

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

1. PathのMIF／SVG／JSON保存、頂点編集、作成ツール、プロパティ編集を追加する。
2. logo、通常image、複数オブジェクトの読み込みを追加する。
3. 別アプリで回転MIFを開いた結果から、vector変換行列と補助IPNGを調整する。
4. Rectangle作成前スタイルUI、キーボード履歴統合、レイヤー名編集は保存・読込の基盤確認後に再開する。
