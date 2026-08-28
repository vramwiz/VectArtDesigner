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
- 縮小した編集ビューでは線幅を画面上1px以上へ補正する。Document、MIF、SVG、AviUtl2出力は
  補正せず、`VectArtDesignerCanvas.pas`の`ENABLE_THIN_STROKE_PREVIEW`で補正全体を無効化できる。
- 直線レイヤーを追加し、作成、選択、移動、両端点編集、削除、線設定、Skia描画、JSON／SVG／MIFの
  基本往復へ対応した。MIFでは`vector element type=6`を使用する。
- 複数頂点を持つPathレイヤーを追加し、元アプリ製の連続直線と多角形MIFからvector PNGの
  頂点コマンド列を復元できる。Skia描画、本体選択、移動、削除、Undo／Redoまで接続済み。
  MIFでは同じ頂点コマンドPNGを新規生成し、SVGの`polyline`／`polygon`と内部JSONでも往復できる。
  選択時の各頂点ドラッグ、クリック入力による開いたPath／閉じたPathの作成、外接範囲、塗り、線、
  不透明度のプロパティ編集にも対応し、各操作をUndo／Redo対象にしている。
- MIFの調査結果と確度は [mif_analysis.md](mif_analysis.md) を参照する。
- 元アプリ製MIFの通常`image`と`logo`をPNG本体と配置4頂点を保持する画像レイヤーとして読み込める。
  回転と左右／上下反転を4頂点からSkia描画へ反映し、複数画像の順序を維持する。MIF再保存では元の
  PNGメタデータを再利用する。`logo`は現段階では見た目を優先した画像扱いで、文字としては未編集とする。
- 画像はキャンバス上の本体クリックで選択し、4頂点に追従する選択枠から移動、辺／四隅リサイズ、
  回転を操作できる。反転状態と回転方向を維持したまま4頂点を更新し、Undo／RedoとMIF配置メタデータの
  再保存へ接続している。画像レイヤーの削除と積層順変更も既存操作バーから実行できる。
- 単一画像はオブジェクト設定から基準頂点X／Y、回転軸に沿った幅／高さ、不透明度を数値編集できる。
  回転と反転方向を維持して4頂点を再計算し、Undo／Redo対象とする。内部JSONではPNGをBase64と4頂点で、
  SVGでは埋め込みPNGの標準`image`要素と`matrix`変換で保存・再読込できる。
- 複数画像は共通の外接枠からまとめて移動・縦横拡大縮小でき、各画像の回転・反転を4頂点の相対関係として
  維持する。操作は1回のUndo／Redoへまとめる。同種の複数画像はPNG本体と属性を保持して24pxずらして
  複製できる。SVGの外部参照画像は自己完結性とオフライン動作を優先して読み込まず、埋め込みPNGだけを扱う。
- 独自`ShortcutAction`をプロジェクト内へ取り込み、ファイル、履歴、削除、全選択、複製、選択解除を
  一元管理する。レイヤー一覧はCtrlクリックで追加／解除、Shiftクリックでアンカーからの範囲選択、
  Ctrl+Shiftクリックで範囲追加を行い、キャンバスではCtrlクリックで選択を追加／解除できる。
- 選択変更はDocumentの描画リビジョンを進めずUIだけへ通知し、画像レイヤーのサムネイルPNGは
  デコード結果をキャッシュする。画像選択だけで2Kキャンバスの再合成やPNG再デコードを行わない。
- Lineのレイヤーサムネイルは中心線を基準に配置し、実線幅を対数的な1～10pxの表示幅へ変換する。
  表示線幅ぶん端点を内側へ寄せ、背景範囲で安全クリップし、実際の線幅は詳細文字列へ表示する。
- 上部コンテキストツールバーはLineツールまたはLineだけの選択時に「詳細」を表示する。詳細パネル上部の
  線幅と線種は、未選択時は
  黒・1px・実線を初期値とする次のLine設定、選択時は単一／複数Lineの現在値または混在状態を表示し、
  一括変更を1回のUndo／Redoへまとめる。作成中プレビュー、MIF保存・再読込まで同じ値を使用する。
- 線幅は共通`HorizontalTrackBar`と数値欄を横並びにする。トラックバーは1～100pxを1px単位で
  扱い、クリック位置への移動、ドラッグ追従、ホイール1px変更に対応する。ドラッグ中は即時表示し、
  マウスを離した時点で1回のUndoとして確定する。数値欄では100pxを超える値も直接指定できる。
- Lineツールバーは対象表示とダーク表示の「詳細」ボタンだけを基本UIとする。詳細パネルは横幅を抑え、
  線幅、その下に線種を縦に並べ、続けて線端、接合、アンチエイリアス、矢印の装飾を配置する。
- Lineツールバーの選択状態、編集、Undo同期と独自コントロール描画を分離し、線端・接合・AAの
  ダークアイコンは`VectArtDesignerLineStyleControls`へ集約する。
- 線の先端形状はリストではなく、平型・角型・丸型を示す3個のアイコンボタンで選択する。
  最初の詳細設定として線端形状（Butt／Square／Round）を実装し、作成初期値、単一／複数Line編集、
  作成中プレビュー、Undo／Redo、JSON、SVGの`stroke-linecap`、MIFの`vector stroke cap`へ接続する。
- 接合形式もマイター／ベベル／ラウンドの3個のアイコンボタンで選択する。直線だけでは接合部は
  描画されないが、将来の連続線でも値を失わないようDocument、Undo／Redo、JSON、SVGの
  `stroke-linejoin`、MIFの`vector stroke join`へ接続する。
- 線端・接合形式のアイコンは端の四角・丸・接合部を維持し、線の胴体を細く描いて判別しやすくする。
- 詳細パネルのAAボタンでアンチエイリアスを切り替える。新規作成、複数Line、Undo／Redo、作成中の
  Direct2Dプレビュー、共有Renderer、JSON、SVGの`shape-rendering`、MIFの`vector quality`へ接続する。
- 始点／終点形状はアイコン式コンボで、なし、開いた矢印、塗りつぶし矢印、幅広矢印、丸、菱形、
  くぼみ矢印、小矢印、斜線、星形の10項目から独立して選択する。作成中プレビュー、共有Renderer、
  Undo／Redo、JSON、SVG marker、MIFの`vector start/end stroke marker`へ接続する。
- 開いた矢印と斜線は、先端形状自身の輪郭線幅を元のLineの線幅へ追従させる。
- 「詳細」パネルは内部のボタン、コンボ、トラックバー間でフォーカスが移る間は表示を維持し、
  上部ツール、キャンバス、別ツール、別ウィンドウへフォーカスが移ると自動的に閉じる。
- 始点／終点の矢印サイズはそれぞれ専用トラックバーで1～100を1刻みで編集する。矢印なしでは
  対応トラックを無効化し、クリック、ドラッグ、ホイール操作、複数Line編集、Undo／Redo、新規作成、
  作成中プレビュー、共有Renderer、JSON、SVGへ接続する。MIFでは実サンプルと同じ個別メタデータへ
  保存し、互換範囲の1～20へWriterだけで丸める。

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
- Document、編集UI、SVGはMIFの装飾値上限に制限されない。MIF固有の数値制限や未対応表現への縮退は
  Writerの互換変換層だけで行い、保存によって編集中のDocument値を変更しない。
- 元アプリ製`線.mif`は始点マーカー1、終点マーカー9、マーカーサイズ11を持つ。添付された元UIの
  一覧順に従い、MIF値0～9をなし、開いた矢印、塗りつぶし矢印、幅広矢印、丸、菱形、くぼみ矢印、
  小矢印、斜線、星形として取り込み・保存する。
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

1. Line詳細設定の次の装飾項目を選定し、同じ縦断方式で実装する。
