defimpl String.Chars, for: PID do
  def to_string(pid) do
    # info = Process.info(pid)
    # name = info[:registered_name]

    self() |> Process.info()
    pid |> Process.info()

    if is_pid(pid) do
      "yes"
    else
      "no"
    end
  end
end
