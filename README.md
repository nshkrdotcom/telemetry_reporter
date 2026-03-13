<p align="center">
  <img src="assets/telemetry_reporter.svg" alt="TelemetryReporter" width="200">
</p>

# TelemetryReporter

TelemetryReporter is a transport-agnostic telemetry batching library for
Elixir/BEAM apps. It uses Pachka for size and time based flushing, drops on
overload to protect producers, and isolates encoding failures so a single bad
event never poisons a batch.

## Installation

Add `telemetry_reporter` to your dependencies:

```elixir
def deps do
  [
    {:telemetry_reporter, "~> 0.1.0"}
  ]
end
```

## Quick Start

Define a transport:

```elixir
defmodule MyApp.TelemetryTransport do
  @behaviour TelemetryReporter.Transport

  @impl true
  def send_batch(events, _opts) do
    # Deliver encoded events to your backend.
    :ok
  end
end
```

Start the reporter and log events:

```elixir
{:ok, _pid} =
  TelemetryReporter.start_link(
    name: MyReporter,
    transport: MyApp.TelemetryTransport,
    max_batch_size: 200,
    max_batch_delay: :timer.seconds(2)
  )

:ok = TelemetryReporter.log(MyReporter, "user.login", %{user_id: "123"}, :info)
```

## Configuration

TelemetryReporter options:
- `:transport` - module implementing `TelemetryReporter.Transport` (required)
- `:transport_opts` - options passed to the transport (default: [])
- `:event_encoder` - encode events before delivery (default: `TelemetryReporter.Event.encode/1`)
- `:retry_backoff` - backoff strategy or function (default: `{:linear, 1_000}`)

All other options are forwarded to `Pachka.start_link/1` (such as
`max_batch_size`, `max_batch_delay`, `critical_queue_size`, and `export_timeout`).

## Telemetry Adapter

Forward `:telemetry` events into TelemetryReporter:

```elixir
handler_id =
  TelemetryReporter.TelemetryAdapter.attach_many(
    reporter: MyReporter,
    events: [[:my_app, :http, :request, :stop]],
    severity: :info
  )

# Later...
TelemetryReporter.TelemetryAdapter.detach(handler_id)
```

## Telemetry Events

TelemetryReporter emits telemetry events with prefix `[:telemetry_reporter]`:
- `[:telemetry_reporter, :event, :dropped]`
- `[:telemetry_reporter, :event, :encode_error]`
- `[:telemetry_reporter, :batch, :sent]`
- `[:telemetry_reporter, :batch, :failed]`

## Docs

See `docs/usage.md` for advanced usage, encoder details, and retry backoff
configuration.

## License

MIT — see [LICENSE](LICENSE) for details.
