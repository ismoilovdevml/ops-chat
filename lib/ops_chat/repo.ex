defmodule OpsChat.Repo do
  use Ecto.Repo,
    otp_app: :ops_chat,
    adapter: Ecto.Adapters.SQLite3
end
