defmodule OpsChat.Accounts do
  @moduledoc """
  User management and authentication context.
  """

  alias OpsChat.Accounts.User
  alias OpsChat.Repo

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_username(username), do: Repo.get_by(User, username: username)

  def list_users, do: Repo.all(User)

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def change_user(%User{} = user, attrs \\ %{}), do: User.changeset(user, attrs)

  def authenticate(username, password) do
    user = get_user_by_username(username)

    cond do
      user && User.verify_password(user, password) -> {:ok, user}
      user -> {:error, :invalid_password}
      true ->
        Bcrypt.no_user_verify()
        {:error, :not_found}
    end
  end
end
