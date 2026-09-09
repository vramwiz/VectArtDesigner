# MIF解析メモ

対象: IBM WebArt Designer の `.mif` キャンバスデータ解析  
目的: MIFファイルの構造を把握し、互換読み書きの実現可能性を検証する

## 1. 全体構造
- 先頭は `MIMG` (`4D 49 4D 47`)。
- 続いて `MHDR`、その後に複数の `IPNG` ブロック。
- 各 `IPNG` の実体はPNG (`89 50 4E 47 0D 0A 1A 0A`)。
- PNGの`tEXt`チャンクに`object type`などが、独自`waDA`チャンクに`waDA...`情報が保存される。

2026-08-20に全12サンプルで確認した外側コンテナーの正確な配置:

```text
8 bytes  MIMG\r\n\x1A\x00
repeat {
    4 bytes  データ長（符号なし32bit、ビッグエンディアン）
    4 bytes  タグ（MHDR / IPNG / MEND など）
    N bytes  データ
}
```

- `MHDR`は長さ4で、値は`MHDR`と`MEND`を除く外側チャンク数をビッグエンディアンで保持する。
  空ファイルでは`2`、四角形1個では`6`、四角形2個では`10`になることを実データで確認済み。
- `IPNG`データはPNGシグネチャからIENDのCRCまでを含む完全なPNG。
- 最後は長さ0の`MEND`。
- 外側チャンクにCRCはない。
- 全12サンプルをこの規則でファイル末尾まで過不足なく走査できた。
- 未解釈チャンクをバイト列のまま保持すれば、無変更保存で完全な原データを再現できる。

代表例:
```text
application name = "WebArt Designer"
waDAapplication version
waDAbackground page index
object type
waDAimage ...
waDAlogo ...
waDAfont ...
waDAtexture ...
```

## 2. 共通オブジェクト情報
多くのオブジェクトで以下を持つ。

```text
waDAimage position1 x/y
waDAimage position2 x/y
waDAimage position3 x/y
waDAimage position4 x/y
waDAimage alpha
waDAimage hidden
```

基本配置は、
```text
position1 = 左上
position2 = 右上
position3 = 右下
position4 = 左下
```
と考えられる。

位置・幅・高さ・回転・反転は4頂点座標で表現される。

`四角_回転.mif`で、回転したRectangleの4頂点が
`(187,109) (323,145) (306,211) (170,175)`として保存されることを確認した。
第1頂点から第2頂点の角度は約14.826度で、4頂点の平均`(246.5,160)`が回転中心になる。
同じオブジェクトの`vector original position1..4`は未回転の基準矩形を保持し、
`vector matrix a..f`は基準矩形から回転後4頂点へのアフィン変換を保持する。

`四角_回転2.mif`との比較から、行列は整数化された`image position1..4`から逆算するのではなく、
丸め前の回転・拡縮頂点から生成され、行列を`vector original position1..4`へ適用した結果を丸めると
`image position1..4`へ一致することを確認した。新規Rectangleも同じ順序で行列を生成する。
同ファイル内でWebArt Designer 7が生成した76x1の四角形用vector IPNGは、新規Rectangle用として
埋め込んでいる補助IPNGとバイト単位で一致する。

通常値として、
```text
waDAimage alpha  = 255
waDAimage hidden = 0
```
を確認。

### 2.1 Rectangleの線

`白い塗りつぶし四角.mif`、`白い塗りつぶし四角に黒い枠.mif`、
`白い塗りつぶし四角に黒い複雑な点線の枠.mif`の比較から、次を確認した。

```text
waDAvector enable stroke texture = 0: 線なし / 1: 線あり
waDAvector stroke style          = 0～8: 線種コンボの上から順
waDAvector stroke width          = 8バイトのビッグエンディアン倍精度値
```

線色は対象imageの3つ後ろにあるストローク用texture IPNGの
`waDAtexture color1`へ`0x00BBGGRR`で保存される。確認サンプルの線幅は`1.0`、線色は黒だった。
元アプリの線種コンボ画像とstyle 3サンプルを対応させ、現行モデルでは次の順で保持する。

```text
0 実線
1 点線
2 短い破線
3 ダッシュ・ドット
4 ダッシュ・ドット・ドット
5 間隔の広い点線
6 中間長の破線
7 長いダッシュ・ドット
8 長い破線
```

### 2.2 Ellipse

`丸.mif`では楕円が`object type=image`、`object subtype=vector`、
`vector element type=2`として保存されている。確認値は次のとおり。

```text
vector closed              = 1
vector quality             = 1
vector original position1  = (105, 105)
vector original position3  = (212, 176)
vector stroke width        = 1.0
vector stroke style/cap/join = 0
vector enable fill texture   = 1
vector enable stroke texture = 1
```

塗り色は後続1個目、線色は後続3個目のtexture IPNGに格納される。WebArt Designer 7が生成した
106x1のEllipse用vector IPNGを新規Ellipseの互換ペイロードとして使用する。既存MIFから読み込んだ
同種ペイロードは保存時にそのまま再利用する。

### 2.3 直線

`線.mif`では直線が`object type=image`、`object subtype=vector`、
`vector element type=6`として保存されている。確認値は次のとおり。

```text
vector closed              = 0
vector original position1  = (848, 452)
vector original position3  = (1082, 460)
vector matrix a..f          = 単位行列
vector stroke width        = 100.0
vector stroke style        = 8
vector stroke cap          = 2（丸形として取り込み）
vector stroke join         = 2（ラウンドとして取り込み）
vector start stroke marker = 1
vector end stroke marker   = 9
vector start/end marker size = 11
```

マーカーを除いた線本体は、基準矩形の左右中央`(848,456)`から`(1082,456)`として復元できる。
回転・拡縮された直線は、この2点へ`vector matrix a..f`を適用して端点を求める。
現行Writerは同じelement typeと確認済み31×1のvectorペイロードを使用し、マーカーなしで保存する。

### 2.4 連続直線と多角形

`連続直線.mif`と`多角形.mif`も`vector element type=6`を使用する。直線との区別は
element typeではなく、補助の`object type=vector` PNGに格納されたコマンド数と
`vector closed`で行う。PNGは高さ1pxで、RGBAの各チャンネルをバイト列として使用している。

先頭4バイトはリトルエンディアンのレコード数で、後続は1レコード60バイト。確認済みの
コマンド値は1が開始点、2が直線頂点、3が閉じる操作であり、座標はコマンド値に続く
2個のリトルエンディアンDoubleとして格納される。WebArtのPNGは各4バイト内でR/Bが
入れ替わっているため、デコード後にB,G,R,Aの順へ戻してから解釈する。

- `連続直線.mif`: 176レコード、`vector closed=0`
- `多角形.mif`の対象パス: 5頂点、`vector closed=1`

各頂点には`vector matrix a..f`を適用してDocument座標へ変換する。
現行WriterはDocument座標をそのままDouble頂点として格納し、単位行列、Path外接範囲、
開閉・塗り・線の各メタデータを持つ高さ1pxのvector PNGを新規生成する。

### 2.5 曲線の閉鎖と角丸四角形の調査

WebArt Designer 21のローカルヘルプには、曲線作成とは別に`編集 > 曲線を閉じる`があり、
「始点と終点を直線で結ぶ」操作と明記されている。専用の閉曲線作成ツールではないが、
閉じた曲線自体は元アプリの編集対象である。

付属ギャラリーの6,603個のMIFを横断すると、確認できた`vector element type`は
`2, 4, 6, 9, 11, 12`だった。曲線を含む実データでは、60バイトレコードの
コマンド4が3次ベジェ区間であり、先頭2個のDoubleが終点、次の4個が2制御点を表す。
`bal011.mif`にはtype 9、`bal001.mif`にはtype 11の`vector closed=1`が存在する。
type 11では直線コマンド2とベジェコマンド4の混在も確認できた。閉じたサンプルは末尾に
コマンド3を持たず、最終点も始点と一致しないため、`vector closed=1`によって最後を直線で
閉じる構造と判断でき、ヘルプの説明とも一致する。

したがって閉じたベジェ形状のMIF表現は可能。VectArtDesignerには独立した閉ベジェ作成ツールを追加し、
元アプリで分かれている作成と閉鎖を1操作へまとめた。ただし、現行Readerはコマンド1,2,3だけを読み、
Writerはベジェを16分割した閉じた直線列へ変換するため、見た目と閉鎖は維持できても曲線の編集意味を
保つネイティブ往復は未対応である。次段階でコマンド4とtype 9/11の読書きを実装する。

角丸四角形について、ヘルプは独立ツールと枠／塗りの3状態を説明する一方、丸み量の調整方法や
数値は記載していない。付属MIF群からも角半径を表す`waDA`キーや専用element typeは特定できなかった。
実機観察では作成時の横方向が丸み:中央:丸みで約1:8:1となり、作成後の変形ではこの比率を
再計算せず輪郭全体が変形される。この挙動に合わせ、VectArtDesignerでは作成時半径を幅の1/10、
高さの半分を上限として、各1/4円弧を6分割した閉じたtype 6 Pathへ確定する。これにより現行MIFでも
見た目と変形後の輪郭を往復できる。元アプリの専用element typeと再読込時の種別は、専用サンプルが
得られるまで不明とする。

## 3. 数値の保存形式
多くの数値はPNG内の独自`waDA`チャンクに保存される。PNGチャンクの構造は次のとおり。

```text
length = キー接尾辞 + NUL + 値の長さ
type   = "waDA"
data   = キー接尾辞 + NUL + 値
crc    = 通常のPNG CRC
```

例えば完全なキー`waDAimage position1 x`では、チャンクtypeが`waDA`、data先頭が
`image position1 x`となる。数値はNULの後ろに4バイトのビッグエンディアン符号付き整数として置かれる。

```text
00 00 00 05 = 5
FF FF FF F6 = -10
```

## 4. 色の保存形式
GUI上のRGBとは逆順のBGR系。

```text
GUI #0000FF（青） -> 0x00FF0000
GUI #FF0000（赤） -> 0x000000FF
GUI #FF8000       -> 0x000080FF
```

概念的に `0x00BBGGRR`。

# 5. 文字オブジェクト
文字は、
```text
object type = "logo"
```

代表構造:
```text
waDAlogo fs auto
waDAlogo smooth
waDAlogo pad x/y
waDAlogo margin x/y
waDAlogo format
waDAlogo text unicode
waDAlogo text
waDAfont ...
waDAlogo writing mode
waDAlogo outline ...
waDAlogo effect ...
```

## 5.1 文字列
- `waDAlogo text unicode` はUTF-16系。
- `waDAlogo text` はShift-JIS系と思われる。
- 互換実装ではUnicode側を優先するのが安全。

## 5.2 フォント
例:
```text
font name = "MS UI Gothic"
```

無効果時の代表値:
```text
font height = -22
font width  = 9
waDAlogo fs auto = 1
waDAlogo smooth = 0
pad x = 2
pad y = 2
```

`fs auto=1` のため、外周効果で必要領域が増えるとフォントサイズが自動縮小される。

# 6. 文字の縁取り
```text
waDAlogo outline object type
waDAlogo outline thick
waDAlogo outline color
waDAlogo outline alpha
```

確認済み種類:
```text
なし   = "none"
通常   = "normal"
封蝋   = "seal"
白抜き = "hollow"
囲み   = "enclose"
反転   = "invert"
```

太さ:
```text
最小 = 1
最大 = 5
```

透明度:
```text
透明度 0%   -> alpha = 255
透明度 100% -> alpha = 0
```
概算:
```text
alpha ≒ 255 * (1 - 透明度/100)
```

`seal` のみ `waDAlogo outline direction` を確認。
```text
左側ふくらみ = 3
右側ふくらみ = 7
```

pad例:
```text
none / invert -> (2,2)

normal / seal / hollow
thick=1 -> (3,3)
thick=5 -> (7,7)

enclose
thick=1 -> (5,3)
thick=5 -> (9,7)
```

# 7. 文字エフェクト
共通構造:
```text
waDAlogo effect object type
waDAlogo effect level
waDAlogo effect color
waDAlogo effect offset x
waDAlogo effect offset y
waDAlogo effect direction
```

確認済み:
```text
なし       = "none"
ぼかし     = "blur"
動き       = "motion blur"
影         = "shadow"
切り抜き   = "cutout"
エンボス   = "emboss"
炎         = "flame"
```

## 7.1 blur
```text
level = 0..5
```
最小:
```text
pad=(2,2)
font=(-22,9)
```
最大:
```text
pad=(12,12)
font=(-13,5)
```
外側に広がる効果。

## 7.2 motion blur
```text
level = 0..5
```
方向:
```text
0 = 左
1 = 左下
2 = 下      ※推定
3 = 右下
4 = 右
5 = 右上
6 = 上
7 = 左上    ※推定
```
直接確認済み: 0,1,3,4,5,6。

最大レベル時のpad例:
```text
右   -> (27,7)
上   -> (7,17)
右上 -> (27,17)
```

## 7.3 shadow
```text
level = 0..5
offset x = -10..10
offset y = -10..10
```
GUI対応:
```text
強さ   -> level
色     -> color
横位置 -> offset x
縦位置 -> offset y
```

最低例:
```text
level=0
offset=-10,-10
pad=(13,12)
font=(-13,5)
```

最大例:
```text
level=5
offset=10,10
pad=(23,23)
font=(-2,2)
```

## 7.4 cutout
```text
level = 0..5
offset x/y = -10..10
color = BGR
```
ただし最小・最大とも:
```text
pad=(2,2)
font=(-22,9)
```
外側描画領域を増やさない。

## 7.5 emboss
```text
effect object type = "emboss"
level = 0..5
direction = 0..7
```
確認:
```text
左下 = 1
右下 = 3
```
最小・最大とも:
```text
pad=(2,2)
font=(-22,9)
```
`color` と `offset x/y` は未使用の共通保持値とみられる。

## 7.6 flame
```text
effect object type = "flame"
level = 0..5
color = BGR
```
色例:
```text
赤 -> 0x000000FF
青 -> 0x00FF0000
```
最低:
```text
pad=(2,2)
font=(-22,9)
```
最大:
```text
pad=(12,17)
font=(-8,3)
```
外側に大きく広がる効果。

# 8. 「情報」タブ
文字固有ではなく共通オブジェクトGUIと考えられる。

```text
オブジェクトの種類
X座標
Y座標
幅
高さ
縦横比保持
透明度
```

# 9. ペン
GUI上の「ペン」は独立MIFオブジェクトではない。

保存時:
```text
object type = "image"
```

描画結果をラスタライズして画像として保存しているとみられる。
`pen / brush / stroke / point / path` 等の固有再編集データは確認できていない。

したがってMIF解析では、
```text
ペン = 画像編集用GUI機能
保存結果 = image
```
として独立型としては無視可能。

# 10. 画像オブジェクト
画像配置時:
```text
object type = "image"
```

構造:
```text
image {
    embedded PNG
    position1 x/y
    position2 x/y
    position3 x/y
    position4 x/y
    alpha
    hidden
}
```

## 10.1 拡大縮小
表示幅を変更しても埋め込みPNG自体のピクセルサイズは変わらない。
4頂点座標だけが変更される。

## 10.2 回転
約45度右回転でPNG本体は不変。
4頂点座標のみが回転。
別のrotationフィールドは不要と考えられる。

## 10.3 左右反転
PNG本体を作り直さず、左右頂点の対応を入れ替える。

概念:
```text
通常:
P1=左上 P2=右上 P3=右下 P4=左下

左右反転:
P1=右上 P2=左上 P3=左下 P4=右下
```

## 10.4 上下反転
同様に上下頂点を入れ替える。

```text
上下反転:
P1=左下 P2=右下 P3=右上 P4=左上
```

## 10.5 入力画像形式
JPEG / PNG / GIF / BMP 等を配置して確認した結果、MIF内の画像ブロックはPNGシグネチャだった。
VectArtDesignerもファイルドロップ時にWindows Imaging ComponentでPNGへ変換し、画像データ本体を
Documentへ複製する。取込元フルパスは参照情報であり、描画時に元ファイルを開き直さない。
MIFには取込元パスを格納せず、埋め込みPNGだけを保存して変換レポートへ通知する。

```text
JPEG ┐
PNG  ├→ PNGへ正規化 → IPNGとして格納
GIF  ┤
BMP  ┘
```

元ファイル名・元拡張子・外部パスを保持している形跡は現時点では確認できていない。

# 11. texture オブジェクト
```text
object type = "texture"
```

代表項目:
```text
waDAtexture object type
waDAtexture color1
waDAtexture color2
waDAtexture angle
waDAtexture level
waDAtexture pathname
```

画像本体とは別の背景/テクスチャ系データとみられる。
詳細は未解析。

# 12. 現時点のオブジェクト分類
```text
logo    = 文字
image   = 画像
texture = テクスチャ系
```

ペンは `image` へ変換されるため独立型ではない。

# 13. 画像で未確認の項目

実装では通常`image`のPNG本体、alpha、hidden、配置4頂点を画像レイヤーへ取り込む。`logo`は
`logo text unicode`をUTF-16LEとして読み、フォント名、高さ、weight、italic、underline、strikeout、
色、alpha、hidden、配置4頂点を編集可能なTextへ復元する。新規Textも同じ`logo`メタデータと
ラスタライズ済みPNGを生成する。`logo writing mode=0`を横書き、0以外を縦書きとして復元し、
書出し時も同じフラグと縦組み済み表示PNGを生成する。outlineとeffectは今後の分類対象とする。
字間率・行間率は編集モデルと表示PNGへ反映する。対応するMIFの編集可能属性は未確定のため、
0以外を保存した場合はMIF変換レポートへ通知し、再読込時の率そのものは0へ戻る。
文字の左右／上下反転も画像と同じく`image position1..4`の頂点順へ反映する。読込時は第1→第2辺と
第1→第4辺の外積が負なら反転配置として復元する。左右反転は同じ見た目の「180度回転＋上下反転」へ
正規化される場合があるが、表示と続く反転操作は維持される。
1. `waDAimage alpha` とGUI透明度の正確な対応
2. `waDAimage hidden` のON時の値
3. 縦横比保持チェック状態そのものがMIF保存されるか
4. 四隅自由変形が可能か

# 14. 互換実装上の方針
有力なReader/Writer方針:

```text
1. MIMG/MHDRを解析
2. IPNGブロックを順次抽出
3. PNGとして解析
4. tEXtから object type / waDA* を取得
5. object typeごとに構造化
6. imageはembedded PNG + 4頂点 + alpha + hiddenで復元
7. logoは文字・フォント・縁取り・効果を復元
```

Rectangle／Ellipseサンプルでは、編集対象の図形が`object type=image`のラスタ画像として含まれ、
その後ろに塗りtexture、vector、線textureの補助IPNGが並ぶ。現行Documentではelement type 4を
Rectangle、type 2をEllipseへ対応付け、4個のIPNGを一組として読み書きする。

画像では回転・拡縮・左右反転・上下反転を専用フラグとして持たず、4頂点から再現可能。

# 15. 確度
## ほぼ確定
- MIF先頭は `MIMG`
- 外側はビッグエンディアン長、4文字タグ、データの連続で、`MEND`で終了する
- `IPNG` 内にPNG
- PNG `tEXt` に通常メタデータ、独自`waDA`チャンクにwaDAメタデータ
- 文字=`logo`
- 画像=`image`
- 画像はMIF内部でPNG化
- 画像の位置/サイズ/回転/反転=4頂点
- ペンは画像化され `image`
- 色はBGR系
- 文字のoutline/effect主要種類
- 多くの数値は32bit big-endian

## 推定を含む
- motion blur direction 2=下
- motion blur direction 7=左上
- textureの詳細用途
- alphaの全変換式
- hiddenのON値
- 縦横比保持チェックの保存有無

# 16. 次回候補

1. IPNG内のPNGチャンクをReaderで列挙し、`tEXt`と`waDA`を型付きメタデータへ変換する。
2. 先頭の合成画像、背景texture、編集対象image、補助texture／vectorの関連を確認する。
3. 未知IPNGを保持したまま、既知imageだけをDocumentの画像レイヤーへ読み込む方式を設計する。
4. 透明度50%、hidden ON、縦横比保持、自由変形の追加サンプルを調べる。

## 2026-09-09 放射状グラデーションのMIF保存・再読込

- 提供サンプル `mif/四角_グラデーション_放射状.mif` の塗りPNGで `texture object type=gradation radiate` を確認。color1=255（赤）、color2=16711680（青）、angle=0、level=0、pathname=@。
- Rectangle／Ellipse／閉じたPathの放射状塗りをこのネイティブ属性で保存・再読込する。塗りPNGと図形・合成PNGは既存の共通描画を使用し、独自MIFキーは追加しない。放射状の角度は0とする。
- 放射状をMIF非対応判定から除外。画像テクスチャのMIF保存は引き続き非対応。
- FillIntegrationTestsで提供サンプルの読込・再保存、属性名、2色、四角・横長楕円・閉じたPathの往復、画素、Undo、既存線形／SVG／JSONを確認。MIF診断は29サンプルすべてバイト一致。
- Win64 Debug／Releaseは警告0・エラー0。通常EXEもDebugで更新。検証成果物はTestOutput配下。
- WebArt本体で書出しファイルを開いた表示・再編集の確認は未実施。

## 2026-09-09 放射状の広がりを元アプリへ修正

- ユーザーの比較画像と元の赤青MIFの図形PNGを確認。放射状は外接矩形へ伸ばした楕円ではなく、中心からの実距離／対角線の半分で色を補間する円だった。前回は属性の往復だけを確認し、描画の一致を見落としていた。
- 共通FillPaintを円形の実座標へ修正。キャンバス、色見本、サムネイル、MIFの図形・合成PNGへ反映。SVGもuserSpaceOnUseの中心と半径へ接続した。
- 180×100の元サンプルの赤成分（上辺中央133、左辺中央34、左1/4位置143）と描画結果を許容差4以内で検証。FillIntegrationTests PASS。Win64 Debug／Releaseは警告・エラー0、通常EXEも更新済み。
- WebArt本体による書出しファイルの再編集確認は引き続き未実施。

## 2026-09-09 円形グラデーション

- `mif/四角_グラデーション_円形.mif`を解析。`texture object type=gradation circle`、color1=255、color2=16711680、angle=0、level=0、pathname=@。左を色1、右を色2、上下を中間色とする実座標の偏角補間であり、放射状の距離補間とは異なる。
- 共通Skia描画へ3ストップのSweep Shaderを追加。整数中心画素をSkiaの画素中心へ合わせた。元サンプル180×100と書出し図形PNGの枠から2px内側の全画素を比較し、RGB各成分の差は最大1、平均0.332。比較スクリプト・画像はTestOutputに保存。
- 共通色ポップアップの種別へ「円形」を追加。2色編集、再表示、Undo／Redo、新規図形の塗り既定値、色見本、テンプレ図形へ接続。プレビューは実寸座標を使い、長方形の縦横比による偏角の歪みを防ぐ。
- FillKindは末尾へvfkCircleを追加し、既存JSONの序数を維持。Rectangle／Ellipse／閉じたPathの既存塗りモデルを使用し、MIFへ独自キーは追加しない。今回は確認できたangle=0のみ。
- SVGは標準の角度グラデーションを持たないため、塗りをPNGのpatternへ変換する。長辺最大2048px、図形自体はベクターを維持。data-vad-fill／data-vad-color1／data-vad-color2で本アプリ再読込時に2色の円形設定を復元する。他アプリでは画像塗りとして表示する。
- FillIntegrationTests（画素、中心色、JSON／SVG／MIF、提供MIF、閉じたPath、Undo）とSettingsUiTests（円形選択・再表示・Undo／Redo・新規作成色）がPASS。画面PNGも確認。
- Win64 Debug／Releaseは警告0・エラー0。通常EXEをDebugで更新済み。WebArt本体での書出し結果の目視確認は未実施。

## 2026-09-09 角形グラデーション

- 提供サンプル `mif/四角_グラデーション_角形.mif` の `texture object type=gradation square`を確認。color1=255、color2=16711680、angle=0、level=0、pathname=@。
- 中心からの横・縦距離をそれぞれ半幅・半高さで正規化し、最大値で2色を補間する。等色線は外接矩形と同じ縦横比の長方形。Skia Runtime Shaderを一度コンパイルし、色・配置を差し替えて再利用する。
- 共通ポップアップに「角形」を追加。共通描画、色見本、再表示、新規図形の塗り既定値、Undo／Redoへ接続。vfkSquareは末尾に追加し、既存JSON序数を維持。MIFはネイティブ属性で保存・再読込し、独自キーは追加しない。確認対象はangle=0。
- SVGは円形と同じPNG pattern方式を共有。data-vad-fill=squareと2色から本アプリで編集設定を復元する。塗りPNGは長辺最大2048px、図形はベクターを維持する。
- 元サンプル180×100と書出し図形PNGの枠から2px内側を比較し、RGB各成分の差は最大1、平均0.321。比較画像・スクリプトはTestOutput配下。
- FillIntegrationTests（JSON／SVG／MIF、提供サンプル、閉じたPath、画素、Undo）、SettingsUiTests（角形選択・再表示・Undo／Redo・作成既定色）がPASS。実設定画面のPNGを確認。
- Win64 Debug／Releaseとも警告0・エラー0。TestOutput/AppDebugとTestOutput/AppReleaseへ出力。通常EXE更新は起動中のF2039で失敗したため、アプリ終了後の更新が必要。WebArt本体での書出し結果の確認は未実施。

## 2026-09-09 波状グラデーション

- 提供サンプル `mif/四角_グラデーション_波状_5.mif`を解析。`texture object type=gradation wave`、color1=255、color2=16711680、angle=0、level=5、pathname=@。
- 中心からの実距離を対角線の半分で割り、t=(1-cos(2π×繰り返し数×正規化距離))/2で2色を補間する。Skia Runtime Shaderを再利用し、長方形でも円形の波を描く。
- 既存の塗りレコードにWaveCountを追加し、MIFのtexture levelへ接続。vfkWaveは末尾に追加して既存JSON序数を維持。JSONはfillWaveCountを追加し、省略時0。波状以外の塗りへ影響させない。
- 共通ポップアップに「波状」と繰り返し数の共通スライダーを追加。既定5、入力0～100、スライダー0～20。0は色1の単色となる。色見本・プレビュー・Undo／Redo・新規作成色へ反映する。
- SVGは既存のPNG pattern方式を共有。data-vad-fill=wave、2色、data-vad-wave-countから編集設定を復元する。
- 元サンプル180×100と書出し図形PNGの枠から2px内側を全画素比較。RGB各成分の差は最大1、平均0.332。提供サンプルで確認した繰り返し数は5、その他は同じ数式で実装。
- FillIntegrationTests（画素、提供MIF、閉じたPath、MIF／SVG／JSON往復、繰り返し0・1・3・5・10、Undo）、SettingsUiTests（波状選択・繰り返し変更・再表示・Undo／Redo・作成既定色）がPASS。実設定画面PNGも確認。
- Win64 Debug／Releaseは警告0・エラー0。通常EXEもDebugで更新済み。検証成果物はTestOutput配下。WebArt本体で書出し結果を開く確認は未実施。

## 2026-09-09 線形スペクトル

- 提供サンプル `mif/四角_グラデーション_スペクトル_赤.mif` を解析。texture object type=spectrum linear、color1=255、color2=0、angle=45、level=0、pathname=@。
- 実座標を指定方向へ投影し、開始色から色相を一周させる。色相の折れ点をRGBストップへ展開してSkiaとSVGで共有。vfkSpectrumは列挙末尾に追加して既存JSON序数を維持する。
- 共通ポップアップへ「スペクトル」を追加。開始色と角度を編集し、色2は非表示。角度を変えてもスペクトル種別を維持する。プレビュー、色見本、作成既定色、Undo／Redoへ接続。
- MIFはspectrum linearと開始色・角度を保存して再編集できる。SVGは標準linearGradientの複数ストップでベクター表示を維持し、data-vad-fill=spectrum、data-vad-color1、data-vad-angleから編集設定を復元する。
- 赤・45度の180×100サンプルと書出し図形PNGの枠から2px内側を全画素比較し、RGB各成分の差は最大1、平均0.168。開始色の彩度・明度を維持して色相を回す実装だが、赤以外の元アプリ製サンプルとの比較は未実施。
- FillIntegrationTests（元MIF、画素、閉じたPath、JSON／SVG／MIF、角度0・45・90・135・180・270・315、Undo）、SettingsUiTests（選択・色2非表示・角度変更・再表示・Undo／Redo・作成既定色）がPASS。画面PNG確認済み。
- Win64 Debug／Releaseは警告0・エラー0。通常EXEもDebugで更新済み。成果物はTestOutput配下。WebArt本体で書出し結果を開いた確認は未実施。

## 2026-09-09 線・枠のグラデーション

- ユーザー指定に従い、線の経路長や各辺ではなく図形全体の座標で色を配置し、線の形状だけに描画する。塗りとは独立したStrokePaintを持ち、Rectangle／Ellipse／Line／Pathのスナップショット・作成・複製・削除Undoへ保持する。
- 「線の色」とテンプレ図形の線色を共通ペイントポップアップへ接続。ベタと全6種類（線形・放射・円形・角形・波状・スペクトル）を選べる。線の画像テクスチャは選択肢から除外する。線幅・線種・内側の塗りを維持し、複数選択の変更は一件のUndo。ロック・選択変更時のポップアップ終了も維持。
- 新規図形・Lineの線設定へ引き継ぎ、キャンバス・マーカー・レイヤー／グループサムネイル・テンプレ一覧へ反映。水平／垂直Lineには線幅に応じた非ゼロの描画領域を与える。
- 追加された元MIF枠線6サンプルで、線用テクスチャがオブジェクトPNGの3チャンク後にあることを確認。既存texture属性で保存・再読込し、MIFへ独自キーは追加しない。JSONはstrokeで始まる塗り設定キーを追加し、省略時は従来の単色。
- 線形・放射・円形・波状・スペクトルは奇数寸法で整数の半幅／半高さを基準にする。角形は全寸法を使う。線形・放射には元画像の画素中心補正も適用。元サンプルとの比較は6種類とも色領域のRGB各成分で最大1差。輪郭と塗り境界のアンチエイリアス差は比較から除外した。
- SVGの線にもペイント参照を保存。線形・放射・スペクトルは標準グラデーション、円形・角形・波状はPNG pattern＋編集設定を使用。水平／垂直Lineでも実座標を指定し、線幅とマーカー用の余白を含めた画像でpattern境界の繰り返しを防ぐ。
- StrokePaintTestsを追加し、全方式のRectangle／Line／Path、内部塗りの維持、JSON／SVG／MIF往復、削除スナップショット、サムネイル、元MIF6サンプルの画素基準を検証。SettingsUiTestsに線色UI、再表示、作成引継ぎ、複数選択一括Undo、ロックを追加してPASS。
- FillIntegrationTests、LineToolbarTests、RoundedRectangleCreationTests、MainFormLifecycleTestsもPASS。Debug／Releaseは警告0・エラー0。通常EXEをDebugで更新済み。検証成果物はTestOutput配下。WebArt本体で書出し結果を開く確認は未実施。

## 文字グラデーションの追加確認（2026-09-09）

文字_グラデーション_*.mifの6種を確認。logo IPNGの次のIPNGにtexture object type、color1／color2、angle、levelがあり、図形と同じ6種類の属性名を使用する。追加の独自属性は不要。文字画像は175×85、色場は文字全体で共有され、透明部分にもRGBを保持している。線と同様に整数半寸法を基準とする。角形の奇数寸法は中央2画素が同色となる対称配置で、整数半寸法を分母にする。色場の全画素検証は5種最大1、角形最大2（8画素の境界付近）であり、完全なバイト一致ではない。

ネイティブlogo format=0のtext unicodeには終端CRLFがあり、読込時に末尾1組を除去する。自アプリのformat=2は末尾改行もユーザー入力として維持する。文字のグラデーション設定と表示PNGを2チャンクで書き出す。

## 画像テクスチャの確認（2026-09-09）

四角_テクスチャ.mif、四角枠_テクスチャ.mif、文字_テクスチャ.mifは、1254×1254のPNGをtextureとして埋め込む。waDAのtexture object type=image、color1=0、color2=0、angle=0、level=0、pathname=@に元画像のWindowsパスを続けた文字列。外側チャンク番号は四角の塗りと文字で4、枠で6（0始まり）。画像の配置は左上0,0から1253,1253。

オブジェクトPNGは順に180×100、170×95、175×85。縮小せず元画像の左上を実寸で使用する。四角内部と文字不透明部は対応する元画像RGBと完全一致。再生成オブジェクトとの色比較は輪郭境界を除きRGB各成分差1以内で通過した。

アプリは元寸法PNGとimage属性を保存し、外部依存を作らないためpathname=@とする。小画像の反復は実装したが、提供サンプルは全て画像より小さいため元アプリのタイル境界は未検証。angle／levelの非ゼロ値と、書出しファイルのWebArt本体での再編集も未検証。
