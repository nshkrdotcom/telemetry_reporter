defmodule TelemetryReporter.Event do
  @moduledoc """
  Structured telemetry event representation.
  """

  @type severity :: :debug | :info | :warning | :error | :critical | String.t()

  @type t :: %__MODULE__{
          id: String.t(),
          timestamp: DateTime.t() | NaiveDateTime.t() | integer() | String.t(),
          name: String.t(),
          severity: severity(),
          data: map(),
          metadata: map()
        }

  @enforce_keys [:id, :timestamp, :name, :severity, :data, :metadata]
  defstruct @enforce_keys

  @spec new(String.t() | [atom()], map(), severity(), map()) :: t()
  def new(name, data \\ %{}, severity \\ :info, metadata \\ %{}) do
    %__MODULE__{
      id: generate_id(),
      timestamp: DateTime.utc_now(),
      name: normalize_name(name),
      severity: severity,
      data: data || %{},
      metadata: metadata || %{}
    }
  end

  @spec normalize_name(String.t() | [atom()]) :: String.t()
  def normalize_name(name) when is_list(name) do
    Enum.map_join(name, ".", &to_string/1)
  end

  def normalize_name(name), do: to_string(name)

  @spec encode(t() | map()) :: {:ok, map()} | {:error, term()}
  def encode(event) do
    {:ok, to_map(event)}
  rescue
    error -> {:error, error}
  end

  @spec to_map(t() | map()) :: map()
  def to_map(%__MODULE__{} = event) do
    %{
      "id" => event.id,
      "timestamp" => format_timestamp(event.timestamp),
      "name" => event.name,
      "severity" => normalize_severity(event.severity),
      "data" => sanitize(event.data),
      "metadata" => sanitize(event.metadata)
    }
  end

  def to_map(map) when is_map(map), do: sanitize(map)

  @spec exception_data(Exception.t(), keyword()) :: map()
  def exception_data(exception, opts \\ []) do
    data = %{
      "type" => exception |> Map.get(:__struct__, exception) |> to_string(),
      "message" => Exception.message(exception)
    }

    case Keyword.get(opts, :stacktrace, []) do
      [] -> data
      stacktrace -> Map.put(data, "stacktrace", Exception.format_stacktrace(stacktrace))
    end
  end

  @spec sanitize(term()) :: term()
  def sanitize(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  def sanitize(%NaiveDateTime{} = datetime), do: NaiveDateTime.to_iso8601(datetime)
  def sanitize(%_struct{} = struct), do: struct |> Map.from_struct() |> sanitize()

  def sanitize(map) when is_map(map) do
    Enum.into(map, %{}, fn {key, value} -> {sanitize_key(key), sanitize(value)} end)
  end

  def sanitize(list) when is_list(list), do: Enum.map(list, &sanitize/1)
  def sanitize(value) when is_atom(value), do: Atom.to_string(value)

  def sanitize(value)
      when is_number(value) or is_binary(value) or is_boolean(value) or is_nil(value),
      do: value

  def sanitize(value), do: inspect(value)

  defp generate_id do
    System.unique_integer([:positive]) |> Integer.to_string()
  end

  defp normalize_severity(severity) when is_atom(severity), do: Atom.to_string(severity)
  defp normalize_severity(severity) when is_binary(severity), do: String.downcase(severity)
  defp normalize_severity(severity), do: to_string(severity)

  defp format_timestamp(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp format_timestamp(%NaiveDateTime{} = datetime), do: NaiveDateTime.to_iso8601(datetime)
  defp format_timestamp(timestamp) when is_integer(timestamp), do: timestamp
  defp format_timestamp(timestamp) when is_binary(timestamp), do: timestamp
  defp format_timestamp(timestamp), do: inspect(timestamp)

  defp sanitize_key(key) when is_binary(key), do: key
  defp sanitize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp sanitize_key(key) when is_number(key), do: to_string(key)
  defp sanitize_key(key), do: inspect(key)
end
