defmodule OpsChat.SSH do
  @moduledoc """
  SSH connection and command execution module.
  Uses Erlang's built-in :ssh library.
  """

  alias OpsChat.Servers
  alias OpsChat.Servers.Server

  @timeout 30_000

  @doc """
  Execute a command on a remote server by server name.
  """
  def execute(server_name, command) when is_binary(server_name) do
    case Servers.get_server_by_name(server_name) do
      nil -> {:error, "Server '#{server_name}' topilmadi"}
      server -> execute_on_server(server, command)
    end
  end

  @doc """
  Execute a command on a server struct.
  """
  def execute_on_server(%Server{} = server, command) do
    opts = build_connection_opts(server)

    with {:ok, conn} <- connect(server.host, server.port, opts),
         {:ok, result} <- run_command(conn, command) do
      disconnect(conn)
      {:ok, result}
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Test connection to a server.
  """
  def test_connection(%Server{} = server) do
    opts = build_connection_opts(server)

    case connect(server.host, server.port, opts) do
      {:ok, conn} ->
        disconnect(conn)
        {:ok, "Ulanish muvaffaqiyatli!"}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  def test_connection(server_name) when is_binary(server_name) do
    case Servers.get_server_by_name(server_name) do
      nil -> {:error, "Server '#{server_name}' topilmadi"}
      server -> test_connection(server)
    end
  end

  # Private functions

  defp build_connection_opts(%Server{} = server) do
    # Create temp SSH dir if needed to prevent Erlang SSH from failing
    tmp_ssh_dir = "/tmp/ops_chat_ssh"
    File.mkdir_p(tmp_ssh_dir)

    base_opts = [
      user: String.to_charlist(server.username),
      silently_accept_hosts: true,
      user_interaction: false,
      connect_timeout: @timeout,
      user_dir: String.to_charlist(tmp_ssh_dir)
    ]

    case server.auth_type do
      "password" ->
        # Password auth
        base_opts ++ [password: String.to_charlist(server.password)]

      "key" ->
        # Key auth - check for custom key or use default SSH dir
        home = System.get_env("HOME") || "/root"
        ssh_dir = Path.join(home, ".ssh")

        key_opts = if server.private_key && server.private_key != "" do
          # Custom private key provided
          case decode_private_key(server.private_key) do
            {:ok, key} -> [key_cb: {__MODULE__.KeyCallback, key: key}]
            _ -> []
          end
        else
          # Use default SSH keys from ~/.ssh/ if exists
          if File.dir?(ssh_dir) do
            [user_dir: String.to_charlist(ssh_dir)]
          else
            []
          end
        end
        base_opts ++ key_opts

      _ ->
        base_opts
    end
  end

  defp connect(host, port, opts) do
    host_charlist = String.to_charlist(host)

    try do
      case :ssh.connect(host_charlist, port, opts, @timeout) do
        {:ok, conn} -> {:ok, conn}
        {:error, reason} -> {:error, reason}
      end
    catch
      :error, {:badmatch, {:error, reason}} -> {:error, {:badmatch, {:error, reason}}}
      :error, reason -> {:error, reason}
      :exit, reason -> {:error, {:exit, reason}}
    end
  end

  defp run_command(conn, command) do
    case :ssh_connection.session_channel(conn, @timeout) do
      {:ok, channel} ->
        :ssh_connection.exec(conn, channel, String.to_charlist(command), @timeout)
        collect_response(conn, channel, "")

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp collect_response(conn, channel, acc) do
    receive do
      {:ssh_cm, ^conn, {:data, ^channel, _type, data}} ->
        # Handle both charlist and binary data
        str_data = to_string_safe(data)
        collect_response(conn, channel, acc <> str_data)

      {:ssh_cm, ^conn, {:eof, ^channel}} ->
        collect_response(conn, channel, acc)

      {:ssh_cm, ^conn, {:exit_status, ^channel, status}} ->
        collect_response_with_status(conn, channel, acc, status)

      {:ssh_cm, ^conn, {:closed, ^channel}} ->
        {:ok, String.trim(acc)}
    after
      @timeout ->
        {:error, :timeout}
    end
  end

  defp to_string_safe(data) when is_list(data), do: List.to_string(data)
  defp to_string_safe(data) when is_binary(data), do: data
  defp to_string_safe(data), do: inspect(data)

  defp collect_response_with_status(conn, channel, acc, _status) do
    receive do
      {:ssh_cm, ^conn, {:closed, ^channel}} ->
        {:ok, String.trim(acc)}
    after
      1000 ->
        {:ok, String.trim(acc)}
    end
  end

  defp disconnect(conn) do
    :ssh.close(conn)
  end

  defp decode_private_key(key_content) do
    try do
      entries = :public_key.pem_decode(key_content)

      case entries do
        [{type, der, _}] ->
          key = :public_key.pem_entry_decode({type, der, :not_encrypted})
          {:ok, key}

        _ ->
          {:error, :invalid_key}
      end
    rescue
      _ -> {:error, :invalid_key}
    end
  end

  defp format_error(:timeout), do: "Ulanish vaqti tugadi (timeout)"
  defp format_error(:nxdomain), do: "Server topilmadi (DNS xatosi)"
  defp format_error(:econnrefused), do: "Ulanish rad etildi"
  defp format_error(:ehostunreach), do: "Serverga yetib bo'lmadi"
  defp format_error(:eacces), do: "SSH kalit fayliga kirishga ruxsat yo'q"
  defp format_error({:badmatch, {:error, :eacces}}), do: "SSH kalit fayliga kirishga ruxsat yo'q (~/.ssh/)"
  defp format_error({:badmatch, {:error, reason}}), do: "Autentifikatsiya xatosi: #{inspect(reason)}"
  defp format_error({:badmatch, _}), do: "Autentifikatsiya xatosi"
  defp format_error({:options, {:user_dir, _}}), do: "SSH kalit katalogi topilmadi (~/.ssh/)"
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  # Key callback module for custom private keys
  defmodule KeyCallback do
    @behaviour :ssh_client_key_api

    def add_host_key(_host, _port, _key, _opts), do: :ok

    def is_host_key(_key, _host, _port, _alg, _opts), do: true

    def user_key(alg, opts) do
      key = Keyword.get(opts, :key)
      if key && key_algorithm(key) == alg do
        {:ok, key}
      else
        {:error, :no_matching_key}
      end
    end

    defp key_algorithm({:RSAPrivateKey, _, _, _, _, _, _, _, _, _, _}), do: :"ssh-rsa"
    defp key_algorithm({:ECPrivateKey, _, _, _, _, _}), do: :"ecdsa-sha2-nistp256"
    defp key_algorithm(_), do: :unknown
  end
end
