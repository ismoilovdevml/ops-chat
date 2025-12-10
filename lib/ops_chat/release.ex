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
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn _repo ->
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

    # Create admin user
    case Accounts.get_user_by_username("admin") do
      nil ->
        {:ok, _user} = Accounts.create_user(%{
          username: "admin",
          password: "admin123",
          role: "admin"
        })
        IO.puts("Admin user created: admin / admin123")

      _user ->
        IO.puts("Admin user already exists")
    end

    # Create a regular user for testing
    case Accounts.get_user_by_username("devops") do
      nil ->
        {:ok, _user} = Accounts.create_user(%{
          username: "devops",
          password: "devops123",
          role: "user"
        })
        IO.puts("DevOps user created: devops / devops123")

      _user ->
        IO.puts("DevOps user already exists")
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
