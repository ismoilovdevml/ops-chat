defmodule OpsChatWeb.ServersLive do
  @moduledoc """
  Server management UI with SSH key support.
  """
  use OpsChatWeb, :live_view

  alias OpsChat.Chat
  alias OpsChat.Servers

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
       |> assign(:auth_type, "password")
       |> assign(:form, to_form(default_form()))}
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

  defp default_form do
    %{
      "name" => "",
      "host" => "",
      "port" => "22",
      "username" => "root",
      "auth_type" => "password",
      "password" => "",
      "private_key" => "",
      "description" => ""
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 p-4" data-theme="opschat">
      <div class="container mx-auto max-w-6xl">
        <!-- Header -->
        <div class="flex justify-between items-center mb-6">
          <div>
            <h1 class="text-3xl font-bold text-primary">🖥️ Server Management</h1>
            <p class="text-base-content/60">Remote serverlarni boshqaring</p>
          </div>
          <div class="flex gap-2">
            <.link href={~p"/chat"} class="btn btn-ghost">
              ← Chat
            </.link>
            <%= if @current_user.role == "admin" do %>
              <button phx-click="toggle_add_form" class="btn btn-primary">
                {if @show_add_form, do: "Bekor qilish", else: "+ Server qo'shish"}
              </button>
            <% end %>
          </div>
        </div>
        
    <!-- Add Server Form -->
        <%= if @show_add_form do %>
          <div class="card bg-base-100 shadow-lg mb-6">
            <div class="card-body">
              <h2 class="card-title text-primary">Yangi server qo'shish</h2>
              <.form for={@form} phx-submit="add_server" phx-change="form_change" class="space-y-4">
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                  <div class="form-control">
                    <label class="label">
                      <span class="label-text font-medium">Server nomi *</span>
                    </label>
                    <input
                      type="text"
                      name="name"
                      value={@form[:name].value}
                      placeholder="web1"
                      class="input input-bordered"
                      required
                    />
                  </div>
                  <div class="form-control">
                    <label class="label"><span class="label-text font-medium">Host/IP *</span></label>
                    <input
                      type="text"
                      name="host"
                      value={@form[:host].value}
                      placeholder="192.168.1.10 yoki server.com"
                      class="input input-bordered"
                      required
                    />
                  </div>
                  <div class="form-control">
                    <label class="label"><span class="label-text font-medium">Port</span></label>
                    <input
                      type="number"
                      name="port"
                      value={@form[:port].value}
                      placeholder="22"
                      class="input input-bordered"
                    />
                  </div>
                  <div class="form-control">
                    <label class="label">
                      <span class="label-text font-medium">Username *</span>
                    </label>
                    <input
                      type="text"
                      name="username"
                      value={@form[:username].value}
                      placeholder="root"
                      class="input input-bordered"
                      required
                    />
                  </div>
                  <div class="form-control">
                    <label class="label">
                      <span class="label-text font-medium">Auth usuli *</span>
                    </label>
                    <select
                      name="auth_type"
                      class="select select-bordered"
                      phx-change="auth_type_change"
                    >
                      <option value="password" selected={@auth_type == "password"}>🔑 Password</option>
                      <option value="key" selected={@auth_type == "key"}>🔐 SSH Key</option>
                    </select>
                  </div>
                  <div class="form-control">
                    <label class="label"><span class="label-text font-medium">Tavsif</span></label>
                    <input
                      type="text"
                      name="description"
                      value={@form[:description].value}
                      placeholder="Production web server"
                      class="input input-bordered"
                    />
                  </div>
                </div>
                
    <!-- Password field -->
                <%= if @auth_type == "password" do %>
                  <div class="form-control max-w-md">
                    <label class="label">
                      <span class="label-text font-medium">Password *</span>
                    </label>
                    <input
                      type="password"
                      name="password"
                      value={@form[:password].value}
                      placeholder="••••••••"
                      class="input input-bordered"
                      required
                    />
                    <label class="label">
                      <span class="label-text-alt text-base-content/50">SSH parolini kiriting</span>
                    </label>
                  </div>
                <% end %>
                
    <!-- SSH Key field -->
                <%= if @auth_type == "key" do %>
                  <div class="form-control">
                    <label class="label">
                      <span class="label-text font-medium">Private Key (PEM format)</span>
                      <span class="label-text-alt text-info">RSA, Ed25519, ECDSA</span>
                    </label>
                    <textarea
                      name="private_key"
                      class="textarea textarea-bordered font-mono text-sm h-48"
                      placeholder="-----BEGIN OPENSSH PRIVATE KEY-----&#10;b3BlbnNzaC1rZXktdjEAAAAA...&#10;-----END OPENSSH PRIVATE KEY-----"
                    ><%= @form[:private_key].value %></textarea>
                    <label class="label">
                      <span class="label-text-alt text-base-content/50">
                        Private key ni to'liq paste qiling (id_rsa, id_ed25519 yoki id_ecdsa)
                      </span>
                      <span class="label-text-alt">
                        <button
                          type="button"
                          class="link link-info text-xs"
                          onclick="document.getElementById('key-help').showModal()"
                        >
                          Qanday olish?
                        </button>
                      </span>
                    </label>
                  </div>
                  
    <!-- Key help modal -->
                  <dialog id="key-help" class="modal">
                    <div class="modal-box">
                      <h3 class="font-bold text-lg mb-4">SSH Key qanday olish</h3>
                      <div class="space-y-3 text-sm">
                        <p><strong>1. Mavjud kalitni ko'rish:</strong></p>
                        <pre class="bg-base-200 p-2 rounded text-xs">cat ~/.ssh/id_ed25519</pre>
                        <p class="text-base-content/60">yoki id_rsa, id_ecdsa</p>

                        <p class="mt-4"><strong>2. Yangi kalit yaratish:</strong></p>
                        <pre class="bg-base-200 p-2 rounded text-xs">ssh-keygen -t ed25519 -C "your@email.com"</pre>

                        <p class="mt-4"><strong>3. Public key ni serverga qo'shish:</strong></p>
                        <pre class="bg-base-200 p-2 rounded text-xs">ssh-copy-id user@server</pre>

                        <div class="alert alert-warning mt-4">
                          <span class="text-sm">
                            ⚠️ Private key ni hech kimga bermang va xavfsiz saqlang!
                          </span>
                        </div>
                      </div>
                      <div class="modal-action">
                        <form method="dialog">
                          <button class="btn">Yopish</button>
                        </form>
                      </div>
                    </div>
                    <form method="dialog" class="modal-backdrop">
                      <button>close</button>
                    </form>
                  </dialog>
                <% end %>

                <div class="card-actions justify-end pt-4">
                  <button type="button" phx-click="toggle_add_form" class="btn btn-ghost">
                    Bekor qilish
                  </button>
                  <button type="submit" class="btn btn-primary">
                    <span class="hero-plus w-5 h-5"></span> Qo'shish
                  </button>
                </div>
              </.form>
            </div>
          </div>
        <% end %>
        
    <!-- Command Panel -->
        <%= if length(@selected_servers) > 0 do %>
          <div class="card bg-base-100 shadow-lg mb-6">
            <div class="card-body">
              <h2 class="card-title">
                <span class="hero-server-stack w-6 h-6 text-primary"></span>
                Tanlangan serverlar: {length(@selected_servers)}
              </h2>
              <div class="flex flex-wrap gap-2 mb-4">
                <%= for server_name <- @selected_servers do %>
                  <span class="badge badge-primary badge-lg gap-1">
                    <span class="hero-server w-4 h-4"></span>
                    {server_name}
                  </span>
                <% end %>
              </div>

              <div class="flex flex-wrap gap-2">
                <button
                  phx-click="run_command"
                  phx-value-cmd="uptime"
                  class={"btn btn-sm #{if @running_command, do: "loading"}"}
                  disabled={@running_command}
                >
                  <span class="hero-clock w-4 h-4"></span> Status
                </button>
                <button
                  phx-click="run_command"
                  phx-value-cmd="df -h"
                  class={"btn btn-sm #{if @running_command, do: "loading"}"}
                  disabled={@running_command}
                >
                  <span class="hero-circle-stack w-4 h-4"></span> Disk
                </button>
                <button
                  phx-click="run_command"
                  phx-value-cmd="free -h"
                  class={"btn btn-sm #{if @running_command, do: "loading"}"}
                  disabled={@running_command}
                >
                  <span class="hero-cpu-chip w-4 h-4"></span> Memory
                </button>
                <button
                  phx-click="run_command"
                  phx-value-cmd="top -bn1 | head -20"
                  class={"btn btn-sm #{if @running_command, do: "loading"}"}
                  disabled={@running_command}
                >
                  <span class="hero-chart-bar w-4 h-4"></span> Processes
                </button>
                <%= if @current_user.role == "admin" do %>
                  <button
                    phx-click="run_command"
                    phx-value-cmd="dnf check-update 2>/dev/null | head -30 || apt list --upgradable 2>/dev/null | head -30"
                    class={"btn btn-sm btn-warning #{if @running_command, do: "loading"}"}
                    disabled={@running_command}
                  >
                    <span class="hero-arrow-path w-4 h-4"></span> Updates
                  </button>
                <% end %>
              </div>

              <%= if @current_user.role == "admin" do %>
                <form phx-submit="run_custom_command" class="mt-4 flex gap-2">
                  <input
                    type="text"
                    name="custom_cmd"
                    placeholder="Custom buyruq kiriting..."
                    class="input input-bordered flex-1"
                  />
                  <button
                    type="submit"
                    class={"btn btn-primary #{if @running_command, do: "loading"}"}
                    disabled={@running_command}
                  >
                    <span class="hero-play w-5 h-5"></span> Bajarish
                  </button>
                </form>
              <% end %>
            </div>
          </div>
        <% end %>
        
    <!-- Command Result -->
        <%= if @command_result do %>
          <div class="card bg-base-100 shadow-lg mb-6">
            <div class="card-body">
              <div class="flex justify-between items-center">
                <h2 class="card-title text-info">
                  <span class="hero-command-line w-6 h-6"></span> Natija
                </h2>
                <button phx-click="clear_result" class="btn btn-ghost btn-sm btn-circle">✕</button>
              </div>
              <div class="space-y-4">
                <%= for {server, result} <- @command_result do %>
                  <div class="bg-neutral rounded-lg p-4">
                    <div class="text-success font-bold mb-2 flex items-center gap-2">
                      <span class="hero-server w-5 h-5"></span>
                      {server}
                    </div>
                    <pre class="text-sm text-neutral-content whitespace-pre-wrap font-mono"><%= result %></pre>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
        
    <!-- Servers List -->
        <div class="card bg-base-100 shadow-lg">
          <div class="card-body">
            <div class="flex justify-between items-center mb-4">
              <h2 class="card-title">
                <span class="hero-server-stack w-6 h-6"></span> Serverlar ro'yxati
              </h2>
              <%= if length(@servers) > 0 do %>
                <button phx-click="select_all" class="btn btn-ghost btn-sm">
                  {if length(@selected_servers) == length(@servers),
                    do: "Bekor qilish",
                    else: "Hammasini tanlash"}
                </button>
              <% end %>
            </div>

            <%= if length(@servers) == 0 do %>
              <div class="text-center py-12 text-base-content/50">
                <span class="hero-server-stack w-16 h-16 mx-auto mb-4 opacity-30"></span>
                <p class="font-medium">Hali serverlar qo'shilmagan</p>
                <%= if @current_user.role == "admin" do %>
                  <p class="text-sm mt-2">Yuqoridagi "Server qo'shish" tugmasini bosing</p>
                <% end %>
              </div>
            <% else %>
              <div class="overflow-x-auto">
                <table class="table">
                  <thead>
                    <tr class="text-base-content/70">
                      <th class="w-12">
                        <input
                          type="checkbox"
                          class="checkbox checkbox-sm"
                          checked={
                            length(@selected_servers) == length(@servers) && length(@servers) > 0
                          }
                          phx-click="select_all"
                        />
                      </th>
                      <th>Server</th>
                      <th>Host</th>
                      <th>Auth</th>
                      <th class="text-right">Amallar</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for server <- @servers do %>
                      <tr class={"hover transition-colors #{if server.name in @selected_servers, do: "bg-primary/5"}"}>
                        <td>
                          <input
                            type="checkbox"
                            class="checkbox checkbox-primary checkbox-sm"
                            checked={server.name in @selected_servers}
                            phx-click="toggle_server"
                            phx-value-name={server.name}
                          />
                        </td>
                        <td>
                          <div class="flex items-center gap-3">
                            <div class="avatar placeholder">
                              <div class="bg-neutral text-neutral-content rounded-lg w-10">
                                <span class="text-lg">🖥️</span>
                              </div>
                            </div>
                            <div>
                              <div class="font-bold">{server.name}</div>
                              <div class="text-sm text-base-content/50">
                                {server.description || "#{server.username}@#{server.host}"}
                              </div>
                            </div>
                          </div>
                        </td>
                        <td>
                          <div class="font-mono text-sm">{server.host}:{server.port}</div>
                        </td>
                        <td>
                          <span class={"badge badge-sm #{if server.auth_type == "key", do: "badge-success", else: "badge-warning"}"}>
                            {if server.auth_type == "key", do: "🔐 Key", else: "🔑 Password"}
                          </span>
                          <%= if server.auth_type == "key" && server.private_key do %>
                            <span class="badge badge-sm badge-ghost ml-1">Custom</span>
                          <% end %>
                        </td>
                        <td class="text-right">
                          <div class="flex justify-end gap-1">
                            <button
                              phx-click="test_connection"
                              phx-value-name={server.name}
                              class="btn btn-ghost btn-xs"
                            >
                              <span class="hero-signal w-4 h-4"></span> Test
                            </button>
                            <%= if @current_user.role == "admin" do %>
                              <button
                                phx-click="delete_server"
                                phx-value-name={server.name}
                                class="btn btn-ghost btn-xs text-error"
                                data-confirm="#{server.name} serverini o'chirmoqchimisiz?"
                              >
                                <span class="hero-trash w-4 h-4"></span>
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
    {:noreply,
     socket
     |> assign(:show_add_form, !socket.assigns.show_add_form)
     |> assign(:auth_type, "password")
     |> assign(:form, to_form(default_form()))}
  end

  @impl true
  def handle_event("auth_type_change", %{"auth_type" => auth_type}, socket) do
    {:noreply, assign(socket, :auth_type, auth_type)}
  end

  @impl true
  def handle_event("form_change", params, socket) do
    {:noreply, assign(socket, :auth_type, params["auth_type"] || socket.assigns.auth_type)}
  end

  @impl true
  def handle_event("add_server", params, socket) do
    server_params = %{
      name: params["name"],
      host: params["host"],
      username: params["username"],
      port: String.to_integer(params["port"] || "22"),
      auth_type: params["auth_type"],
      password: if(params["auth_type"] == "password", do: params["password"], else: nil),
      private_key: if(params["auth_type"] == "key", do: params["private_key"], else: nil),
      description: params["description"],
      user_id: socket.assigns.current_user.id
    }

    case Servers.create_server(server_params) do
      {:ok, server} ->
        # Create server channel
        Chat.create_server_channel(server)

        servers = Servers.list_servers()

        {:noreply,
         socket
         |> assign(:servers, servers)
         |> assign(:show_add_form, false)
         |> assign(:form, to_form(default_form()))
         |> put_flash(:info, "✅ #{server.name} serveri qo'shildi!")}

      {:error, changeset} ->
        errors = format_errors(changeset)
        {:noreply, put_flash(socket, :error, "Xatolik: #{errors}")}
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
         |> put_flash(:info, "🗑️ #{name} serveri o'chirildi")}

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
          {:ok, _msg} ->
            {:noreply, put_flash(socket, :info, "✅ #{name}: Ulanish muvaffaqiyatli!")}

          {:error, err} ->
            {:noreply, put_flash(socket, :error, "❌ #{name}: #{err}")}
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

    if Enum.empty?(selected) do
      {:noreply, put_flash(socket, :error, "Avval server tanlang")}
    else
      socket = assign(socket, :running_command, true)

      results =
        Enum.map(selected, fn server_name ->
          case Servers.get_server_by_name(server_name) do
            nil ->
              {server_name, "Server topilmadi"}

            server ->
              case OpsChat.SSH.execute_on_server(server, cmd) do
                {:ok, output} -> {server_name, output}
                {:error, reason} -> {server_name, "❌ Xatolik: #{reason}"}
              end
          end
        end)

      {:noreply,
       socket
       |> assign(:command_result, results)
       |> assign(:running_command, false)}
    end
  end

  defp format_errors(changeset),
    do: OpsChat.Helpers.format_changeset_errors(changeset)
end
