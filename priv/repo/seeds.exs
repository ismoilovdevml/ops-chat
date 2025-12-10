# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# For production, set environment variables:
#     ADMIN_USERNAME, ADMIN_PASSWORD, USER_USERNAME, USER_PASSWORD

alias OpsChat.Accounts

admin_username = System.get_env("ADMIN_USERNAME", "admin")
admin_password = System.get_env("ADMIN_PASSWORD", "admin123")
user_username = System.get_env("USER_USERNAME", "devops")
user_password = System.get_env("USER_PASSWORD", "devops123")

# Create admin user
case Accounts.get_user_by_username(admin_username) do
  nil ->
    {:ok, _user} =
      Accounts.create_user(%{
        username: admin_username,
        password: admin_password,
        role: "admin"
      })

    IO.puts("Admin user created: #{admin_username}")

  _user ->
    IO.puts("Admin user already exists")
end

# Create a regular user
case Accounts.get_user_by_username(user_username) do
  nil ->
    {:ok, _user} =
      Accounts.create_user(%{
        username: user_username,
        password: user_password,
        role: "user"
      })

    IO.puts("User created: #{user_username}")

  _user ->
    IO.puts("User already exists")
end
