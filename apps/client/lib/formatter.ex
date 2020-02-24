defmodule Formatter do
  require Logger
  alias Logger.Formatter, as: F

  @spec format(any, any, any, nil | keyword | map) :: <<_::64, _::_*8>>
  def format(level, message, timestamp, metadata) do
    # timestamp
    "#{F.format_date(elem(timestamp, 0))} #{F.format_time(elem(timestamp, 1))} " <>
      "#{metadata[:file]}:" <>
      "#{metadata[:line]}: " <>
      "#{metadata[:function]} " <>
      "[#{level}] " <>
      "#{message}\n"
  end

  @spec info(any, [{:label, any}, ...]) :: :ok | {:error, any}
  def info(obj, label: text) do
    Logger.info(text <> "#{obj}")
    obj
  end

end


defimpl String.Chars, for: Map do

  def to_string(map) do
    map
    |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
    |> Enum.join(", ")
  end
end

defimpl String.Chars, for: Tuple do

  def to_string(tuple) do
    tuple
    |> Tuple.to_list
    |> Enum.join(", ")
  end
end
