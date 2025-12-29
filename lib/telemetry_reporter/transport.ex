defmodule TelemetryReporter.Transport do
  @moduledoc """
  Behaviour for delivering encoded telemetry batches.
  """

  @typedoc "Encoded event payloads passed to the transport."
  @type event :: term()

  @callback send_batch(events :: [event()], opts :: term()) :: :ok | {:error, term()}
end
