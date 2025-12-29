defmodule TelemetryReporter.TelemetryAdapter do
  @moduledoc """
  Adapter for forwarding `:telemetry` events into TelemetryReporter.
  """

  alias TelemetryReporter.Event

  @type option :: {atom(), term()}

  @doc """
  Attach a handler that forwards events to a TelemetryReporter instance.

  Options:
    * `:reporter` - reporter pid or name (required)
    * `:events` - telemetry events to attach (required)
    * `:handler_id` - handler id (default: generated)
    * `:event_name_transform` - function to convert event name to string (default: join with ".")
    * `:metadata_filter` - function to filter metadata (default: identity)
    * `:severity` - default severity (default: :info)
    * `:severity_mapper` - function to compute severity
    * `:event_builder` - custom builder that returns {:ok, {name, data, severity}} or :skip
  """
  @spec attach_many([option()]) :: term()
  def attach_many(opts) do
    reporter = Keyword.fetch!(opts, :reporter)
    events = Keyword.fetch!(opts, :events)
    handler_id = Keyword.get(opts, :handler_id, default_handler_id())

    event_name_transform = Keyword.get(opts, :event_name_transform, &default_event_name/1)
    metadata_filter = Keyword.get(opts, :metadata_filter, & &1)
    default_severity = Keyword.get(opts, :severity, :info)

    severity_mapper =
      Keyword.get(
        opts,
        :severity_mapper,
        fn _event, _measurements, _metadata -> default_severity end
      )

    event_builder =
      Keyword.get_lazy(opts, :event_builder, fn ->
        default_event_builder(event_name_transform, metadata_filter, severity_mapper)
      end)

    config = %{
      reporter: reporter,
      event_builder: event_builder
    }

    :ok = :telemetry.attach_many(handler_id, events, &__MODULE__.handle_event/4, config)
    handler_id
  end

  @doc """
  Detach a telemetry handler.
  """
  @spec detach(term()) :: :ok | {:error, :not_found}
  def detach(handler_id), do: :telemetry.detach(handler_id)

  @doc false
  def handle_event(event_name, measurements, metadata, config) do
    case config.event_builder.(event_name, measurements, metadata) do
      {:ok, %Event{} = event} ->
        TelemetryReporter.send_event(config.reporter, event)

      {:ok, {name, data, severity}} ->
        TelemetryReporter.log(config.reporter, name, data, severity)

      :skip ->
        :ok

      {:skip, _reason} ->
        :ok

      _other ->
        :ok
    end
  rescue
    _error -> :ok
  end

  defp default_event_builder(event_name_transform, metadata_filter, severity_mapper) do
    fn event_name, measurements, metadata ->
      data = %{
        measurements: measurements,
        metadata: metadata_filter.(metadata)
      }

      {:ok,
       {event_name_transform.(event_name), data,
        severity_mapper.(event_name, measurements, metadata)}}
    end
  end

  defp default_event_name(event) when is_list(event) do
    Enum.map_join(event, ".", &to_string/1)
  end

  defp default_event_name(event), do: to_string(event)

  defp default_handler_id do
    "telemetry-reporter-#{System.unique_integer([:positive])}"
  end
end
