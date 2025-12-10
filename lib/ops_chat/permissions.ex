defmodule OpsChat.Permissions do
  @moduledoc """
  Role-based access control for bot commands.

  Roles:
  - admin: Full access to all commands
  - user: Read-only commands (status, logs, etc.)
  """

  # Commands that require admin role
  @admin_commands [
    "/restart",
    "/stop",
    "/start",
    "/kill",
    "/ssh add",
    "/ssh remove",
    "/ssh delete",
    "/exec",
    "/run"
  ]

  # Commands available to all users
  @user_commands [
    "/help",
    "/status",
    "/uptime",
    "/disk",
    "/memory",
    "/cpu",
    "/logs",
    "/ps",
    "/network",
    "/who",
    "/ssh list",
    "/ssh test",
    "/servers"
  ]

  @doc """
  Check if user has permission to execute a command.
  """
  def can_execute?(user, command) do
    role = user.role || "user"
    cmd = extract_command(command)

    cond do
      role == "admin" ->
        true

      is_admin_command?(cmd) ->
        false

      true ->
        true
    end
  end

  @doc """
  Get list of commands available for a role.
  """
  def available_commands(role) do
    case role do
      "admin" -> @admin_commands ++ @user_commands
      _ -> @user_commands
    end
  end

  @doc """
  Check if a command requires admin privileges.
  """
  def is_admin_command?(command) do
    cmd = extract_command(command)
    Enum.any?(@admin_commands, fn admin_cmd ->
      String.starts_with?(cmd, admin_cmd)
    end)
  end

  @doc """
  Get permission denied message.
  """
  def denied_message(command) do
    """
    Ruxsat berilmagan!

    '#{extract_command(command)}' buyrug'i faqat admin uchun.
    Sizning rolingiz: user

    Sizga ruxsat berilgan buyruqlar: /help
    """
  end

  # Extract the command part (e.g., "/ssh add" from "/ssh add server1 ...")
  defp extract_command(command) do
    command
    |> String.trim()
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.join(" ")
    |> String.trim()
  end
end
