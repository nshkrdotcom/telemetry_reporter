defmodule TelemetryReporter.Config do
  @moduledoc false

  alias TelemetryReporter.{Backoff, Event}

  @type event_encoder :: (Event.t() -> {:ok, term()} | {:error, term()} | term())

  @type t :: %__MODULE__{
          transport: module(),
          transport_opts: keyword(),
          event_encoder: event_encoder(),
          retry_backoff: Backoff.t()
        }

  @enforce_keys [:transport, :transport_opts, :event_encoder, :retry_backoff]
  defstruct @enforce_keys

  @telemetry_reporter_keys [
    :transport,
    :transport_opts,
    :event_encoder,
    :retry_backoff,
    :sink,
    :server_value
  ]

  @spec from_opts(keyword()) :: {t(), keyword()}
  def from_opts(opts) do
    transport =
      case Keyword.fetch(opts, :transport) do
        {:ok, module} when is_atom(module) ->
          module

        _ ->
          raise ArgumentError,
                "expected :transport to be a module implementing TelemetryReporter.Transport"
      end

    transport_opts = Keyword.get(opts, :transport_opts, [])

    event_encoder =
      case Keyword.get(opts, :event_encoder, &Event.encode/1) do
        encoder when is_function(encoder, 1) -> encoder
        _ -> raise ArgumentError, "expected :event_encoder to be a function of arity 1"
      end

    retry_backoff =
      Keyword.get(opts, :retry_backoff, {:linear, 1_000})
      |> case do
        strategy ->
          if Backoff.valid?(strategy) do
            strategy
          else
            raise ArgumentError, "invalid :retry_backoff configuration"
          end
      end

    config = %__MODULE__{
      transport: transport,
      transport_opts: transport_opts,
      event_encoder: event_encoder,
      retry_backoff: retry_backoff
    }

    {config, Keyword.drop(opts, @telemetry_reporter_keys)}
  end
end
