defmodule OpsChat.Servers.Server do
  use Ecto.Schema
  import Ecto.Changeset

  schema "servers" do
    field :name, :string
    field :host, :string
    field :port, :integer, default: 22
    field :username, :string
    field :auth_type, :string, default: "key"  # key, password
    field :private_key, :string
    field :password, :string
    field :description, :string

    belongs_to :user, OpsChat.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(server, attrs) do
    server
    |> cast(attrs, [:name, :host, :port, :username, :auth_type, :private_key, :password, :description, :user_id])
    |> validate_required([:name, :host, :username, :user_id])
    |> validate_inclusion(:auth_type, ["key", "password"])
    |> validate_number(:port, greater_than: 0, less_than: 65536)
    |> unique_constraint(:name)
    |> validate_auth()
  end

  defp validate_auth(changeset) do
    auth_type = get_field(changeset, :auth_type)

    case auth_type do
      "password" ->
        validate_required(changeset, [:password])

      "key" ->
        changeset

      _ ->
        changeset
    end
  end
end
