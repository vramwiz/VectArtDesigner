# Lib

VectArtDesignerが直接利用する外部ライブラリを配置する。

- `TextRenderer`: Syncroh2で使用しているGoogle Skiaベースの装飾文字レンダラー。
- `Skia/Win64/sk4d.dll`: Delphi 37のWin64用Google Skiaランタイム。

Win64ビルド後は`Lib/Skia/Win64/sk4d.dll`を実行ファイルと同じフォルダーへコピーする。
アプリケーション起動時にランタイムを取得し、終了時に解放する。
