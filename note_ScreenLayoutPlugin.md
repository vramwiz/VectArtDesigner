# 画面レイアウトプラグイン 固有作業ノート

AviUtl2配置プラグイン固有の登録名、設定項目、現在状況を扱う。
3プロジェクト共通の設計と規約は [note.md](note.md)、完了済み作業は [HISTORY.md](HISTORY.md) を参照する。

## プロジェクト

- Delphiプロジェクト名は`SYNC_ScreenLayout_Filter`とする。
- `.dpr`と`.dproj`はリポジトリルートへ配置する。
- AviUtl2上のプラグイン名は`【画面レイアウト】`、分類は`SYNC`とする。
- 対象はWin64のAviUtl2フィルタープラグインとする。

## 現在の段階

- 設定項目は`編集`ボタンと、シリアライズ済み文字列を保持する`配置データ`の2つだけとする。
- `編集`ボタンは選択中オブジェクトの`配置データ`をUTF-8で取得し、単独アプリと同じ
  `TMainForm`をモーダル表示する。画面終了時は編集DocumentをJSON化して同じ項目へ書き戻す。
- 空の`配置データ`では新規Documentを開き、不正なJSONは既存値を上書きせずエラー表示する。
- Document JSONは現在バージョン1で、キャンバス、矩形レイヤー、選択位置を保持する。
- 映像コールバックは入力映像を変更せず成功を返すだけとし、描画処理はまだ実装しない。
- AviUtl2の設定項目登録は`Lib\AviUtl2\PluginFilterTable.pas`へ共通化し、
  `SetupPluginTable`、`AddButton`、`AddString`を使用する。
- DCUは`Win64\SYNC_ScreenLayout_Filter\<Config>\DCU`へ分離する。
- Win64ビルド時はローカルへDLLを生成し、`C:\ProgramData\aviutl2\Plugin\SYNC_ScreenLayout`へ
  `.auf2`としてコピーする。共通UI用の`sk4d.dll`も配置し、ローカルの`.dll`、`.rsm`、
  誤生成された`.exe`は削除する。

## 次の作業

1. AviUtl2の現在映像を編集背景として共通UIへ渡す。
2. `配置データ`から作った不変スナップショットを映像コールバックで描画する。
3. JSONへ文字・線など今後追加するレイヤー型を拡張する。
