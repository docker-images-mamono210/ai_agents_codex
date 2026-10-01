# #5465 Redmine evidence template

このテンプレートには秘密値を記入しないでください。

## GHCR package

- Candidate / confirmed package:
- Existing package collision: PASS / FAIL
- Unexpected existing artifact: PASS / FAIL

## Dedicated publish account

- GitHub login:
- Organization role:
- Organization owner: NO
- Organization base permission:
- Repository permission:
- Package creation policy:
- Member package creation permission:
- Production package write reachability:
- Result: PASS / FAIL

## PAT policy

- Token type: classic PAT
- Required scope: write:packages
- delete:packages: NO
- Unnecessary repo scope: NO
- Expiration policy:
- Rotation owner:
- PAT issued in #5465: NO

## CircleCI

- Project:
- Integration type:
- `pipeline.config.ref` available: YES / NO
- Context:
- Project restriction:
- Expression restriction:
- CircleCI Organization Administrator recorded as trusted bypass: YES / NO
- Fork / PR secret protection checked: YES / NO

## Context deny probe

- Probe branch: `5465-context-deny-probe`
- Probe principal:
- Organization Administrator: NO
- Expected result: Unauthorized before job steps
- Actual result:
- Job URL:
- Docker login executed: NO
- GHCR access executed: NO
- Push executed: NO
- Temporary repository permission removed: YES / N/A
- Result: PASS / FAIL

## Ruleset A - main update authorization

- Ruleset name:
- Target:
- Restrict updates: YES
- Bypass actors:
  - actor / type / bypass mode / purpose:

## Ruleset B - main history immutability

- Ruleset name:
- Target:
- Block force pushes: YES
- Restrict deletions: YES
- Bypass actors: NONE

## Ruleset probe

- Probe branch:
- Bypass-external update rejected: PASS / FAIL
- Bypass actor normal update allowed: PASS / FAIL
- Force push rejected: PASS / FAIL
- Branch deletion rejected: PASS / FAIL
- Probe target removed before branch deletion: YES / NO
- Main target rechecked: YES / NO
- Probe branch deleted: YES / NO
- Temporary permission removed: YES / N/A

## Human integration check

- Integration method:
- Source branch:
- Result:
- Main history remained intact: YES / NO

## Next-stage identity handoff

- Human GitHub identity will not be shared with Agent: YES
- Human CircleCI personal API token will not be shared with Agent: YES
- CircleCI Administrator credential will not be shared with Agent: YES
- Agent identity will not be auto-added to main bypass: YES

## Final #5465 gate

- Real GHCR PAT registered in Context: NO
- GHCR image pushed: NO
- Target package created by this ticket: NO
- Temporary CircleCI deny-probe blocks removed before main integration: YES
- All completion criteria satisfied: YES / NO
