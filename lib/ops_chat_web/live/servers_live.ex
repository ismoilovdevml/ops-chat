defmodule OpsChatWeb.ServersLive do
  use OpsChatWeb, :live_view

  alias OpsChat.Servers
  alias OpsChat.Servers.Server

  @impl true
  def mount(_params, session, socket) do
    current_user = get_user_from_session(session)

    if current_user do
      servers = Servers.list_servers()

      {:ok,
       socket
       |> assign(:current_user, current_user)
       |> assign(:servers, servers)
       |> assign(:selected_servers, [])
       |> assign(:show_add_form, false)
       |> assign(:command_result, nil)
       |> assign(:running_command, false)
       |> assign(:form, to_form(%{"name" => "", "host" => "", "port" => "22", "username" => "", "auth_type" => "key", "password" => ""}))}
    else
      {:ok, redirect(socket, to: ~p"/login")}
    end
  end

  defp get_user_from_session(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> OpsChat.Accounts.get_user(user_id)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-300 p-4" data-theme="opschat">
      <div class="container mx-auto max-w-6xl">
        <!-- Header -->
        <div class="flex justify-between items-center mb-6">
          <div>
            <h1 class="text-3xl font-bold text-success">🖥️ Server Management</h1>
            <p class="text-base-content/70">Remote serverlarni boshqaring</p>
          </div>
          <div class="flex gap-2">
            <.link href={~p"/chat"} class="btn btn-ghost">
              ← Chat
            </.link>
            <%= if @current_user.role == "admin" do %>
              <button phx-click="toggle_add_form" class="btn btn-success">
                <%= if @show_add_form, do: "Bekor qilish", else: "+ Server qo'shish" %>
              </button>
            <% end %>
          </div>
        </div>

        <!-- Add Server Form -->
        <%= if @show_add_form do %>
          <div class="card bg-base-200 shadow-xl mb-6">
            <div class="card-body">
              <h2 class="card-title text-success">Yangi server qo'shish</h2>
              <.form for={@form} phx-submit="add_server" class="space-y-4">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div class="form-control">
                    <label class="label"><span class="label-text">Server nomi</span></label>
                    <input type="text" name="name" value={@form[:name].value} placeholder="web1" class="input input-bordered" required />
                  </div>
                  <div class="form-control">
                    <label class="label"><span class="label-text">Host</span></label>
                    <input type="text" name="host" value={@form[:host].value} placeholder="192.168.1.10" class="input input-bordered" required />
                  </div>
                  <div class="form-control">
                    <label class="label"><span class="label-text">Username</span></label>
                    <input type="text" name="username" value={@form[:username].value} placeholder="root" class="input input-bordered" required />
                  </div>
                  <div class="form-control">
                    <label class="label"><span class="label-text">Port</span></label>
                    <input type="number" name="port" value={@form[:port].value} placeholder="22" class="input input-bordered" />
                  </div>
                  <div class="form-control">
                    <label class="label"><span class="label-text">Auth type</span></label>
                    <select name="auth_type" class="select select-bordered">
                      <option value="key" selected={@form[:auth_type].value == "key"}>SSH Key</option>
                      <option value="password" selected={@form[:auth_type].value == "password"}>Password</option>
                    </select>
                  </div>
                  <div class="form-control">
                    <label class="label"><span class="label-text">Password (agar kerak bo'lsa)</span></label>
                    <input type="password" name="password" value={@form[:password].value} placeholder="••••••••" class="input input-bordered" />
                  </div>
                </div>
                <div class="card-actions justify-end">
                  <button type="submit" class="btn btn-success">Qo'shish</button>
                </div>
              </.form>
            </div>
          </div>
        <% end %>

        <!-- Command Panel -->
        <%= if length(@selected_servers) > 0 do %>
          <div class="card bg-base-200 shadow-xl mb-6">
            <div class="card-body">
              <h2 class="card-title text-primary">
                Tanlangan serverlar: <%= length(@selected_servers) %>
              </h2>
              <div class="flex flex-wrap gap-2 mb-4">
                <%= for server_name <- @selected_servers do %>
                  <span class="badge badge-primary badge-lg"><%= server_name %></span>
                <% end %>
              </div>

              <div class="flex flex-wrap gap-2">
                <button phx-click="run_command" phx-value-cmd="uptime" class={"btn btn-sm btn-outline #{if @running_command, do: "loading"}"} disabled={@running_command}>
                  Status
                </button>
                <button phx-click="run_command" phx-value-cmd="df -h" class={"btn btn-sm btn-outline #{if @running_command, do: "loading"}"} disabled={@running_command}>
                  Disk
                </button>
                <button phx-click="run_command" phx-value-cmd="free -h" class={"btn btn-sm btn-outline #{if @running_command, do: "loading"}"} disabled={@running_command}>
                  Memory
                </button>
                <button phx-click="run_command" phx-value-cmd="top -bn1 | head -20" class={"btn btn-sm btn-outline #{if @running_command, do: "loading"}"} disabled={@running_command}>
                  CPU/Processes
                </button>
                <%= if @current_user.role == "admin" do %>
                  <button phx-click="run_command" phx-value-cmd="dnf check-update 2>/dev/null | head -30 || apt list --upgradable 2>/dev/null | head -30" class={"btn btn-sm btn-warning #{if @running_command, do: "loading"}"} disabled={@running_command}>
                    Check Updates
                  </button>
                <% end %>
              </div>

              <!-- Custom command input for admin -->
              <%= if @current_user.role == "admin" do %>
                <form phx-submit="run_custom_command" class="mt-4 flex gap-2">
                  <input type="text" name="custom_cmd" placeholder="Custom buyruq (masalan: dnf update -y)" class="input input-bordered flex-1" />
                  <button type="submit" class={"btn btn-primary #{if @running_command, do: "loading"}"} disabled={@running_command}>
                    Bajarish
                  </button>
                </form>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Command Result -->
        <%= if @command_result do %>
          <div class="card bg-base-200 shadow-xl mb-6">
            <div class="card-body">
              <div class="flex justify-between items-center">
                <h2 class="card-title text-info">Natija</h2>
                <button phx-click="clear_result" class="btn btn-ghost btn-sm">✕</button>
              </div>
              <div class="bg-base-300 rounded-lg p-4 overflow-x-auto">
                <%= for {server, result} <- @command_result do %>
                  <div class="mb-4 last:mb-0">
                    <div class="text-success font-bold mb-1">📡 <%= server %>:</div>
                    <pre class="text-sm text-base-content whitespace-pre-wrap"><%= result %></pre>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Servers List -->
        <div class="card bg-base-200 shadow-xl">
          <div class="card-body">
            <div class="flex justify-between items-center mb-4">
              <h2 class="card-title">Serverlar ro'yxati</h2>
              <%= if length(@servers) > 0 do %>
                <button phx-click="select_all" class="btn btn-ghost btn-sm">
                  <%= if length(@selected_servers) == length(@servers), do: "Hammasini bekor qilish", else: "Hammasini tanlash" %>
                </button>
              <% end %>
            </div>

            <%= if length(@servers) == 0 do %>
              <div class="text-center py-8 text-base-content/50">
                <p class="text-4xl mb-2">📭</p>
                <p>Hali serverlar qo'shilmagan</p>
                <%= if @current_user.role == "admin" do %>
                  <p class="mt-2">Yuqoridagi "Server qo'shish" tugmasini bosing</p>
                <% end %>
              </div>
            <% else %>
              <div class="overflow-x-auto">
                <table class="table">
                  <thead>
                    <tr>
                      <th>
                        <input
                          type="checkbox"
                          class="checkbox"
                          checked={length(@selected_servers) == length(@servers)}
                          phx-click="select_all"
                        />
                      </th>
                      <th>Nomi</th>
                      <th>Host</th>
                      <th>Username</th>
                      <th>Port</th>
                      <th>Auth</th>
                      <th>Amallar</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for server <- @servers do %>
                      <tr class={"hover #{if server.name in @selected_servers, do: "bg-primary/10"}"}>
                        <td>
                          <input
                            type="checkbox"
                            class="checkbox checkbox-primary"
                            checked={server.name in @selected_servers}
                            phx-click="toggle_server"
                            phx-value-name={server.name}
                          />
                        </td>
                        <td class="font-bold"><%= server.name %></td>
                        <td><%= server.host %></td>
                        <td><%= server.username %></td>
                        <td><%= server.port %></td>
                        <td>
                          <span class={"badge #{if server.auth_type == "key", do: "badge-success", else: "badge-warning"}"}>
                            <%= server.auth_type %>
                          </span>
                        </td>
                        <td>
                          <div class="flex gap-1">
                            <button phx-click="test_connection" phx-value-name={server.name} class="btn btn-ghost btn-xs">
                              Test
                            </button>
                            <%= if @current_user.role == "admin" do %>
                              <button phx-click="delete_server" phx-value-name={server.name} class="btn btn-ghost btn-xs text-error" data-confirm="Rostdan o'chirmoqchimisiz?">
                                O'chirish
                              </button>
                            <% end %>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_add_form", _, socket) do
    {:noreply, assign(socket, :show_add_form, !socket.assigns.show_add_form)}
  end

  @impl true
  def handle_event("add_server", params, socket) do
    server_params = %{
      name: params["name"],
      host: params["host"],
      username: params["username"],
      port: String.to_integer(params["port"] || "22"),
      auth_type: params["auth_type"],
      password: params["password"],
      user_id: socket.assigns.current_user.id
    }

    case Servers.create_server(server_params) do
      {:ok, _server} ->
        servers = Servers.list_servers()
        {:noreply,
         socket
         |> assign(:servers, servers)
         |> assign(:show_add_form, false)
         |> assign(:form, to_form(%{"name" => "", "host" => "", "port" => "22", "username" => "", "auth_type" => "key", "password" => ""}))
         |> put_flash(:info, "Server qo'shildi!")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Xatolik: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_event("delete_server", %{"name" => name}, socket) do
    case Servers.delete_server_by_name(name) do
      {:ok, _} ->
        servers = Servers.list_servers()
        selected = Enum.reject(socket.assigns.selected_servers, &(&1 == name))
        {:noreply,
         socket
         |> assign(:servers, servers)
         |> assign(:selected_servers, selected)
         |> put_flash(:info, "Server o'chirildi!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Server topilmadi")}
    end
  end

  @impl true
  def handle_event("toggle_server", %{"name" => name}, socket) do
    selected = socket.assigns.selected_servers
    new_selected =
      if name in selected do
        Enum.reject(selected, &(&1 == name))
      else
        [name | selected]
      end

    {:noreply, assign(socket, :selected_servers, new_selected)}
  end

  @impl true
  def handle_event("select_all", _, socket) do
    new_selected =
      if length(socket.assigns.selected_servers) == length(socket.assigns.servers) do
        []
      else
        Enum.map(socket.assigns.servers, & &1.name)
      end

    {:noreply, assign(socket, :selected_servers, new_selected)}
  end

  @impl true
  def handle_event("test_connection", %{"name" => name}, socket) do
    case Servers.get_server_by_name(name) do
      nil ->
        {:noreply, put_flash(socket, :error, "Server topilmadi")}

      server ->
        case OpsChat.SSH.test_connection(server) do
          {:ok, msg} -> {:noreply, put_flash(socket, :info, "#{name}: #{msg}")}
          {:error, err} -> {:noreply, put_flash(socket, :error, "#{name}: #{err}")}
        end
    end
  end

  @impl true
  def handle_event("run_command", %{"cmd" => cmd}, socket) do
    run_command_on_selected(socket, cmd)
  end

  @impl true
  def handle_event("run_custom_command", %{"custom_cmd" => cmd}, socket) do
    if String.trim(cmd) == "" do
      {:noreply, put_flash(socket, :error, "Buyruq kiriting")}
    else
      run_command_on_selected(socket, cmd)
    end
  end

  @impl true
  def handle_event("clear_result", _, socket) do
    {:noreply, assign(socket, :command_result, nil)}
  end

  defp run_command_on_selected(socket, cmd) do
    selected = socket.assigns.selected_servers

    if length(selected) == 0 do
      {:noreply, put_flash(socket, :error, "Avval server tanlang")}
    else
      socket = assign(socket, :running_command, true)

      # Run commands on all selected servers
      results =
        Enum.map(selected, fn server_name ->
          case Servers.get_server_by_name(server_name) do
            nil ->
              {server_name, "Server topilmadi"}

            server ->
              case OpsChat.SSH.execute_on_server(server, cmd) do
                {:ok, output} -> {server_name, output}
                {:error, reason} -> {server_name, "Xatolik: #{reason}"}
              end
          end
        end)

      {:noreply,
       socket
       |> assign(:command_result, results)
       |> assign(:running_command, false)}
    end
  end
end
