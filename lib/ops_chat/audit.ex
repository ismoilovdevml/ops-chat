defmodule OpsChat.Audit do
  @moduledoc """
  The Audit context - command audit logging and statistics.
  """

  import Ecto.Query

  alias OpsChat.Repo
  alias OpsChat.Audit.Log

  # ============ Logging ============

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

  # ============ Queries ============

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
    |> preload(:user)
    |> Repo.all()
  end

  def list_logs_by_date(date, limit \\ 100) do
    start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

    Log
    |> where([l], l.inserted_at >= ^start_of_day and l.inserted_at <= ^end_of_day)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
  end

  def list_logs_by_status(status, limit \\ 100) do
    Log
    |> where(status: ^status)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
  end

  # ============ Statistics ============

  def count_total_logs do
    Repo.aggregate(Log, :count)
  end

  def count_logs_today do
    today = Date.utc_today()
    start_of_day = DateTime.new!(today, ~T[00:00:00], "Etc/UTC")

    Log
    |> where([l], l.inserted_at >= ^start_of_day)
    |> Repo.aggregate(:count)
  end

  def count_by_status do
    Log
    |> group_by(:status)
    |> select([l], {l.status, count(l.id)})
    |> Repo.all()
    |> Map.new()
  end

  def count_by_action(limit \\ 10) do
    Log
    |> group_by(:action)
    |> select([l], {l.action, count(l.id)})
    |> order_by([l], desc: count(l.id))
    |> limit(^limit)
    |> Repo.all()
  end

  def count_by_target(limit \\ 10) do
    Log
    |> where([l], not is_nil(l.target) and l.target != "")
    |> group_by(:target)
    |> select([l], {l.target, count(l.id)})
    |> order_by([l], desc: count(l.id))
    |> limit(^limit)
    |> Repo.all()
  end

  def count_by_user(limit \\ 10) do
    Log
    |> join(:left, [l], u in assoc(l, :user))
    |> group_by([l, u], u.username)
    |> select([l, u], {u.username, count(l.id)})
    |> order_by([l, u], desc: count(l.id))
    |> limit(^limit)
    |> Repo.all()
  end

  def count_by_hour_today do
    today = Date.utc_today()
    start_of_day = DateTime.new!(today, ~T[00:00:00], "Etc/UTC")

    Log
    |> where([l], l.inserted_at >= ^start_of_day)
    |> select([l], {fragment("strftime('%H', ?)", l.inserted_at), count(l.id)})
    |> group_by([l], fragment("strftime('%H', ?)", l.inserted_at))
    |> order_by([l], fragment("strftime('%H', ?)", l.inserted_at))
    |> Repo.all()
  end

  def count_by_day(days \\ 7) do
    start_date = Date.add(Date.utc_today(), -days)
    start_datetime = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")

    Log
    |> where([l], l.inserted_at >= ^start_datetime)
    |> select([l], {fragment("date(?)", l.inserted_at), count(l.id)})
    |> group_by([l], fragment("date(?)", l.inserted_at))
    |> order_by([l], fragment("date(?)", l.inserted_at))
    |> Repo.all()
  end

  def recent_failures(limit \\ 20) do
    Log
    |> where(status: "error")
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
  end

  def get_stats do
    %{
      total: count_total_logs(),
      today: count_logs_today(),
      by_status: count_by_status(),
      by_action: count_by_action(),
      by_target: count_by_target(),
      by_user: count_by_user(),
      by_hour: count_by_hour_today(),
      by_day: count_by_day()
    }
  end
end
