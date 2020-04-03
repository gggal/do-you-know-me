defmodule Mock.User do
  @behaviour UserBehaviour

  def exists?("username1"), do: true
  def exists?(_), do: false

  def insert("username1"), do: false
  def insert(_), do: false
end
