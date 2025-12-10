defmodule OpsChat.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :content, :string
    field :type, :string, default: "user"  # user, bot, system

    belongs_to :user, OpsChat.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :user_id, :type])
    |> validate_required([:content, :user_id])
    |> validate_inclusion(:type, ["user", "bot", "system"])
    |> foreign_key_constraint(:user_id)
  end
end
