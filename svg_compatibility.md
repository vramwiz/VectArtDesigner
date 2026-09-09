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
| `ellipse` | Ellipse | `cx`／`cy`／`rx`／`ry`を保持する。平行移動、拡大縮小、回転後も直交する場合に対応し、せん断された場合は要素を無視して通知する。 |
| `line` | Line | 2端点と有効なstrokeが必要。 |
| `polyline` | 開いたPath | 2頂点以上と有効なstrokeが必要。 |
| `polygon` | 閉じたPath | 2頂点以上。fillまたはstrokeの少なくとも一方が必要。 |
| `path` | Path | 単一サブパスの直線命令`M/m`、`L/l`、`H/h`、`V/v`、`Z/z`だけを扱う。 |
| `image` | Image | 自己完結した`data:image/png;base64`だけを扱う。画像側の`preserveAspectRatio`は保持せず、4頂点のアフィン配置へ変換して通知する。 |
| `text` | Text | 単色の横書き／縦書き文字を扱う。直下の`tspan`を明示改行として連結し、フォント名・サイズ・太字・斜体・字間・行間・`writing-mode`・回転・直交する左右／上下反転を保持する。せん断は無視して通知する。 |

曲線命令、複数サブパス、外部参照画像、不正PNG、描画不能な要素はその要素だけを無視して通知する。
`circle`、`use`など上表にない描画要素も無視して通知する。

## 対応属性

- 色: `fill`、`stroke`の単色。`none`を含む。グラデーション、パターン、フィルターは扱わない。
- 線: `stroke-width`、`stroke-dasharray`、`stroke-linecap`、`stroke-linejoin`。
  任意の外部dash配列はDocumentの汎用破線へまとめる。アプリ自身が出力した9線種は`vad:stroke-style`で保持する。
- 表示: `opacity`、`fill-opacity`、`stroke-opacity`、`display`、`visibility`。
  塗りと線の不透明度が異なる図形は、単一のレイヤー不透明度へ統合して通知する。
- 品質: `shape-rendering="crispEdges"`をアンチエイリアス無効として扱う。
- 変換: `matrix`、`translate`、`scale`、`rotate`、`skewX`、`skewY`を座標へ適用する。
- 文字: `font-family`、`font-size`、`font-weight`、`font-style`、`letter-spacing`、`writing-mode`。外部SVGに文字幅・高さがない場合は
  フォントサイズと文字数から編集外接寸法を算出し、アプリ自身の出力では`vad:width`／`vad:height`、
  `vad:letter-spacing-ratio`／`vad:line-spacing-ratio`で正確に往復する。字形反転は標準SVGの直交
  `matrix`変換として書き出し、読込時に回転と反転へ分解する。
- マーカー: アプリ自身が出力した`vad:start-marker`、`vad:end-marker`と各サイズをLineおよび開いたPathで保持する。
  任意のSVG `marker-start`／`marker-end`定義は編集モデルへ推測変換しない。
- アプリ固有値: 名前、ロック、選択、元のVCL色値、画像種別、画像取込元フルパスなど、標準SVGだけでは
  可逆でない値は`vad`名前空間へ保持する。画像取込元は`vad:source-file`、角丸四角Pathの
  外接枠編集指定は`vad:bounds-editing`で保持する。

`stroke-dashoffset`、既定値以外の`stroke-miterlimit`、`vector-effect`、`paint-order`、
`transform-origin`、`mix-blend-mode`は保持せず通知する。`fill-rule="evenodd"`は通常塗りへ変換して通知する。
`filter`、`clip-path`、`mask`は図形またはグループに指定されていても保持せず通知する。

## 保存

DocumentのRectangle、Ellipse、Line、Path、PNG Image、Textだけを出力する。Documentは常にMIF対象型で構成されるため、
SVG保存によってSVG専用の内部データが増えることはない。開いたPathとLineのマーカーは標準SVGの
`marker`表示と`vad`属性を併記し、再読込時は`vad`属性を編集値の正本とする。

SVG読込レポートは入力時に失われるSVG表現を示す。MIF保存時の座標丸め、透明度丸め、サイズ制限などは
別途`TMifExportReport`で判定する。

## 2026-09-09 円形グラデーション

円形（MIFのgradation circle）は標準SVGに同じグラデーションがないため、PNGを埋め込んだpatternへ変換する。長辺は最大2048pxで、図形の輪郭はベクターのまま保持する。patternのdata-vad-fill=circle、data-vad-color1、data-vad-color2から本アプリでは編集可能な円形設定を復元する。他アプリでは画像の塗りとして表示される。

- 2026-09-09：角形も同じPNG pattern方式を使用。data-vad-fill=squareと2色の属性から角形の編集設定を復元する。

- 2026-09-09：波状もPNG pattern方式を共有。data-vad-fill=wave、2色、data-vad-wave-countから波状の編集設定を復元する。

- 2026-09-09：線形スペクトルは実座標のlinearGradientと複数の色ストップで保存する。data-vad-fill=spectrum、data-vad-color1、data-vad-angleから開始色と角度の編集設定を復元する。表示はベクターのまま維持する。

## 2026-09-09 線・枠のペイント

線のstrokeにも塗りと独立したペイント参照を保存する。線形・放射・スペクトルは標準グラデーション、円形・角形・波状はPNG patternと編集設定で往復する。実座標の領域を使用し、画像には線幅とマーカーの余白を含める。線の画像テクスチャはUI・MIF保存とも未対応。

## 文字色グラデーション（2026-09-09）

textのfillへ6種類のグラデーション参照を出力し、読込時にTextData.FillStyleへ復元する。線形・放射状・スペクトルは標準gradient、円形・角形・波状は表示PNG patternと既存data-vad属性で再編集情報を保持する。色場は文字オブジェクト全体を基準とする。外部SVGビューアーのフォントメトリクス・文字配置の完全一致は従来どおり保証しない。

## 画像テクスチャ（2026-09-09）

図形のfill、線のstroke、文字のfillに埋め込みPNGのpatternを使用する。patternUnits=userSpaceOnUse、x／yは図形の左上、width／heightと子imageは元画像の寸法とし、実寸で繰り返す。画像はbase64で埋め込み、再読込時にTexturePngへ戻す。水平・垂直LineもobjectBoundingBoxへ依存しない。

以前のアプリが書いた画像引き伸ばしpatternも画像は読み込むが、現在のMIF編集モデルでは実寸配置になる。任意の外部SVGのpatternTransformや配置パラメータ全般の再現は対応範囲外。


### 図形の影（2026-09-09）

単一図形の影は標準feDropShadowを1要素だけ持つfilterへ書き出し、filter付きgroupから再読込する。
整数dx／dy、整数stdDeviation、単色flood-color、影の独立不透明度1を対応範囲とする。
複合フィルター、非整数値、独立した影不透明度は無視の通知対象。SkiaとSVG実装間のぼかし境界の画素一致は保証しない。
