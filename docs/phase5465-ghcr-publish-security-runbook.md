# #5465 GHCR publish security setup runbook

このファイルは Redmine #5465
「GHCR publish 用の権限・CircleCI Context・main protection を準備する」
の手動作業と検証順序を固定するための runbook です。

## 重要な制限

- このチケットでは GHCR へ image を push しません。
- 本物の GHCR PAT をまだ CircleCI Context に登録しません。
- image build / publish の実装変更は行いません。
- `main` に対して force push / delete の probe を行いません。
- secret value を Redmine、Git、CI log に記録しません。
- CircleCI Organization Administrator は Context restriction の trusted bypass actor として扱います。

## 1. GHCR package name を確認する

候補:

```text
ghcr.io/docker-images-mamono210/ai-agents/codex
```

確認事項:

- 同名 package が既に存在しないこと。
- 意図しない既存 version / artifact が存在しないこと。
- 採用した完全な package name を #5465 journal に記録すること。

この段階では target package を作成しません。

## 2. Dedicated publish account を準備する

条件:

- GitHub Organization owner ではない。
- 人間の日常操作用 account と共用しない。
- CI publish 専用とする。

次を確認して記録します。

- GitHub login
- Organization role
- Organization base permission
- repository permission
- repository-linked package の permission inheritance
- 既存 package への effective write access
- Organization の package creation policy
- member が作成できる package visibility / 種類

Codex publish に不要な production package を変更できる account は採用しません。

## 3. PAT policy だけを確定する

このチケットでは PAT を発行しません。

方針:

- classic PAT
- `write:packages`
- `delete:packages` なし
- 不要な `repo` scope なし
- expiration あり
- rotation owner / rotation procedure を記録

PAT の実発行は #5467 の allow probe 成功後です。

## 4. CircleCI integration type を確認する

CircleCI project の integration type と利用可能な Pipeline Values を実測します。

`pipeline.config.ref` が利用可能なら Context expression は次です。

```text
pipeline.git.branch == "main"
and pipeline.config.ref == "refs/heads/main"
and not job.ssh.enabled
and not (pipeline.config_source starts-with "api")
```

利用できない場合:

```text
pipeline.git.branch == "main"
and not job.ssh.enabled
and not (pipeline.config_source starts-with "api")
```

存在しない Pipeline Value を expression に追加しません。

## 5. Dedicated Context を作成する

Context 名:

```text
codex-ghcr-publish
```

設定:

- 対象 CircleCI project への project restriction
- 前項で確定した expression restriction

この段階では本物の PAT を入れません。

dummy secret のみ登録します。

推奨名:

```text
GHCR_PUBLISH_PROBE
```

値は非機密の marker で構いません。値そのものを CI log に表示しないでください。

## 6. Deny probe を実行する

この ZIP の `.circleci/config.yml` には一時的な probe job が含まれています。

専用 branch:

```text
5465-context-deny-probe
```

で実行します。

期待結果:

- `context-deny-probe` job は CircleCI により `Unauthorized` となる。
- job step は1つも開始されない。
- Docker login / GHCR access / push は発生しない。

### 失敗判定

もし job が実行され、次のいずれかが log に出た場合は Context restriction が効いていません。

```text
SECURITY_CONTROL_FAILURE=probe_variable_missing
SECURITY_CONTROL_FAILURE=publish_context_accessible_on_denied_branch
```

この場合は #5465 を完了扱いにせず、Context restriction を修正してください。

### Probe principal

Organization Administrator ではない principal で実行します。

probe のためだけに publish account へ repository write 権限を追加しないでください。
必要なら別の非管理者検証 account を使い、一時権限は probe 後に外します。

## 7. Fork / public repository protection を確認する

repository は public です。

fork 由来の PR / pipeline に project secret や publish Context を渡さない CircleCI project 設定であることを確認します。

これは Context expression restriction とは別の防御として記録します。

## 8. Main Ruleset A を作成する

目的: main update authorization。

設定:

- target: `main`
- `Restrict updates`
- bypass actor を明示

記録:

- actor
- actor type
- bypass mode
- 用途

## 9. Main Ruleset B を作成する

目的: main history immutability。

設定:

- target: `main`
- `Block force pushes`
- `Restrict deletions`
- bypass actor なし

Ruleset A の bypass actor も Ruleset B を bypass しない構成にします。

## 10. Ruleset probe は一時 branch で行う

`main` に destructive probe をしません。

例:

```text
ruleset-probe
```

この branch を一時的に ruleset の対象へ加えて次を確認します。

1. Ruleset A bypass 外 actor の通常 update が拒否される。
2. Ruleset A bypass actor の許可された通常 update が成功する。
3. force push が Ruleset B により拒否される。
4. branch deletion が Ruleset B により拒否される。

### 後片付け

必ず次の順で行います。

1. `ruleset-probe` を ruleset target から外す。
2. Ruleset A / B の `main` target が残っていることを再確認する。
3. probe branch を削除する。
4. probe 用に付与した一時権限があれば削除する。

## 11. Human integration check

ruleset 適用後も、現在の通常運用である branch からの人による squash integration が成功することを確認します。

force push や main delete を使って確認してはいけません。

## 12. CircleCI Administrator を記録する

CircleCI Organization Administrator は Context restriction の trusted bypass actor です。

次段への handoff 条件として次を残します。

- Agent に人間の CircleCI personal API token を渡さない。
- Agent に CircleCI Organization Administrator として動作できる credential を渡さない。
- Agent に人間と同じ GitHub identity / credential を渡さない。
- Agent identity を main ruleset bypass actor へ自動追加しない。

## 13. Deny probe の後片付け

deny probe が完了したら、`main` へ統合する前に `.circleci/config.yml` から次の2ブロックを削除します。

```text
# BEGIN #5465 temporary deny probe.
...
# END #5465 temporary deny probe.
```

対象は:

- `jobs.context-deny-probe`
- `workflows.phase5465-context-deny-probe`

削除後、通常の `main` CI 設定が #5461 完了時点の挙動を維持することを確認します。

`codex-ghcr-publish` Context 自体は残しますが、本物の PAT はまだ登録しません。

## 14. #5465 完了時に残すもの

repository:

- この runbook
- evidence template
- 通常 CI（temporary deny probe は削除済み）

外部設定:

- dedicated publish account
- PAT policy（PAT 自体は未発行）
- dedicated CircleCI Context + restrictions
- Main Ruleset A
- Main Ruleset B

Redmine:

- 秘密値を含まない設定記録
- deny probe 結果
- ruleset probe 結果
- human integration check
- fork protection 確認
- 次段 identity 分離条件
