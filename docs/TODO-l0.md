# TODO: L0

## Decisions

Toolchain: GHC 9.10.3 is set in `cabal.project`; cabal 3.16.1.0 is the installed tool, as recorded
in `STATUS.md`.

| Dependency | Used by | Reason |
|---|---|---|
| `base` | all | Standard library. `^>=4.20` is the series GHC 9.10 ships. |
| `tasty` | test | Test runner that combines the three test styles below. |
| `tasty-hunit` | test | Example-based tests, such as classifier fixtures. Used by the current test. |
| `tasty-quickcheck` | test | Property tests for the generator and classifier (`docs/design/architecture.md`). Not imported yet. |
| `tasty-golden` | test | Golden fixtures from probes and report snapshots (`docs/design/architecture.md`). Not imported yet. |
