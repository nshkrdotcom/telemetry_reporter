defmodule TelemetryReporter.Sink do
  @moduledoc false

  @behaviour Pachka.Sink

  alias TelemetryReporter.{Backoff, Config, Telemetry}

  @impl true
  def send_batch(events, %Config{} = config) do
    {encoded, errors} = encode_events(events, config.event_encoder)

    if errors != [] do
      [first | _] = errors
      Telemetry.encode_error(length(errors), first)
    end

    case encoded do
      [] ->
        :ok

      _ ->
        case config.transport.send_batch(encoded, config.transport_opts) do
          :ok ->
            Telemetry.batch_sent(length(encoded))
            :ok

          {:error, reason} = error ->
            Telemetry.batch_failed(length(encoded), reason)
            error
        end
    end
  end

  @impl true
  def retry_timeout(retry_num, reason, %Config{retry_backoff: backoff}) do
    Backoff.timeout(backoff, retry_num, reason)
  end

  defp encode_events(events, encoder) do
    Enum.reduce(events, {[], []}, fn event, {encoded, errors} ->
      case safe_encode(event, encoder) do
        {:ok, encoded_event} -> {[encoded_event | encoded], errors}
        {:error, reason} -> {encoded, [reason | errors]}
      end
    end)
    |> then(fn {encoded, errors} -> {Enum.reverse(encoded), Enum.reverse(errors)} end)
  end

  defp safe_encode(event, encoder) do
    case encoder.(event) do
      {:ok, encoded_event} -> {:ok, encoded_event}
      {:error, reason} -> {:error, reason}
      encoded_event -> {:ok, encoded_event}
    end
  rescue
    error -> {:error, error}
  catch
    kind, reason -> {:error, {kind, reason}}
  end
end
