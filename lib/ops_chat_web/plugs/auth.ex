defmodule OpsChatWeb.Plugs.Auth do
  @moduledoc """
  Authentication plug for session-based auth.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias OpsChat.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    if user_id do
      user = Accounts.get_user(user_id)

      if user do
        assign(conn, :current_user, user)
      else
        conn
        |> clear_session()
        |> assign(:current_user, nil)
      end
    else
      assign(conn, :current_user, nil)
    end
  end

  def require_auth(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "Tizimga kirishingiz kerak")
      |> redirect(to: "/login")
      |> halt()
    end
  end

  def login(conn, user) do
    conn
    |> put_session(:user_id, user.id)
    |> configure_session(renew: true)
  end

  def logout(conn) do
    conn
    |> clear_session()
    |> configure_session(drop: true)
  end
end
