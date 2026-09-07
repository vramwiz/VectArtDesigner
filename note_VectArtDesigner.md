# VectArtDesigner 実装ノート

## 現在の位置付け

`VectArtDesigner`はIBM WebArt Designerとの互換性を目標に、MIFを主保存形式とする単体アプリである。
互換性はMIFコンテナーだけでなく、WebArt Designerのオブジェクト構造、編集操作、プロパティ設定と
保存結果の対応を基準にする。SVGも読み書きするが、編集モデルとUIはMIFで表現できる範囲へ限定する。
編集モード切替はなく、常に同じMIF仕様で編集する。

WebArt Designerの全機能をそのまま複製することは目的にしない。当面は作図・編集ツールとしての
機能追加を優先し、各ツールの実装時に実際の操作と操作前後のMIF差分を調査する。調査結果から
互換対象、変換対象、本アプリには不要な機能を分類する。

## プロジェクト構成

- 実行プロジェクト: `VectArtDesigner.dpr` / `VectArtDesigner.dproj`
- コアモデル: `Source/Core`
- 編集操作: `Source/Editor`
- 描画: `Source/Rendering`
- MIF永続化: `Source/Persistence/Mif`
- SVG永続化: `Source/Persistence/Svg`
- シェルとメニュー: `Source/Shell`
- レイヤーUI: `Source/Layers`
- オブジェクト設定: `Source/ObjectProperties`
- AviUtl2プラグインプロジェクトと専用ライブラリは2026-08-31の方針変更で削除した。
- 類似機能の実装時は`D:\DelphiProg\test\SYNC_ScreenLayout`のツール、モデル、作成・操作処理、描画、
  プロパティUI、Undo／Redo、テストを都度参照する。AviUtl2連携、プラグイン用公開口、独自JSON仕様は
  移植せず、本プロジェクトの単体アプリ方針とWebArt Designer互換MIFモデルへ適合させる。

## 編集キャンバスの描画経路と性能

- 編集キャンバスの最終合成、背景、選択表示は、利用可能な環境ではVCLの`TDirect2DCanvas`を使う。
  Direct2Dが利用できない場合または描画例外時はGDIへフォールバックする。
- Documentの図形本体はDirect2Dベクター描画ではない。共通レンダラーがSkia CPU raster-directで
  キャンバス全体を透明RGBA8へ描き、premultiplied BGRAの`TBitmap`へ変換した後でDirect2Dへ渡す。
- Document Revisionが変わるたび図形本体を全体再描画するため、大きなキャンバスや多数レイヤーでは
  頂点移動中の主な負荷になる。縮小表示時は実際の表示寸法までで描き、同一寸法の描画バッファを再利用する。
- 移動、リサイズ、回転、Path頂点移動は`BeginInteractiveUpdate`から`EndInteractiveUpdate`までの
  対話更新として扱う。ドラッグ中はキャンバスだけをライブ更新し、その他のUIは終了時に同期する。
- さらに負荷が問題になる段階では、変更図形の旧・新Boundsを使った部分再描画、または編集中レイヤーを
  背景キャッシュから分離する方式を優先して検討する。
- ベジェの制御点計算と表示用分割は`VectArtDesignerBezierGeometry`、手書き入力の間隔判定と頂点整理は
  `VectArtDesignerFreehandGeometry`へ分離し、図形作成の入力状態から幾何アルゴリズムを独立させる。

## 実装済みモデル

- Canvas: サイズ、背景色、透明背景
- Rectangle: 座標、回転、塗り、枠線色、線幅、線種、表示、ロック、不透明度
- Line: 始点／終点、線色、線幅、線種、cap、join、アンチエイリアス、始点／終点マーカーとサイズ
- Path: 頂点列、開閉、塗り、輪郭色、線幅、線種、cap、join、アンチエイリアス、
  開いたPathの始点／終点マーカーとサイズ
- Image: PNG、4頂点配置、image／logo区分、表示、ロック、不透明度
- 内部データの線種、品質、マーカー関連は通常名を使用する。`Mif`名はコンテナーと形式変換処理に限定する。

## 編集UI

- アプリ全体へDelphi 37.0標準の`Windows Modern Dark` VCL Styleを適用する。メニューなどは
  標準VCLを優先し、正しくダーク化できない箇所だけ独自方式で補う。
- スクロールバーとトラックスライダーは独自UIを維持する。キャンバス、ツールアイコン、線種など
  内容自体の可視化が必要なコントロールは、ダーク化だけを目的とする独自実装とは区別する。
- `編集`メニューはUndo、Redo、キャンバス設定を提供する。モード項目は持たない。
- Rectangle、Line、Pathの生成既定値は`TVectArtEditorState`で共有する。
- ベジェ曲線ツールはクリックしたアンカー列から滑らかな3次ベジェを自動生成し、ダブルクリックまたは
  右クリックで確定する。Pathモデルには指定したアンカーとベジェ属性だけを保持し、描画と当たり判定時に
  3次ベジェを生成するため、編集頂点には指定アンカーだけを表示する。
- Document変更はUndo／Redoコマンドを通して適用する。
- 複数選択時は共通値だけを表示し、ロックされたレイヤーを含む場合は変更を禁止する。
- 縮小表示時だけ線幅を画面上1px以上へ補正し、DocumentおよびMIF／SVG出力値は変更しない。
- 開いたPathは始点／終点マーカーと各サイズを編集できる。閉じたPathではマーカーを描画せず、
  Object Propertiesの対応項目を無効化する。
- Lineと開いたPathのマーカーはレイヤー一覧のGDI／Direct2Dサムネイルにも表示し、マーカー部分の
  クリックで対象レイヤーを選択できる。Path選択枠は頂点範囲を編集基準として維持する。
- 手書きはドラッグ軌跡をマウスアップ時に鋭角頂点の連続直線Pathへ変換する方式と、連続ベジェPathへ
  変換する方式の両方を実装している。入力中は軌跡を折れ線表示し、確定時に頂点整理と曲線変換を行う。
- パレットは選択、直線、連続線グループ、手書きグループ、Rectangleの5ボタンとする。連続線と手書きの
  各グループは、選択中のボタンを再クリックすると直線版／ベジェ版を交互に切り替え、アイコンにも反映する。
- 編集キャンバス上のツールキーは選択`S`、直線`L`、連続線グループ`P`、手書きグループ`B`とする。
  `P`と`B`の再入力はボタン再クリックと同じ切替を行う。文字入力欄では発動させず、`B`が将来の機能と
  競合した場合だけ割当を変更する。
- 派生図形は専用レイヤー型ではなく、閉じたPathの頂点データを生成するプリセットとして扱う。
  基本作図ツールより優先度を下げる。

## MIFとSVG

- MIF読込では既知のRectangle、Line、Path、ImageをDocumentへ変換する。
- ベジェ生成結果は現時点ではMIFへ連続直線として保存される。WebArt Designer固有の曲線コマンドは
  サンプルMIFを作成して構造を確認した後にネイティブ表現へ置き換える。
- MIF保存では元コンテナーを可能な範囲で再利用し、変換や非対応内容を`TMifExportReport`で返す。
- MIF生成を伴わない`TryAnalyzeVectArtMifExport`を編集状態の判定に使い、ステータスバーへ
  完全互換、変換あり、非対応を表示する。詳細はステータスのヒントへ表示する。
- SVGはMIF編集モデルへ変換できる要素と属性だけをDocumentへ取り込む。
- 詳細な対応範囲と変換・無視・エラー方針は[SVG互換表](svg_compatibility.md)を参照する。
- SVG読込で変換または無視した描画要素と装飾は`TSvgImportReport`へ記録し、アプリ上で通知する。
- SVGルートの`viewBox`と`preserveAspectRatio`はキャンバス座標へ変換する。角丸、個別不透明度、
  fill-rule、線の補助属性、filter／clip／mask／合成指定などMIFへ保持できない属性も読込レポートへ記録する。
- SVG保存はDocumentの値を標準SVG属性へ出力し、線種・マーカーなど必要な補助情報は既存のVAD名前空間で保持する。
- MIFとSVGのどちらから開いても同じDocument型と同じ編集UIを使用する。

## 現在の検証対象

- Document選択・Revision
- Rectangle、Line、Path、Imageの操作
- Object PropertiesとLine Toolbar
- 共通レンダラー
- Document JSON往復
- SVG往復と外部SVG取込
- MIFコンテナー往復、Document往復、WebArtサンプル取込

## ビルド

Debug:

```bat
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\VectArtDesigner\VectArtDesigner.dproj"" /t:Build /p:Config=Debug /p:Platform=Win64"
```

Release:

```bat
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\VectArtDesigner\VectArtDesigner.dproj"" /t:Build /p:Config=Release /p:Platform=Win64"
```

## 次の作業

1. 次は既存の`丸.mif`で`vector element type = 2`を確認できる楕円ツールを実装候補とする。
2. その後は曲線系、文字、塗り系をWebArt Designerの操作とMIF構造を確認しながら追加する。
3. 各ツールについてUI設定、MIFメタデータ、再読込結果の対応表を作る。
4. 調査した機能を互換対象、変換対象、不要機能に分類する。
5. 派生図形を閉じたPathの低優先度プリセットとして追加する。
6. MIF互換性詳細を常時開く専用UIが必要か、実際の編集操作で確認する。
7. 単体アプリ化後も残る外部ホスト用APIとコメントを整理する。
