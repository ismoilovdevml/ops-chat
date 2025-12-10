defmodule OpsChat.Servers do
  @moduledoc """
  The Servers context - SSH server management.
  """

  import Ecto.Query
  alias OpsChat.Repo
  alias OpsChat.Servers.Server

  def list_servers do
    Server
    |> order_by(:name)
    |> Repo.all()
  end

  def list_servers_by_user(user_id) do
    Server
    |> where(user_id: ^user_id)
    |> order_by(:name)
    |> Repo.all()
  end

  def get_server(id), do: Repo.get(Server, id)

  def get_server_by_name(name) do
    Repo.get_by(Server, name: name)
  end

  def create_server(attrs) do
    %Server{}
    |> Server.changeset(attrs)
    |> Repo.insert()
  end

  def update_server(%Server{} = server, attrs) do
    server
    |> Server.changeset(attrs)
    |> Repo.update()
  end

  def delete_server(%Server{} = server) do
    Repo.delete(server)
  end

  def delete_server_by_name(name) do
    case get_server_by_name(name) do
      nil -> {:error, :not_found}
      server -> delete_server(server)
    end
  end
end
