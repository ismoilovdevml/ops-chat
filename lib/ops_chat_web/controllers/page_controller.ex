defmodule OpsChatWeb.PageController do
  use OpsChatWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
