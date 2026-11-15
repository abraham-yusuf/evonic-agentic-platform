# Evonic APD Kit v3

This workload packages Evonic from upstream commit `c902fae060192ac6261697598ce0034ce10b5819` and starts its Flask dashboard on `0.0.0.0:8080`. The first-run `/setup` route is unauthenticated until an administrator account is created; only expose the forwarded UI privately and finish setup immediately.

Evonic's first-run setup creates agents with `sandbox_enabled=0` by default. That fallback runs agent tools as local subprocesses inside the APD sandbox, without a nested Docker daemon. It is less isolated than per-agent Docker sandboxing; the APD sandbox remains the outer security boundary.

## Build locally

From this directory:

```sh
docker buildx build . -f evonic-agentic-platform.yaml --output type=oci,dest=evonic-kit.tar
```

To publish, use the APD-supported registry and authenticated Buildx builder:

```sh
docker buildx build . -f evonic-agentic-platform.yaml --tag docker.io/OWNER/evonic-agentic-platform:v3 --push
```

Do not use the legacy `spec.yaml` as the v3 descriptor. Kit v3 requires the YAML descriptor and companion Dockerfile to have the same basename.

## Run and verify

Run the workload in APD and forward port 8080 through the supported sandbox port-forward feature. Keep this port private while completing Evonic's first-run admin setup; the setup route is unauthenticated until an administrator exists. Configure model providers and any Telegram/Discord/Slack credentials in Evonic's own settings.

The kit declares outbound network policy for provider APIs and messaging services. This is egress only. It does not create a public webhook/inbound Telegram endpoint. Telegram polling can work only if Evonic's connector implementation and selected credentials support it and APD permits those outbound hosts.

Persistent volume: `/opt/evonic/shared` (Evonic SQLite DB at `shared/db/evonic.db`).
