# MIF診断ツール

`mif`以下の実データを、アプリと同じMIF Reader／Writerで一括して読み込み、別ファイルへ保存して
バイト単位の差分を調べる。AIからはルートのPowerShellスクリプトだけを呼び出せばよい。

```powershell
.\Tools\Invoke-MifDiagnostics.ps1
```

完全な16進ダンプも必要な場合は次を使用する。

```powershell
.\Tools\Invoke-MifDiagnostics.ps1 -Hex
```

入力と出力は指定できる。相対パスは呼び出した時点の現在フォルダーを基準に解決される。

```powershell
.\Tools\Invoke-MifDiagnostics.ps1 -InputPath .\mif -OutputPath .\Win64\MifDiagnostics\manual -Hex
```

## 出力

- `report.md`: 人が確認する全ファイルの集計。
- `report.json`: AIやスクリプトが読む集計とファイル別結果。
- `saved/*.roundtrip.mif`: ReaderからWriterへ通した保存結果。
- `semantic/*.semantic.txt`: MIF／PNGチャンク、CRC、`tEXt`、`waDA`を読みやすくした構造表示。
- `semantic/*.diff.txt`: 最初の差分位置と周辺バイト。完全一致時も一致したことを記録する。
- `hex/*.hex.txt`: `-Hex`指定時だけ作る、元データと保存データの完全な16進ダンプ。

終了コードは、全件一致が`0`、読込または保存エラーが`1`、バイト差分ありが`2`となる。
通常の出力先は`Win64/MifDiagnostics/runs/<実行日時>`であり、過去の診断結果を上書きしない。

