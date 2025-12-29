# Usage Guide

## Start a Reporter

Provide a transport module and any Pachka batching options. TelemetryReporter
forwards all non-reporter options directly to `Pachka.start_link/1`.

```elixir
defmodule MyApp.TelemetryTransport do
  @behaviour TelemetryReporter.Transport

  @impl true
  def send_batch(events, _opts) do
    # Deliver encoded events to your backend.
    :ok
  end
end

{:ok, _pid} =
  TelemetryReporter.start_link(
    name: MyReporter,
    transport: MyApp.TelemetryTransport,
    max_batch_size: 250,
    max_batch_delay: :timer.seconds(2),
    critical_queue_size: 10_000
  )
```

## Log Events

```elixir
:ok = TelemetryReporter.log(MyReporter, "user.login", %{user_id: "123"}, :info)
```

Use `log_exception/3` for exceptions:

```elixir
try do
  raise "oops"
rescue
  exception -> TelemetryReporter.log_exception(MyReporter, exception, :error)
end
```

## Flush and Drain

```elixir
:ok = TelemetryReporter.flush(MyReporter)
:ok = TelemetryReporter.flush(MyReporter, sync?: true, timeout: 5_000)

TelemetryReporter.wait_until_drained(MyReporter, 5_000)
```

## Encoding Strategy

The default encoder converts `TelemetryReporter.Event` structs into maps with
string keys and sanitizes values for JSON friendliness. You can override it:

```elixir
event_encoder = fn event ->
  TelemetryReporter.Event.encode(event)
end

{:ok, _pid} =
  TelemetryReporter.start_link(
    transport: MyApp.TelemetryTransport,
    event_encoder: event_encoder
  )
```

If the encoder raises or returns `{:error, reason}`, the event is dropped and
the batch continues.

## Retry Backoff

Control retry backoff with `:retry_backoff`:

```elixir
{:ok, _pid} =
  TelemetryReporter.start_link(
    transport: MyApp.TelemetryTransport,
    retry_backoff: {:exponential, 500, 30_000}
  )
```

Supported strategies:
- `:linear` (1s, 2s, 3s...)
- `{:linear, base_ms}`
- `{:fixed, ms}`
- `{:exponential, base_ms}`
- `{:exponential, base_ms, max_ms}`
- function `(retry_num, reason) -> timeout_ms`

## Telemetry Adapter

Forward `:telemetry` events into TelemetryReporter:

```elixir
handler_id =
  TelemetryReporter.TelemetryAdapter.attach_many(
    reporter: MyReporter,
    events: [[:my_app, :http, :request, :stop]],
    severity_mapper: fn event, _measurements, _metadata ->
      if event == [:my_app, :http, :request, :exception], do: :error, else: :info
    end
  )

# Later...
TelemetryReporter.TelemetryAdapter.detach(handler_id)
```

## Telemetry Events

TelemetryReporter emits its own telemetry events with prefix `[:telemetry_reporter]`:
- `[:telemetry_reporter, :event, :dropped]` with `%{count: 1}`
- `[:telemetry_reporter, :event, :encode_error]` with `%{count: n}`
- `[:telemetry_reporter, :batch, :sent]` with `%{count: n}`
- `[:telemetry_reporter, :batch, :failed]` with `%{count: n}`

