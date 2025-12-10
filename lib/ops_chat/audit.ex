defmodule OpsChat.Audit do
  @moduledoc """
  The Audit context - command audit logging.
  """

  import Ecto.Query
  alias OpsChat.Repo
  alias OpsChat.Audit.Log

  def log_command(user_id, action, target, result, status \\ "success") do
    %Log{}
    |> Log.changeset(%{
      user_id: user_id,
      action: action,
      target: target,
      result: result,
      status: status
    })
    |> Repo.insert()
  end

  def list_logs(limit \\ 100) do
    Log
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
  end

  def list_logs_by_user(user_id, limit \\ 50) do
    Log
    |> where(user_id: ^user_id)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end
end
