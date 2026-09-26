---
name: release
description: >-
  Cut a ToyFoxx release: fast-forward master to develop, bump the minor
  version, build and package the Release zip, tag it, push, and create the
  GitHub release with gh. `/release 0.3.0` overrides the version. Only when
  the user types /release.
disable-model-invocation: true
---

# /release — リリースを 1 本出す

`develop` の今の状態を `master` に取り込んで出す。**`/release` を打ったこと自体が `master` への
push、タグの push、GitHub 公開の指示**なので、途中で承認は取らない（CLAUDE.md の「`master` への
push の前に確認」はこのスキルでは適用済み）。何かが失敗したらそこで止まって報告する。

## 1. 前提確認（1 つでも欠けたら何もせずに理由を言って終わる）

```
git rev-parse --abbrev-ref HEAD                     # develop
git status --porcelain                              # 空（未追跡の .mcp.json だけは無視してよい）
git fetch origin --tags
git rev-list --count HEAD..origin/develop           # 0（origin が先行していない）
git merge-base --is-ancestor origin/master HEAD     # 成功（master を fast-forward できる）
python scripts/gen_third_party_notices.py --check   # up to date
```

`HEAD` が `origin/develop` より先行しているのはよい（そのコミットごと出る）。`master` に
`develop` に無いコミットがあったら fast-forward できないので、止まって報告する（勝手に merge
コミットを作らない）。

## 2. 版を決めて上げる

- 引数があればそれ（`v` 付きなら剥がす）。
- 無ければ最新タグ（`git describe --tags --abbrev=0`）の **MINOR を 1 上げ、PATCH を 0**
  にする（`v0.2.0` → `0.3.0`）。
- **タグが 1 つも無い（初回）なら、`CMakeLists.txt` の版をそのまま出す**（まだ一度も出して
  いない版なので上げる理由がない）。

`git tag -l vX.Y.Z` が空、`gh release view vX.Y.Z` が not found であることを確かめる。

版を変えるときは、`develop` 上で `CMakeLists.txt` の `project(ToyFoxx VERSION ...)` を書き換えて
コミットする。ここが唯一の版の在処で、`--version` の表示も zip 名もここから出る。
`THIRD-PARTY-NOTICES.txt` にはアプリの版を書いていないので、版を上げても再生成は要らない。

```
git add CMakeLists.txt
git commit           # Subject: Bump the version to X.Y.Z（trailer は他のコミットに合わせる）
```

## 3. パッケージ

PowerShell から:

```
./scripts/package.ps1
```

`build-release/` に Release ビルド → QML lint → CPack の zip → 中身の検査（Qt・FFmpeg・QML
モジュール・MSVC ランタイム・ライセンス 2 点が揃い、GPL 専用の Qt Quick 3D / Timeline と
`qmltooling` が入っていないこと）→ zip を一時ディレクトリに展開し、Qt を `PATH` から外して起動、
ウィンドウが出ることの確認、までをこのスクリプトがやる。起動確認で ToyFoxx のウィンドウが
数秒開いて閉じることを、実行前にユーザーへ一言伝える。**手で zip を作らない**（検査が抜ける）。
出来上がりは `build-release/package/ToyFoxx-X.Y.Z-win64.zip`。**zip 名の版が 2. の版と一致して
いるか見る。**

## 4. master へ取り込み、タグ、push、公開

```
git checkout master
git merge --ff-only develop
git tag -a vX.Y.Z -m "ToyFoxx X.Y.Z"
git push origin develop master
git push origin vX.Y.Z
gh release create vX.Y.Z --verify-tag --title "vX.Y.Z" \
    --notes "<1〜2 行>" build-release/package/ToyFoxx-X.Y.Z-win64.zip
git checkout develop
```

リリース文は**英語で 1〜2 行**。前のタグからの `git log --oneline` を眺めて、ユーザーに見える
変化を一言で書く（初回なら "First release." 程度）。内部の変更しかなければ
"Minor fixes and internal changes." でよい。`--draft` / `--prerelease` は指示されたときだけ。

最後に必ず `develop` に戻しておく（作業ブランチは `develop`）。

## 5. 報告

リリース URL、zip 名とサイズ、含まれるコミット数を 2〜3 行で。

## 途中で落ちたとき

push より前ならローカルだけなので戻せるが、**戻す操作（`git tag -d`、`git reset --hard HEAD~1`、
`master` を元の位置に戻す操作）は実行前に見せて確認を取る。** push した後に問題が見つかったら、
タグや release を消さずに次の版を出すのが既定。
