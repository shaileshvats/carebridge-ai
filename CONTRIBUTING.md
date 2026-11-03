# Contributing

1. Load the AI Hub image and start the stack as described in [docs/installation.md](docs/installation.md).
2. Edit ObjectScript under `src/CareBridge`. Reload into the running container with:
   ```bash
   docker compose exec iris iris session IRIS -U CAREBRIDGE "##class(%SYSTEM.OBJ).LoadDir(\"/home/irisowner/dev/src\",\"ck\",,1)"
   ```
   or rebuild with `docker compose up -d --build`.
3. Run the tests (see [docs/testing.md](docs/testing.md)) and the demo scenarios before opening a pull request.
4. Use synthetic data only. Never add real patient information, credentials or API keys.

Every change to the policy gate needs a unit test showing the rule allowing and refusing an action.
