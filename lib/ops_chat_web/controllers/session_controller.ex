defmodule OpsChatWeb.SessionController do
  use OpsChatWeb, :controller

  alias OpsChat.Accounts
  alias OpsChatWeb.Plugs.Auth

  def login(conn, _params) do
    render(conn, :login)
  end

  def create(conn, %{"user" => %{"username" => username, "password" => password}}) do
    case Accounts.authenticate(username, password) do
      {:ok, user} ->
        conn
        |> Auth.login(user)
        |> put_flash(:info, "Xush kelibsiz, #{user.username}!")
        |> redirect(to: ~p"/chat")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Login yoki parol xato")
        |> render(:login)
    end
  end

  def logout(conn, _params) do
    conn
    |> Auth.logout()
    |> put_flash(:info, "Chiqish muvaffaqiyatli")
    |> redirect(to: ~p"/login")
  end
end
