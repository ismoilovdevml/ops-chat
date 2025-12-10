defmodule OpsChatWeb.HealthController do
  use OpsChatWeb, :controller

  def index(conn, _params) do
    # Check database connection
    db_status = check_database()

    status = if db_status == :ok, do: 200, else: 503

    conn
    |> put_status(status)
    |> json(%{
      status: if(status == 200, do: "healthy", else: "unhealthy"),
      database: db_status,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  defp check_database do
    try do
      OpsChat.Repo.query!("SELECT 1")
      :ok
    rescue
      _ -> :error
    end
  end
end
