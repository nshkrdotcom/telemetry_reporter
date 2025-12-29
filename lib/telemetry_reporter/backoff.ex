defmodule TelemetryReporter.Backoff do
  @moduledoc false

  @type strategy ::
          :linear
          | {:linear, pos_integer()}
          | {:fixed, pos_integer()}
          | {:exponential, pos_integer()}
          | {:exponential, pos_integer(), pos_integer()}
          | (pos_integer(), term() -> timeout())

  @type t :: strategy()

  @spec valid?(term()) :: boolean()
  def valid?(:linear), do: true
  def valid?({:linear, base}) when is_integer(base) and base > 0, do: true
  def valid?({:fixed, ms}) when is_integer(ms) and ms >= 0, do: true
  def valid?({:exponential, base}) when is_integer(base) and base > 0, do: true

  def valid?({:exponential, base, max})
      when is_integer(base) and base > 0 and is_integer(max) and max > 0,
      do: true

  def valid?(fun) when is_function(fun, 2), do: true
  def valid?(_), do: false

  @spec timeout(t(), pos_integer(), term()) :: timeout()
  def timeout(:linear, retry_num, _reason), do: timeout({:linear, 1_000}, retry_num, nil)

  def timeout({:linear, base}, retry_num, _reason) when retry_num > 0 do
    base * retry_num
  end

  def timeout({:fixed, ms}, _retry_num, _reason), do: ms

  def timeout({:exponential, base}, retry_num, _reason) when retry_num > 0 do
    base * pow2(retry_num - 1)
  end

  def timeout({:exponential, base, max}, retry_num, reason) do
    min(timeout({:exponential, base}, retry_num, reason), max)
  end

  def timeout(fun, retry_num, reason) when is_function(fun, 2) do
    fun.(retry_num, reason)
  end

  defp pow2(exp) when exp <= 0, do: 1
  defp pow2(exp), do: trunc(:math.pow(2, exp))
end
