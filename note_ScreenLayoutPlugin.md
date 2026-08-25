# 画面レイアウトプラグイン 固有作業ノート

AviUtl2配置プラグイン固有の登録名、設定項目、現在状況を扱う。
3プロジェクト共通の設計と規約は [note.md](note.md)、完了済み作業は [HISTORY.md](HISTORY.md) を参照する。

## プロジェクト

- Delphiプロジェクト名は`SYNC_ScreenLayout_Filter`とする。
- `.dpr`と`.dproj`はリポジトリルートへ配置する。
- AviUtl2上のプラグイン名は`画面レイアウト`、分類は`SYNC`とする。
- 対象はWin64のAviUtl2フィルタープラグインとする。

## 現在の段階

- 設定項目は`編集`ボタンと、シリアライズ済み文字列を保持する`配置データ`の2つだけとする。
- `編集`ボタンは選択中オブジェクトの`配置データ`をUTF-8で取得し、単独アプリと同じ
  `TMainForm`をモーダル表示する。画面終了時は編集DocumentをJSON化して同じ項目へ書き戻す。
- 空の`配置データ`では新規Documentを開き、不正なJSONは既存値を上書きせずエラー表示する。
- Document JSONは現在バージョン1で、キャンバス、矩形レイヤー、選択位置を保持する。
- 映像コールバックはObject IDとEffect IDの組み合わせごとにコンテキストを取得し、現在の
  `配置データ`と解析済みDocumentをオブジェクト単位で保持する。
- 同じObject IDとEffect IDのコンテキストは再利用し、異なるキー間でDocumentや背景を
  共有しない。
- `配置データ`が変更されたときだけJSONを再解析し、不正データでは直前の正常な
  Documentを維持する。
- 各映像コールバックで`GetFramebufferTexture2D`からAviUtl2の合成済み現在映像を取得し、
  RGBA8画像として対象コンテキストだけに保持する。
- `編集`ボタンでは選択オブジェクトのレイヤーと配置範囲から対応コンテキストを取得し、
  保持した最新背景を共通編集キャンバスへ参照表示する。
- 参照背景はDocumentとJSONへ含めない。単独アプリは背景を注入しないため従来表示を維持する。
- Documentの表示図形は共通Skiaレンダラーで透明RGBA8へ描画し、映像コールバックで
  `GetImageData`の入力映像へSource-over合成して`SetImageData`へ返す。
- 同じDocument Revisionと出力寸法では透明RGBA8をコンテキスト内で再利用し、毎フレームの
  Skia再描画を避ける。入力映像との合成だけをフレームごとに行う。
- AviUtl2の設定項目登録は`Lib\AviUtl2\PluginFilterTable.pas`へ共通化し、
  `SetupPluginTable`、`AddButton`、`AddString`を使用する。
- オブジェクト単位のコンテキスト検索と所有権管理は
  `Lib\AviUtl2\PluginFilterContextManager.pas`を共通の接続口とする。
- DCUは`Win64\SYNC_ScreenLayout_Filter\<Config>\DCU`へ分離する。
- Win64ビルド時はローカルへDLLを生成し、`C:\ProgramData\aviutl2\Plugin\SYNC_ScreenLayout`へ
  `.auf2`としてコピーする。共通UI用の`sk4d.dll`も配置し、ローカルの`.dll`、`.rsm`、
  誤生成された`.exe`は削除する。

## 次の作業

1. Documentから描画専用の不変スナップショットを生成し、UI編集と映像描画の同時実行を分離する。
2. JSONと共通レンダラーへ文字・線など今後追加するレイヤー型を拡張する。
3. AviUtl2実画面で座標、色、透明度、上下方向がDelphiプレビューと一致することを確認する。
