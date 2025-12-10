defmodule OpsChat.Audit.Log do
  use Ecto.Schema
  import Ecto.Changeset

  schema "audit_logs" do
    field :action, :string      # command executed: status, disk, restart, etc.
    field :target, :string      # target server/service
    field :result, :string      # command output
    field :status, :string, default: "success"  # success, error

    belongs_to :user, OpsChat.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:action, :target, :result, :status, :user_id])
    |> validate_required([:action, :target, :user_id])
    |> validate_inclusion(:status, ["success", "error"])
    |> foreign_key_constraint(:user_id)
  end
end
