defmodule OpsChat.Chat do
  @moduledoc """
  The Chat context - channels and messages management.
  """

  import Ecto.Query

  alias OpsChat.Chat.{Channel, Message}
  alias OpsChat.Repo

  # ============ Channels ============

  def list_channels do
    Channel
    |> order_by([c], [c.position, c.name])
    |> Repo.all()
  end

  def list_channels_by_type(type) do
    Channel
    |> where([c], c.type == ^type)
    |> order_by([c], [c.position, c.name])
    |> Repo.all()
  end

  def get_channel(id), do: Repo.get(Channel, id)

  def get_channel!(id), do: Repo.get!(Channel, id)

  def get_channel_by_slug(slug), do: Repo.get_by(Channel, slug: slug)

  def get_channel_by_slug!(slug), do: Repo.get_by!(Channel, slug: slug)

  def get_default_channel do
    get_channel_by_slug("general") || List.first(list_channels())
  end

  def create_channel(attrs) do
    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()
  end

  def update_channel(%Channel{} = channel, attrs) do
    channel
    |> Channel.changeset(attrs)
    |> Repo.update()
  end

  def delete_channel(%Channel{} = channel) do
    Repo.delete(channel)
  end

  def ensure_default_channels do
    defaults = [
      %{
        name: "general",
        slug: "general",
        type: "general",
        icon: "💬",
        description: "Umumiy chat",
        position: 0
      },
      %{
        name: "alerts",
        slug: "alerts",
        type: "general",
        icon: "🚨",
        description: "Tizim ogohlantirishlari",
        position: 1
      },
      %{
        name: "deployments",
        slug: "deployments",
        type: "general",
        icon: "🚀",
        description: "Deploy loglar",
        position: 2
      }
    ]

    Enum.each(defaults, fn channel_attrs ->
      case get_channel_by_slug(channel_attrs.slug) do
        nil -> create_channel(channel_attrs)
        _ -> :ok
      end
    end)
  end

  def create_server_channel(server) do
    create_channel(%{
      name: "server-#{server.name}",
      slug: "server-#{server.name}",
      type: "server",
      icon: "🖥️",
      description: "#{server.name} server xabarlari",
      server_id: server.id
    })
  end

  # ============ Messages ============

  def list_messages(channel_id, limit \\ 100)

  def list_messages(channel_id, limit) when is_integer(channel_id) do
    Message
    |> where([m], m.channel_id == ^channel_id)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
    |> Enum.reverse()
  end

  def list_all_messages(limit \\ 100) do
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
      {:ok, message} -> {:ok, Repo.preload(message, :user)}
      error -> error
    end
  end

  def create_channel_message(channel_id, user_id, content, type \\ "user") do
    create_message(%{
      content: content,
      user_id: user_id,
      channel_id: channel_id,
      type: type
    })
  end

  def create_bot_message(content, user_id, channel_id \\ nil) do
    create_message(%{content: content, user_id: user_id, channel_id: channel_id, type: "bot"})
  end

  def create_system_message(content, user_id, channel_id \\ nil) do
    create_message(%{content: content, user_id: user_id, channel_id: channel_id, type: "system"})
  end

  def create_alert_message(content, channel_id \\ nil) do
    # Alerts channel ga yozish
    channel_id = channel_id || (get_channel_by_slug("alerts") && get_channel_by_slug("alerts").id)
    create_message(%{content: content, channel_id: channel_id, type: "alert"})
  end

  def count_unread_messages(channel_id, last_read_at) do
    Message
    |> where([m], m.channel_id == ^channel_id)
    |> where([m], m.inserted_at > ^last_read_at)
    |> Repo.aggregate(:count)
  end
end
