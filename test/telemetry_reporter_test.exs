defmodule TelemetryReporterTest do
  use ExUnit.Case, async: false

  alias TelemetryReporter.{Event, TelemetryAdapter}

  describe "log/4 batching" do
    test "sends encoded events to the transport in order" do
      {:ok, pid} =
        TelemetryReporter.start_link(
          name: unique_name("reporter"),
          transport: TelemetryReporter.TestTransport,
          transport_opts: [test_pid: self()],
          max_batch_size: 2,
          max_batch_delay: 5_000
        )

      on_exit(fn -> TelemetryReporter.stop(pid) end)

      assert :ok = TelemetryReporter.log(pid, "alpha", %{value: 1}, :info)
      assert :ok = TelemetryReporter.log(pid, "beta", %{value: 2}, :warning)

      assert_receive {:batch, [first, second], _opts}, 500
      assert first["name"] == "alpha"
      assert first["severity"] == "info"
      assert second["name"] == "beta"
      assert second["severity"] == "warning"
    end
  end

  describe "overload handling" do
    test "returns an error and emits telemetry when the queue is full" do
      handler_id = unique_name("drop-handler")

      :ok =
        :telemetry.attach(
          handler_id,
          [:telemetry_reporter, :event, :dropped],
          &TelemetryReporter.TestTelemetryHandler.handle_event/4,
          %{test_pid: self(), tag: :dropped}
        )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      {:ok, pid} =
        TelemetryReporter.start_link(
          name: unique_name("reporter"),
          transport: TelemetryReporter.TestTransport,
          transport_opts: [test_pid: self()],
          max_batch_size: 10,
          max_batch_delay: 5_000,
          critical_queue_size: 1
        )

      on_exit(fn -> TelemetryReporter.stop(pid) end)

      assert :ok = TelemetryReporter.log(pid, "one", %{}, :info)
      assert {:error, :overloaded} = TelemetryReporter.log(pid, "two", %{}, :info)
      assert_receive {:dropped, %{count: 1}, %{reason: :overloaded}}, 500
    end
  end

  describe "encoding errors" do
    test "drops malformed events without failing the batch" do
      handler_id = unique_name("encode-handler")

      :ok =
        :telemetry.attach(
          handler_id,
          [:telemetry_reporter, :event, :encode_error],
          &TelemetryReporter.TestTelemetryHandler.handle_event/4,
          %{test_pid: self(), tag: :encode_error}
        )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      event_encoder = fn
        %Event{name: "bad"} -> {:error, :bad_event}
        event -> Event.encode(event)
      end

      {:ok, pid} =
        TelemetryReporter.start_link(
          name: unique_name("reporter"),
          transport: TelemetryReporter.TestTransport,
          transport_opts: [test_pid: self()],
          event_encoder: event_encoder,
          max_batch_size: 2,
          max_batch_delay: 5_000
        )

      on_exit(fn -> TelemetryReporter.stop(pid) end)

      assert :ok = TelemetryReporter.log(pid, "good", %{value: 1}, :info)
      assert :ok = TelemetryReporter.log(pid, "bad", %{value: 2}, :info)

      assert_receive {:batch, [event], _opts}, 500
      assert event["name"] == "good"
      assert_receive {:encode_error, %{count: 1}, %{reason: :bad_event}}, 500
    end
  end

  describe "flush and drain" do
    test "flush with sync waits for pending events to drain" do
      {:ok, pid} =
        TelemetryReporter.start_link(
          name: unique_name("reporter"),
          transport: TelemetryReporter.TestTransport,
          transport_opts: [test_pid: self()],
          max_batch_size: 100,
          max_batch_delay: 5_000
        )

      on_exit(fn -> TelemetryReporter.stop(pid) end)

      assert :ok = TelemetryReporter.log(pid, "flush-me", %{value: 1}, :info)
      assert :ok = TelemetryReporter.flush(pid, sync?: true, timeout: 1_000)
      assert_receive {:batch, [_event], _opts}, 500
      assert TelemetryReporter.wait_until_drained(pid, 1_000)
    end
  end

  describe "telemetry adapter" do
    test "forwards telemetry events into the reporter" do
      {:ok, pid} =
        TelemetryReporter.start_link(
          name: unique_name("reporter"),
          transport: TelemetryReporter.TestTransport,
          transport_opts: [test_pid: self()],
          max_batch_size: 1,
          max_batch_delay: 5_000
        )

      on_exit(fn -> TelemetryReporter.stop(pid) end)

      handler_id =
        TelemetryAdapter.attach_many(
          reporter: pid,
          events: [[:demo, :event]],
          handler_id: unique_name("adapter")
        )

      on_exit(fn -> TelemetryAdapter.detach(handler_id) end)

      :telemetry.execute([:demo, :event], %{duration: 123}, %{foo: "bar"})

      assert_receive {:batch, [event], _opts}, 500
      assert event["name"] == "demo.event"
      assert event["data"]["measurements"]["duration"] == 123
      assert event["data"]["metadata"]["foo"] == "bar"
    end
  end

  defp unique_name(prefix) do
    :"#{prefix}-#{System.unique_integer([:positive])}"
  end
end
