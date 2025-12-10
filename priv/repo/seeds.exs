# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs

alias OpsChat.Accounts

# Create admin user
case Accounts.get_user_by_username("admin") do
  nil ->
    {:ok, _user} = Accounts.create_user(%{
      username: "admin",
      password: "admin123",
      role: "admin"
    })
    IO.puts("Admin user created: admin / admin123")

  _user ->
    IO.puts("Admin user already exists")
end

# Create a regular user for testing
case Accounts.get_user_by_username("devops") do
  nil ->
    {:ok, _user} = Accounts.create_user(%{
      username: "devops",
      password: "devops123",
      role: "user"
    })
    IO.puts("DevOps user created: devops / devops123")

  _user ->
    IO.puts("DevOps user already exists")
end
