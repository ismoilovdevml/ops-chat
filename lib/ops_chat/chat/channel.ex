defmodule OpsChat.Chat.Channel do
  @moduledoc """
  Channel schema for Discord-style chat rooms.

  Types:
  - "general" - Default channels (general, alerts)
  - "server" - Auto-created for each server
  - "custom" - User-created channels
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias OpsChat.Accounts.User

  @type_values ~w(general server custom)

  schema "channels" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :type, :string, default: "custom"
    field :icon, :string, default: "💬"
    field :position, :integer, default: 0
    field :is_private, :boolean, default: false
    field :server_id, :integer

    belongs_to :user, User
    has_many :messages, OpsChat.Chat.Message

    timestamps(type: :utc_datetime)
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :type,
      :icon,
      :position,
      :is_private,
      :user_id,
      :server_id
    ])
    |> validate_required([:name, :slug])
    |> validate_inclusion(:type, @type_values)
    |> validate_length(:name, min: 1, max: 50)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/, message: "faqat kichik harflar, raqamlar va tire")
    |> unique_constraint(:slug)
    |> unique_constraint(:name)
    |> generate_slug()
  end

  defp generate_slug(changeset) do
    case get_change(changeset, :slug) do
      nil ->
        case get_change(changeset, :name) do
          nil -> changeset
          name -> put_change(changeset, :slug, slugify(name))
        end

      _ ->
        changeset
    end
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end
end
