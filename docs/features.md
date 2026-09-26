# ToyFoxx 実装機能一覧

ToyBoxx（WPF + FFME 版）の実装を読み取って作成した、ToyFoxx で実装すべき機能の仕様書。

- 参照元: https://github.com/tackme31/ToyBoxx
- 対象コミット時点の ToyBoxx: .NET 9 / WPF / WPF-UI 4.0.3 / FFME.Windows 7.0.361-beta.1
- ToyFoxx 側の前提: Qt 6.11+ / Qt Quick / Qt Multimedia（FFmpeg バックエンド）

ToyBoxx の挙動は「仕様の出典」として扱う。バグや WPF 固有の回避策まで再現する必要はなく、
本ドキュメントで「変更する」と明記した箇所は意図的に変える。

---

## 1. 実装チェックリスト

`P1` = これが無いとプレイヤーとして使えない / `P2` = ToyBoxx の体験を成立させる主要機能 /
`P3` = 付加機能。

| ID | 機能 | 優先 | 状態 |
|---|---|---|---|
| F-01 | ウィンドウ / アプリ起動 | P1 | 一部（空ウィンドウまで。サイズ復元とアイコンは未） |
| F-02 | メディアを開く（ダイアログ / D&D / コマンドライン引数） | P1 | 済（失敗時は `console.warn` のみ。F-24 待ち） |
| F-03 | 再生 / 一時停止 / 停止 | P1 | 済 |
| F-04 | シークバー（位置表示・クリックシーク・ドラッグシーク） | P1 | 一部（1 フレーム単位の `stepSize` と区間マーカーは未） |
| F-05 | 再生位置 / 総再生時間の表示 | P1 | 済 |
| F-06 | 音量 / ミュート | P1 | 未 |
| F-07 | 全画面切り替え | P1 | 済（スリープ抑止は F-22） |
| F-08 | ウィンドウタイトル | P1 | 未 |
| F-09 | コントローラーパネル（レイアウト・ボタン活性制御） | P1 | 一部（開く / 再生 / 一時停止 / 停止 / 時間 / 全画面のみ。ボタンはテキスト表示） |
| F-10 | コントローラーパネルの自動非表示とカーソル非表示 | P2 | 未 |
| F-11 | キーボードショートカット | P2 | 未 |
| F-12 | 再生速度変更（音程維持） | P2 | 済（`pitchCompensation` は既定値任せ。可否による出し分けは未） |
| F-13 | 全体ループ再生 | P2 | 未 |
| F-14 | 区間ループ（A-B ループ）とシークバー上のマーカー | P2 | 未 |
| F-15 | コマ送り | P2 | 未 |
| F-16 | ズーム / パン / 回転 / 等倍表示 / リセット | P2 | 未 |
| F-17 | スクリーンショット保存 | P2 | 未 |
| F-18 | 通知トースト（Snackbar 相当） | P2 | 未 |
| F-19 | シークバーのサムネイルプレビュー | P3 | 未 |
| F-20 | 設定の永続化 | P3 | 未 |
| F-21 | テーマ（Dark / Light / HighContrast） | P3 | 未 |
| F-22 | 全画面中のスリープ抑止 | P3 | 未 |
| F-23 | カスタムタイトルバー | P3 | 未 |
| F-24 | エラー表示 | P3 | 未 |

推奨実装順: **F-01〜F-09 → F-10〜F-11 → F-12〜F-15 → F-16〜F-18 → F-19〜F-24**

---

## 2. 機能仕様

### F-01 ウィンドウ / アプリ起動

ToyBoxx:
- `FluentWindow`、最小サイズ 640x640、起動位置は `WindowStartupLocation="Manual"` で設定値から復元。
- DI ホスト（`Microsoft.Extensions.Hosting`）の `IHostedService` が、テーマ適用 → FFmpeg 初期化 →
  ウィンドウ生成・表示、という順で起動する。
- ウィンドウ `Loaded` 時にコマンドライン引数のファイルを開く。

ToyFoxx:
- `QGuiApplication` + `QQmlApplicationEngine`。DI コンテナは導入しない（C++ シングルトンを QML に公開する）。
- 最小サイズ 640x640。既定サイズは設定値（F-20）から復元、無ければ 1280x720 程度。
- Qt Multimedia の初期化は不要（FFmpeg は Qt に同梱）。`QGuiApplication` を**メインスレッドで最初に**
  生成すること（Windows の COM/STA 初期化要件）。

### F-02 メディアを開く

入力経路は 3 つ。いずれも同じ解決処理を通す。

1. **コマンドライン引数**: 第 1 引数をパスとして扱う（`QCommandLineParser`）。
2. **ドラッグ & ドロップ**: ウィンドウ全体が受け付ける。複数ドロップ時は**先頭 1 件のみ**。
3. **ファイルダイアログ**: `FileDialog`。ToyBoxx にはダイアログが無く D&D と引数のみだが、
   ToyFoxx では追加する。

ソース解決規則（ToyBoxx `MediaSourceHelper.Resolve` と同等）:
- 前後の空白と `"` を除去する。
- ローカルファイルとして存在すれば絶対パスに正規化する。
- そうでなく絶対 URI として解釈できて `file:` 以外なら、**文字列をそのまま**使う
  （署名付き URL のクエリを正規化で壊さないため）。http / https / rtsp などのストリームを許容する。
- どちらでもなければ何もしない。

開く手順:
- 既にメディアが開いていれば閉じる。プレビュー用プレイヤー（F-19）も閉じる。
- メインを開く。プレビューは**待たずに**別途開く（起動体感を落とさない）。
- 開いた直後は再生を開始する（ToyBoxx は `LoadedBehavior="Play"`）。Qt では `autoPlay: true` か
  `mediaStatus` 監視で `play()`。
- 失敗時は F-24 のエラー表示。

### F-03 再生 / 一時停止 / 停止

| 操作 | 挙動 |
|---|---|
| 再生 | 末尾到達済み（`EndOfMedia`）なら位置 0 にシークしてから再生 |
| 一時停止 | そのまま一時停止 |
| 停止 | 停止したうえで位置 0 に戻す（`MediaPlayer.stop()` で兼ねられるか要確認。必要なら明示的に `position = 0`） |

### F-04 シークバー

ToyBoxx は `Slider` を継承した独自コントロール 2 つを使っている。

**`HtmlLikeSlider`（= HTML の `<input type=range>` 風の挙動）**
- トラックのどこをクリックしてもその位置へ**即座に**値が飛び、そのままドラッグ操作に入る。
  WPF 標準 Slider はクリックで 1 ステップずつ動くだけなので独自実装している。
- Qt Quick Controls の `Slider` は既定でこの挙動（`live: true`、トラッククリックでジャンプ）なので、
  **独自コントロールは不要**。ハンドル外クリックの扱いだけ確認する。
- ボリュームスライダーにも同じコントロールを使っている。

**`PositionSlider`（`HtmlLikeSlider` を継承）**
- 区間ループの開始 / 終了位置に、白 2px の縦線マーカーを描画する（F-14）。

その他:
- 範囲は `0..duration` ではなく **`PlaybackStartTime..PlaybackEndTime`**（FFME の概念）。
  Qt では `0..duration` で十分。ただしライブストリームで `duration == 0` になるケースを考慮する。
- `SmallChange` / `LargeChange` は 1 フレーム相当（FFME の `PositionStep`）。Qt では
  `metaData` のフレームレートから算出する。
- 再生中に値が更新され続けるため、**ユーザーがドラッグ中は位置バインディングを上書きしない**こと。

### F-05 再生位置 / 総再生時間の表示

- 右下に `hh:mm:ss / hh:mm:ss` 形式で表示。
- ToyBoxx は書式が `hh\:mm\:ss` 固定なので 100 時間超は破綻するが、実用上問題なし。同じ方式でよい。

### F-06 音量 / ミュート

- ミュートはトグルボタン。ミュート中は音量スライダーを無効化する。
- 音量スライダーは 0.0〜1.0、幅 100。
- 値は設定に永続化する（F-20）。
- Qt では `AudioOutput.volume` / `AudioOutput.muted`。`volume` は線形値なので、
  知覚的な音量にしたい場合は `QAudio::convertVolume` 相当の変換を検討する（ToyBoxx は未対応）。

### F-07 全画面切り替え

- 発火経路: ウィンドウのダブルクリック、コントローラーパネルの全画面ボタン。
- ToyBoxx は `WindowStyle=None` + `WindowState=Maximized` で擬似全画面にし、解除時に
  以前のウィンドウ状態（`WindowState` / `WindowStyle` / `ResizeMode` / `Top` / `Left`）を復元する。
- ToyFoxx では `Window.visibility` を `Window.FullScreen` / `Window.Windowed` で切り替える。
  Qt が状態を保持するので、独自の状態退避クラスは不要。
- 全画面の間はスリープを抑止する（F-22）。
- **注意**: コントローラーパネル上のダブルクリックは全画面トグルを発火させない。ToyBoxx は
  パネルの `PreviewMouseDown` でダブルクリック間隔内の 2 回目を `Handled` にして潰している。
  ToyFoxx ではパネル側の `MouseArea` でイベントを消費すればよい。

### F-08 ウィンドウタイトル

- 形式: `<タイトル> - ToyFoxx`。メディア未オープン時は `ToyFoxx` のみ。
- タイトル = 拡張子を除いたファイル名。URL でファイル名が取れない場合はホスト名。
- 64 文字を超えたら 64 文字に切って `...` を付ける。

### F-09 コントローラーパネル

画面下部に重ねる。高さ 120、不透明度 0.8、背景はテーマの背景色。上段 20px がシークバー、
下段 70px がボタン列。

**左側（左寄せ）**

| 要素 | 表示条件 | 活性条件 |
|---|---|---|
| 再生ボタン | 再生中でないとき | オープン済 && 再生中でない && シーク中でない && 状態変更中でない |
| 一時停止ボタン | 一時停止可能 && 再生中 | オープン済 && 一時停止可能 && 再生中 |
| 停止ボタン | 常時 | オープン済 && 状態変更中でない && シーク中でない |
| コマ送りボタン | 常時 | オープン済 && 末尾未到達 && シーク中でない && 一時停止中 |
| 速度ボタン（トグル + ポップアップ） | 常時 | オープン済 && シーク中でない |
| ミュートトグル | 常時 | 常時 |
| 音量スライダー | 常時 | ミュートでないとき |

再生ボタンと一時停止ボタンは同じ位置で排他表示。

**右側（右寄せ）**

| 要素 | 内容 |
|---|---|
| 位置 / 総時間ラベル | F-05 |
| 全体ループトグル | F-13 |
| 区間ループトグル | F-14 |
| 全画面ボタン | F-07 |

ToyFoxx では、この活性条件のもとになる状態を QML 側で `MediaPlayer` のプロパティから導出する。
対応関係の目安:

| FFME | Qt Multimedia |
|---|---|
| `IsOpen` | `mediaStatus >= MediaPlayer.LoadedMedia && mediaStatus != MediaPlayer.InvalidMedia` |
| `IsPlaying` | `playing`（6.5+） |
| `IsPaused` | `playbackState === MediaPlayer.PausedState` |
| `HasMediaEnded` | `mediaStatus === MediaPlayer.EndOfMedia` |
| `IsSeekable` | `seekable` |
| `CanPause` | 相当なし。`seekable` で代替するか常に true とする |
| `IsSeeking` / `IsChanging` | 相当なし。シーク要求中フラグを QML 側で持つ |

### F-10 コントローラーパネルの自動非表示

- 150ms 周期で監視し、**マウス静止 3 秒**でパネルをフェードアウト（300ms）し、
  カーソルを非表示にする。
- 操作再開時はフェードイン（100ms）してカーソルを戻す。
- マウスがパネル上にある間は非表示にしない。
- ウィンドウからマウスが出たら即座に非表示扱いにする。
- ToyFoxx では `Timer` + `opacity` の `Behavior`/`NumberAnimation`、カーソルは
  `Qt.BlankCursor`（`cursorShape`）で実現する。`visible: false` にするのではなく
  `opacity: 0` のままにするとヒットテストが残るので、アニメーション完了後に `visible` を落とす。

### F-11 キーボードショートカット

| キー | 動作 | 条件 |
|---|---|---|
| `Space` | 再生 / 一時停止のトグル | オープン済 |
| `Left` | 5 秒戻る | オープン済 && シーク中でない |
| `Right` | 5 秒進む | オープン済 && シーク中でない |
| `S` | スクリーンショット保存（F-17） | オープン済 |
| `R` | 時計回りに 90 度回転（累積） | オープン済 |
| `F` | 等倍表示（F-16） | オープン済 && 映像あり |
| ダブルクリック | 全画面トグル | — |
| `Ctrl` + ホイール | ズーム | — |
| 左ドラッグ | パン（ズーム倍率 > 1.0 のときのみ） | — |
| 中クリック | ズーム / パン / 回転のリセット | — |
| `F4` | 診断オーバーレイの表示切替（ToyFoxx で追加。既定は非表示） | — |

ToyBoxx はコントローラーパネルにフォーカスが移ってもキーが効くように、キー入力ごとに
フォーカスをウィンドウへ戻している。ToyFoxx では最上位 `Item` に `focus: true` を置き、
ボタン類を `focusPolicy`/`activeFocusOnTab` で除外する形にする。

### F-12 再生速度変更

- 選択肢: **0.25 / 0.5 / 0.75 / 1.0 / 1.25 / 1.5 / 2.0 / 3.0**。
- トグルボタンに現在値を `x 1.5` 形式で表示し、押すとポップアップで一覧を出す。選択後に閉じる。
- ToyBoxx は音程維持のために SoundTouch を使っているが、ToyFoxx では
  `MediaPlayer.playbackRate` + `pitchCompensation`（Qt 6.10+）で代替し、**SoundTouch は使わない**。
  `pitchCompensationAvailability` を確認してボタンの出し方を決める。

### F-13 全体ループ再生

- トグルボタン。ToyBoxx は FFME の `LoopingBehavior`（`Play` / `Pause`）で表現し、設定に
  `int` で保存している。
- ToyFoxx では `MediaPlayer.loops = MediaPlayer.Infinite : 1`。設定には `bool` で保存する
  （ToyBoxx の `int` 値は移行しない）。

### F-14 区間ループ（A-B ループ）

トグルボタン 1 つを押すたびに状態が進む 3 段階の操作。

1. **未設定** → 1 回押す: 現在位置を開始点に設定（有効化はまだしない）。
2. **開始点のみ** → 押す: 現在位置を終了点に設定して有効化する。
   ただし `開始点 >= 現在位置` の場合は**何もしない**。
3. **有効** → 押す: 開始点・終了点を破棄して無効化する。

- 新しいメディアを開いたら常にクリアする。
- 有効時は再生位置の変化を監視し、`位置 < 開始点` または `終了点 < 位置` で開始点へシークする。
- シークバー上に開始点・終了点を白 2px の縦線で描画する。
- ToyFoxx では `onPositionChanged` で判定する。位置通知の間隔ぶんの誤差が出る点は許容する
  （ポーリングで精度を上げようとしないこと）。

### F-15 コマ送り

- 一時停止してから 1 フレーム進める。
- ToyBoxx は連打に対応するため `Click` ではなく `MouseLeftButtonDown` を直接拾っている。
  ToyFoxx でも押下ごとに 1 回進む実装にする（`autoRepeat` の活用も可）。
- **Qt Multimedia にコマ送り API は無い**。`position += 1000 / フレームレート`（`metaData` の
  `VideoFrameRate`）で近似する。シーク粒度の制約で厳密な 1 フレームにならない場合があることを
  UI 上は隠さず、実装コメントに残す。

### F-16 ズーム / パン / 回転 / 等倍表示 / リセット

ToyBoxx は映像要素に `ScaleTransform` → `RotateTransform` → `TranslateTransform` の
`TransformGroup` を適用している。Scale と Rotate の中心はどちらも**表示要素の中心**。
ToyFoxx でも同じ順序で `transform: [Scale {}, Rotation {}, Translate {}]` を映像アイテムに付ける。

| 操作 | 仕様 |
|---|---|
| ズーム | `Ctrl` + ホイール。ステップ 0.1、下限 0.1。中心は表示領域の中心 |
| ズーム縮小時の補正 | 倍率が 1.0 未満になったら平行移動量を 0 にリセットする |
| パン | 左ドラッグ。**倍率 > 1.0 のときのみ有効**。マウス移動量をそのまま加算 |
| 回転 | `R` で +90 度（累積、360 で正規化してよい） |
| 等倍表示 | `F`。`scale = 1 / min(表示幅 / 映像幅, 表示高 / 映像高)`。映像は常にアスペクト維持で表示領域に収まっているので、この倍率でピクセル等倍になる |
| リセット | 中クリック。倍率 1.0 / 平行移動 0 / 回転 0 |

- 映像の解像度は Qt では `VideoOutput.sourceRect` または `metaData` の `Resolution` から取る。
- 映像は表示領域でクリップする（ToyBoxx は `ClipToBounds="True"` の `Grid`）。
- **性能上の制約**: これらは必ずシーングラフの transform で行い、フレームのリサイズや
  `layer.enabled` を使わないこと（`CLAUDE.md` の Performance rules 参照）。
- 既知の粗さ: 回転後に `F` を押しても回転を考慮した等倍計算にならない。ToyFoxx で直すかは未決。

### F-17 スクリーンショット保存

- `S` キー、またはボタン（ToyBoxx はキーのみ）。
- 保存先: **ピクチャフォルダ**（`QStandardPaths::PicturesLocation`）。
- ファイル名: `<タイトル>_<タイムスタンプ>.png`。タイトルはファイル名として不正な文字を除去したもの。
  ToyBoxx の書式は `yyyyMMddhhmmssfff` で 12 時間制のため午前 / 午後が区別できない。
  ToyFoxx では `yyyyMMddHHmmsszzz` 相当（24 時間制）にする。
- 実行中の多重起動を防ぐ再入ガードを持つ。
- 保存は UI をブロックしない（ToyBoxx はバックグラウンドスレッド）。
- 保存後にトースト表示（F-18）。クリックでエクスプローラーの該当ファイルを選択状態で開く。
- **取得方法**: `videoOutput.videoSink.videoFrame` を取得して `QVideoFrame::toImage()`。
  押されたときだけ 1 回読み戻す。`grabToImage` は使わない（変換後・合成後の画になる）。
  出力はソース解像度、変換（ズーム / 回転）は反映しない ＝ ToyBoxx と同じ。

### F-18 通知トースト

- ToyBoxx は WPF-UI の Snackbar。表示 3 秒、タイトル + メッセージ、右寄せ、幅 500。
- クリック可能にできる（スクリーンショットの保存先を開く用途）。
- ToyFoxx では同一ウィンドウ内の QML オーバーレイとして自作する。用途は
  スクリーンショット保存通知とエラー通知（F-24）。

### F-19 シークバーのサムネイルプレビュー

- シークバーにマウスを乗せると、シークバーの**上**に 160x130 のプレビュー枠を出す。
  枠は角丸 5、1px の枠線付き。
- 枠はマウスの X 座標を中心に水平移動する。
- 枠の下端にホバー位置の時刻を `hh:mm:ss` で表示する。
- ホバー位置 = `min + (マウスX / スライダー幅) * (max - min)`。
- **250ms のアイドル debounce** を置き、マウスが止まってからプレビュー用プレイヤーをシークする。
- マウスが離れたら枠を隠す。

ToyBoxx はこれを 2 つ目の `MediaElement` で実現しており、低負荷化のため次の設定を入れている:
- 1/4 解像度デコード（`LowResolutionIndex = Quarter`）
- 高速デコード / 低遅延デコード有効
- 音声・字幕を無効化
- ハードウェアデコード有効

ToyFoxx では **`VideoOutput` を持たない 2 つ目の `QMediaPlayer` + 素の `QVideoSink`** を C++ 側に
用意し、シーク後に届いたフレームを 1 枚だけ画像として QML へ渡す（`QQuickImageProvider` か
`QVideoSink` を直接バインドしたアイテム）。フル解像度のプレイヤーを 2 つ動かす構成は避ける。

### F-20 設定の永続化

ToyBoxx が保存している項目（終了時に保存、起動時に復元）:

| 項目 | 型 | 備考 |
|---|---|---|
| ウィンドウ位置 Top / Left | double | 最大化中でも復元後の矩形（`RestoreBounds`）を保存 |
| ウィンドウサイズ Width / Height | double | 同上 |
| 全体ループ | int | ToyFoxx では **bool** にする |
| 音量 | double | 0.0〜1.0 |
| ミュート | bool | |

ToyFoxx では `QSettings`（C++）か `QtCore` の `Settings`（QML）で保持する。
保存タイミングはウィンドウクローズ時。マルチモニタ構成で画面外に復元されないよう、
利用可能なスクリーン矩形に収める補正を入れる（ToyBoxx には無い）。

### F-21 テーマ

- ToyBoxx は `appsettings.json` の `ApplicationTheme` で `Dark` / `Light` / `HighContrast` を選び、
  WPF-UI の `ApplicationThemeManager` に適用する。UI からは切り替えられない。
  `appsettings.user.json` による上書きも可。
- ToyFoxx では Qt Quick Controls の **FluentWinUI3** スタイルを使い、
  Dark / Light はスタイルの配色指定 + 自前のテーマシングルトンで切り替える。
  HighContrast は優先度を下げてよい。
- 設定ファイルの形式は JSON に縛られない（`QSettings` で十分）。

### F-22 全画面中のスリープ抑止

- ToyBoxx は全画面に入るときに `SetThreadExecutionState(ES_DISPLAY_REQUIRED | ES_CONTINUOUS)`、
  出るときに `ES_CONTINUOUS` に戻す（**再生中ではなく全画面中**が条件）。
- ToyFoxx でも同じ Win32 API を `platform/` の小さなラッパーで呼ぶ。
  条件を「再生中」に変えるかは未決（変えるほうが自然だが挙動差になる）。

### F-23 カスタムタイトルバー

- ToyBoxx は WPF-UI の `TitleBar` を映像の上に重ね、アイコンとタイトルを表示する
  （ウィンドウ枠は Fluent のもの）。
- ToyFoxx の第 1 段階では**OS 標準のウィンドウ枠で十分**。フレームレス化と自前タイトルバーは
  後回しにする。全画面時はいずれにせよ非表示。

### F-24 エラー表示

- ToyBoxx はメディアオープンの例外を Snackbar で出す（`Media Failed: <型>\n<メッセージ>`）。
  プレビュー側の失敗は黙って無視する。
- ToyFoxx では `MediaPlayer.onErrorOccurred` で `error` / `errorString` を拾い、
  F-18 のトーストで表示する。プレビュー側の失敗は無視する。

---

## 3. ToyBoxx から意図的に変える点

| 項目 | ToyBoxx | ToyFoxx |
|---|---|---|
| 再生エンジン | FFME（GPU→CPU→GPU 往復） | Qt Multimedia FFmpeg バックエンド（GPU テクスチャのまま） |
| 音程維持 | SoundTouch | `MediaPlayer.pitchCompensation` |
| FFmpeg の配布 | `requirements.ps1` で別途 DL | Qt 同梱、`windeployqt` が配置 |
| スライダー | 独自 `HtmlLikeSlider` | Qt Quick Controls の `Slider` 標準挙動 |
| 全画面 | `WindowStyle` / `WindowState` を直接操作 | `Window.visibility` |
| 全体ループの保存形式 | `int`（`MediaPlaybackState`） | `bool` |
| スクリーンショットのタイムスタンプ | 12 時間制（`hh`） | 24 時間制 |
| ファイルを開く手段 | D&D / コマンドライン引数のみ | ファイルダイアログも追加 |
| DI | `Microsoft.Extensions.Hosting` | 使わない |
| ウィンドウ位置の復元 | 無条件に復元 | スクリーン矩形内に収める |

## 4. 未決事項

- コマ送りの精度をどこまで追い込むか（`position` 加算の近似で妥協するか、`QVideoSink` を使って
  フレーム単位で制御するか）。後者は Performance rules と衝突しうるので慎重に。
- 回転状態を考慮した等倍表示（F-16）を直すか、ToyBoxx と同じ挙動に留めるか。
- スリープ抑止の条件を「全画面中」から「再生中」に変えるか。
- `CanPause` / `IsSeeking` / `IsChanging` に相当する状態を QML 側でどこまで作り込むか。
- HighContrast テーマを実装するか。

## 5. 人間側の作業待ち

コードでは解決できず、判断か実機作業が必要なもの。

- **アイコン素材** — ToyBoxx の `img/icons/*.png` と `256x256.ico` を流用するか作り直すか。
  ウィンドウアイコンと exe のアイコン（F-01 / F-23）に必要。
- **LICENSE と著者表記** — ToyBoxx は MIT / Takumi Yamada。同じでよいかの確認待ち。
- **4K テスト動画と計測ベースライン** — `CLAUDE.md` の Baseline に挙げた項目を、置き換え前の
  ToyBoxx で同じ動画・同じ PC について記録しておく必要がある。これが無いと改善を判断できない。
  解像度 / fps / コーデック / ビット深度も控えること。
- **`playback-performance.md` をこのリポジトリに複製するか** — 現状は前身リポジトリ参照のみ。

## 6. 進捗メモ

- `develop` ブランチで作業中。
- 実装済み: F-02 / F-03 / F-05 / F-07、F-04 と F-09 の一部。Qt 6.11.1 + MSVC 14.44 でビルド・
  `all_qmllint` ともにクリーン。
- 起動時のシーングラフのログで **D3D11 RHI + FLIP_\* スワップチェーン**（`use legacy
  (non-FLIP) model = false`）を確認済み。WPF が使えなかった経路で、書き換えの前提が成立している。
- ffmpeg で生成した 4K60 H.264 のテストクリップで、`qt.multimedia.ffmpeg.hwaccel` のログに
  **d3d11va** が選択され、HW フレーム形式（D3D11 テクスチャ）で出力されることを確認済み。
  **4K の実測（Baseline の項目）が可能な状態**になった。
- ソース解決（F-02 の規則）は C++ の `MediaSource` シングルトン（`src/app/`）。コマンドライン引数は
  `main.cpp` で同じ関数を通して `Main.initialSource` に渡す。
- `VideoSurface.qml` はまだ無い。変換を持たない段階ではラッパーが不要なので、F-16 で作る。
- **診断オーバーレイ**（`PlaybackDiagnostics.qml` + `src/media/PlaybackMonitor`、`F4` で表示切替、既定は非表示）。
  ToyBoxx で再生ボタンが点滅した現象（FFME のクロック停止）に相当する指標を出す。Qt の FFmpeg
  バックエンドは遅延時にクロックを止めずフレームを捨てる設計と見られるため、状態の点滅（Stall events /
  playing toggles）だけでなく、シンクへのフレーム到着間隔（Max gap / Late frames = 期待間隔の 1.5 倍超）と
  シーングラフの表示レート（Present fps）も出している。シーク直後は間隔が空くので Late frames に 1 件入る。
  `Rate` 行に再生速度と、それを掛けた期待フレームレートを出す。速度を変えると累計はリセットされる。
  常設する。非表示の間は計測の接続を切るので負荷は無い。今後の実装で邪魔になれば削除してよい。
- **実機での体感確認（2026-09-27）**: 実際の 4K 素材を 3 倍速・全画面で再生すると、診断ランプが
  ごくまれに一瞬赤く（Late frames）なる程度。オーバーレイ無しでは気にならず、ToyBoxx より明らかに
  改善している。CLAUDE.md の Baseline 項目（CPU / GPU / PresentMon）による数値比較はまだ。
- 次の着手候補: **4K 実測** → F-06 / F-08 / F-09 の残り → F-10〜F-11。
