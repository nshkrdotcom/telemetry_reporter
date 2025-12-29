defmodule TelemetryReporter do
  @moduledoc """
  Transport-agnostic telemetry reporter that batches events with Pachka.

  `TelemetryReporter` keeps producers fast by enqueueing events and letting Pachka
  handle time/size-based batching, retries, and overload protection.
  """

  alias TelemetryReporter.{Config, Event, Telemetry}

  @type reporter :: GenServer.server()
  @type severity :: Event.severity()

  @typedoc """
  Options for `start_link/1`.

  TelemetryReporter-specific options:
    * `:transport` - module implementing `TelemetryReporter.Transport` (required)
    * `:transport_opts` - options passed to the transport (default: [])
    * `:event_encoder` - encoder function for events (default: `&TelemetryReporter.Event.encode/1`)
    * `:retry_backoff` - backoff strategy or function (default: `{:linear, 1_000}`)

  All other options are forwarded to `Pachka.start_link/1`.
  """
  @type option :: {atom(), term()}
  @type options :: [option()]

  @doc """
  Starts a TelemetryReporter instance.
  """
  @spec start_link(options()) :: GenServer.on_start()
  def start_link(opts) do
    {config, pachka_opts} = Config.from_opts(opts)

    Pachka.start_link(
      pachka_opts
      |> Keyword.put(:sink, TelemetryReporter.Sink)
      |> Keyword.put(:server_value, config)
    )
  end

  @doc """
  Returns a child spec for starting the reporter under a supervisor.
  """
  @spec child_spec(options()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @doc """
  Logs a telemetry event.
  """
  @spec log(reporter(), String.t() | [atom()], map(), severity()) ::
          :ok | {:error, :overloaded} | {:error, :not_running}
  def log(reporter, name, data \\ %{}, severity \\ :info) do
    event = Event.new(name, data, severity)
    send_event(reporter, event)
  end

  @doc """
  Logs an exception event.
  """
  @spec log_exception(reporter(), Exception.t(), severity()) ::
          :ok | {:error, :overloaded} | {:error, :not_running}
  def log_exception(reporter, exception, severity \\ :error) do
    data = Event.exception_data(exception)
    event = Event.new("exception", data, severity)
    send_event(reporter, event)
  end

  @doc """
  Forces a batch flush.

  Options:
    * `:sync?` - when true, waits for drain (default: false)
    * `:timeout` - wait timeout in milliseconds when sync? is true (default: 5_000)
  """
  @spec flush(reporter(), keyword()) :: :ok | {:error, :timeout} | {:error, :not_running}
  def flush(reporter, opts \\ []) do
    sync? = Keyword.get(opts, :sync?, false)
    timeout = Keyword.get(opts, :timeout, 5_000)

    with {:ok, pid} <- resolve_pid(reporter) do
      send(pid, :batch_timeout)

      if sync? do
        if wait_until_drained(pid, timeout) do
          :ok
        else
          {:error, :timeout}
        end
      else
        :ok
      end
    end
  end

  @doc """
  Stops the reporter gracefully.
  """
  @spec stop(reporter(), timeout()) :: :ok | {:error, :not_running}
  def stop(reporter, timeout \\ :infinity) do
    Pachka.stop(reporter, timeout)
  catch
    :exit, _reason -> {:error, :not_running}
  end

  @doc """
  Waits until the reporter has drained its queue.

  Returns `true` if drained before the timeout, `false` otherwise.
  """
  @spec wait_until_drained(reporter(), timeout()) :: boolean()
  def wait_until_drained(reporter, timeout \\ 5_000) do
    case resolve_pid(reporter) do
      {:ok, pid} ->
        deadline = System.monotonic_time(:millisecond) + timeout
        do_wait_until_drained(pid, deadline)

      :error ->
        false
    end
  end

  @doc false
  @spec send_event(reporter(), Event.t()) ::
          :ok | {:error, :overloaded} | {:error, :not_running}
  def send_event(reporter, %Event{} = event) do
    case safe_send_message(reporter, event) do
      :ok ->
        :ok

      {:error, :overloaded} = error ->
        Telemetry.event_dropped(:overloaded)
        error

      {:error, :not_running} = error ->
        Telemetry.event_dropped(:not_running)
        error
    end
  end

  defp safe_send_message(reporter, event) do
    Pachka.send_message(reporter, event)
  catch
    :exit, _reason -> {:error, :not_running}
  end

  defp resolve_pid(pid) when is_pid(pid) do
    if Process.alive?(pid) do
      {:ok, pid}
    else
      :error
    end
  end

  defp resolve_pid(name) do
    case GenServer.whereis(name) do
      nil -> :error
      pid -> {:ok, pid}
    end
  end

  defp do_wait_until_drained(pid, deadline) do
    if drained?(pid) do
      true
    else
      if System.monotonic_time(:millisecond) >= deadline do
        false
      else
        Process.sleep(10)
        do_wait_until_drained(pid, deadline)
      end
    end
  end

  defp drained?(pid) do
    case :sys.get_state(pid) do
      %Pachka.State{queue_length: 0, state: %Pachka.State.Idle{}} -> true
      %Pachka.State{} -> false
      _ -> false
    end
  catch
    :exit, _reason -> false
  end
end
