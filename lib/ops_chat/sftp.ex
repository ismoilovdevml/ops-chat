defmodule OpsChat.SFTP do
  @moduledoc """
  SFTP file operations module.
  Uses Erlang's :ssh_sftp library for remote file management.
  """

  alias OpsChat.Servers
  alias OpsChat.Servers.Server

  @timeout 30_000

  @doc """
  List directory contents on a remote server.
  """
  def list_dir(server_name, path) when is_binary(server_name) do
    case Servers.get_server_by_name(server_name) do
      nil -> {:error, "Server '#{server_name}' topilmadi"}
      server -> list_dir_on_server(server, path)
    end
  end

  def list_dir_on_server(%Server{} = server, path) do
    with {:ok, {conn, sftp}} <- connect_sftp(server),
         {:ok, files} <- do_list_dir(sftp, path) do
      disconnect(conn)
      {:ok, files}
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Get file info (size, permissions, etc.)
  """
  def stat(server_name, path) when is_binary(server_name) do
    case Servers.get_server_by_name(server_name) do
      nil -> {:error, "Server '#{server_name}' topilmadi"}
      server -> stat_on_server(server, path)
    end
  end

  def stat_on_server(%Server{} = server, path) do
    with {:ok, {conn, sftp}} <- connect_sftp(server),
         {:ok, info} <- do_stat(sftp, path) do
      disconnect(conn)
      {:ok, info}
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Read file contents.
  """
  def read_file(server_name, path) when is_binary(server_name) do
    case Servers.get_server_by_name(server_name) do
      nil -> {:error, "Server '#{server_name}' topilmadi"}
      server -> read_file_on_server(server, path)
    end
  end

  def read_file_on_server(%Server{} = server, path) do
    with {:ok, {conn, sftp}} <- connect_sftp(server),
         {:ok, content} <- do_read_file(sftp, path) do
      disconnect(conn)
      {:ok, content}
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Write file contents.
  """
  def write_file(server_name, path, content) when is_binary(server_name) do
    case Servers.get_server_by_name(server_name) do
      nil -> {:error, "Server '#{server_name}' topilmadi"}
      server -> write_file_on_server(server, path, content)
    end
  end

  def write_file_on_server(%Server{} = server, path, content) do
    with {:ok, {conn, sftp}} <- connect_sftp(server),
         :ok <- do_write_file(sftp, path, content) do
      disconnect(conn)
      :ok
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Delete a file.
  """
  def delete_file(server_name, path) when is_binary(server_name) do
    case Servers.get_server_by_name(server_name) do
      nil -> {:error, "Server '#{server_name}' topilmadi"}
      server -> delete_file_on_server(server, path)
    end
  end

  def delete_file_on_server(%Server{} = server, path) do
    with {:ok, {conn, sftp}} <- connect_sftp(server),
         :ok <- do_delete_file(sftp, path) do
      disconnect(conn)
      :ok
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Create a directory.
  """
  def mkdir(server_name, path) when is_binary(server_name) do
    case Servers.get_server_by_name(server_name) do
      nil -> {:error, "Server '#{server_name}' topilmadi"}
      server -> mkdir_on_server(server, path)
    end
  end

  def mkdir_on_server(%Server{} = server, path) do
    with {:ok, {conn, sftp}} <- connect_sftp(server),
         :ok <- do_mkdir(sftp, path) do
      disconnect(conn)
      :ok
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Remove a directory.
  """
  def rmdir(server_name, path) when is_binary(server_name) do
    case Servers.get_server_by_name(server_name) do
      nil -> {:error, "Server '#{server_name}' topilmadi"}
      server -> rmdir_on_server(server, path)
    end
  end

  def rmdir_on_server(%Server{} = server, path) do
    with {:ok, {conn, sftp}} <- connect_sftp(server),
         :ok <- do_rmdir(sftp, path) do
      disconnect(conn)
      :ok
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  Rename/move a file or directory.
  """
  def rename(server_name, old_path, new_path) when is_binary(server_name) do
    case Servers.get_server_by_name(server_name) do
      nil -> {:error, "Server '#{server_name}' topilmadi"}
      server -> rename_on_server(server, old_path, new_path)
    end
  end

  def rename_on_server(%Server{} = server, old_path, new_path) do
    with {:ok, {conn, sftp}} <- connect_sftp(server),
         :ok <- do_rename(sftp, old_path, new_path) do
      disconnect(conn)
      :ok
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  # Private functions

  defp connect_sftp(%Server{} = server) do
    opts = build_connection_opts(server)
    host = String.to_charlist(server.host)

    try do
      case :ssh.connect(host, server.port, opts, @timeout) do
        {:ok, conn} ->
          case :ssh_sftp.start_channel(conn, timeout: @timeout) do
            {:ok, sftp} -> {:ok, {conn, sftp}}
            {:error, reason} -> {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    catch
      :error, reason -> {:error, reason}
      :exit, reason -> {:error, {:exit, reason}}
    end
  end

  defp build_connection_opts(%Server{} = server) do
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
        base_opts ++ [password: String.to_charlist(server.password)]

      "key" ->
        home = System.get_env("HOME") || "/root"
        ssh_dir = Path.join(home, ".ssh")

        key_opts =
          if server.private_key && server.private_key != "" do
            case decode_private_key(server.private_key) do
              {:ok, key} -> [key_cb: {OpsChat.SSH.KeyCallback, key: key}]
              _ -> []
            end
          else
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

  defp do_list_dir(sftp, path) do
    path_chars = String.to_charlist(path)

    case :ssh_sftp.list_dir(sftp, path_chars, @timeout) do
      {:ok, files} ->
        file_list =
          files
          |> Enum.reject(&(&1 in [~c".", ~c".."]))
          |> Enum.map(&List.to_string/1)
          |> Enum.sort()

        # Get detailed info for each file
        detailed =
          Enum.map(file_list, fn name ->
            full_path = Path.join(path, name)
            info = get_file_info(sftp, full_path)
            Map.merge(%{name: name, path: full_path}, info)
          end)

        {:ok, detailed}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_file_info(sftp, path) do
    path_chars = String.to_charlist(path)

    case :ssh_sftp.read_file_info(sftp, path_chars, @timeout) do
      {:ok, info} ->
        type =
          case elem(info, 1) do
            :directory -> :directory
            :regular -> :file
            :symlink -> :symlink
            _ -> :other
          end

        %{
          type: type,
          size: elem(info, 2),
          mtime: elem(info, 9),
          mode: elem(info, 4)
        }

      {:error, _} ->
        %{type: :unknown, size: 0, mtime: nil, mode: 0}
    end
  end

  defp do_stat(sftp, path) do
    path_chars = String.to_charlist(path)

    case :ssh_sftp.read_file_info(sftp, path_chars, @timeout) do
      {:ok, info} ->
        type =
          case elem(info, 1) do
            :directory -> :directory
            :regular -> :file
            :symlink -> :symlink
            _ -> :other
          end

        {:ok,
         %{
           type: type,
           size: elem(info, 2),
           atime: elem(info, 8),
           mtime: elem(info, 9),
           mode: elem(info, 4),
           uid: elem(info, 5),
           gid: elem(info, 6)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_read_file(sftp, path) do
    path_chars = String.to_charlist(path)

    case :ssh_sftp.read_file(sftp, path_chars, @timeout) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_write_file(sftp, path, content) do
    path_chars = String.to_charlist(path)

    case :ssh_sftp.write_file(sftp, path_chars, content, @timeout) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_delete_file(sftp, path) do
    path_chars = String.to_charlist(path)

    case :ssh_sftp.delete(sftp, path_chars, @timeout) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_mkdir(sftp, path) do
    path_chars = String.to_charlist(path)

    case :ssh_sftp.make_dir(sftp, path_chars, @timeout) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_rmdir(sftp, path) do
    path_chars = String.to_charlist(path)

    case :ssh_sftp.del_dir(sftp, path_chars, @timeout) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_rename(sftp, old_path, new_path) do
    old_chars = String.to_charlist(old_path)
    new_chars = String.to_charlist(new_path)

    case :ssh_sftp.rename(sftp, old_chars, new_chars, @timeout) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp disconnect(conn) do
    :ssh.close(conn)
  end

  defp decode_private_key(key_content) when is_binary(key_content) do
    key_content = String.trim(key_content)

    try do
      entries = :public_key.pem_decode(key_content)

      case entries do
        [] ->
          {:error, :invalid_key}

        [{type, der, :not_encrypted}] ->
          key = :public_key.pem_entry_decode({type, der, :not_encrypted})
          {:ok, key}

        _ ->
          {:error, :invalid_key}
      end
    rescue
      _ -> {:error, :invalid_key}
    end
  end

  defp decode_private_key(_), do: {:error, :invalid_key}

  defp format_error(:no_such_file), do: "Fayl yoki papka topilmadi"
  defp format_error(:permission_denied), do: "Ruxsat yo'q"
  defp format_error(:timeout), do: "Vaqt tugadi (timeout)"
  defp format_error(:enoent), do: "Fayl topilmadi"
  defp format_error(:eacces), do: "Kirishga ruxsat yo'q"
  defp format_error(:eisdir), do: "Bu papka, fayl emas"
  defp format_error(:enotdir), do: "Bu fayl, papka emas"
  defp format_error(:eexist), do: "Fayl allaqachon mavjud"
  defp format_error(:enotempty), do: "Papka bo'sh emas"
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
