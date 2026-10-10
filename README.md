# 星屑弾幕 — Flutter デスクトップ弾幕ゲーム

一人で遊べる、ボス戦タイプの小さな弾幕シューティングです。Flutter の `CustomPainter` で描画し、外部アセットや追加パッケージは使いません。

## 操作
- 移動：WASD または矢印キー
- 低速移動：Shift（当たり判定表示）
- ショット：自動連射
- ポーズ／再開：P または Esc
- スタート／リトライ：Enter または画面のボタン

## 起動方法（Windows）
1. Flutter SDK をインストールし、`flutter doctor` で Windows desktop 開発環境を確認します。
2. このフォルダでターミナルを開きます。
3. 実行します。

```bash
flutter create --platforms=windows .
flutter pub get
flutter run -d windows
```

`flutter create` は Windows 用の runner ファイルを生成します。Flutter の Windows デスクトップ開発には Visual Studio の「Desktop development with C++」ワークロードが必要です。

## ビルド
```bash
flutter build windows
```

実行ファイルは通常 `build/windows/x64/runner/Release/` 以下に生成されます。
