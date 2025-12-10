defmodule OpsChatWeb.FilesLive do
  @moduledoc """
  Enterprise File Manager - SFTP based file browser for remote servers.
  Features: Security confirmations, safe defaults, permission display.
  """
  use OpsChatWeb, :live_view

  alias OpsChat.Servers
  alias OpsChat.SFTP
  alias OpsChatWeb.Icons

  # Dangerous paths that require confirmation
  @dangerous_paths ["/", "/etc", "/bin", "/sbin", "/usr", "/var", "/boot", "/root", "/lib", "/lib64"]
  # File extensions for syntax highlighting hints
  @code_extensions ~w(.ex .exs .erl .js .ts .jsx .tsx .py .rb .go .rs .java .c .cpp .h .php .sh .bash .zsh .yml .yaml .json .xml .html .css .scss .sql .md)
  @config_extensions ~w(.conf .cfg .ini .env .toml)

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
       |> assign(:current_path, nil)
       |> assign(:files, [])
       |> assign(:loading, false)
       |> assign(:error, nil)
       |> assign(:selected_file, nil)
       |> assign(:file_content, nil)
       |> assign(:editing, false)
       |> assign(:show_new_folder, false)
       |> assign(:show_new_file, false)
       |> assign(:show_rename, false)
       |> assign(:show_delete_confirm, false)
       |> assign(:show_path_warning, false)
       |> assign(:pending_path, nil)
       |> assign(:breadcrumbs, [])}
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
      <aside class="w-72 bg-base-300 flex flex-col border-r border-base-content/10">
        <div class="p-4 border-b border-base-content/10">
          <h1 class="text-xl font-bold text-primary flex items-center gap-2">
            <Icons.icon name="folder" class="w-6 h-6" /> File Manager
          </h1>
          <p class="text-xs text-base-content/50 mt-1">Enterprise SFTP Browser</p>
        </div>

        <div class="flex-1 overflow-y-auto p-3">
          <div class="mb-3">
            <span class="text-xs font-semibold text-base-content/50 uppercase tracking-wider">
              Serverlar
            </span>
          </div>
          <%= if Enum.empty?(@servers) do %>
            <div class="text-center py-8 text-base-content/50">
              <Icons.icon name="server" class="w-12 h-12 mx-auto mb-3 opacity-30" />
              <p class="text-sm">Serverlar yo'q</p>
              <.link href={~p"/servers"} class="btn btn-primary btn-sm mt-3">
                <Icons.icon name="plus" class="w-4 h-4" /> Server qo'shish
              </.link>
            </div>
          <% else %>
            <div class="space-y-1">
              <%= for server <- @servers do %>
                <button
                  phx-click="select_server"
                  phx-value-id={server.id}
                  class={"flex items-center gap-3 w-full px-3 py-2.5 rounded-lg text-sm transition-all #{if @selected_server && @selected_server.id == server.id, do: "bg-primary text-primary-content shadow-md", else: "hover:bg-base-200 text-base-content/70"}"}
                >
                  <div class={"w-2 h-2 rounded-full #{if @selected_server && @selected_server.id == server.id, do: "bg-success animate-pulse", else: "bg-base-content/30"}"}>
                  </div>
                  <Icons.icon name="server" class="w-4 h-4" />
                  <div class="flex-1 text-left">
                    <div class="font-medium">{server.name}</div>
                    <div class="text-xs opacity-60">{server.host}</div>
                  </div>
                </button>
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Quick navigation -->
        <%= if @selected_server do %>
          <div class="p-3 border-t border-base-content/10">
            <div class="text-xs font-semibold text-base-content/50 uppercase mb-2">Tezkor o'tish</div>
            <div class="space-y-1">
              <button
                phx-click="quick_nav"
                phx-value-path="/home"
                class="btn btn-ghost btn-sm w-full justify-start gap-2"
              >
                <Icons.icon name="home" class="w-4 h-4" /> /home
              </button>
              <button
                phx-click="quick_nav"
                phx-value-path="/var/log"
                class="btn btn-ghost btn-sm w-full justify-start gap-2"
              >
                <Icons.icon name="file" class="w-4 h-4" /> /var/log
              </button>
              <button
                phx-click="quick_nav"
                phx-value-path="/tmp"
                class="btn btn-ghost btn-sm w-full justify-start gap-2"
              >
                <Icons.icon name="folder" class="w-4 h-4" /> /tmp
              </button>
            </div>
          </div>
        <% end %>

        <!-- User info -->
        <div class="p-3 border-t border-base-content/10 bg-base-200/50">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2">
              <div class="avatar placeholder">
                <div class="bg-primary text-primary-content rounded-full w-8">
                  <span class="text-sm">{String.first(@current_user.username) |> String.upcase()}</span>
                </div>
              </div>
              <div>
                <div class="font-medium text-sm">{@current_user.username}</div>
                <div class="text-xs text-base-content/50">{@current_user.role}</div>
              </div>
            </div>
            <.link href={~p"/chat"} class="btn btn-ghost btn-sm" title="Chatga qaytish">
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
            <%= if @selected_server && @current_path do %>
              <button phx-click="go_home" class="btn btn-ghost btn-sm" title="Home papkasiga">
                <Icons.icon name="home" class="w-4 h-4" />
              </button>
              <.breadcrumbs crumbs={@breadcrumbs} current_path={@current_path} />
            <% else %>
              <span class="text-base-content/50">Server tanlang</span>
            <% end %>
          </div>
          <%= if @selected_server && @current_path do %>
            <div class="flex items-center gap-1">
              <button phx-click="refresh" class="btn btn-ghost btn-sm" title="Yangilash">
                <Icons.icon name="refresh" class="w-4 h-4" />
              </button>
              <div class="divider divider-horizontal mx-1"></div>
              <button phx-click="toggle_new_folder" class="btn btn-ghost btn-sm gap-1" title="Yangi papka">
                <Icons.icon name="folder" class="w-4 h-4 text-warning" />
                <Icons.icon name="plus" class="w-3 h-3" />
              </button>
              <button phx-click="toggle_new_file" class="btn btn-ghost btn-sm gap-1" title="Yangi fayl">
                <Icons.icon name="file" class="w-4 h-4 text-info" />
                <Icons.icon name="plus" class="w-3 h-3" />
              </button>
            </div>
          <% end %>
        </header>

        <!-- Error/Warning messages -->
        <%= if @error do %>
          <div class="alert alert-error m-4 shadow-lg">
            <Icons.icon name="x" class="w-5 h-5" />
            <span>{@error}</span>
            <button phx-click="clear_error" class="btn btn-ghost btn-sm">Yopish</button>
          </div>
        <% end %>

        <!-- Path warning modal -->
        <%= if @show_path_warning do %>
          <.modal title="Xavfli papka" on_cancel="cancel_path_warning">
            <div class="py-4">
              <div class="alert alert-warning mb-4">
                <Icons.icon name="x" class="w-5 h-5" />
                <span>
                  <strong>{@pending_path}</strong>
                  - bu tizim papkasi. O'zgartirish tizimga zarar yetkazishi mumkin.
                </span>
              </div>
              <p class="text-sm text-base-content/70">
                Bu papkaga kirishni xohlaysizmi? Faqat o'qish uchun tavsiya etiladi.
              </p>
            </div>
            <div class="flex justify-end gap-2">
              <button phx-click="cancel_path_warning" class="btn btn-ghost">Bekor qilish</button>
              <button phx-click="confirm_path_warning" class="btn btn-warning">
                Ha, davom etish
              </button>
            </div>
          </.modal>
        <% end %>

        <!-- Delete confirmation modal -->
        <%= if @show_delete_confirm do %>
          <.modal title="O'chirishni tasdiqlash" on_cancel="cancel_delete">
            <div class="py-4">
              <div class="alert alert-error mb-4">
                <Icons.icon name="trash" class="w-5 h-5" />
                <span>Bu amalni qaytarib bo'lmaydi!</span>
              </div>
              <p class="text-base-content/70">
                <strong>{@selected_file && @selected_file.name}</strong>
                <%= if @selected_file && @selected_file.type == :directory do %>
                  papkasini va uning barcha tarkibini o'chirmoqchimisiz?
                <% else %>
                  faylini o'chirmoqchimisiz?
                <% end %>
              </p>
            </div>
            <div class="flex justify-end gap-2">
              <button phx-click="cancel_delete" class="btn btn-ghost">Bekor qilish</button>
              <button phx-click="confirm_delete" class="btn btn-error">
                <Icons.icon name="trash" class="w-4 h-4" /> Ha, o'chirish
              </button>
            </div>
          </.modal>
        <% end %>

        <!-- New folder/file forms -->
        <%= if @show_new_folder do %>
          <div class="p-4 border-b border-base-content/10 bg-base-200/50">
            <form phx-submit="create_folder" class="flex gap-2 items-center">
              <Icons.icon name="folder" class="w-5 h-5 text-warning" />
              <input
                type="text"
                name="name"
                placeholder="Yangi papka nomi"
                class="input input-bordered input-sm flex-1"
                autofocus
                pattern="[^/\\]+"
                title="Papka nomida / yoki \ bo'lmasligi kerak"
              />
              <button type="submit" class="btn btn-primary btn-sm">Yaratish</button>
              <button type="button" phx-click="toggle_new_folder" class="btn btn-ghost btn-sm">
                Bekor
              </button>
            </form>
          </div>
        <% end %>

        <%= if @show_new_file do %>
          <div class="p-4 border-b border-base-content/10 bg-base-200/50">
            <form phx-submit="create_file" class="flex gap-2 items-center">
              <Icons.icon name="file" class="w-5 h-5 text-info" />
              <input
                type="text"
                name="name"
                placeholder="Yangi fayl nomi (masalan: config.yml)"
                class="input input-bordered input-sm flex-1"
                autofocus
                pattern="[^/\\]+"
                title="Fayl nomida / yoki \ bo'lmasligi kerak"
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
          <div class={"overflow-y-auto bg-base-100 #{if @selected_file, do: "w-1/2", else: "flex-1"}"}>
            <%= if @loading do %>
              <div class="flex flex-col items-center justify-center h-full">
                <span class="loading loading-spinner loading-lg text-primary"></span>
                <p class="mt-4 text-base-content/50">Yuklanmoqda...</p>
              </div>
            <% else %>
              <%= if @selected_server == nil do %>
                <div class="flex flex-col items-center justify-center h-full text-base-content/50">
                  <Icons.icon name="server" class="w-20 h-20 mb-4 opacity-20" />
                  <p class="text-xl font-medium">Server tanlang</p>
                  <p class="text-sm mt-2">Chap paneldan serverni tanlang</p>
                </div>
              <% else %>
                <%= if @current_path == nil do %>
                  <div class="flex flex-col items-center justify-center h-full text-base-content/50">
                    <Icons.icon name="folder" class="w-20 h-20 mb-4 opacity-20" />
                    <p class="text-xl font-medium">Papka tanlang</p>
                    <p class="text-sm mt-2">Tezkor o'tish tugmalaridan foydalaning</p>
                  </div>
                <% else %>
                  <%= if Enum.empty?(@files) do %>
                    <div class="flex flex-col items-center justify-center h-full text-base-content/50">
                      <Icons.icon name="folder" class="w-20 h-20 mb-4 opacity-20" />
                      <p class="text-xl font-medium">Papka bo'sh</p>
                      <p class="text-sm mt-2">Yangi fayl yoki papka yarating</p>
                    </div>
                  <% else %>
                    <!-- File table header -->
                    <div class="sticky top-0 bg-base-200 px-4 py-2 flex items-center gap-3 text-xs font-semibold text-base-content/50 uppercase border-b border-base-content/10">
                      <span class="w-8"></span>
                      <span class="flex-1">Nomi</span>
                      <span class="w-24 text-right">Hajmi</span>
                      <span class="w-40 text-right">O'zgartirilgan</span>
                      <span class="w-20 text-right">Ruxsat</span>
                    </div>

                    <!-- Parent directory -->
                    <%= if @current_path != "/" do %>
                      <button
                        phx-click="go_up"
                        class="w-full px-4 py-2.5 flex items-center gap-3 hover:bg-base-200 transition-colors text-left border-b border-base-content/5"
                      >
                        <span class="w-8 flex justify-center">
                          <Icons.icon name="folder" class="w-5 h-5 text-warning" />
                        </span>
                        <span class="flex-1 font-medium">..</span>
                        <span class="w-24"></span>
                        <span class="w-40"></span>
                        <span class="w-20 text-right text-xs text-base-content/50">Yuqoriga</span>
                      </button>
                    <% end %>

                    <!-- Files list -->
                    <%= for file <- @files do %>
                      <.file_row
                        file={file}
                        selected={@selected_file && @selected_file.path == file.path}
                      />
                    <% end %>
                  <% end %>
                <% end %>
              <% end %>
            <% end %>
          </div>

          <!-- File preview panel -->
          <%= if @selected_file do %>
            <div class="w-1/2 border-l border-base-content/10 flex flex-col bg-base-100">
              <!-- Preview header -->
              <div class="p-4 border-b border-base-content/10 bg-base-200/30">
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-3 min-w-0">
                    <.file_icon type={@selected_file.type} name={@selected_file.name} size="lg" />
                    <div class="min-w-0">
                      <h3 class="font-semibold truncate">{@selected_file.name}</h3>
                      <p class="text-xs text-base-content/50">{@selected_file.path}</p>
                    </div>
                  </div>
                  <button phx-click="close_preview" class="btn btn-ghost btn-sm btn-circle">
                    <Icons.icon name="x" class="w-5 h-5" />
                  </button>
                </div>
              </div>

              <!-- Action buttons -->
              <div class="px-4 py-2 border-b border-base-content/10 flex items-center gap-2">
                <%= if @selected_file.type == :file do %>
                  <%= if @editing do %>
                    <button phx-click="save_file" class="btn btn-success btn-sm gap-1">
                      <Icons.icon name="save" class="w-4 h-4" /> Saqlash
                    </button>
                    <button phx-click="cancel_edit" class="btn btn-ghost btn-sm">Bekor</button>
                  <% else %>
                    <button phx-click="edit_file" class="btn btn-ghost btn-sm gap-1">
                      <Icons.icon name="edit" class="w-4 h-4" /> Tahrirlash
                    </button>
                    <button phx-click="download_file" class="btn btn-ghost btn-sm gap-1">
                      <Icons.icon name="download" class="w-4 h-4" /> Yuklab olish
                    </button>
                  <% end %>
                <% else %>
                  <button
                    phx-click="open_dir"
                    phx-value-path={@selected_file.path}
                    class="btn btn-primary btn-sm gap-1"
                  >
                    <Icons.icon name="folder" class="w-4 h-4" /> Ochish
                  </button>
                <% end %>
                <div class="flex-1"></div>
                <button phx-click="toggle_rename" class="btn btn-ghost btn-sm gap-1">
                  <Icons.icon name="edit" class="w-4 h-4" /> Nomini o'zgartirish
                </button>
                <button phx-click="request_delete" class="btn btn-ghost btn-sm gap-1 text-error">
                  <Icons.icon name="trash" class="w-4 h-4" /> O'chirish
                </button>
              </div>

              <!-- Rename form -->
              <%= if @show_rename do %>
                <div class="p-4 border-b border-base-content/10 bg-warning/5">
                  <form phx-submit="rename_item" class="flex gap-2">
                    <input
                      type="text"
                      name="new_name"
                      value={@selected_file.name}
                      class="input input-bordered input-sm flex-1"
                      autofocus
                    />
                    <button type="submit" class="btn btn-warning btn-sm">Saqlash</button>
                    <button type="button" phx-click="toggle_rename" class="btn btn-ghost btn-sm">
                      Bekor
                    </button>
                  </form>
                </div>
              <% end %>

              <!-- File info -->
              <div class="p-4 border-b border-base-content/10 grid grid-cols-2 gap-3 text-sm">
                <div>
                  <span class="text-base-content/50">Turi:</span>
                  <span class="ml-2 font-medium">
                    {if @selected_file.type == :directory, do: "Papka", else: file_type_label(@selected_file.name)}
                  </span>
                </div>
                <div>
                  <span class="text-base-content/50">Hajmi:</span>
                  <span class="ml-2 font-medium">{format_size(@selected_file.size)}</span>
                </div>
                <div>
                  <span class="text-base-content/50">O'zgartirilgan:</span>
                  <span class="ml-2 font-medium">{format_mtime(@selected_file.mtime)}</span>
                </div>
                <div>
                  <span class="text-base-content/50">Ruxsatlar:</span>
                  <span class="ml-2 font-mono text-xs bg-base-200 px-2 py-0.5 rounded">
                    {format_mode(@selected_file.mode)}
                  </span>
                </div>
              </div>

              <!-- File content -->
              <%= if @file_content != nil do %>
                <div class="flex-1 overflow-auto bg-base-200/30">
                  <%= if @editing do %>
                    <textarea
                      id="file-editor"
                      phx-hook="FileEditor"
                      class="w-full h-full p-4 font-mono text-sm bg-transparent resize-none focus:outline-none"
                      spellcheck="false"
                    >{@file_content}</textarea>
                  <% else %>
                    <pre class="p-4 font-mono text-sm whitespace-pre-wrap"><%= @file_content %></pre>
                  <% end %>
                </div>
              <% else %>
                <%= if @selected_file.type == :file && @selected_file.size >= 1_048_576 do %>
                  <div class="flex-1 flex items-center justify-center text-base-content/50">
                    <div class="text-center">
                      <Icons.icon name="file" class="w-16 h-16 mx-auto mb-4 opacity-30" />
                      <p>Fayl juda katta ({format_size(@selected_file.size)})</p>
                      <p class="text-sm mt-1">Ko'rish uchun yuklab oling</p>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Status bar -->
        <%= if @selected_server && @current_path do %>
          <div class="h-8 px-4 flex items-center justify-between border-t border-base-content/10 bg-base-200/50 text-xs text-base-content/50">
            <span>{length(@files)} element</span>
            <span>{@selected_server.username}@{@selected_server.host}:{@current_path}</span>
          </div>
        <% end %>
      </main>
    </div>
    """
  end

  # Components
  defp modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/50" phx-click={@on_cancel}></div>
      <div class="relative bg-base-100 rounded-xl shadow-2xl w-full max-w-md mx-4 p-6">
        <h3 class="text-lg font-bold mb-4">{@title}</h3>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

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
          class={"hover:text-primary transition-colors truncate max-w-24 #{if idx == length(@crumbs) - 1, do: "font-medium text-primary", else: ""}"}
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
      class={"w-full px-4 py-2.5 flex items-center gap-3 transition-colors cursor-pointer border-b border-base-content/5 #{if @selected, do: "bg-primary/10", else: "hover:bg-base-200"}"}
      phx-click="select_file"
      phx-value-path={@file.path}
    >
      <span class="w-8 flex justify-center">
        <.file_icon type={@file.type} name={@file.name} />
      </span>
      <span class={"flex-1 truncate #{if @file.type == :directory, do: "font-medium"}"}>{@file.name}</span>
      <span class="w-24 text-right text-sm text-base-content/60">
        {if @file.type == :directory, do: "-", else: format_size(@file.size)}
      </span>
      <span class="w-40 text-right text-sm text-base-content/50">{format_mtime(@file.mtime)}</span>
      <span class="w-20 text-right font-mono text-xs text-base-content/40">
        {format_mode(@file.mode)}
      </span>
    </div>
    """
  end

  defp file_icon(%{type: :directory} = assigns) do
    size_class = if assigns[:size] == "lg", do: "w-8 h-8", else: "w-5 h-5"
    assigns = assign(assigns, :size_class, size_class)

    ~H"""
    <div class={"#{@size_class} flex items-center justify-center"}>
      <Icons.icon name="folder" class={"#{@size_class} text-warning"} />
    </div>
    """
  end

  defp file_icon(%{type: :file, name: name} = assigns) do
    size_class = if assigns[:size] == "lg", do: "w-8 h-8", else: "w-5 h-5"
    color = file_color(name)
    assigns = assign(assigns, :size_class, size_class)
    assigns = assign(assigns, :color, color)

    ~H"""
    <div class={"#{@size_class} flex items-center justify-center"}>
      <Icons.icon name="file" class={"#{@size_class} #{@color}"} />
    </div>
    """
  end

  defp file_icon(assigns) do
    size_class = if assigns[:size] == "lg", do: "w-8 h-8", else: "w-5 h-5"
    assigns = assign(assigns, :size_class, size_class)

    ~H"""
    <div class={"#{@size_class} flex items-center justify-center"}>
      <Icons.icon name="file" class={"#{@size_class} text-base-content/50"} />
    </div>
    """
  end

  defp file_color(name) do
    ext = Path.extname(name) |> String.downcase()

    cond do
      ext in @code_extensions -> "text-green-500"
      ext in @config_extensions -> "text-yellow-500"
      ext in ~w(.log .txt) -> "text-base-content/60"
      ext in ~w(.zip .tar .gz .bz2 .xz .7z .rar) -> "text-purple-500"
      ext in ~w(.jpg .jpeg .png .gif .svg .webp .ico) -> "text-pink-500"
      ext in ~w(.pdf .doc .docx .xls .xlsx) -> "text-red-500"
      true -> "text-info"
    end
  end

  defp file_type_label(name) do
    ext = Path.extname(name) |> String.downcase()

    cond do
      ext in @code_extensions -> "Kod fayli"
      ext in @config_extensions -> "Konfiguratsiya"
      ext in ~w(.log) -> "Log fayli"
      ext in ~w(.txt) -> "Matn fayli"
      ext in ~w(.zip .tar .gz .bz2 .xz .7z .rar) -> "Arxiv"
      ext in ~w(.jpg .jpeg .png .gif .svg .webp .ico) -> "Rasm"
      ext in ~w(.pdf) -> "PDF hujjat"
      ext == "" -> "Fayl"
      true -> String.upcase(String.trim_leading(ext, ".")) <> " fayl"
    end
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
    Integer.to_string(rem(mode, 4096), 8)
    |> String.pad_leading(4, "0")
  end

  defp format_mode(_), do: "-"

  defp path_to_breadcrumbs("/"), do: ["/"]

  defp path_to_breadcrumbs(path) do
    parts = String.split(path, "/", trim: true)
    ["/"] ++ parts
  end

  defp dangerous_path?(path) do
    path in @dangerous_paths
  end

  defp default_path(server) do
    "/home/#{server.username}"
  end

  # Event handlers
  @impl true
  def handle_event("select_server", %{"id" => id}, socket) do
    server = Enum.find(socket.assigns.servers, &(to_string(&1.id) == id))
    start_path = default_path(server)

    socket =
      socket
      |> assign(:selected_server, server)
      |> assign(:current_path, start_path)
      |> assign(:breadcrumbs, path_to_breadcrumbs(start_path))
      |> assign(:selected_file, nil)
      |> assign(:file_content, nil)
      |> assign(:loading, true)
      |> assign(:error, nil)

    send(self(), {:load_directory, start_path})
    {:noreply, socket}
  end

  @impl true
  def handle_event("quick_nav", %{"path" => path}, socket) do
    if dangerous_path?(path) do
      {:noreply,
       socket
       |> assign(:show_path_warning, true)
       |> assign(:pending_path, path)}
    else
      navigate_to_path(socket, path)
    end
  end

  @impl true
  def handle_event("confirm_path_warning", _, socket) do
    path = socket.assigns.pending_path

    socket =
      socket
      |> assign(:show_path_warning, false)
      |> assign(:pending_path, nil)

    navigate_to_path(socket, path)
  end

  @impl true
  def handle_event("cancel_path_warning", _, socket) do
    {:noreply,
     socket
     |> assign(:show_path_warning, false)
     |> assign(:pending_path, nil)}
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
      path = default_path(socket.assigns.selected_server)
      navigate_to_path(socket, path)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("go_up", _, socket) do
    current = socket.assigns.current_path
    parent = Path.dirname(current)

    if dangerous_path?(parent) && parent != socket.assigns.current_path do
      {:noreply,
       socket
       |> assign(:show_path_warning, true)
       |> assign(:pending_path, parent)}
    else
      navigate_to_path(socket, parent)
    end
  end

  @impl true
  def handle_event("navigate_to", %{"path" => path}, socket) do
    path = if path == "", do: "/", else: path

    if dangerous_path?(path) do
      {:noreply,
       socket
       |> assign(:show_path_warning, true)
       |> assign(:pending_path, path)}
    else
      navigate_to_path(socket, path)
    end
  end

  @impl true
  def handle_event("open_dir", %{"path" => path}, socket) do
    if dangerous_path?(path) do
      {:noreply,
       socket
       |> assign(:show_path_warning, true)
       |> assign(:pending_path, path)}
    else
      navigate_to_path(socket, path)
    end
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
    name = String.trim(name)

    if name == "" do
      {:noreply, assign(socket, :error, "Papka nomi bo'sh bo'lmasligi kerak")}
    else
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
  end

  @impl true
  def handle_event("create_file", %{"name" => name}, socket) do
    name = String.trim(name)

    if name == "" do
      {:noreply, assign(socket, :error, "Fayl nomi bo'sh bo'lmasligi kerak")}
    else
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
  end

  @impl true
  def handle_event("rename_item", %{"new_name" => new_name}, socket) do
    new_name = String.trim(new_name)

    if new_name == "" do
      {:noreply, assign(socket, :error, "Nom bo'sh bo'lmasligi kerak")}
    else
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
  end

  @impl true
  def handle_event("request_delete", _, socket) do
    {:noreply, assign(socket, :show_delete_confirm, true)}
  end

  @impl true
  def handle_event("cancel_delete", _, socket) do
    {:noreply, assign(socket, :show_delete_confirm, false)}
  end

  @impl true
  def handle_event("confirm_delete", _, socket) do
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
          |> assign(:show_delete_confirm, false)
          |> assign(:loading, true)

        send(self(), {:load_directory, socket.assigns.current_path})
        {:noreply, socket}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:show_delete_confirm, false)
         |> assign(:error, reason)}
    end
  end

  @impl true
  def handle_event("edit_file", _, socket) do
    {:noreply, assign(socket, :editing, true)}
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    send(self(), {:load_file_content, socket.assigns.selected_file.path})
    {:noreply, assign(socket, :editing, false)}
  end

  @impl true
  def handle_event("save_file", _, socket) do
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

  # Private helper for navigation
  defp navigate_to_path(socket, path) do
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
end
