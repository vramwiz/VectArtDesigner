# TextRenderer

複数のSyncroh2プラグインから利用する装飾文字レンダラーです。標準バックエンドにはSkiaを使用します。

このライブラリはAviUtl2 SDK、SerifDrawの共有メモリ、VCLの`TBitmap`へ依存しません。入力として文字列とレイアウト・装飾設定を受け取り、出力として必要範囲だけのストレートアルファRGBA画像を返します。各プラグインは出力画像を自身のホストAPIへ渡すアダプターだけを持ちます。

現時点のファイル:

- `TextRendererTypes.pas`: 描画要求、装飾、RGBA画像、計測結果の共通型
- `TextRenderer.pas`: 描画バックエンドの抽象インターフェース
- `TextRendererSkiaRuntime.pas`: `sk4d.dll`の絶対パス読み込みと参照カウント
- `TextRendererSkia.pas`: Skiaによる外接矩形RGBA生成
- `note.md`: 設計判断、実装段階、検証項目

現在は横書き複数行、左・中央・右揃え、字間、行間、本文色、複数縁取り、複数ドロップシャドウ、透明外周の切り詰めまで実装しています。CRLF・CR・LFを同じ改行として扱い、空行も行送りへ含めます。字間0はtext blob、字間ありはSkiaのグリフ配列と個別座標を使います。影はX/Yオフセット、ぼかし、拡散、ARGB色を扱い、影を含む外接矩形を返します。未実装の縦書き、幅制限などを要求した場合は、異なる見た目を黙って返さず例外で通知します。

縁取りは幅・色に加えてぼかし半径を指定できます。`TTextRenderOutline.Create(width, color)`はぼかし0、`Create(width, blur, color)`はぼかし付きです。ぼかしや影を含む全エフェクト領域は`Bounds`、本文と通常縁取りを基準にした配置領域は`LayoutBounds`へ分離されているため、エフェクトを追加しても利用側の文字アンカーは移動しません。
複数行の実測配置範囲は`TTextRenderImage.LineLayoutBounds`で行ごとに取得できます。空行は高さだけを持ち、横幅は0です。
