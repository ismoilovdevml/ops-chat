defmodule OpsChat.Release do
  @moduledoc """
  Release tasks for production migrations and seeding.
  """

  @app :ops_chat

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          seed_database()
        end)
    end
  end

  defp seed_database do
    alias OpsChat.Accounts
    alias OpsChat.Chat

    # Create default channels
    Chat.ensure_default_channels()
    IO.puts("Default channels created")

    # Get credentials from env or use defaults (dev only)
    admin_username = System.get_env("ADMIN_USERNAME", "admin")
    admin_password = System.get_env("ADMIN_PASSWORD", "admin123")
    user_username = System.get_env("USER_USERNAME", "devops")
    user_password = System.get_env("USER_PASSWORD", "devops123")

    # Create admin user
    case Accounts.get_user_by_username(admin_username) do
      nil ->
        {:ok, _user} =
          Accounts.create_user(%{
            username: admin_username,
            password: admin_password,
            role: "admin"
          })

        IO.puts("Admin user created: #{admin_username}")

      _user ->
        IO.puts("Admin user already exists")
    end

    # Create a regular user
    case Accounts.get_user_by_username(user_username) do
      nil ->
        {:ok, _user} =
          Accounts.create_user(%{
            username: user_username,
            password: user_password,
            role: "user"
          })

        IO.puts("User created: #{user_username}")

      _user ->
        IO.puts("User already exists")
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
