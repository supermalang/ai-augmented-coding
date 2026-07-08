# OpenTelemetry / collector adapter (notes)

For a real backend you usually don't shell out per event — you instrument the app with an SDK and
export to a collector. This adapter is therefore **notes, not a script**: wire it inside your own
runtime, keeping the same three signals the [emit interface](../README.md) defines.

- **Errors** → record as span events / a logs exporter (e.g. an error handler that reports the
  exception with context attributes).
- **Key metrics** → OTel metrics instruments (counters/histograms) for the handful of numbers in your
  `Emit` list — not everything.
- **Deploy/version marker** → set a `service.version` resource attribute and emit a deploy event/annotation
  so dashboards can correlate a regression with a release.

Point the exporter at your collector endpoint (`OTEL_EXPORTER_OTLP_ENDPOINT`) — a `[CONFIGURE]` value,
read from the environment, never committed. The `SLOs` in `context.md` are then evaluated by your
monitoring backend (or the [health gate](../../docs/health-gate.md)) against these signals.

> Keep the same **inert-when-off** rule: gate SDK initialisation on `Observability → Enabled` so a
> disabled project loads no exporter and pays no runtime cost.
