defmodule OpsChatWeb.SessionController do
  use OpsChatWeb, :controller

  alias OpsChat.Accounts
  alias OpsChatWeb.Plugs.Auth

  def new(conn, _params) do
    render(conn, :new)
  end

  def create(conn, %{"user" => %{"username" => username, "password" => password}}) do
    case Accounts.authenticate(username, password) do
      {:ok, user} ->
        conn
        |> Auth.login(user)
        |> put_flash(:info, "Xush kelibsiz, #{user.username}!")
        |> redirect(to: "/chat")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Login yoki parol xato")
        |> render(:new)
    end
  end

  def delete(conn, _params) do
    conn
    |> Auth.logout()
    |> put_flash(:info, "Chiqish muvaffaqiyatli")
    |> redirect(to: "/login")
  end
end
