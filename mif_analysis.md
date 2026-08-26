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

### 2.2 直線

`線.mif`では直線が`object type=image`、`object subtype=vector`、
`vector element type=6`として保存されている。確認値は次のとおり。

```text
vector closed              = 0
vector original position1  = (848, 452)
vector original position3  = (1082, 460)
vector matrix a..f          = 単位行列
vector stroke width        = 100.0
vector stroke style        = 8
vector start stroke marker = 1
vector end stroke marker   = 9
vector start/end marker size = 11
```

マーカーを除いた線本体は、基準矩形の左右中央`(848,456)`から`(1082,456)`として復元できる。
回転・拡縮された直線は、この2点へ`vector matrix a..f`を適用して端点を求める。
現行Writerは同じelement typeと確認済み31×1のvectorペイロードを使用し、マーカーなしで保存する。

### 2.3 連続直線と多角形

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

Rectangleサンプルでは、編集対象の四角形が`object type=image`のラスタ画像として含まれ、
そのほかに`texture`や`vector`の補助IPNGが並ぶ。したがって現行のRectangleモデルへ直接対応付ける前に、
各IPNGの関連付けを確認するか、画像レイヤーとして保持する必要がある。

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
