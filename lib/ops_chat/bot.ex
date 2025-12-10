defmodule OpsChat.Bot do
  @moduledoc """
  Bot command processor for DevOps operations.
  Currently supports local commands. SSH integration coming soon.
  """

  alias OpsChat.Audit

  @help_text """
  Mavjud buyruqlar:

  /help          - Bu yordam xabarini ko'rsatish
  /status        - Tizim holati
  /uptime        - Tizim ishlash vaqti
  /disk          - Disk holati
  /memory        - Xotira holati
  /cpu           - CPU holati
  /logs [n]      - Oxirgi n qator system log (default: 20)
  /ps            - Eng ko'p resurs ishlatayotgan jarayonlar
  /network       - Tarmoq interfeyslari
  /who           - Tizimga kirgan foydalanuvchilar
  """

  def execute_command(command, user) do
    [cmd | args] = command |> String.trim() |> String.split(" ", trim: true)

    result = case cmd do
      "/help" -> {:ok, @help_text}
      "/status" -> run_status()
      "/uptime" -> run_command("uptime")
      "/disk" -> run_command("df -h")
      "/memory" -> run_memory()
      "/cpu" -> run_cpu()
      "/logs" -> run_logs(args)
      "/ps" -> run_ps()
      "/network" -> run_network()
      "/who" -> run_command("who")
      _ -> {:error, "Noma'lum buyruq: #{cmd}\n/help - buyruqlar ro'yxati"}
    end

    case result do
      {:ok, output} ->
        log_audit(user.id, cmd, "local", output, "success")
        output

      {:error, error} ->
        log_audit(user.id, cmd, "local", error, "error")
        "Xatolik: #{error}"
    end
  end

  defp run_status do
    hostname = run_command("hostname") |> elem(1) |> String.trim()
    uptime = run_command("uptime") |> elem(1) |> String.trim()
    {_, disk} = run_command("df -h / | tail -1")
    {_, mem} = run_memory()

    output = """
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
        # macOS
        {_, vm_stat} = run_command("vm_stat")
        {_, total} = run_command("sysctl -n hw.memsize")

        total_gb = String.trim(total) |> String.to_integer() |> div(1024 * 1024 * 1024)

        {:ok, "Total: #{total_gb} GB\n#{vm_stat}"}

      {:unix, _} ->
        # Linux
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
      [n] -> String.to_integer(n)
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

  defp log_audit(user_id, action, target, result, status) do
    Audit.log_command(user_id, action, target, result, status)
  end
end
