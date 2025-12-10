defmodule OpsChatWeb.AuditLive do
  @moduledoc """
  Audit dashboard - command history and statistics.
  """
  use OpsChatWeb, :live_view

  alias OpsChat.Audit

  @impl true
  def mount(_params, session, socket) do
    current_user = get_user_from_session(session)

    if current_user do
      # Only admin can access audit
      if current_user.role == "admin" do
        stats = Audit.get_stats()
        logs = Audit.list_logs(50)
        failures = Audit.recent_failures(10)

        {:ok,
         socket
         |> assign(:current_user, current_user)
         |> assign(:stats, stats)
         |> assign(:logs, logs)
         |> assign(:failures, failures)
         |> assign(:filter, "all")
         |> assign(:search, "")}
      else
        {:ok, redirect(socket, to: ~p"/chat") |> put_flash(:error, "Faqat admin kirishi mumkin")}
      end
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
    <div class="min-h-screen bg-base-200 p-4" data-theme="opschat">
      <div class="container mx-auto max-w-7xl">
        <!-- Header -->
        <div class="flex justify-between items-center mb-6">
          <div>
            <h1 class="text-3xl font-bold text-primary">📊 Audit Dashboard</h1>
            <p class="text-base-content/60">Barcha buyruqlar tarixi va statistikasi</p>
          </div>
          <div class="flex gap-2">
            <.link href={~p"/chat"} class="btn btn-ghost">← Chat</.link>
            <.link href={~p"/servers"} class="btn btn-ghost">🖥️ Servers</.link>
            <button phx-click="refresh" class="btn btn-primary">
              <span class="hero-arrow-path w-5 h-5"></span> Yangilash
            </button>
          </div>
        </div>
        
    <!-- Stats Cards -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <div class="card bg-base-100 shadow">
            <div class="card-body p-4">
              <div class="text-4xl font-bold text-primary">{@stats.total}</div>
              <div class="text-sm text-base-content/60">Jami buyruqlar</div>
            </div>
          </div>
          <div class="card bg-base-100 shadow">
            <div class="card-body p-4">
              <div class="text-4xl font-bold text-info">{@stats.today}</div>
              <div class="text-sm text-base-content/60">Bugungi buyruqlar</div>
            </div>
          </div>
          <div class="card bg-base-100 shadow">
            <div class="card-body p-4">
              <div class="text-4xl font-bold text-success">{@stats.by_status["success"] || 0}</div>
              <div class="text-sm text-base-content/60">Muvaffaqiyatli</div>
            </div>
          </div>
          <div class="card bg-base-100 shadow">
            <div class="card-body p-4">
              <div class="text-4xl font-bold text-error">{@stats.by_status["error"] || 0}</div>
              <div class="text-sm text-base-content/60">Xatolar</div>
            </div>
          </div>
        </div>
        
    <!-- Charts Row -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
          <!-- Top Actions -->
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <h2 class="card-title text-lg">📈 Eng ko'p ishlatilgan buyruqlar</h2>
              <div class="space-y-2">
                <%= for {action, count} <- @stats.by_action do %>
                  <div class="flex items-center gap-3">
                    <div class="flex-1">
                      <div class="flex justify-between mb-1">
                        <span class="font-mono text-sm">{action}</span>
                        <span class="badge badge-sm">{count}</span>
                      </div>
                      <progress
                        class="progress progress-primary"
                        value={count}
                        max={max_count(@stats.by_action)}
                      >
                      </progress>
                    </div>
                  </div>
                <% end %>
                <%= if Enum.empty?(@stats.by_action) do %>
                  <p class="text-base-content/50 text-center py-4">Hali buyruqlar yo'q</p>
                <% end %>
              </div>
            </div>
          </div>
          
    <!-- Top Servers -->
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <h2 class="card-title text-lg">🖥️ Eng ko'p ishlatilgan serverlar</h2>
              <div class="space-y-2">
                <%= for {target, count} <- @stats.by_target do %>
                  <div class="flex items-center gap-3">
                    <div class="flex-1">
                      <div class="flex justify-between mb-1">
                        <span class="font-medium">{target}</span>
                        <span class="badge badge-sm badge-info">{count}</span>
                      </div>
                      <progress
                        class="progress progress-info"
                        value={count}
                        max={max_count(@stats.by_target)}
                      >
                      </progress>
                    </div>
                  </div>
                <% end %>
                <%= if Enum.empty?(@stats.by_target) do %>
                  <p class="text-base-content/50 text-center py-4">Hali server buyruqlari yo'q</p>
                <% end %>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Users & Activity -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
          <!-- Top Users -->
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <h2 class="card-title text-lg">👥 Faol foydalanuvchilar</h2>
              <div class="space-y-2">
                <%= for {username, count} <- @stats.by_user do %>
                  <div class="flex items-center gap-3">
                    <div class="avatar placeholder">
                      <div class="bg-primary text-primary-content rounded-full w-8">
                        <span class="text-sm">
                          {String.first(username || "?") |> String.upcase()}
                        </span>
                      </div>
                    </div>
                    <div class="flex-1">
                      <div class="flex justify-between">
                        <span class="font-medium">{username || "Unknown"}</span>
                        <span class="badge badge-sm">{count} buyruq</span>
                      </div>
                    </div>
                  </div>
                <% end %>
                <%= if Enum.empty?(@stats.by_user) do %>
                  <p class="text-base-content/50 text-center py-4">Hali faoliyat yo'q</p>
                <% end %>
              </div>
            </div>
          </div>
          
    <!-- Recent Failures -->
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <h2 class="card-title text-lg text-error">⚠️ So'nggi xatolar</h2>
              <div class="space-y-2 max-h-64 overflow-y-auto">
                <%= for log <- @failures do %>
                  <div class="bg-error/10 rounded-lg p-2">
                    <div class="flex justify-between items-start">
                      <div>
                        <span class="font-mono text-sm text-error">{log.action}</span>
                        <%= if log.target do %>
                          <span class="badge badge-sm badge-ghost ml-1">{log.target}</span>
                        <% end %>
                      </div>
                      <span class="text-xs text-base-content/50">{format_time(log.inserted_at)}</span>
                    </div>
                    <div class="text-xs text-base-content/60 mt-1 truncate">{log.result}</div>
                  </div>
                <% end %>
                <%= if Enum.empty?(@failures) do %>
                  <div class="text-center py-4 text-success">
                    <span class="hero-check-circle w-8 h-8 mx-auto mb-2"></span>
                    <p>Xatolar yo'q!</p>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Activity by Day Chart -->
        <%= if length(@stats.by_day) > 0 do %>
          <div class="card bg-base-100 shadow mb-6">
            <div class="card-body">
              <h2 class="card-title text-lg">📅 Haftalik faollik</h2>
              <div class="flex items-end justify-around h-32 gap-2">
                <%= for {date, count} <- @stats.by_day do %>
                  <div class="flex flex-col items-center">
                    <div
                      class="bg-primary rounded-t w-8 min-h-[4px] transition-all"
                      style={"height: #{bar_height(count, @stats.by_day)}px"}
                    >
                    </div>
                    <div class="text-xs text-base-content/50 mt-1 rotate-45 origin-left">
                      {format_date(date)}
                    </div>
                    <div class="text-xs font-bold">{count}</div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
        
    <!-- Logs Table -->
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <div class="flex justify-between items-center mb-4">
              <h2 class="card-title">📋 Buyruqlar tarixi</h2>
              <div class="flex gap-2">
                <select class="select select-bordered select-sm" phx-change="filter">
                  <option value="all" selected={@filter == "all"}>Hammasi</option>
                  <option value="success" selected={@filter == "success"}>Muvaffaqiyatli</option>
                  <option value="error" selected={@filter == "error"}>Xatolar</option>
                </select>
              </div>
            </div>

            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr class="text-base-content/70">
                    <th>Vaqt</th>
                    <th>Foydalanuvchi</th>
                    <th>Buyruq</th>
                    <th>Server</th>
                    <th>Status</th>
                    <th>Natija</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for log <- @logs do %>
                    <tr class="hover">
                      <td class="text-xs text-base-content/60 whitespace-nowrap">
                        {format_datetime(log.inserted_at)}
                      </td>
                      <td>
                        <div class="flex items-center gap-2">
                          <div class="avatar placeholder">
                            <div class="bg-neutral text-neutral-content rounded-full w-6">
                              <span class="text-xs">
                                {String.first((log.user && log.user.username) || "?")
                                |> String.upcase()}
                              </span>
                            </div>
                          </div>
                          <span class="text-sm">{(log.user && log.user.username) || "?"}</span>
                        </div>
                      </td>
                      <td class="font-mono text-sm">{log.action}</td>
                      <td>
                        <%= if log.target do %>
                          <span class="badge badge-sm badge-ghost">{log.target}</span>
                        <% else %>
                          <span class="text-base-content/30">-</span>
                        <% end %>
                      </td>
                      <td>
                        <span class={"badge badge-sm #{if log.status == "success", do: "badge-success", else: "badge-error"}"}>
                          {log.status}
                        </span>
                      </td>
                      <td class="max-w-xs">
                        <div class="text-xs text-base-content/60 truncate" title={log.result}>
                          {String.slice(log.result || "", 0, 50)}{if String.length(log.result || "") >
                                                                       50,
                                                                     do: "..."}
                        </div>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>

              <%= if Enum.empty?(@logs) do %>
                <div class="text-center py-8 text-base-content/50">
                  <span class="hero-document-text w-12 h-12 mx-auto mb-2 opacity-30"></span>
                  <p>Hali buyruqlar yo'q</p>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("refresh", _, socket) do
    stats = Audit.get_stats()
    logs = fetch_logs(socket.assigns.filter)
    failures = Audit.recent_failures(10)

    {:noreply,
     socket
     |> assign(:stats, stats)
     |> assign(:logs, logs)
     |> assign(:failures, failures)}
  end

  @impl true
  def handle_event("filter", %{"_target" => _, "value" => filter}, socket) do
    logs = fetch_logs(filter)
    {:noreply, socket |> assign(:filter, filter) |> assign(:logs, logs)}
  end

  def handle_event("filter", %{"value" => filter}, socket) do
    logs = fetch_logs(filter)
    {:noreply, socket |> assign(:filter, filter) |> assign(:logs, logs)}
  end

  defp fetch_logs("all"), do: Audit.list_logs(50)
  defp fetch_logs(status), do: Audit.list_logs_by_status(status, 50)

  defp max_count(list) when is_list(list) do
    case list do
      [] -> 1
      _ -> list |> Enum.map(fn {_, count} -> count end) |> Enum.max()
    end
  end

  defp bar_height(count, list) do
    max = max_count(list)
    if max > 0, do: round(count / max * 100), else: 4
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M")
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%m/%d %H:%M")
  end

  defp format_date(date_str) when is_binary(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> Calendar.strftime(date, "%m/%d")
      _ -> date_str
    end
  end

  defp format_date(_), do: ""
end
