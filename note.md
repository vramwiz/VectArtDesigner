# VectArtDesigner 作業ノート

作業再開時に最初に確認する、現在の開発状況と基本ルールだけを扱う短いメモ。
試行錯誤や完了済み作業をここへ蓄積せず、制作履歴は [HISTORY.md](HISTORY.md) に記録する。

## プロジェクト

- 製品名とDelphiプロジェクト名は `VectArtDesigner` とする。
- 作業フォルダーは `D:\DelphiProg\test\VectArtDesigner` とする。
- 現在は、IBM WebArt Designerの `.mif` データを調査し、互換読み書きの方針を検討している。
- MIFの調査結果と確度は [mif_analysis.md](mif_analysis.md) を参照する。

## 現在の段階

- `WRT2646\Client` のVCLプロジェクト設定を基に、Win64用のプロジェクト本体を作成済み。
- 現在の画面は、今後の編集機能を追加するためのメインフォーム1つだけで構成する。
- MIFのコンテナー、埋め込みPNG、主要な `waDA*` メタデータの構造を解析中。
- 実装開始前に、Reader/Writerの責務、未知データの保持方針、破損データ時の動作を決める。

## 基本ルール

- 例外をアプリケーション境界の外へ漏らさず、破損ファイルや未知形式でアプリを停止させない。
- 読み込み元に未知の項目がある場合、安易に破棄せず、保持または安全に無視する方針を明確にする。
- 推測で実装した仕様と、実データで確認済みの仕様を区別して記録する。
- 現在の方針が変わったときだけこの文書を更新し、完了事項は `HISTORY.md` へ移す。

## ビルドルール

- Delphi 37.0を使用し、対象プラットフォームはWin64とする。
- DebugとReleaseの両構成を検証する。
- コンパイル警告とエラーを確認し、原則として警告0、エラー0で完了とする。
- `Win32`、`Win64`、`.dcu`、`.rsm`、`.exe`、`.dll` などのビルド成果物はGitへ追加しない。
- 日本語文字列リテラルを持つ `.pas` と `.dpr` はUTF-8 BOM付きで保存する。

ビルドコマンド:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\VectArtDesigner\VectArtDesigner.dproj"" /t:Build /p:Config=Debug /p:Platform=Win64"
```

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\VectArtDesigner\VectArtDesigner.dproj"" /t:Build /p:Config=Release /p:Platform=Win64"
```

## コメントルール

- コードを読めば分かる処理の言い換えではなく、目的、責務、注意点、状態や値の意味を書く。
- 古い仕様や現在の実装と食い違うコメントは、見つけた時点で更新する。
- 不要なコメント、同じ内容の重複、処理を日本語へ置き換えただけのコメントを増やさない。
- ユニット先頭には、そのユニットの目的と担当範囲を `//` で書く。
- `interface` の公開関数・手続きには、呼び出し側から見た責務、入出力、重要な副作用を書く。
- フィールドや定数の短い説明は行末へ置き、同じブロックでは `:`、`=`、`//` の位置を可能な範囲で揃える。
- レコードの各フィールドには用途または値の意味を書く。バイナリー形式に対応するレコードでは、配置と型の理由も明記する。
- コメントと対象の宣言または実装の間に不要な空行を入れない。
- `var` ブロック内へローカル関数・手続きを置かず、補助処理は同じ `implementation` の独立関数へ分ける。
- `property`、`procedure`、`function` の宣言は、112文字以内なら折り返さない。

## 次の作業

1. アプリケーションの最小要件と画面構成を決める。
2. MIF Readerの最小実装から着手し、解析済みサンプルで検証する。
3. 読み込んだオブジェクトを表示する最小キャンバスをメインフォームへ追加する。
