defmodule TelemetryReporter.TestTransport do
  @moduledoc false

  @behaviour TelemetryReporter.Transport

  @impl true
  def send_batch(events, opts) do
    if pid = Keyword.get(opts, :test_pid) do
      send(pid, {:batch, events, opts})
    end

    case Keyword.get(opts, :result, :ok) do
      :ok -> :ok
      {:error, _reason} = error -> error
    end
  end
end
