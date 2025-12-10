defmodule OpsChatWeb.FilesLive do
  @moduledoc """
  File Manager - SFTP based file browser for remote servers.
  """
  use OpsChatWeb, :live_view

  alias OpsChat.Servers
  alias OpsChat.SFTP
  alias OpsChatWeb.Icons

  @impl true
  def mount(_params, session, socket) do
    current_user = get_user_from_session(session)

    if current_user do
      servers = Servers.list_servers()

      {:ok,
       socket
       |> assign(:current_user, current_user)
       |> assign(:servers, servers)
       |> assign(:selected_server, nil)
       |> assign(:current_path, "/")
       |> assign(:files, [])
       |> assign(:loading, false)
       |> assign(:error, nil)
       |> assign(:selected_file, nil)
       |> assign(:file_content, nil)
       |> assign(:editing, false)
       |> assign(:show_new_folder, false)
       |> assign(:show_new_file, false)
       |> assign(:show_rename, false)
       |> assign(:breadcrumbs, ["/"])}
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
    <div class="flex h-screen bg-base-200" data-theme="opschat">
      <!-- Sidebar - Server List -->
      <aside class="w-64 bg-base-300 flex flex-col border-r border-base-content/10">
        <div class="p-4 border-b border-base-content/10">
          <h1 class="text-xl font-bold text-primary flex items-center gap-2">
            <Icons.icon name="folder" class="w-6 h-6" /> File Manager
          </h1>
          <p class="text-xs text-base-content/50 mt-1">SFTP File Browser</p>
        </div>

        <div class="flex-1 overflow-y-auto p-2">
          <div class="mb-2 px-2">
            <span class="text-xs font-semibold text-base-content/50 uppercase">Serverlar</span>
          </div>
          <%= if Enum.empty?(@servers) do %>
            <div class="text-center py-4 text-base-content/50 text-sm">
              <p>Serverlar yo'q</p>
              <.link href={~p"/servers"} class="link link-primary text-xs">Server qo'shish</.link>
            </div>
          <% else %>
            <%= for server <- @servers do %>
              <button
                phx-click="select_server"
                phx-value-id={server.id}
                class={"flex items-center gap-2 w-full px-3 py-2 rounded-lg text-sm transition-colors #{if @selected_server && @selected_server.id == server.id, do: "bg-primary/10 text-primary font-medium", else: "hover:bg-base-200 text-base-content/70"}"}
              >
                <Icons.icon name="server" class="w-4 h-4" />
                <span class="truncate">{server.name}</span>
              </button>
            <% end %>
          <% end %>
        </div>
        
    <!-- User info -->
        <div class="p-3 border-t border-base-content/10 bg-base-200">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2">
              <div class="avatar placeholder">
                <div class="bg-primary text-primary-content rounded-full w-8">
                  <span class="text-sm">
                    {String.first(@current_user.username) |> String.upcase()}
                  </span>
                </div>
              </div>
              <div>
                <div class="font-medium text-sm">{@current_user.username}</div>
              </div>
            </div>
            <.link href={~p"/chat"} class="btn btn-ghost btn-xs" title="Chatga qaytish">
              <Icons.icon name="reply" class="w-4 h-4" />
            </.link>
          </div>
        </div>
      </aside>
      
    <!-- Main Content -->
      <main class="flex-1 flex flex-col overflow-hidden">
        <!-- Header with breadcrumbs -->
        <header class="h-14 px-4 flex items-center justify-between border-b border-base-content/10 bg-base-100">
          <div class="flex items-center gap-2">
            <button phx-click="go_home" class="btn btn-ghost btn-sm" title="Home">
              <Icons.icon name="home" class="w-4 h-4" />
            </button>
            <.breadcrumbs crumbs={@breadcrumbs} />
          </div>
          <%= if @selected_server do %>
            <div class="flex items-center gap-2">
              <button phx-click="refresh" class="btn btn-ghost btn-sm gap-1" title="Yangilash">
                <Icons.icon name="refresh" class="w-4 h-4" />
              </button>
              <button
                phx-click="toggle_new_folder"
                class="btn btn-ghost btn-sm gap-1"
                title="Yangi papka"
              >
                <Icons.icon name="folder" class="w-4 h-4" />
                <Icons.icon name="plus" class="w-3 h-3" />
              </button>
              <button
                phx-click="toggle_new_file"
                class="btn btn-ghost btn-sm gap-1"
                title="Yangi fayl"
              >
                <Icons.icon name="file" class="w-4 h-4" />
                <Icons.icon name="plus" class="w-3 h-3" />
              </button>
            </div>
          <% end %>
        </header>
        
    <!-- Error/Loading state -->
        <%= if @error do %>
          <div class="alert alert-error m-4">
            <span>{@error}</span>
            <button phx-click="clear_error" class="btn btn-ghost btn-sm">
              <Icons.icon name="x" class="w-4 h-4" />
            </button>
          </div>
        <% end %>
        
    <!-- New folder/file form -->
        <%= if @show_new_folder do %>
          <div class="p-4 border-b border-base-content/10 bg-base-200">
            <form phx-submit="create_folder" class="flex gap-2">
              <input
                type="text"
                name="name"
                placeholder="Papka nomi"
                class="input input-bordered input-sm flex-1"
                autofocus
              />
              <button type="submit" class="btn btn-primary btn-sm">Yaratish</button>
              <button type="button" phx-click="toggle_new_folder" class="btn btn-ghost btn-sm">
                Bekor
              </button>
            </form>
          </div>
        <% end %>

        <%= if @show_new_file do %>
          <div class="p-4 border-b border-base-content/10 bg-base-200">
            <form phx-submit="create_file" class="flex gap-2">
              <input
                type="text"
                name="name"
                placeholder="Fayl nomi"
                class="input input-bordered input-sm flex-1"
                autofocus
              />
              <button type="submit" class="btn btn-primary btn-sm">Yaratish</button>
              <button type="button" phx-click="toggle_new_file" class="btn btn-ghost btn-sm">
                Bekor
              </button>
            </form>
          </div>
        <% end %>
        
    <!-- Content area -->
        <div class="flex-1 flex overflow-hidden">
          <!-- File list -->
          <div class={"flex-1 overflow-y-auto #{if @selected_file, do: "w-1/2", else: "w-full"}"}>
            <%= if @loading do %>
              <div class="flex items-center justify-center h-full">
                <span class="loading loading-spinner loading-lg text-primary"></span>
              </div>
            <% else %>
              <%= if @selected_server == nil do %>
                <div class="flex flex-col items-center justify-center h-full text-base-content/50">
                  <Icons.icon name="server" class="w-16 h-16 mb-4 opacity-30" />
                  <p class="text-lg">Server tanlang</p>
                  <p class="text-sm mt-1">Chap paneldan serverni tanlang</p>
                </div>
              <% else %>
                <%= if Enum.empty?(@files) do %>
                  <div class="flex flex-col items-center justify-center h-full text-base-content/50">
                    <Icons.icon name="folder" class="w-16 h-16 mb-4 opacity-30" />
                    <p class="text-lg">Papka bo'sh</p>
                  </div>
                <% else %>
                  <div class="divide-y divide-base-content/10">
                    <!-- Parent directory -->
                    <%= if @current_path != "/" do %>
                      <button
                        phx-click="go_up"
                        class="w-full px-4 py-3 flex items-center gap-3 hover:bg-base-200 transition-colors text-left"
                      >
                        <Icons.icon name="folder" class="w-5 h-5 text-warning" />
                        <span class="font-medium">..</span>
                        <span class="text-xs text-base-content/50 ml-auto">Yuqoriga</span>
                      </button>
                    <% end %>
                    <!-- Files -->
                    <%= for file <- @files do %>
                      <.file_row
                        file={file}
                        selected={@selected_file && @selected_file.path == file.path}
                      />
                    <% end %>
                  </div>
                <% end %>
              <% end %>
            <% end %>
          </div>
          
    <!-- File preview panel -->
          <%= if @selected_file do %>
            <div class="w-1/2 border-l border-base-content/10 flex flex-col bg-base-100">
              <div class="p-4 border-b border-base-content/10 flex items-center justify-between">
                <div class="flex items-center gap-2 min-w-0">
                  <%= if @selected_file.type == :directory do %>
                    <Icons.icon name="folder" class="w-5 h-5 text-warning flex-shrink-0" />
                  <% else %>
                    <Icons.icon name="file" class="w-5 h-5 text-info flex-shrink-0" />
                  <% end %>
                  <span class="font-medium truncate">{@selected_file.name}</span>
                </div>
                <div class="flex items-center gap-1">
                  <%= if @selected_file.type == :file do %>
                    <%= if @editing do %>
                      <button phx-click="save_file" class="btn btn-primary btn-sm gap-1">
                        <Icons.icon name="save" class="w-4 h-4" /> Saqlash
                      </button>
                      <button phx-click="cancel_edit" class="btn btn-ghost btn-sm">Bekor</button>
                    <% else %>
                      <button phx-click="edit_file" class="btn btn-ghost btn-sm gap-1">
                        <Icons.icon name="edit" class="w-4 h-4" /> Tahrirlash
                      </button>
                      <button phx-click="download_file" class="btn btn-ghost btn-sm gap-1">
                        <Icons.icon name="download" class="w-4 h-4" />
                      </button>
                    <% end %>
                  <% end %>
                  <button phx-click="toggle_rename" class="btn btn-ghost btn-sm">
                    <Icons.icon name="edit" class="w-4 h-4" />
                  </button>
                  <button
                    phx-click="delete_item"
                    class="btn btn-ghost btn-sm text-error"
                    data-confirm="Rostdan ham o'chirmoqchimisiz?"
                  >
                    <Icons.icon name="trash" class="w-4 h-4" />
                  </button>
                  <button phx-click="close_preview" class="btn btn-ghost btn-sm">
                    <Icons.icon name="x" class="w-4 h-4" />
                  </button>
                </div>
              </div>
              
    <!-- Rename form -->
              <%= if @show_rename do %>
                <div class="p-4 border-b border-base-content/10 bg-base-200">
                  <form phx-submit="rename_item" class="flex gap-2">
                    <input
                      type="text"
                      name="new_name"
                      value={@selected_file.name}
                      class="input input-bordered input-sm flex-1"
                      autofocus
                    />
                    <button type="submit" class="btn btn-primary btn-sm">Saqlash</button>
                    <button type="button" phx-click="toggle_rename" class="btn btn-ghost btn-sm">
                      Bekor
                    </button>
                  </form>
                </div>
              <% end %>
              
    <!-- File info -->
              <div class="p-4 border-b border-base-content/10 text-sm space-y-1">
                <div class="flex justify-between">
                  <span class="text-base-content/50">Hajmi:</span>
                  <span>{format_size(@selected_file.size)}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-base-content/50">O'zgartirilgan:</span>
                  <span>{format_mtime(@selected_file.mtime)}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-base-content/50">Ruxsatlar:</span>
                  <span class="font-mono">{format_mode(@selected_file.mode)}</span>
                </div>
              </div>
              
    <!-- File content -->
              <%= if @file_content != nil do %>
                <div class="flex-1 overflow-auto">
                  <%= if @editing do %>
                    <textarea
                      id="file-editor"
                      phx-hook="FileEditor"
                      class="w-full h-full p-4 font-mono text-sm bg-base-200 resize-none"
                    >{@file_content}</textarea>
                  <% else %>
                    <pre class="p-4 font-mono text-sm whitespace-pre-wrap"><%= @file_content %></pre>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </main>
    </div>
    """
  end

  # Components
  defp breadcrumbs(assigns) do
    ~H"""
    <div class="flex items-center gap-1 text-sm overflow-x-auto">
      <%= for {crumb, idx} <- Enum.with_index(@crumbs) do %>
        <%= if idx > 0 do %>
          <Icons.icon name="chevron-right" class="w-4 h-4 text-base-content/30 flex-shrink-0" />
        <% end %>
        <button
          phx-click="navigate_to"
          phx-value-path={build_path(@crumbs, idx)}
          class="hover:text-primary transition-colors truncate max-w-32"
        >
          {if crumb == "/", do: "root", else: crumb}
        </button>
      <% end %>
    </div>
    """
  end

  defp file_row(assigns) do
    ~H"""
    <div
      class={"w-full px-4 py-3 flex items-center gap-3 hover:bg-base-200 transition-colors cursor-pointer #{if @selected, do: "bg-primary/10"}"}
      phx-click="select_file"
      phx-value-path={@file.path}
    >
      <%= if @file.type == :directory do %>
        <Icons.icon name="folder" class="w-5 h-5 text-warning flex-shrink-0" />
      <% else %>
        <Icons.icon name="file" class="w-5 h-5 text-info flex-shrink-0" />
      <% end %>
      <span class="flex-1 truncate">{@file.name}</span>
      <span class="text-xs text-base-content/50">{format_size(@file.size)}</span>
      <%= if @file.type == :directory do %>
        <button
          phx-click="open_dir"
          phx-value-path={@file.path}
          class="btn btn-ghost btn-xs"
          title="Ochish"
        >
          <Icons.icon name="chevron-right" class="w-4 h-4" />
        </button>
      <% end %>
    </div>
    """
  end

  # Helpers
  defp build_path(crumbs, idx) do
    crumbs
    |> Enum.take(idx + 1)
    |> Enum.join("/")
    |> String.replace("//", "/")
  end

  defp format_size(nil), do: "-"
  defp format_size(0), do: "0 B"

  defp format_size(size) when is_integer(size) do
    cond do
      size >= 1_073_741_824 -> "#{Float.round(size / 1_073_741_824, 1)} GB"
      size >= 1_048_576 -> "#{Float.round(size / 1_048_576, 1)} MB"
      size >= 1024 -> "#{Float.round(size / 1024, 1)} KB"
      true -> "#{size} B"
    end
  end

  defp format_size(_), do: "-"

  defp format_mtime(nil), do: "-"

  defp format_mtime({{year, month, day}, {hour, minute, _}}) do
    "#{year}-#{pad(month)}-#{pad(day)} #{pad(hour)}:#{pad(minute)}"
  end

  defp format_mtime(_), do: "-"

  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: "#{n}"

  defp format_mode(nil), do: "-"

  defp format_mode(mode) when is_integer(mode) do
    # Convert to octal and take last 3 digits
    Integer.to_string(rem(mode, 4096), 8)
    |> String.pad_leading(4, "0")
  end

  defp format_mode(_), do: "-"

  defp path_to_breadcrumbs("/"), do: ["/"]

  defp path_to_breadcrumbs(path) do
    parts = String.split(path, "/", trim: true)
    ["/"] ++ parts
  end

  # Event handlers
  @impl true
  def handle_event("select_server", %{"id" => id}, socket) do
    server = Enum.find(socket.assigns.servers, &(to_string(&1.id) == id))

    socket =
      socket
      |> assign(:selected_server, server)
      |> assign(:current_path, "/")
      |> assign(:breadcrumbs, ["/"])
      |> assign(:selected_file, nil)
      |> assign(:file_content, nil)
      |> assign(:loading, true)
      |> assign(:error, nil)

    send(self(), {:load_directory, "/"})
    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh", _, socket) do
    socket = assign(socket, :loading, true)
    send(self(), {:load_directory, socket.assigns.current_path})
    {:noreply, socket}
  end

  @impl true
  def handle_event("go_home", _, socket) do
    if socket.assigns.selected_server do
      socket =
        socket
        |> assign(:current_path, "/")
        |> assign(:breadcrumbs, ["/"])
        |> assign(:selected_file, nil)
        |> assign(:file_content, nil)
        |> assign(:loading, true)

      send(self(), {:load_directory, "/"})
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("go_up", _, socket) do
    current = socket.assigns.current_path
    parent = Path.dirname(current)

    socket =
      socket
      |> assign(:current_path, parent)
      |> assign(:breadcrumbs, path_to_breadcrumbs(parent))
      |> assign(:selected_file, nil)
      |> assign(:file_content, nil)
      |> assign(:loading, true)

    send(self(), {:load_directory, parent})
    {:noreply, socket}
  end

  @impl true
  def handle_event("navigate_to", %{"path" => path}, socket) do
    path = if path == "", do: "/", else: path

    socket =
      socket
      |> assign(:current_path, path)
      |> assign(:breadcrumbs, path_to_breadcrumbs(path))
      |> assign(:selected_file, nil)
      |> assign(:file_content, nil)
      |> assign(:loading, true)

    send(self(), {:load_directory, path})
    {:noreply, socket}
  end

  @impl true
  def handle_event("open_dir", %{"path" => path}, socket) do
    socket =
      socket
      |> assign(:current_path, path)
      |> assign(:breadcrumbs, path_to_breadcrumbs(path))
      |> assign(:selected_file, nil)
      |> assign(:file_content, nil)
      |> assign(:loading, true)

    send(self(), {:load_directory, path})
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_file", %{"path" => path}, socket) do
    file = Enum.find(socket.assigns.files, &(&1.path == path))

    if file do
      socket =
        socket
        |> assign(:selected_file, file)
        |> assign(:file_content, nil)
        |> assign(:editing, false)
        |> assign(:show_rename, false)

      # Load file content for text files
      if file.type == :file && file.size < 1_048_576 do
        send(self(), {:load_file_content, path})
      end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_preview", _, socket) do
    {:noreply,
     socket
     |> assign(:selected_file, nil)
     |> assign(:file_content, nil)
     |> assign(:editing, false)}
  end

  @impl true
  def handle_event("toggle_new_folder", _, socket) do
    {:noreply,
     socket
     |> assign(:show_new_folder, !socket.assigns.show_new_folder)
     |> assign(:show_new_file, false)}
  end

  @impl true
  def handle_event("toggle_new_file", _, socket) do
    {:noreply,
     socket
     |> assign(:show_new_file, !socket.assigns.show_new_file)
     |> assign(:show_new_folder, false)}
  end

  @impl true
  def handle_event("toggle_rename", _, socket) do
    {:noreply, assign(socket, :show_rename, !socket.assigns.show_rename)}
  end

  @impl true
  def handle_event("create_folder", %{"name" => name}, socket) do
    server = socket.assigns.selected_server
    path = Path.join(socket.assigns.current_path, name)

    case SFTP.mkdir(server.name, path) do
      :ok ->
        socket =
          socket
          |> assign(:show_new_folder, false)
          |> assign(:loading, true)

        send(self(), {:load_directory, socket.assigns.current_path})
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, assign(socket, :error, reason)}
    end
  end

  @impl true
  def handle_event("create_file", %{"name" => name}, socket) do
    server = socket.assigns.selected_server
    path = Path.join(socket.assigns.current_path, name)

    case SFTP.write_file(server.name, path, "") do
      :ok ->
        socket =
          socket
          |> assign(:show_new_file, false)
          |> assign(:loading, true)

        send(self(), {:load_directory, socket.assigns.current_path})
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, assign(socket, :error, reason)}
    end
  end

  @impl true
  def handle_event("rename_item", %{"new_name" => new_name}, socket) do
    server = socket.assigns.selected_server
    old_path = socket.assigns.selected_file.path
    new_path = Path.join(Path.dirname(old_path), new_name)

    case SFTP.rename(server.name, old_path, new_path) do
      :ok ->
        socket =
          socket
          |> assign(:show_rename, false)
          |> assign(:selected_file, nil)
          |> assign(:loading, true)

        send(self(), {:load_directory, socket.assigns.current_path})
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, assign(socket, :error, reason)}
    end
  end

  @impl true
  def handle_event("delete_item", _, socket) do
    server = socket.assigns.selected_server
    file = socket.assigns.selected_file

    result =
      if file.type == :directory do
        SFTP.rmdir(server.name, file.path)
      else
        SFTP.delete_file(server.name, file.path)
      end

    case result do
      :ok ->
        socket =
          socket
          |> assign(:selected_file, nil)
          |> assign(:file_content, nil)
          |> assign(:loading, true)

        send(self(), {:load_directory, socket.assigns.current_path})
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, assign(socket, :error, reason)}
    end
  end

  @impl true
  def handle_event("edit_file", _, socket) do
    {:noreply, assign(socket, :editing, true)}
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    # Reload original content
    send(self(), {:load_file_content, socket.assigns.selected_file.path})
    {:noreply, assign(socket, :editing, false)}
  end

  @impl true
  def handle_event("save_file", _, socket) do
    # Trigger JS hook to send content
    {:noreply, push_event(socket, "save-file", %{})}
  end

  @impl true
  def handle_event("save_file_content", %{"content" => content}, socket) do
    server = socket.assigns.selected_server
    path = socket.assigns.selected_file.path

    case SFTP.write_file(server.name, path, content) do
      :ok ->
        {:noreply,
         socket
         |> assign(:file_content, content)
         |> assign(:editing, false)}

      {:error, reason} ->
        {:noreply, assign(socket, :error, reason)}
    end
  end

  @impl true
  def handle_event("download_file", _, socket) do
    # TODO: Implement file download
    {:noreply, put_flash(socket, :info, "Yuklab olish hali tayyor emas")}
  end

  @impl true
  def handle_event("clear_error", _, socket) do
    {:noreply, assign(socket, :error, nil)}
  end

  # Handle async operations
  @impl true
  def handle_info({:load_directory, path}, socket) do
    server = socket.assigns.selected_server

    case SFTP.list_dir(server.name, path) do
      {:ok, files} ->
        # Sort: directories first, then files
        sorted =
          Enum.sort_by(files, fn f ->
            {if(f.type == :directory, do: 0, else: 1), String.downcase(f.name)}
          end)

        {:noreply,
         socket
         |> assign(:files, sorted)
         |> assign(:loading, false)
         |> assign(:error, nil)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:files, [])
         |> assign(:loading, false)
         |> assign(:error, reason)}
    end
  end

  @impl true
  def handle_info({:load_file_content, path}, socket) do
    server = socket.assigns.selected_server

    case SFTP.read_file(server.name, path) do
      {:ok, content} ->
        # Try to decode as UTF-8, fallback to latin1
        content_str =
          case :unicode.characters_to_binary(content, :utf8) do
            {:error, _, _} -> :unicode.characters_to_binary(content, :latin1)
            {:incomplete, _, _} -> :unicode.characters_to_binary(content, :latin1)
            str -> str
          end

        {:noreply, assign(socket, :file_content, content_str)}

      {:error, _reason} ->
        {:noreply, assign(socket, :file_content, "[Fayl o'qib bo'lmadi]")}
    end
  end
end
