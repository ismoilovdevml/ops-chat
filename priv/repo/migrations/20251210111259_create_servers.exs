defmodule OpsChat.Repo.Migrations.CreateServers do
  use Ecto.Migration

  def change do
    create table(:servers) do
      add :name, :string
      add :host, :string
      add :port, :integer
      add :username, :string
      add :auth_type, :string
      add :private_key, :text
      add :password, :text
      add :description, :string
      add :user_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:servers, [:name])
    create index(:servers, [:user_id])
  end
end
