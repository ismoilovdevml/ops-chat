defmodule OpsChat.Permissions do
  @moduledoc """
  Role-based access control for bot commands.
  """

  @admin_commands ~w(/restart /stop /start /kill /exec /run)
  @admin_prefixes ["/ssh add", "/ssh remove", "/ssh delete"]

  @user_commands ~w(/help /status /uptime /disk /memory /cpu /logs /ps /network /who /servers)

  def can_execute?(user, command) do
    case user.role do
      "admin" -> true
      _ -> not admin_command?(command)
    end
  end

  def admin_command?(command) do
    cmd = normalize_command(command)

    Enum.any?(@admin_commands, &(cmd == &1)) or
      Enum.any?(@admin_prefixes, &String.starts_with?(cmd, &1))
  end

  def available_commands("admin"), do: @admin_commands ++ @user_commands
  def available_commands(_), do: @user_commands

  def denied_message(command) do
    """
    ⛔ Ruxsat berilmagan!

    '#{normalize_command(command)}' buyrug'i faqat admin uchun.
    Ruxsat berilgan buyruqlar uchun: /help
    """
  end

  defp normalize_command(command) do
    command
    |> String.trim()
    |> String.split(" ", parts: 3)
    |> Enum.take(2)
    |> Enum.join(" ")
  end
end
