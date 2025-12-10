defmodule OpsChat.Audit.Log do
  @moduledoc "Audit log entry schema for tracking command executions."

  use Ecto.Schema
  import Ecto.Changeset

  schema "audit_logs" do
    # command executed: status, disk, restart, etc.
    field :action, :string
    # target server/service
    field :target, :string
    # command output
    field :result, :string
    # success, error
    field :status, :string, default: "success"

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
