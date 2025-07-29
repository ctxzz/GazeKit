# GazeKit Project Guidelines (CLAUDE.md)

This document provides essential context for the GazeKit project. Please adhere to these guidelines when generating or modifying code.

## プロジェクト概要

- **目的**: iPadのTrueDepthカメラとARKitを利用した、高精度な視線追跡（アイトラッキング）ライブラリ `GazeKit` と、そのデモアプリ `GazeKitDemo` を開発する。
- **管理ツール**: プロジェクトファイルは **XcodeGen** で管理する。`project.yml` が定義ファイルである。
- **依存関係**: Swift Package Manager (SPM) を使用する。外部ライブラリは最小限に抑える。

## 開発ワークフロー

- **プロジェクト生成**: `project.yml` を編集後、必ず `xcodegen generate` を実行して `.xcodeproj` を更新すること。
- **ビルドと実行**:
  - `GazeKitDemo` スキームを選択してビルドする。
  - **重要**: 実行は必ず**TrueDepthカメラ搭載のiPad実機**で行うこと。シミュレータでは動作しない。
- **テスト**:
  - `GazeKit` ターゲットの単体テストを主に行う。Xcodeで `Cmd+U` を実行してテストする。

## 主要ファイルとアーキテクチャ

- `Sources/GazeKit/GazeTracker.swift`: ライブラリのメインクラス。外部に公開するAPIを管理する。
- `Sources/GazeKit/Calibration.swift`: 画面座標へのマッピング精度を向上させるためのキャリブレーションロジック。
- `Sources/GazeKit/ARKitHandler.swift`: `ARSession` の管理と `ARFaceAnchor` からのデータ取得を担当する内部クラス。
- `Sources/GazeKitDemo/GazeTrackingViewController.swift`: `GazeKit` ライブラリを使用した実装例。

## コードスタイル

- **命名規則**: Appleの [API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) に従う。
- **アクセス修飾子**: `private` や `fileprivate` を適切に使用し、不要な外部公開を避ける。
- **コメント**: 複雑な計算（特に3Dベクトルの計算やキャリブレーションの補正ロジック）には、処理内容を説明するコメントを必ず追加すること。
- **エラーハンドリング**: `do-catch` と独自エラー型 `GazeKitError` を用いて、初期化失敗などのエラーを明確に処理する。

## 重要事項 (IMPORTANT)

- **実機必須**: このプロジェクトはARKitの顔追跡機能に依存しているため、**シミュレータでは絶対に動作しない**。
- **カメラ権限**: `GazeKitDemo/Info.plist` には `NSCameraUsageDescription` が必須。権限リクエストの処理を忘れないこと。
- **座標系**: ARKitの3D座標系とUIKitの2D画面座標系の変換は慎重に行うこと。バグの温床になりやすい。
