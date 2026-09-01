# herdr-mode

Herdrのprefixを毎回押さず、kittyのkeyboard modeで一時的な操作モードへ入る参考実装です。完成品のインストーラーではありません。

prefix が `Ctrl+;` なら、通常は次のようになります。

```text
Ctrl+; → h
Ctrl+; → j
Ctrl+; → k
Ctrl+; → l
```

herdr-mode では次のようになります。

```text
Ctrl+;        # モードへ入る
h / j / k / l
...
Esc           # 抜ける
```

通常時はpane内アプリへキーを渡し、モード中だけ1キーでHerdrを叩きます。Herdr本体の置き換えではなく、Terminalが prefix+キー を送るだけです。

## 自分のキーで試す

このリポジトリのキーマップは作者の設定です。Herdrデフォルト（`ctrl+b` など）ではありません。

`~/.config/herdr/config.toml` とこのリポジトリをAIへ渡し、「prefixとキーはそのままで、同じモード遷移を自分のTerminalへ合わせて」と頼んでください。

Herdr側では次の設定が必要です。

```toml
[ui]
window_title = "herdr:{workspace}"
```

対象は Herdr 0.8.2以降と、keyboard modeを使える現行版のkittyです。

## 仕組み

- kitty は `integrations/kitty/herdr-mode.conf`
- ロゴは任意で `integrations/kitty/herdr-mode-logo.conf`

prefixは各ファイル先頭にあります。モード中の `h` は `prefix` に続けて `h` を送るだけです。

copy / selection / resize は入れ子です。未知キーはpaneへpassthroughします。

WezTermでもkey tableを使えば同様の操作モードを構成できると考えられますが、このリポジトリでは実装例を提供しません。

## Herdr logo

モード中のインジケーターとして使うことがあります。このプロジェクトのブランドロゴではありません。

> Herdr logo © Herdr contributors, licensed under Apache-2.0. Modified for visibility.

元画像は [herdr v0.8.0 `assets/logo.png`](https://github.com/herdrdev/herdr/blob/v0.8.0/assets/logo.png) です。暗い背景向けに配色を変えています。詳細は `NOTICE`。

## License

Apache License 2.0
