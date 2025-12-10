defmodule OpsChat.Chat do
  @moduledoc """
  The Chat context - message management.
  """

  import Ecto.Query
  alias OpsChat.Repo
  alias OpsChat.Chat.Message

  def list_messages(limit \\ 100) do
    Message
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
    |> Enum.reverse()
  end

  def create_message(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        {:ok, Repo.preload(message, :user)}

      error ->
        error
    end
  end

  def create_bot_message(content, user_id) do
    create_message(%{content: content, user_id: user_id, type: "bot"})
  end

  def create_system_message(content, user_id) do
    create_message(%{content: content, user_id: user_id, type: "system"})
  end
end
