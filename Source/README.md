# ソース構成

グラデーションと画像テクスチャは図形の塗り・線・文字の3対象でいったん完成（2026-09-09、ユーザー動作確認済み）。今後の追加は以下の責務へ配置し、公開窓口へ描画や属性変換を集積しない。

| フォルダ | 担当 |
|---|---|
| Rendering/Paint | ペイント適用、グラデーション座標、角形・波状シェーダー |
| Persistence/Mif | コンテナー、公開変換APIと互換性判定、ネイティブ読込、PNGメタデータ |
| Persistence/Mif/Rendering | 埋込PNG描画、画像配置と数値属性、ペイント属性の入出力 |
| Persistence/Svg/Paint | ペイント定義の読込と書出し、標準表現のない方式の表示PNG |
| Persistence | Document JSON、選択画像の埋込PNG変換（TextureImage） |
| ObjectProperties/Color | 色選択UI、色見本、ペイントプレビュー |
| Core/Commands/Appearance | 塗り・線・文字のペイントと枠／塗りの有効状態 |
| Core/Commands/Transform | 選択全体の反転・回転 |
| Core/Commands/Structure | 挿入・削除・積層順・グループ所属・表示切替 |
| Core/Commands | 共通編集コマンドと一括挿入 |

MIFの依存方向は公開変換APIからReader／Raster／Paint／Placementへ向ける。ReaderとPNG描画は公開変換APIへ依存しない。SVGの図形読込はPaintReaderへペイント解析を、書出しはPaintWriterへ定義生成を委譲する。XML属性・数値表記の共通処理はSvgPrimitivesへ置く。色ポップアップはTextureImageへ画像変換を委ね、ダイアログと適用通知を担当する。描画用シェーダーはUIや永続化へ依存しない。

ユニット先頭には目的と担当範囲を書く。処理内コメントは意図・互換性上の制約・所有権などを説明し、コードの言い換えを増やさない。日本語を含むPascalソースはUTF-8 BOM付きとする。

ユニットの追加・移動時は本体のdpr／dprojとテスト内の明示パスを更新する。検証出力はTestOutput配下へ限定する。

Source内の各フォルダは最大6ユニット（今回の追加後も同じ）。大量のユニットが集中したフォルダはなく、現在の責務別分類を維持する。
