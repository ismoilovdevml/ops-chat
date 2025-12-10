defmodule OpsChat.Repo.Migrations.AddReplyToIdToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :reply_to_id, :integer
    end
  end
end
