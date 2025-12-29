defmodule TelemetryReporter.Telemetry do
  @moduledoc false

  @prefix [:telemetry_reporter]

  @spec event_dropped(atom()) :: :ok
  def event_dropped(reason) do
    execute([:event, :dropped], %{count: 1}, %{reason: reason})
  end

  @spec encode_error(non_neg_integer(), term()) :: :ok
  def encode_error(count, reason) do
    execute([:event, :encode_error], %{count: count}, %{reason: reason})
  end

  @spec batch_sent(non_neg_integer()) :: :ok
  def batch_sent(count) do
    execute([:batch, :sent], %{count: count}, %{})
  end

  @spec batch_failed(non_neg_integer(), term()) :: :ok
  def batch_failed(count, reason) do
    execute([:batch, :failed], %{count: count}, %{reason: reason})
  end

  defp execute(suffix, measurements, metadata) do
    :telemetry.execute(@prefix ++ suffix, measurements, metadata)
  end
end
