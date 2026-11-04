# Contributing

Contributions are welcome. By contributing you agree that your contribution is licensed under the project's licence, [AGPL-3.0-only](LICENSE).

## Development loop

1. Load the AI Hub image and start the stack (see [docs/installation.md](docs/installation.md)).
2. Edit ObjectScript under `src/CareBridge`, then copy the sources into the running container and compile:
   ```bash
   docker compose cp src/. iris:/home/irisowner/dev/src/
   docker compose exec -T iris iris session IRIS -U CAREBRIDGE <<'EOF2'
   do $system.OBJ.LoadDir("/home/irisowner/dev/src","ck-d",.err,1)
   halt
   EOF2
   ```
   Business hosts keep the old code until restarted: `do ##class(Ens.Director).RestartProduction()`.
3. Dashboard files: `docker compose cp web/. iris:/usr/irissys/csp/carebridge/`, then bump the `?v=` query in `web/index.html`.
4. Before a pull request, run `scripts/run-tests.sh --all` and `scripts/demo.sh`, or `scripts/qc.sh`.

## Rules

- **Synthetic data only.** Never add real patient information, credentials or API keys.
- Every change to the policy gate needs a unit test that shows the rule allowing and refusing an action.
- The agent's tools must stay read-only. Anything that changes state goes through the router and the policy gate.
- New claims in docs need evidence (a test, a QC log or a usage report).
- Follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Useful pitfalls (learned the hard way)

- `At` and `Authorization` are reserved words in IRIS SQL, so quote them.
- Dynamic SQL from the unauthenticated web app needs the `CareBridgeWeb` role grants. Embedded SQL doesn't.
- `%AI.Policy.Audit.%LogExecution` must return `%Status`.
- Assign a Workflow task to the reviewer (`EnsLib.Workflow.Engine.AssignTask`) before `CompleteTask`, or the reviewer's name is lost.
