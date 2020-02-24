defmodule Formatter do
  require Logger
  alias Logger.Formatter, as: F

  @spec format(any, any, any, nil | keyword | map) :: <<_::64, _::_*8>>
  def format(level, message, timestamp, metadata) do
    # timestamp
    "#{F.format_date(elem(timestamp, 0))} #{F.format_time(elem(timestamp, 1))} " <>
      "#{metadata[:file]}:" <>
      "#{metadata[:line]}: " <> "#{metadata[:function]} " <> "[#{level}] " <> "#{message}\n"
  end
end
