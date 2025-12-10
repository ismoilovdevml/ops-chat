defmodule OpsChat.Bot do
  @moduledoc """
  Bot command processor for DevOps operations.
  Supports local and remote (SSH) commands with role-based access control.
  """

  alias OpsChat.Audit
  alias OpsChat.Permissions
  alias OpsChat.Servers
  alias OpsChat.SSH

  @help_text """
  === OpsChat Buyruqlar ===

  LOKAL BUYRUQLAR:
    /help              Yordam
    /status            Lokal tizim holati
    /uptime            Ishlash vaqti
    /disk              Disk holati
    /memory            Xotira holati
    /cpu               CPU holati
    /logs [n]          System log (default: 20)
    /ps                Top jarayonlar
    /network           Tarmoq interfeyslari
    /who               Kirgan foydalanuvchilar

  SERVER BOSHQARUVI:
    /servers           Serverlar ro'yxati
    /ssh list          Serverlar ro'yxati
    /ssh test <name>   Server ulanishini tekshirish
    /ssh add <name> <user@host> [port]  Server qo'shish (admin)
    /ssh remove <name> Server o'chirish (admin)

  REMOTE BUYRUQLAR:
    /r <server> <cmd>  Remote buyruq (masalan: /r web1 uptime)
    /rstatus <server>  Remote server holati
    /rdisk <server>    Remote disk holati
    /rmemory <server>  Remote xotira holati
    /rlogs <server>    Remote loglar

  ADMIN BUYRUQLARI:
    /restart <server> <service>  Service restart
    /exec <server> <cmd>         Ixtiyoriy buyruq
  """

  def execute_command(command, user) do
    # Check permissions
    if Permissions.can_execute?(user, command) do
      do_execute(command, user)
    else
      Permissions.denied_message(command)
    end
  end

  defp do_execute(command, user) do
    [cmd | args] = command |> String.trim() |> String.split(" ", trim: true)

    result = case cmd do
      # Help
      "/help" -> {:ok, @help_text}

      # Local commands
      "/status" -> run_status()
      "/uptime" -> run_command("uptime")
      "/disk" -> run_command("df -h")
      "/memory" -> run_memory()
      "/cpu" -> run_cpu()
      "/logs" -> run_logs(args)
      "/ps" -> run_ps()
      "/network" -> run_network()
      "/who" -> run_command("who")

      # Server management
      "/servers" -> list_servers()
      "/ssh" -> handle_ssh_command(args, user)

      # Remote commands
      "/r" -> remote_command(args, user)
      "/rstatus" -> remote_status(args, user)
      "/rdisk" -> remote_disk(args, user)
      "/rmemory" -> remote_memory(args, user)
      "/rlogs" -> remote_logs(args, user)

      # Admin commands
      "/restart" -> remote_restart(args, user)
      "/exec" -> remote_exec(args, user)

      _ -> {:error, "Noma'lum buyruq: #{cmd}\n/help - buyruqlar ro'yxati"}
    end

    case result do
      {:ok, output} ->
        log_audit(user.id, cmd, get_target(args), output, "success")
        output

      {:error, error} ->
        log_audit(user.id, cmd, get_target(args), error, "error")
        "Xatolik: #{error}"
    end
  end

  # ============ SSH Commands ============

  defp handle_ssh_command([], _user), do: list_servers()

  defp handle_ssh_command(["list" | _], _user), do: list_servers()

  defp handle_ssh_command(["test", name | _], _user) do
    case SSH.test_connection(name) do
      {:ok, msg} -> {:ok, "#{name}: #{msg}"}
      {:error, err} -> {:error, "#{name}: #{err}"}
    end
  end

  defp handle_ssh_command(["add", name, user_host | rest], user) do
    {username, host} = parse_user_host(user_host)
    port = case rest do
      [p | _] -> String.to_integer(p)
      _ -> 22
    end

    case Servers.create_server(%{
      name: name,
      host: host,
      port: port,
      username: username,
      auth_type: "key",
      user_id: user.id
    }) do
      {:ok, server} ->
        {:ok, """
        Server qo'shildi:
          Nomi: #{server.name}
          Host: #{server.host}
          Port: #{server.port}
          User: #{server.username}

        Tekshirish: /ssh test #{server.name}
        """}

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)
        {:error, "Server qo'shishda xatolik: #{errors}"}
    end
  end

  defp handle_ssh_command(["remove", name | _], _user) do
    case Servers.delete_server_by_name(name) do
      {:ok, _} -> {:ok, "Server '#{name}' o'chirildi"}
      {:error, :not_found} -> {:error, "Server '#{name}' topilmadi"}
      {:error, _} -> {:error, "Server o'chirishda xatolik"}
    end
  end

  defp handle_ssh_command(["delete" | rest], user) do
    handle_ssh_command(["remove" | rest], user)
  end

  defp handle_ssh_command(_, _user) do
    {:error, "Noto'g'ri ssh buyrug'i. /help ko'ring"}
  end

  defp list_servers do
    servers = Servers.list_servers()

    if Enum.empty?(servers) do
      {:ok, "Hech qanday server qo'shilmagan.\n\nServer qo'shish: /ssh add <name> <user@host> [port]"}
    else
      list = servers
      |> Enum.map(fn s ->
        "  #{s.name} → #{s.username}@#{s.host}:#{s.port}"
      end)
      |> Enum.join("\n")

      {:ok, "Serverlar:\n#{list}"}
    end
  end

  # ============ Remote Commands ============

  defp remote_command([], _user), do: {:error, "Foydalanish: /r <server> <command>"}
  defp remote_command([_server], _user), do: {:error, "Buyruq ko'rsatilmagan"}
  defp remote_command([server | cmd_parts], _user) do
    command = Enum.join(cmd_parts, " ")
    SSH.execute(server, command)
  end

  defp remote_status([], _user), do: {:error, "Server nomi kerak: /rstatus <server>"}
  defp remote_status([server | _], _user) do
    commands = [
      "hostname",
      "uptime",
      "df -h / | tail -1",
      "free -h 2>/dev/null || vm_stat | head -5"
    ]
    command = Enum.join(commands, " && echo '---' && ")

    case SSH.execute(server, command) do
      {:ok, output} -> {:ok, "=== #{server} Status ===\n#{output}"}
      error -> error
    end
  end

  defp remote_disk([], _user), do: {:error, "Server nomi kerak: /rdisk <server>"}
  defp remote_disk([server | _], _user) do
    case SSH.execute(server, "df -h") do
      {:ok, output} -> {:ok, "=== #{server} Disk ===\n#{output}"}
      error -> error
    end
  end

  defp remote_memory([], _user), do: {:error, "Server nomi kerak: /rmemory <server>"}
  defp remote_memory([server | _], _user) do
    cmd = "free -h 2>/dev/null || top -l 1 | head -10"
    case SSH.execute(server, cmd) do
      {:ok, output} -> {:ok, "=== #{server} Memory ===\n#{output}"}
      error -> error
    end
  end

  defp remote_logs([], _user), do: {:error, "Server nomi kerak: /rlogs <server>"}
  defp remote_logs([server | rest], _user) do
    lines = case rest do
      [n | _] -> n
      _ -> "20"
    end
    cmd = "journalctl -n #{lines} --no-pager 2>/dev/null || tail -#{lines} /var/log/syslog 2>/dev/null || tail -#{lines} /var/log/messages"
    case SSH.execute(server, cmd) do
      {:ok, output} -> {:ok, "=== #{server} Logs ===\n#{output}"}
      error -> error
    end
  end

  defp remote_restart([], _user), do: {:error, "Foydalanish: /restart <server> <service>"}
  defp remote_restart([_server], _user), do: {:error, "Service nomi kerak"}
  defp remote_restart([server, service | _], _user) do
    cmd = "sudo systemctl restart #{service} && systemctl status #{service} --no-pager"
    case SSH.execute(server, cmd) do
      {:ok, output} -> {:ok, "=== #{server} - #{service} restarted ===\n#{output}"}
      error -> error
    end
  end

  defp remote_exec([], _user), do: {:error, "Foydalanish: /exec <server> <command>"}
  defp remote_exec([_server], _user), do: {:error, "Buyruq kerak"}
  defp remote_exec([server | cmd_parts], _user) do
    command = Enum.join(cmd_parts, " ")
    case SSH.execute(server, command) do
      {:ok, output} -> {:ok, "=== #{server} ===\n$ #{command}\n\n#{output}"}
      error -> error
    end
  end

  # ============ Local Commands ============

  defp run_status do
    hostname = run_command("hostname") |> elem(1) |> String.trim()
    uptime = run_command("uptime") |> elem(1) |> String.trim()
    {_, disk} = run_command("df -h / | tail -1")
    {_, mem} = run_memory()

    output = """
    === Lokal Tizim ===
    Hostname: #{hostname}
    Uptime: #{uptime}

    Disk (/):
    #{disk}

    Memory:
    #{mem}
    """

    {:ok, output}
  end

  defp run_memory do
    case :os.type() do
      {:unix, :darwin} ->
        {_, vm_stat} = run_command("vm_stat")
        {_, total} = run_command("sysctl -n hw.memsize")
        total_gb = String.trim(total) |> String.to_integer() |> div(1024 * 1024 * 1024)
        {:ok, "Total: #{total_gb} GB\n#{vm_stat}"}

      {:unix, _} ->
        run_command("free -h")

      _ ->
        {:error, "Qo'llab-quvvatlanmaydigan OS"}
    end
  end

  defp run_cpu do
    case :os.type() do
      {:unix, :darwin} ->
        {_, load} = run_command("sysctl -n vm.loadavg")
        {_, cores} = run_command("sysctl -n hw.ncpu")
        {:ok, "Load Average: #{String.trim(load)}\nCPU Cores: #{String.trim(cores)}"}

      {:unix, _} ->
        run_command("top -bn1 | head -5")

      _ ->
        {:error, "Qo'llab-quvvatlanmaydigan OS"}
    end
  end

  defp run_logs(args) do
    lines = case args do
      [n | _] -> String.to_integer(n)
      _ -> 20
    end

    case :os.type() do
      {:unix, :darwin} ->
        run_command("log show --last 5m --style compact | tail -#{lines}")

      {:unix, _} ->
        run_command("journalctl -n #{lines} --no-pager")

      _ ->
        {:error, "Qo'llab-quvvatlanmaydigan OS"}
    end
  end

  defp run_ps do
    case :os.type() do
      {:unix, :darwin} ->
        run_command("ps aux | head -11")

      {:unix, _} ->
        run_command("ps aux --sort=-%mem | head -11")

      _ ->
        {:error, "Qo'llab-quvvatlanmaydigan OS"}
    end
  end

  defp run_network do
    case :os.type() do
      {:unix, :darwin} ->
        run_command("ifconfig | grep -E '^[a-z]|inet '")

      {:unix, _} ->
        run_command("ip addr | grep -E '^[0-9]|inet '")

      _ ->
        {:error, "Qo'llab-quvvatlanmaydigan OS"}
    end
  end

  defp run_command(cmd) do
    try do
      {output, exit_code} = System.cmd("sh", ["-c", cmd], stderr_to_stdout: true)

      if exit_code == 0 do
        {:ok, output}
      else
        {:error, "Exit code: #{exit_code}\n#{output}"}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  # ============ Helpers ============

  defp parse_user_host(user_host) do
    case String.split(user_host, "@") do
      [user, host] -> {user, host}
      [host] -> {"root", host}
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
    |> Enum.join("; ")
  end

  defp get_target([server | _]) when is_binary(server), do: server
  defp get_target(_), do: "local"

  defp log_audit(user_id, action, target, result, status) do
    # Truncate result if too long
    result = if String.length(result) > 10000 do
      String.slice(result, 0, 10000) <> "\n... (truncated)"
    else
      result
    end

    Audit.log_command(user_id, action, target, result, status)
  end
end
