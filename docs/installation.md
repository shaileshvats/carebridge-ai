# Installation

## 1. Get the AI Hub image (once per machine)

CareBridge targets the **InterSystems AI Hub Early Access Community build 2027.1.0AI.109.0**, using the **IRIS for Health** image. The organizers' latest contest clarification names 109 as the current build.

1. Sign in at <https://evaluation.intersystems.com/Eval/early-access/AIHub>.
2. Download the community image for your CPU:
   - Apple Silicon or other ARM64: `irishealth_arm64-community-2027.1.0AI.109.0-docker.tar.gz`
   - x86-64: `irishealth-community-2027.1.0AI.109.0-docker.tar.gz`
3. Load it and give it the tag the Dockerfile expects:

   ```bash
   scripts/load-image.sh ~/Downloads/irishealth_arm64-community-2027.1.0AI.109.0-docker.tar.gz
   ```

   That is equivalent to:

   ```bash
   docker image load -i ~/Downloads/irishealth_arm64-community-2027.1.0AI.109.0-docker.tar.gz
   docker images            # note the loaded name, e.g. intersystems/irishealth-community-arm64:2027.1.0AI.109.0
   docker tag <loaded image name> irishealth-community:2027.1.0AI.109.0
   ```

   If you would rather keep a different tag, set `IRIS_IMAGE=<your tag>` in `.env`.

Do not push this image, or the `carebridge-ai:local` image built on it, to any public registry.

## 2. Configure (optional)

```bash
cp .env.example .env
```

The defaults run in **REPLAY** mode, which needs no key. To use a live model, see [ai-agent.md](ai-agent.md#provider-configuration).

## 3. Start

```bash
docker compose up -d --build
scripts/wait-ready.sh
```

The first build compiles the package and loads it through IPM, in the same way an IPM install would. It downloads the IPM client if the image does not include one.

## 4. Verify

```bash
curl -s http://localhost:52773/api/carebridge/health
```

`productionRunning` should be `1`. Then open:

- Dashboard: <http://localhost:52773/carebridge/index.html>
- Management Portal (production, Visual Trace, Workflow): <http://localhost:52773/csp/sys/UtilHome.csp>. Use the image's default credentials, which `iris.script` keeps from expiring in this development container.

## 5. Run the demo and tests

```bash
scripts/demo.sh             # all scenarios through the production
scripts/run-tests.sh        # unit tests
scripts/run-tests.sh --all  # unit + integration (resets demo data)
```

## Install with IPM into an existing instance

On an AI Hub build 2026.3 or later, in an interoperability-enabled namespace:

```objectscript
zpm "install carebridge-ai"
do ##class(CareBridge.Setup.Installer).StartProduction()
```

The module declares `<SystemRequirements Version="&gt;=2026.3" Interoperability="enabled"/>`, so IPM refuses to install it on older versions or in namespaces without interoperability.

## Stop, reset, remove

```bash
scripts/reset.sh            # clear demo data, keep running
docker compose down         # stop; the carebridge-data volume keeps the database
docker compose down -v      # stop and delete the database volume
```
