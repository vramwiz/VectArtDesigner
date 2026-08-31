# SVG入出力のMIF編集互換範囲

`VectArtDesigner`ではSVGを独立した高機能編集形式とはせず、MIF編集モデルとの交換形式として扱う。
読込時は対応する図形をDocumentへ変換し、変換または無視した描画要素を`TSvgImportReport`で通知する。

## 読込結果

| 区分 | 動作 |
| --- | --- |
| 対応 | 表示と編集に必要な値をDocumentへ保持する。通知しない。 |
| 変換 | MIF編集モデルの別表現へ確定変換して読み込み、読込レポートへ記録する。 |
| 無視 | 対象要素だけを読み込まず、ほかの対応要素は読み込む。読込レポートへ記録する。 |
| エラー | SVGルート、キャンバス寸法、XMLなど文書全体を安全に解釈できない場合は読込を中止する。 |

`defs`、`title`、`desc`、`metadata`、`style`は図形レイヤーではないため、レポートなしで無視する。

## 対応要素

| SVG要素 | Document | 条件と扱い |
| --- | --- | --- |
| `svg` | Canvas | 正の`width`／`height`、または正の寸法を持つ`viewBox`が必要。`viewBox`は`preserveAspectRatio`の`none`と9方向の`meet`／`slice`をキャンバス座標へ適用する。背景色と透明状態を保持する。 |
| `g` | グループ解除 | 子要素へtransform、opacity、visibility、対応する継承スタイルを適用する。グループ自体は保持しない。 |
| `rect` | Rectangle | 平行移動、拡大縮小、回転後も直交する場合。`rx`／`ry`の角丸は直線的なRectangleへ、せん断された場合は閉じたPathへ変換して通知する。 |
| `line` | Line | 2端点と有効なstrokeが必要。 |
| `polyline` | 開いたPath | 2頂点以上と有効なstrokeが必要。 |
| `polygon` | 閉じたPath | 2頂点以上。fillまたはstrokeの少なくとも一方が必要。 |
| `path` | Path | 単一サブパスの直線命令`M/m`、`L/l`、`H/h`、`V/v`、`Z/z`だけを扱う。 |
| `image` | Image | 自己完結した`data:image/png;base64`だけを扱う。画像側の`preserveAspectRatio`は保持せず、4頂点のアフィン配置へ変換して通知する。 |

曲線命令、複数サブパス、外部参照画像、不正PNG、描画不能な要素はその要素だけを無視して通知する。
`circle`、`ellipse`、`text`、`use`など上表にない描画要素も無視して通知する。

## 対応属性

- 色: `fill`、`stroke`の単色。`none`を含む。グラデーション、パターン、フィルターは扱わない。
- 線: `stroke-width`、`stroke-dasharray`、`stroke-linecap`、`stroke-linejoin`。
  任意の外部dash配列はDocumentの汎用破線へまとめる。アプリ自身が出力した9線種は`vad:stroke-style`で保持する。
- 表示: `opacity`、`fill-opacity`、`stroke-opacity`、`display`、`visibility`。
  塗りと線の不透明度が異なる図形は、単一のレイヤー不透明度へ統合して通知する。
- 品質: `shape-rendering="crispEdges"`をアンチエイリアス無効として扱う。
- 変換: `matrix`、`translate`、`scale`、`rotate`、`skewX`、`skewY`を座標へ適用する。
- マーカー: アプリ自身が出力した`vad:start-marker`、`vad:end-marker`と各サイズをLineおよび開いたPathで保持する。
  任意のSVG `marker-start`／`marker-end`定義は編集モデルへ推測変換しない。
- アプリ固有値: 名前、ロック、選択、元のVCL色値、画像種別など、標準SVGだけでは可逆でない値は
  `vad`名前空間へ保持する。

`stroke-dashoffset`、既定値以外の`stroke-miterlimit`、`vector-effect`、`paint-order`、
`transform-origin`、`mix-blend-mode`は保持せず通知する。`fill-rule="evenodd"`は通常塗りへ変換して通知する。
`filter`、`clip-path`、`mask`は図形またはグループに指定されていても保持せず通知する。

## 保存

DocumentのRectangle、Line、Path、PNG Imageだけを出力する。Documentは常にMIF対象型で構成されるため、
SVG保存によってSVG専用の内部データが増えることはない。開いたPathとLineのマーカーは標準SVGの
`marker`表示と`vad`属性を併記し、再読込時は`vad`属性を編集値の正本とする。

SVG読込レポートは入力時に失われるSVG表現を示す。MIF保存時の座標丸め、透明度丸め、サイズ制限などは
別途`TMifExportReport`で判定する。
