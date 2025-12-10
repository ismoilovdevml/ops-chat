defmodule OpsChat.Chat.Message do
  @moduledoc """
  Message schema for chat messages in channels.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias OpsChat.Accounts.User
  alias OpsChat.Chat.Channel

  @type_values ~w(user bot system alert)

  schema "messages" do
    field :content, :string
    field :type, :string, default: "user"
    field :reply_to_id, :integer

    belongs_to :user, User
    belongs_to :channel, Channel

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :user_id, :type, :channel_id, :reply_to_id])
    |> validate_required([:content])
    |> validate_inclusion(:type, @type_values)
    |> validate_length(:content, min: 1, max: 10_000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:channel_id)
  end
end
