# herdr-mode

Herdrを、毎回prefixを入力せずに操作するためのTerminal側モーダルキーバインディングです。

通常のHerdrでは、pane移動なら次のように操作します。
（prefixキーが `Ctrl+;` の場合）

```text
Ctrl+; → h
Ctrl+; → j
Ctrl+; → k
Ctrl+; → l
```

`herdr-mode` では、一度モードに入ればその後は直接操作できます。

```text
Ctrl+;        # Herdr modeへ入る
h / j / k / l
h / j / k / l
...
Esc           # 通常のTerminal操作へ戻る
```

## Motivation

Terminal multiplexerのprefixは、pane内で動くShell・Neovim・TUIなどとのキーバインド競合を避けるための優れた仕組みです。

一方で、pane移動やresizeのような連続操作では、その都度prefixを入力するのは少し面倒です。

かといってHerdrの操作を常にprefixなしで割り当てると、ShellやNeovimなどが使用するキーと競合します。

`herdr-mode` では、Terminal側に一時的なHerdr専用モードを作ることで、

- 通常時はpane内アプリへキーをそのまま渡す
- Herdrを操作したいときだけ専用モードへ入る
- モード中はVimライクな1キー操作を使う

という形で両者を分離します。

Herdr本体の操作体系を置き換えるものではありません。外側のTerminalがキーを変換し、既存のHerdrキーバインディングへ入力を送る薄いintegrationです。

## Compatibility

| 対象 | バージョン |
| --- | --- |
| Herdr | 0.8.2 以降（`ui.window_title` が必要） |
| kitty | keyboard mode を使える現行版 |
| WezTerm | key table を使える現行版 |

Herdrのデフォルトprefixは `ctrl+b` です。このリポジトリのキーマップは `ctrl+semicolon`（`Ctrl+;`）を前提にしています。変更する場合は、Herdr側とTerminal側の両方を揃えてください。

## Install

```bash
git clone https://github.com/riii111/herdr-mode.git
cd herdr-mode
./install.sh kitty          # または wezterm / kitty wezterm
```

ロゴインジケーターを使わない場合は `--no-logo` を付けます。

```bash
./install.sh --no-logo kitty
```

`install.sh` は既存設定を置き換えません。

- kitty: `~/.config/kitty/` へsymlinkし、`kitty.conf` へ include ブロックだけを追加します。再実行してもブロックは1つだけです。
- WezTerm: `~/.config/wezterm/herdr_mode.lua` へsymlinkします。`wezterm.lua` は自動編集しないので、次のsnippetを `return config` の前へ追加してください。

```lua
local herdr_mode = require("herdr_mode")
config.keys = config.keys or {}
config.key_tables = config.key_tables or {}
herdr_mode.install(config.keys, config.key_tables)
```

すでに `config.keys` を別モジュールで組み立てている場合は、そのtableを `install()` へ渡してください。

削除:

```bash
./uninstall.sh kitty        # または wezterm / kitty wezterm
```

herdr-modeが追加したincludeブロックとsymlinkだけを外します。WezTermの `require` 行は手で削除してください。

## Herdr config

`examples/herdr-config.toml` を `~/.config/herdr/config.toml` へマージしてください。必須なのは次の2点です。

```toml
[keys]
prefix = "ctrl+semicolon"

[ui]
window_title = "herdr:{workspace}"
```

kittyはウィンドウtitleが `herdr` で始まるときだけモードへ入ります。WezTermは前景プロセス名が `herdr` の場合、またはpane titleが `herdr` で始まる場合に入ります。

残りの `[keys]` は、このリポジトリが送る1キー操作と揃えるための例です。Herdrのデフォルト割当とは異なります。

## Operations

```text
Herdr mode
├── copy mode      (v)
├── selection mode (Space または g)
└── resize mode    (r、または Shift+h/j/k/l)
```

| キー | 動作 | モード |
| --- | --- | --- |
| `Ctrl+;` | Herdr modeへ入る / 抜ける | 通常 ↔ Herdr |
| `Esc` | 1つ上のモードへ戻る | 各モード |
| `h` `j` `k` `l` | pane移動 | Herdr |
| `r` のあと `h` `j` `k` `l` | pane resize | resize |
| `[` `]` | 前後のtab | Herdr |
| `{` `}` | 前後のworkspace | Herdr |
| `,` `.` | 前後のagent | Herdr |
| `1`–`9` | workspace 1–9 | Herdr |
| `p` / `Shift+d` | 縦 / 横 split | Herdr |
| `t` `w` | 新しいtab / workspace | 実行後に抜ける |
| `v` | copy mode | copy |
| `Space` `g` | picker / goto | selection |
| `z` | zoom | Herdr |

copy / selection / resize の入れ子も維持します。たとえばresize中は `h/j/k/l` を連続入力でき、`Esc` または `r` でHerdr modeへ戻ります。`Ctrl+;` はネストしたモードからもまとめて抜けます。

未定義キーは、kittyではpane内アプリへpassthroughします。WezTermのkey tableは未定義キーでtableを抜けることがあるため、READMEの制約を見てください。

## How it works

kittyでは keyboard mode、WezTermでは key table を使います。モード中の `h` は、Terminalが `Ctrl+;` に続けて `h` をHerdrへ送るだけです。Herdr内部の状態機械は使いません。

prefix値は各integrationの先頭に集約しています。

- kitty: `action_alias herdr_send_prefix`
- WezTerm: `PREFIX` / `PREFIX_KEY` / `PREFIX_MODS`

## Constraints

- Herdr 0.8.2未満では `ui.window_title` がないため、kittyのtitle判定が動きません。
- prefixを変えるときは、Herdrの `[keys].prefix` とintegration先頭の定義、kittyの `ctrl+;` mapキーを揃えてください。
- kittyのロゴ表示には `remote_control` が必要です。例: `allow_remote_control socket-only`
- WezTermは未知キーをpassthroughしつつkey tableに留まる、というkitty同等の指定がありません。未割り当てキーはHerdr modeを終了することがあります。
- WezTermのタブ着色などは呼び出し側で `herdr_mode.styles` と `active_mode_for_tab()` を使う任意機能です。無効化は `install(..., { indicator = false })` です。

## Status

dotfilesから独立したOSSとして切り出した初期リリースです。APIやキーマップ、インストール方法は今後変わる可能性があります。

## Herdr logo

モード中であることを示す視覚的インジケーターとして、Herdrのロゴを使う場合があります。

Herdrのロゴはこのプロジェクト自身のブランドやロゴではありません。

> Herdr logo © Herdr contributors, licensed under Apache-2.0. Modified for visibility.

元画像は [herdr v0.8.0 `assets/logo.png`](https://github.com/herdrdev/herdr/blob/v0.8.0/assets/logo.png) です。暗い背景で見分けやすいよう配色を調整しています。詳細は `NOTICE` を参照してください。

無効化:

```bash
./install.sh --no-logo kitty
```

```lua
herdr_mode.install(config.keys, config.key_tables, { indicator = false })
```

## License

Apache License 2.0
