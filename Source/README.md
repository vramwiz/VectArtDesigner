# ソース構成

グラデーションと画像テクスチャは図形の塗り・線・文字の3対象でいったん完成（2026-09-09、ユーザー動作確認済み）。今後の追加は以下の責務へ配置し、公開窓口へ描画や属性変換を集積しない。

| フォルダ | 担当 |
|---|---|
| Rendering/Paint | ペイント適用、グラデーション座標、角形・波状シェーダー |
| Persistence/Mif | コンテナー、公開変換APIと互換性判定、ネイティブ読込、PNGメタデータ |
| Persistence/Mif/Rendering | 埋込PNG描画、画像配置と数値属性、ペイント属性の入出力 |
| Persistence/Svg/Paint | ペイント定義の読込と書出し、標準表現のない方式の表示PNG |
| Persistence | Document JSON、選択画像の埋込PNG変換（TextureImage） |
| Shell | メイン画面でのUI接続と状態表示 |
| Shell/Document | Revisionに基づく未保存状態、表示名、破棄前の保存確認 |
| Shell/File | ファイルメニュー、SVG／MIF入出力、最近使ったファイルの永続化 |
| ObjectProperties/Color | 色選択UI、色見本、ペイントプレビュー |
| Core/Commands/Appearance | 塗り・線・文字のペイントと枠／塗りの有効状態 |
| Core/Commands/Transform | 選択全体の整列・反転・回転 |
| Core/Commands/Structure | 挿入・削除・積層順・グループ所属・表示切替 |
| Core/Commands | 共通編集コマンドと一括挿入 |
| Core/Transfer | レイヤー状態から挿入・削除用データへの共通転送 |
| Editor/Clipboard | 選択オブジェクト＋透明PNGのコピー、内部形式優先の貼り付け |
| Layers/Interaction | レイヤー一覧D&Dの挿入境界、順序計算、Undo／Redo |

MIFの依存方向は公開変換APIからReader／Raster／Paint／Placementへ向ける。ReaderとPNG描画は公開変換APIへ依存しない。SVGの図形読込はPaintReaderへペイント解析を、書出しはPaintWriterへ定義生成を委譲する。XML属性・数値表記の共通処理はSvgPrimitivesへ置く。色ポップアップはTextureImageへ画像変換を委ね、ダイアログと適用通知を担当する。描画用シェーダーはUIや永続化へ依存しない。

ユニット先頭には目的と担当範囲を書く。処理内コメントは意図・互換性上の制約・所有権などを説明し、コードの言い換えを増やさない。日本語を含むPascalソースはUTF-8 BOM付きとする。

ユニットの追加・移動時は本体のdpr／dprojとテスト内の明示パスを更新する。検証出力はTestOutput配下へ限定する。

Source内の各フォルダは最大6ユニット（今回の追加後も同じ）。大量のユニットが集中したフォルダはなく、現在の責務別分類を維持する。

新規キャンバスは既存のDocument参照を交換せず、Document.ResetでCanvas以外のレイヤー、選択、識別子を初期化する。Shell/FileActionsUIはメニューとダイアログ、Shell/File/RecentFilesは最大10件の履歴と設定ファイル、Shell/File/DocumentFileControllerはSVG／MIF入出力とMIFコンテナーの所有権を担当する。MainFormは各処理の接続とステータス表示だけを行う。

Shell/Document/DocumentSessionはDocument.Revisionの変化を未保存変更として追跡し、選択変更だけでは未保存扱いにしない。終了、新規キャンバス、ウィザード新規作成、別ファイル読込の前に保存確認を行い、保存が失敗またはキャンセルされた場合は後続操作を中止する。保存処理はコールバックとし、ファイル形式へ依存させない。

作成色はEditorStateのColor1／Color2だけで保持し、ToolPalette/CreationColorsが単色編集を担当する。オブジェクト設定から作成色を更新しない。Dockの親ウィンドウ確定後に色欄を生成する。

テンプレ図形はToolPalette/TemplatePanelFrameを独立した左ドック枠とし、TemplatePickerを埋め込む。TemplatePickerは分類・枠／塗りモード・図形選択だけを担当し、専用色UIを持たない。一覧描画と配置結果はToolPalette下部と同じEditorState.Color1／Color2を参照する。


Core/Appearance/ObjectAttributesは線・図形・文字の見た目のスナップショットとデータへの適用を担当する。
作成は開始時の単一選択を取得し、同分類のみ適用する。線＝直線／開いたPath、図形＝Rectangle／閉じたPath、文字＝Text。
形状・位置・サイズ・回転・反転・名前・グループ・ロック・表示状態・文字内容は対象外。不透明度は見た目として含める。
四角に存在しない線端・品質などは貼付け先の初期値を維持する。画像バイトは取得時と適用時に複製する。
将来の既存オブジェクトへの属性コピーはCaptureVectArtObjectAttributesとApplyVectArtObjectAttributesを再利用し、
対象データの変更通知・Undoを呼出側で処理する。現段階では貼付け操作のUIは追加していない。


図形の影はDocumentのShadowレコードを正本とする。Rendering/Paint/ShadowPaintが合成・外形、
Persistence/Mif/Rendering/MifShadowがネイティブ属性・影付きPNG配置、Persistence/Svg/Paint/SvgShadowが標準SVGの対応を担当する。
ObjectProperties/Pages/ShadowSettingsは編集UI、Core/Commands/Appearance/ShadowCommandは履歴、ObjectAttributesは図形間の引継ぎを担当する。
影付きPNGの領域と、編集対象の本体領域は分離する。文字の影／装飾はこの図形向け機能へ暗黙に含めない。


設定カテゴリの積み上げはObjectProperties/Pages/SettingsSectionsが担当する。PageControl／TabSheetや
カテゴリ切替を使用せず、既存の設定パネルを1つの縦スクロール領域へalTopで並べる。利用可能なパネルを
すべて同時表示し、見出しと1pxベベルを持つホストで区切る。パネルの入力欄と編集コマンドは
ObjectPropertiesControl側の担当を維持する。

- UI/VectArtDesignerSettingsFont.pas: 設定ページと色ポップアップの共通文字寸法・書体と、入れ子の欄への適用を担当する。


設定編集の責務分離（2026-09-09）:
- Core/Selection/VectArtDesignerSettingsSelection.pas: 適用対象の分類、ロック判定、四角選択の境界。UI非依存で状態は変更しない。
- Core/Commands/Geometry/VectArtDesignerSettingsGeometry.pas: 情報ページからの位置・寸法適用とUndo登録。文字・画像・Path・四角の変形規則を担当する。
- ObjectProperties/Pages/: カテゴリ切替、影、未対応装飾のページ専用UIを配置する。
- ObjectPropertiesControlは入力検証と表示同期を担当し、選択判定と変形を上記ユニットへ委譲する。


レイヤー一覧のスクロール（2026-09-09）:
- Lib/VerticalScrollBar/VerticalScrollBarControl.pas: Windows標準スクロールバーに依存しない暗色の縦スクロールバー。範囲・ページ量・ホイール・キー・つまみ操作を担当する。
- Layers/VectArtDesignerLayerRenderer.pas: 下端基準の行順を保ったスクロール量、全行の内容高、1行単位の移動量を担当する。
- Layers/VectArtDesignerLayerList.pas: 表示範囲、スクロールバー同期、ホイール入力、スクロール後のクリック判定を担当する。グループ展開とDocument変更時は表示行数から範囲を再計算する。
- Layers/Interaction/VectArtDesignerLayerDragDrop.pas: D&Dの編集可否、フラットグループ境界、移動後のLayerId順とUndo／Redoを担当する。LayerListはマウス捕捉、挿入線、自動スクロールだけを保持する。
- Layersの一覧表示は可視／ロック操作とサムネイルに限定し、名称・寸法・不透明度はObjectPropertiesへ集約する。左ドックでは一覧を170pxに抑え、独立したテンプレ図形枠へ幅を配分する。

完成整理（2026-09-09）:
- ClipboardとLayerDuplicationに重複していたRectangle／Line／Path／Imageのデータ取得と種類別削除をCore/Transferへ集約した。画像バイト列とPath頂点列は元レイヤーの寿命から分離する。
- LayerListへ追加されたD&Dの順序構築と履歴コマンドをLayers/Interactionへ分離した。表示ControlはDocumentの並びを直接組み替えず、生成された1コマンドを実行する。

切り取り領域（2026-09-09）:
- Core/EditorStateは切り取りツールの四角／丸／鋭角の閉じた図形／閉じた自由曲線という4モードだけを共有し、選択領域自体はDocumentへ保存しない。
- Editor/Clipboard/CutoutSelectionはキャンバス論理座標の一時領域、マウス入力、表示輪郭を担当する。Canvasは入力転送とGDI／Direct2Dの点線表示を担当する。
- Editor/Clipboard/ClipboardOperationsは選択領域とキャンバスの交差範囲を再描画し、非四角形の外側を透明化してPNG／Bitmapをクリップボードへ渡す。独自オブジェクト形式は付加しない。
- Editor/Clipboard/AttributePasteOperationsは単一オブジェクトの独自クリップボード形式から、色・サイズ・文字・フォント名だけを選択中の互換オブジェクトへ一括適用し、1回のUndo／Redoで戻せるようにする。
- 16384pxを超える領域はレンダラー上限内へ縮小し、形状マスクのサンプリング座標も同じ縮小率へ追従する。
