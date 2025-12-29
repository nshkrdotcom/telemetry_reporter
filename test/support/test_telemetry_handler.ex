defmodule TelemetryReporter.TestTelemetryHandler do
  @moduledoc false

  def handle_event(_event, measurements, metadata, %{test_pid: test_pid, tag: tag}) do
    send(test_pid, {tag, measurements, metadata})
  end
end
