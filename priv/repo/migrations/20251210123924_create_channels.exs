defmodule OpsChat.Repo.Migrations.CreateChannels do
  use Ecto.Migration

  def change do
    create table(:channels) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :string
      add :type, :string, default: "custom"
      add :icon, :string, default: "💬"
      add :position, :integer, default: 0
      add :is_private, :boolean, default: false
      add :server_id, :integer
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:channels, [:slug])
    create unique_index(:channels, [:name])
    create index(:channels, [:user_id])
    create index(:channels, [:type])
    create index(:channels, [:server_id])

    # Update messages table to add channel_id
    alter table(:messages) do
      add :channel_id, references(:channels, on_delete: :delete_all)
    end

    create index(:messages, [:channel_id])
  end
end
