# VectArtDesigner 実装ノート

## 現在の位置付け

`VectArtDesigner`はMIFを主保存形式とする単体アプリである。SVGも読み書きするが、編集モデルとUIは
MIFで表現できる範囲へ限定する。編集モード切替はなく、常に同じMIF仕様で編集する。

## プロジェクト構成

- 実行プロジェクト: `VectArtDesigner.dpr` / `VectArtDesigner.dproj`
- コアモデル: `Source/Core`
- 編集操作: `Source/Editor`
- 描画: `Source/Rendering`
- MIF永続化: `Source/Persistence/Mif`
- SVG永続化: `Source/Persistence/Svg`
- シェルとメニュー: `Source/Shell`
- レイヤーUI: `Source/Layers`
- オブジェクト設定: `Source/ObjectProperties`
- AviUtl2プラグインプロジェクトと専用ライブラリは2026-08-31の方針変更で削除した。

## 実装済みモデル

- Canvas: サイズ、背景色、透明背景
- Rectangle: 座標、回転、塗り、枠線色、線幅、線種、表示、ロック、不透明度
- Line: 始点／終点、線色、線幅、線種、cap、join、アンチエイリアス、始点／終点マーカーとサイズ
- Path: 頂点列、開閉、塗り、輪郭色、線幅、線種、cap、join、アンチエイリアス、
  開いたPathの始点／終点マーカーとサイズ
- Image: PNG、4頂点配置、image／logo区分、表示、ロック、不透明度
- 内部データの線種、品質、マーカー関連は通常名を使用する。`Mif`名はコンテナーと形式変換処理に限定する。

## 編集UI

- `編集`メニューはUndo、Redo、キャンバス設定を提供する。モード項目は持たない。
- Rectangle、Line、Pathの生成既定値は`TVectArtEditorState`で共有する。
- Document変更はUndo／Redoコマンドを通して適用する。
- 複数選択時は共通値だけを表示し、ロックされたレイヤーを含む場合は変更を禁止する。
- 縮小表示時だけ線幅を画面上1px以上へ補正し、DocumentおよびMIF／SVG出力値は変更しない。
- 開いたPathは始点／終点マーカーと各サイズを編集できる。閉じたPathではマーカーを描画せず、
  Object Propertiesの対応項目を無効化する。
- Lineと開いたPathのマーカーはレイヤー一覧のGDI／Direct2Dサムネイルにも表示し、マーカー部分の
  クリックで対象レイヤーを選択できる。Path選択枠は頂点範囲を編集基準として維持する。

## MIFとSVG

- MIF読込では既知のRectangle、Line、Path、ImageをDocumentへ変換する。
- MIF保存では元コンテナーを可能な範囲で再利用し、変換や非対応内容を`TMifExportReport`で返す。
- MIF生成を伴わない`TryAnalyzeVectArtMifExport`を編集状態の判定に使い、ステータスバーへ
  完全互換、変換あり、非対応を表示する。詳細はステータスのヒントへ表示する。
- SVGはMIF編集モデルへ変換できる要素と属性だけをDocumentへ取り込む。
- 詳細な対応範囲と変換・無視・エラー方針は[SVG互換表](svg_compatibility.md)を参照する。
- SVG読込で変換または無視した描画要素と装飾は`TSvgImportReport`へ記録し、アプリ上で通知する。
- SVGルートの`viewBox`と`preserveAspectRatio`はキャンバス座標へ変換する。角丸、個別不透明度、
  fill-rule、線の補助属性、filter／clip／mask／合成指定などMIFへ保持できない属性も読込レポートへ記録する。
- SVG保存はDocumentの値を標準SVG属性へ出力し、線種・マーカーなど必要な補助情報は既存のVAD名前空間で保持する。
- MIFとSVGのどちらから開いても同じDocument型と同じ編集UIを使用する。

## 現在の検証対象

- Document選択・Revision
- Rectangle、Line、Path、Imageの操作
- Object PropertiesとLine Toolbar
- 共通レンダラー
- Document JSON往復
- SVG往復と外部SVG取込
- MIFコンテナー往復、Document往復、WebArtサンプル取込

## ビルド

Debug:

```bat
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\VectArtDesigner\VectArtDesigner.dproj"" /t:Build /p:Config=Debug /p:Platform=Win64"
```

Release:

```bat
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\VectArtDesigner\VectArtDesigner.dproj"" /t:Build /p:Config=Release /p:Platform=Win64"
```

## 次の作業

1. MIF互換性詳細を常時開く専用UIが必要か、実際の編集操作で確認する。
2. 単体アプリ化後も残る外部ホスト用APIとコメントを整理する。
3. 実際の外部SVGで新たな無通知変換が見つかった場合は互換表とレポートを拡張する。
