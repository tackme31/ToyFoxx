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
| F-01 | ウィンドウ / アプリ起動 | P1 | 一部（空ウィンドウまで。サイズ復元は未） |
| F-02 | メディアを開く（D&D / コマンドライン引数） | P1 | 済（ダイアログは廃止） |
| F-03 | 再生 / 一時停止 / 停止 | P1 | 済 |
| F-04 | シークバー（位置表示・クリックシーク・ドラッグシーク） | P1 | 一部（1 フレーム単位の `stepSize` は未。キー操作が無いので実害なし） |
| F-05 | 再生位置 / 総再生時間の表示 | P1 | 済 |
| F-06 | 音量 / ミュート | P1 | 済（永続化は F-20。ボタンはテキスト表示。スライダーは 3 乗カーブ） |
| F-07 | 全画面切り替え | P1 | 済（スリープ抑止は F-22） |
| F-08 | ウィンドウタイトル | P1 | 済 |
| F-09 | コントローラーパネル（レイアウト・ボタン活性制御） | P1 | 済 |
| F-10 | コントローラーパネルの自動非表示とカーソル非表示 | P2 | 済 |
| F-11 | キーボードショートカット | P2 | 済 |
| F-12 | 再生速度変更（音程維持） | P2 | 済（`pitchCompensation` は既定値任せ。可否による出し分けは未） |
| F-13 | 全体ループ再生 | P2 | 済（永続化は F-20） |
| F-14 | 区間ループ（A-B ループ）とシークバー上のマーカー | P2 | 済 |
| F-15 | コマ送り | P2 | 済（再生中も押せる。下記） |
| F-16 | ズーム / パン / 回転 / 等倍表示 / リセット | P2 | 済（回転時はウィンドウに収める。下記） |
| F-17 | スクリーンショット保存 | P2 | 済（キーのみ。ボタンは未） |
| F-18 | 通知トースト（Snackbar 相当） | P2 | 済 |
| F-19 | シークバーのサムネイルプレビュー | P3 | 済（方式は下記。当初案から変更） |
| F-20 | 設定の永続化 | P3 | 済 |
| F-21 | テーマ（Dark / Light / HighContrast） | — | 対応しない（ダーク固定は済。下記） |
| F-22 | 再生中のスリープ抑止（ToyBoxx は全画面中） | P3 | 済 |
| F-23 | カスタムタイトルバー（映像をタイトルバーの下まで広げる） | P2 | 済（既知の粗さは下記） |
| F-24 | エラー表示 | P3 | 済 |
| F-25 | A-B 区間の書き出し（ToyFoxx で追加） | P3 | 済（下記） |

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
- アプリアイコンは `resources/icons/toyfoxx.svg`（原本）から書き出した `toyfoxx.ico` を
  `resources/toyfoxx.rc` の `IDI_ICON1` として exe に埋め込む。Qt は Windows でこれをウィンドウと
  タスクバーのアイコンにも使う。SVG を直したら `.ico` も書き出し直すこと（16〜64px と 256px を同梱）。
  書き出しは ImageMagick（librsvg 付きの Windows 版）で、各サイズを 4 倍密度で描いて縮小する:
  ```
  for s in 16 20 24 32 40 48 64 256; do
    magick -background none -density $((96*s/256*4)) resources/icons/toyfoxx.svg -resize ${s}x${s} $s.png
  done
  magick 16.png 20.png 24.png 32.png 40.png 48.png 64.png 256.png -depth 8 resources/icons/toyfoxx.ico
  ```
- アイコンの意匠（2026-09-27 決定）: 折り紙風の狐の横顔で、外形がそのまま再生ボタン ▶ の三角形になる。
  右上の余白は半透明のオレンジで埋める。スチールブルー（`#3A6585`）の円に、狐を 80% で置く。
  三角形は外接矩形ではなく重心が中央よりわずかに右に来る位置に置き、見た目の中心を揃えている。
  正面顔・背景なし・角丸四角・ネイビーほか 8 色も比較したうえでの選択。Inkscape での微調整は SVG に反映済み。
- Qt Multimedia の初期化は不要（FFmpeg は Qt に同梱）。`QGuiApplication` を**メインスレッドで最初に**
  生成すること（Windows の COM/STA 初期化要件）。

### F-02 メディアを開く

入力経路は 3 つ。いずれも同じ解決処理を通す。

1. **コマンドライン引数**: 第 1 引数をパスとして扱う（`QCommandLineParser`）。
2. **ドラッグ & ドロップ**: ウィンドウ全体が受け付ける。複数ドロップ時は**先頭 1 件のみ**。
3. ~~**ファイルダイアログ**~~: 一度 `FileDialog` と開くボタンを追加したが、不要との判断で削除した
   （2026-09-27）。ToyBoxx と同じく D&D と引数のみ。

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
- 音量スライダーは 0.0〜1.0、幅 100（ToyBoxx はパネルに常時表示の横スライダー）。
- **ToyFoxx（2026-09-27 変更）**: YouTube と同様、ミュートボタンにホバーするとボタンの上に縦スライダー
  （34x104）をポップアップする。ボタンの押下はミュート切り替えのまま。ボタンとポップアップの両方から
  離れて 300ms で閉じる。表示中はパネルを自動非表示にしない。FluentWinUI3 の `Popup` は上下左右の
  パディングを個別に設定しており、`padding` では上書きできない。背景も影付きの 9-patch 画像を負の
  インセットで外側へ描くため縮まない。この 2 点を上書きしている（`VolumeControl.qml`）。
- 値は設定に永続化する（F-20）。
- Qt では `AudioOutput.volume` / `AudioOutput.muted`。`volume` は線形のゲインなので、線形スライダーでは
  上半分でほとんど変わらず下端で急に小さくなる（ToyBoxx はこのまま）。
- **ToyFoxx（2026-09-27 変更）**: スライダー位置 = `volume` の立方根（位置 0.5 で約 -18 dB。PulseAudio / mpv
  と同じ曲線）。`QtAudio::convertVolume` の対数スケールは QML に公開されておらず、上端 1 割で -6 dB→0 dB と
  偏るため使わない。保存値は線形の `volume` のままなので、既存の設定値の意味は変わらない。

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

ボタンは `IconButton.qml`（Segoe Fluent Icons の 1 文字 + ツールチップ / アクセシブル名）。割り当ては
再生 `E768` / 一時停止 `E769` / 停止 `E71A` / コマ送り `EBE7` / ミュート `E767`・`E74F` /
全体ループ `E8EE` / 全画面 `E740`・`E73F`。A-B ループ（`A-B` / `A-`）と速度（`x 1.5`）は文字のまま。
ToyBoxx の「開く」相当は無い（F-02）。

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
| `T` | A-B 区間をビデオフォルダへ書き出す（F-25。ToyFoxx で追加） | オープン済 && 映像あり |
| `F4` | 診断オーバーレイの表示切替（ToyFoxx で追加。既定は非表示） | — |

ToyBoxx はコントローラーパネルにフォーカスが移ってもキーが効くように、キー入力ごとに
フォーカスをウィンドウへ戻している。ToyFoxx では最上位 `Item` に `focus: true` を置き、
ボタン類を `focusPolicy`/`activeFocusOnTab` で除外する形にする。

### F-12 再生速度変更

- 選択肢: **0.25 / 0.5 / 0.75 / 1.0 / 1.25 / 1.5 / 2.0 / 3.0**。
- トグルボタンに現在値を `x 1.5` 形式で表示し、押すとポップアップで一覧を出す。選択後に閉じる。
  ToyFoxx ではボタン幅を最長の表示（`x 0.25`）に合わせて固定し、もう一度押すとポップアップが閉じる。
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
- ToyBoxx の既知の粗さとされていた「回転後の `F`」は、実際には等倍の計算自体は回転に依存せず正しい
  （フィット倍率の逆数なので）。粗さの正体は、1.0 倍のまま 90° 回すと映像がはみ出すこと。
  ToyFoxx では 90° / 270° のとき横倒しの映像をウィンドウに収める補正（`rotationFit`）を表示倍率に掛け、
  `zoom` = 1 が常に「ウィンドウに収まった状態」を意味するようにした。`F` はこの補正を打ち消す。
- `F` の等倍はデバイスピクセル基準（`Screen.devicePixelRatio` を考慮）。表示スケール 100% 以外では
  ToyBoxx（DIP 基準）と倍率が異なるが、本当の等倍になる。

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

当初案は「`VideoOutput` を持たない 2 つ目の `QMediaPlayer` + 素の `QVideoSink` からフレームを
1 枚ずつ画像化する」だったが、それだとホバーのたびに 4K フレームを CPU へ読み戻して縮小することになる。
実装（`SeekBarPreview.qml`）では次のようにした:
- 2 つ目の `MediaPlayer` を**一時停止のまま**、プレビュー枠内の小さな `VideoOutput` に直接描画させる。
  フレームは GPU テクスチャのままシーングラフで縮小され、CPU への読み戻しは無い（Performance rules 1）。
  一時停止中のプレイヤーは `position` を変えるとその位置のフレームを描画する。
- 音声・字幕トラックは `activeAudioTrack` / `activeSubtitleTrack` = -1 で無効化。
- **遅延オープン**: メディアを開いた時点ではなく、最初のホバーでプレビュー側を開く。ストリームを
  二重に取得するのはプレビューを実際に使ったときだけになる。メインのソースが変わったら閉じる。
- シーク不可、または `duration` が 0（ライブ配信）のときはプレビューを出さない。
- ホバー位置 → 時刻の変換はハンドル中心の式（`SeekBar.positionAt`、A-B マーカーの `markerX` の逆）。
- ToyBoxx の 1/4 解像度デコードに相当する API は Qt に無い。HW デコードなのでフル解像度でも問題なかった。

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
- 保存先はレジストリではなく **`%APPDATA%\ToyFoxx\ToyFoxx.ini`**（`main.cpp` で
  `QSettings::setDefaultFormat(QSettings::IniFormat)`。QML の `Settings` もこれに従う）。
- 保存タイミングは終了時ではなく**値の変更時**（2026-09-27 決定）。複数起動時は最後の変更が残る
  （Last Write Wins）。INI への書き込みは QSettings がロックとマージを行う。
- ループ・音量・ミュートは `Main.qml` の `Settings`（カテゴリ `Playback`）。ループは `bool`。
- ウィンドウ位置とサイズは `WindowGeometry.qml`（カテゴリ `Window`、`x` / `y` / `width` / `height` の整数。
  `rect` 型だと INI に `@Variant` のバイナリ表記で書かれるため）。通常状態のときだけ、300ms 遅らせて保存する
  （最大化の瞬間はジオメトリ変化が状態変化より先に届きうる）。最大化状態そのものは保存しない（ToyBoxx と同じ）。
- 起動時は `ScreenGeometry.fitToAvailableScreens`（C++）で、最も重なるスクリーンの作業領域に収めてから表示する。
  収める対象はクライアント領域。F-23 でネイティブのキャプションを外したので、クライアント領域とウィンドウの
  見た目の矩形はほぼ一致し、「タイトルバーが画面外に出る」問題は起きなくなった。

以下は ToyBoxx の当初仕様（保存タイミングはウィンドウクローズ時）。マルチモニタ構成で画面外に復元されないよう、
利用可能なスクリーン矩形に収める補正を入れる（ToyBoxx には無い）。

### F-21 テーマ

- ToyBoxx は `appsettings.json` の `ApplicationTheme` で `Dark` / `Light` / `HighContrast` を選び、
  WPF-UI の `ApplicationThemeManager` に適用する。UI からは切り替えられない。
  `appsettings.user.json` による上書きも可。
- ToyFoxx は**対応しない**（2026-09-27 に決定）。テーマはダーク固定で、切り替えの設定も
  自前のテーマシングルトンも作らない。Light / HighContrast も実装しない。
- `main.cpp` で `QStyleHints::setColorScheme(Qt::ColorScheme::Dark)` を指定し、OS の配色設定に
  関係なくダークで表示する（FluentWinUI3 は指定が無いと OS の設定に従う）。

### F-22 全画面中のスリープ抑止

- ToyBoxx は全画面に入るときに `SetThreadExecutionState(ES_DISPLAY_REQUIRED | ES_CONTINUOUS)`、
  出るときに `ES_CONTINUOUS` に戻す（**再生中ではなく全画面中**が条件）。
- ToyFoxx でも同じ Win32 API を `platform/` の小さなラッパー（`DisplayKeepAwake`）で呼ぶ。
- **条件は「映像の再生中」**（2026-09-27 決定。`player.playing && player.hasVideo`）。ウィンドウ表示でも
  画面が消えず、一時停止・停止すれば通常どおり消える。フラグは `ES_DISPLAY_REQUIRED | ES_SYSTEM_REQUIRED`
  （ToyBoxx はディスプレイのみ）。音声のみのメディアでは抑止しない。
- 実機での動作確認（`powercfg /requests` は管理者権限が必要）は未実施。完了扱いにしている。

### F-23 カスタムタイトルバー

ToyBoxx:
- `FluentWindow` のクライアント領域がタイトルバーの位置まで広がっており、映像はウィンドウの最上端から
  表示される。WPF-UI の `TitleBar`（アイコン + タイトル + 最小化 / 最大化 / 閉じる）はその上に
  **重ねて**描画される（`MainWindow.xaml`、`Grid` の最後の子）。
- 自動非表示の対象はコントローラーパネルだけで、**タイトルバーは常に表示**されている
  （`MainWindow.xaml.cs` のアニメーションのターゲットは `ControllerPanel` のみ）。

ToyFoxx（2026-09-27 に要望。当初の「OS 標準の枠で十分」から方針変更）:
- **QWindowKit**（Apache-2.0、`QWindowKit::Quick`）でネイティブのキャプションを外し、クライアント領域を
  ウィンドウ上端まで広げる。映像（`VideoSurface`）はその全面に敷き、自前の `CaptionBar.qml`
  （アイコン・タイトル・システムボタン 3 つ）を映像の上に重ねる。
- 参考実装: `../MegaExplorer` の Phase 17a（`qml/components/CaptionBar.qml`、`qml/Main.qml`、
  `docs/investigations/STUDY_TITLEBAR_TABS.md`、`docs/PROGRESS.md` の Phase 17a 節）。
  素の `Qt.FramelessWindowHint` + `startSystemMove` では、スナップレイアウトのフライアウト・DWM の
  最小化アニメーション・影・角丸・8 方向リサイズが失われるため、QWindowKit を選んでいる。
- MegaExplorer で踏んだ点（そのまま当てはまる）:
  - `third_party/qwindowkit` にサブモジュールとしてタグ固定（1.5.0）。`BUILD_QUICK=ON` /
    `BUILD_WIDGETS=OFF` / `BUILD_STATIC=ON` / `INSTALL=OFF`。入れ子のサブモジュールがあるので
    `--recursive` が必要。Qt の private モジュールに依存する。
  - QML 型は `QWK::registerTypes` ではなく `QML_FOREIGN` のヘッダで `ToyFoxx` モジュールに登録し、
    `qmllint` / `qmlcachegen` から見えるようにする。
  - `setTitleBar` / `setSystemButton` は `setup()` より後に呼ぶ必要がある（順序を誤るとクラッシュ）。
  - 表示した瞬間にキャプションの高さ（約 31px）ぶんウィンドウが伸びる。F-20 でサイズを保存すると
    起動のたびに大きくなるので、表示直後にサイズを書き戻す。
  - システムボタンは `setSystemButton` で登録しないとスナップレイアウトが出ない。
- **実装（2026-09-27）**:
  - `third_party/qwindowkit`（タグ 1.5.0、静的リンク）。MegaExplorer と同じ CMake オプション。
  - MegaExplorer の `QML_FOREIGN` による登録は、QWindowKit がメタタイプを出力しないため qmllint から
    型が見えない（MegaExplorer でも生成された qmltypes に exports が無い）。`qt_extract_metatypes` は
    ターゲットと同じ CMake ディレクトリでないとビルド規則が生成されず、サブモジュールは書き換えたくない。
    そこで C++ の `FramelessWindow`（`src/platform/`）で包み、`attach(window, titleBar, 最小化, 最大化,
    閉じる)` の 1 呼び出しにした。登録順の制約（`setup()` が先）もこの中で固定される。
  - `CaptionBar.qml`: タイトル + システムボタン 3 つ（Segoe Fluent Icons）。高さ 32。映像の上に重ね、
    パネルと同じ `shown` でフェードする。全画面中は出さない。
  - キャプション上のホバーは `CaptionHoverTracker`（`src/platform/`）が `WM_NCMOUSEMOVE` /
    `WM_NCMOUSELEAVE` をネイティブイベントフィルタで見て補う（`TrackMouseEvent` の `TME_NONCLIENT`）。
    ポーリングはしない。
  - 表示した瞬間にネイティブキャプションの高さぶんクライアント矩形が上へ動く（サイズではなく**位置**が
    ずれ、起動のたびに y が 31px ずつ上がった）。表示直後に復元した位置とサイズの両方を書き戻す。
  - 枠を外した後も `QSG_INFO` で FLIP_\* スワップチェーン（legacy = false）を確認済み。
  - 自動非表示の仕組みとキャプション・パネル・トーストは `WindowChrome.qml` にまとめた。
  - **既知の粗さ**: 最大化中に映像をダブルクリックして全画面にし、もう一度ダブルクリックして戻ると、
    一瞬通常サイズが見えてから最大化に戻る。Qt / Windows が全画面 → 最大化を通常状態経由で行うため。
    直すには全画面を自前実装する必要があり、見送り。
- ToyFoxx 固有の検討事項（実装前のメモ）:
  - **性能の確認が必須**: フレームレス化の前後で、`QSG_INFO` の D3D11 + FLIP_\* スワップチェーンが
    維持されていること、全画面 4K60 のフレーム時間が悪化しないことを確かめる（Performance rules 7）。
  - 全画面（`Window.FullScreen`）との組み合わせ。QWindowKit 下で全画面の出入りとタスクバーの
    扱いが正しいか確認する。全画面中はキャプションを出さない。
  - **タイトルバーは F-10 の自動非表示にパネルと一緒に含める**（2026-09-27 決定。ToyBoxx は常時表示
    なので挙動差になる。§3 に記載）。同じ `controlsShown` で `opacity` をフェードし、消えている間は
    キャプションも出さない。マウスを動かせば戻るので、隠れている間にウィンドウを動かせなくても困らない。
  - 自動非表示にするうえでの要確認点:
    - キャプション上は OS が `WM_NCHITTEST` で `HTCAPTION` を返す非クライアント領域になるため、
      Qt Quick の `HoverHandler` にはマウス移動が届かず、**ウィンドウから出たと判定される可能性が高い**。
      そのままだとキャプションに乗った瞬間にキャプションが消える。キャプション上の移動も操作として
      扱う仕組み（`WM_NCMOUSEMOVE` を拾う C++ のネイティブイベントフィルタを `platform/` に置き、
      `controllerPanel.busy` と同様に扱う、など）が要る。
    - キャプションを `visible: false` にしたとき、QWindowKit がその領域を引き続きキャプションとして
      ヒットテストするか。するなら、隠れている間は映像上のダブルクリック（全画面）がそこで効かない。
  - キャプション部分は OS がドラッグ移動・ダブルクリック最大化を処理する。映像上のダブルクリック
    （全画面トグル）とは領域で住み分ける。
  - キャプション左端のアイコンは `toyfoxx.svg` を 16px で表示している。

### F-24 エラー表示

- ToyBoxx はメディアオープンの例外を Snackbar で出す（`Media Failed: <型>\n<メッセージ>`）。
  プレビュー側の失敗は黙って無視する。
- ToyFoxx では `MediaPlayer.onErrorOccurred` で `error` / `errorString` を拾い、
  F-18 のトーストで表示する。プレビュー側の失敗は無視する。
- 実装: タイトル `Media failed: <種別>`（resource error / unsupported format / network error /
  access denied）、本文は Qt の `errorString`。`console.warn` にも残す（`Main.qml` の `mediaErrorName`）。
- 確認: ランダムなバイト列の `.mp4` を開くと `FormatError` / "Could not open file" になる。テキストファイルは
  FFmpeg が何らかの形式として開いてしまい、エラーにならない。

### F-25 A-B 区間の書き出し（ToyFoxx で追加）

ToyBoxx には無い機能。

- `T` キーで、有効な A-B ループ（F-14）の区間を **ビデオフォルダ**（`QStandardPaths::MoviesLocation`）へ
  MP4 で書き出す。A-B が未設定・開始点のみのときはトーストで案内する。
- ファイル名: `<タイトル>_<yyyyMMddHHmmsszzz>.mp4`（F-17 と同じ規則。`src/app/FileNames`）。
- **無劣化ではなく、区間ぴったりに切る**（ユーザー判断）。ストリームコピーだと開始点がキーフレームに
  丸められるため、映像は A 直前のキーフレームからデコードし、A〜B を再エンコードする。
  - 先頭の GOP だけ再エンコードする「スマートカット」は採らない。Qt 同梱の FFmpeg の映像エンコーダーは
    Media Foundation（`h264_mf` / `hevc_mf`）だけで、元の SPS/PPS に合わせられない。VP9 / AV1 の
    エンコーダーも無い。
  - 映像: H.264 High（MF。GPU ベンダーの MFT があれば HW、無ければ Microsoft のソフトウェア実装）。
    H.264 の最大フレームサイズ（36864 MB、4096x2304）を超えるときは HEVC Main。
    ビットレートは元の 1.25 倍、下限 約 0.08 bit/pixel（1080p30 で 5 Mbps、2160p60 で 40 Mbps）。
    GOP 2 秒。回転メタデータ（display matrix）と色情報は引き継ぐ。
  - **10bit / HDR は 8bit になる**（MF のエンコーダーが NV12 / Main のみ）。HDR のタグは残るが 8bit PQ。
  - 音声: プレイヤーが選ぶのと同じ最良のトラック 1 本。AAC / MP3 / AC-3 / E-AC-3 / Opus / FLAC / ALAC は
    パケットのままコピー（先頭パケットのはみ出しは MP4 の edit list で隠れる）。それ以外（Vorbis / MP2 /
    PCM / DTS など）は AAC に再エンコードし、サンプル単位で切る。
  - 字幕・その他のストリームは捨てる。
- 開始点は「A の時点で画面に出ているフレーム」（A 以前で最後のフレーム）から。終了点は B 未満の最後のフレーム
  まで。位置は Qt と同じく `AVFormatContext::start_time` 起点（Qt の `toTrackPosition` と同じ換算）。
- MPEG-TS などは後方シークしてもキーフレームに着地しないため、デコードした最初のフレームが A より
  後ならシーク位置を 1 秒、2 秒、4 秒…と戻して探り直す。
- 書き出しはスレッドプールで行い、進捗（%）とキャンセルボタンをトーストの位置に出す。完了・失敗・
  キャンセルはトーストで通知し、完了トーストのクリックでエクスプローラーを開く。キャンセル・失敗時は
  途中のファイルを消す。アプリ終了時は書き出しをキャンセルする。
- デコーダーのスレッド数はコア数の半分（同じプロセスの再生に残す）。デコードは CPU なので、4K の書き出し中は
  再生が重くなりうる。書き出しは再生経路とは独立しており、Performance rules には触れない。
- 実装: `src/media/SegmentTranscoder`（FFmpeg 処理、ブロッキング）、`src/media/SegmentExporter`（QML 型、
  スレッドプール・進捗・キャンセル）、`SegmentExport.qml` / `ExportProgress.qml`。FFmpeg のヘッダー取得と
  インポートライブラリ生成・遅延ロードは `cmake/FFmpeg.cmake`（CLAUDE.md の Requirements 参照）。
  Qt 更新で FFmpeg の DLL 名が変わった場合、アプリは起動し、書き出しだけが失敗を報告する。
- 確認（2026-09-27、ffmpeg で生成したクリップ、A=3.370 s / B=7.810 s）: MP4 H.264+AAC（B フレームあり）、
  MKV HEVC 10bit+Opus、WebM VP9+Vorbis、MPEG-TS H.264+MP2（start_time 11.39 s）、回転付き MP4 で、
  出力の先頭・末尾フレームが元の該当フレームと一致（PSNR 44〜55 dB）、音声長も一致。4K60 H.264 の
  10 秒区間は約 10 秒（NVIDIA MFT）、5K は HEVC で出力。キャンセル時の途中ファイル削除も確認。
  同日、実機（アプリ上の `T`・進捗・キャンセル・トースト）でも確認済み。

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
| 音量スライダー | パネルに常時表示の横スライダー | ミュートボタンのホバーで縦スライダーをポップアップ |
| スリープ抑止の条件 | 全画面中 | 映像の再生中（ウィンドウ表示でも） |
| コマ送りボタンの活性条件 | 一時停止中のみ | 再生中も押せ、押すと一時停止してから進む |
| タイトルバー | 常時表示 | コントローラーパネルと一緒に自動非表示 |
| 90° / 270° 回転時の表示 | はみ出す | ウィンドウに収める |
| スクリーンショットのタイムスタンプ | 12 時間制（`hh`） | 24 時間制 |
| DI | `Microsoft.Extensions.Hosting` | 使わない |
| ウィンドウ位置の復元 | 無条件に復元 | スクリーン矩形内に収める |
| 設定の保存 | 終了時に `Properties/Settings`（user.config） | 変更時に `%APPDATA%\ToyFoxx\ToyFoxx.ini` |
| A-B 区間の書き出し | 無し | `T` で MP4 に書き出す（F-25） |

## 4. 未決事項

- コマ送りの精度をどこまで追い込むか（`position` 加算の近似で妥協するか、`QVideoSink` を使って
  フレーム単位で制御するか）。後者は Performance rules と衝突しうるので慎重に。
- `CanPause` / `IsSeeking` / `IsChanging` に相当する状態を QML 側でどこまで作り込むか。

## 5. 人間側の作業待ち

コードでは解決できず、判断か実機作業が必要なもの。

- **4K テスト動画と計測ベースライン** — `CLAUDE.md` の Baseline に挙げた項目を、置き換え前の
  ToyBoxx で同じ動画・同じ PC について記録しておく必要がある。これが無いと改善を判断できない。
  解像度 / fps / コーデック / ビット深度も控えること。
- **`playback-performance.md` をこのリポジトリに複製するか** — 現状は前身リポジトリ参照のみ。

## 6. 進捗メモ

- `develop` ブランチで作業中。
- 実装済み: F-02 / F-03 / F-05 / F-06 / F-07 / F-08 / F-12、F-04 と F-09 の一部。Qt 6.11.1 + MSVC 14.44 でビルド・
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
- ウィンドウタイトルの導出（F-08）は `MediaSource.displayTitle()`（C++）。F-17 のファイル名でも使う。
- F-10 は 150ms ポーリングではなく、ウィンドウ全体の `HoverHandler` の移動イベントで 3 秒タイマーを
  再始動する方式。パネル上にいる間と速度ポップアップ表示中は隠さない。
- キーボードショートカット（F-11）は `Shortcut`（ウィンドウ単位）なので、フォーカスを戻す処理は不要。
- 区間ループ（F-14）の状態は非表示コンポーネント `SegmentLoop.qml`。位置監視の `Connections` は有効中だけ
  接続する。終了点が動画末尾と重なる場合に備え、`EndOfMedia` でも開始点へ戻す。
- コマ送り（F-15）は `metaData` の `VideoFrameRate`（無ければ 30fps とみなす）から 1 フレーム分シークする。
  実機確認で 1 コマずつ進み、連打・長押し（`autoRepeat`）とも問題なし。
- ズーム系（F-16）は `VideoSurface.qml`。`VideoOutput` の `scale` / `rotation` / `x` / `y` のみで行い、
  親の `clip`（シザー）ではみ出しを切る。ダブルクリック・中クリック・パン・`Ctrl`+ホイールは同ファイルの
  ハンドラで受ける。
- スクリーンショット（F-17）は C++ の `ScreenshotSaver`（`src/media/`）。`QVideoSink` を QML から受け取り、
  GUI スレッドで `toImage()` を 1 回だけ呼び、PNG のエンコードと書き込みはスレッドプールで行う。
  トーストのクリックは `ShellIntegration.revealInExplorer`（`src/platform/`、`SHOpenFolderAndSelectItems`）。
- キーボードショートカットは `KeyboardShortcuts.qml` に集約している。
- ビルドフォルダに `windeployqt` を実行済みだと、アプリは `build/qml` だけを見る。新しい QML モジュールを
  import したら（例: `QtCore`）`windeployqt` を再実行しないと「モジュールがインストールされていない」で起動に失敗する。
- **コードレビュー（2026-09-27、qt-qml-review / qt-cpp-review をサブエージェントで実行）** の後始末:
  - 修正済み: 自動非表示タイマーの再始動漏れ、速度ポップアップをボタンで閉じられない、フェード時間の
    評価順依存、スクリーンショット保存中の終了時の競合、診断モニタの終了時の競合、コマンドライン引数の
    `file:` URL、タイトル切り詰めでのサロゲートペア分断。
  - **計測待ち**: シークバーのドラッグ中は移動のたびにシークしている（`SeekBar.qml` の `onMoved`）。4K の
    長 GOP 素材でドラッグが引っかかるようなら、100ms 程度に間引いて離したときにもう一度シークする。
  - 対応しない: プレビューの時刻表示が映像より先に変わる（意図した挙動）。
- 自動非表示は、Qt Quick が静止カーソル位置で合成ホバーを毎フレーム配り直すため、`HoverHandler.point` の
  変化ではなく 1px 以上の実移動だけを操作とみなしている（`WindowChrome.qml`）。
- ファイルダイアログは削除した。必要になれば `Ctrl`+`O` のショートカットだけで復活させる案がある（未依頼）。
- **リリース準備（2026-09-27）**: ライセンスは MIT（`LICENSE`）。配布 zip は `scripts/package.ps1`、
  公開は `/release` スキル（`.claude/skills/release/SKILL.md`）。初回は `CMakeLists.txt` の 0.1.0 を
  そのまま出す予定で、**まだ一度もリリースしていない**（タグ無し、`master` は未更新）。ユーザーが
  しばらく自分で使ってから `/release` を打つ。
  - zip（約 55 MB）には、使っていない Controls スタイル（Material / Universal / Fusion / Imagine）、
    `Qt6Pdf` と `qpdf`、`opengl32sw.dll`、WMF の `windowsmediaplugin` も入っている。ライセンス上は
    問題なく、容量を減らしたくなったら `package.ps1` の検査を保ったまま除外を足す。
- 次の着手候補: **試用のフィードバック** → `/release` → **4K 実測** → F-01 の残り。
