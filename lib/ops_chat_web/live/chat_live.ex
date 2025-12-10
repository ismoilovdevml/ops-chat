defmodule OpsChatWeb.ChatLive do
  @moduledoc """
  Discord-style chat with channels sidebar and message actions.
  """
  use OpsChatWeb, :live_view

  alias OpsChat.Bot
  alias OpsChat.Chat

  @impl true
  def mount(%{"channel" => channel_slug}, session, socket) do
    mount_with_channel(channel_slug, session, socket)
  end

  def mount(_params, session, socket) do
    mount_with_channel("general", session, socket)
  end

  defp mount_with_channel(channel_slug, session, socket) do
    current_user = get_user_from_session(session)

    if current_user do
      Chat.ensure_default_channels()

      channels = Chat.list_channels()
      current_channel = Chat.get_channel_by_slug(channel_slug) || Chat.get_default_channel()

      if connected?(socket) do
        Phoenix.PubSub.subscribe(OpsChat.PubSub, "chat:#{current_channel.id}")
      end

      messages = if current_channel, do: Chat.list_messages(current_channel.id), else: []

      {:ok,
       socket
       |> assign(:current_user, current_user)
       |> assign(:channels, channels)
       |> assign(:current_channel, current_channel)
       |> assign(:messages, messages)
       |> assign(:show_channel_form, false)
       |> assign(:editing_message_id, nil)
       |> assign(:edit_content, "")}
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
      <!-- Sidebar -->
      <aside class="w-64 bg-base-300 flex flex-col border-r border-base-content/10">
        <div class="p-4 border-b border-base-content/10">
          <h1 class="text-xl font-bold text-primary flex items-center gap-2">
            🖥️ OpsChat
          </h1>
          <p class="text-xs text-base-content/50 mt-1">DevOps Command Center</p>
        </div>

        <div class="flex-1 overflow-y-auto p-2">
          <div class="mb-4">
            <div class="flex items-center justify-between px-2 mb-1">
              <span class="text-xs font-semibold text-base-content/50 uppercase">Kanallar</span>
              <%= if @current_user.role == "admin" do %>
                <button phx-click="toggle_channel_form" class="btn btn-ghost btn-xs">➕</button>
              <% end %>
            </div>
            <%= for channel <- Enum.filter(@channels, &(&1.type in ["general", "custom"])) do %>
              <.channel_item channel={channel} current={@current_channel} />
            <% end %>
          </div>

          <%= if Enum.any?(@channels, &(&1.type == "server")) do %>
            <div class="mb-4">
              <span class="text-xs font-semibold text-base-content/50 uppercase px-2">Serverlar</span>
              <%= for channel <- Enum.filter(@channels, &(&1.type == "server")) do %>
                <.channel_item channel={channel} current={@current_channel} />
              <% end %>
            </div>
          <% end %>
        </div>

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
                <div class="text-xs text-base-content/50">{@current_user.role}</div>
              </div>
            </div>
            <.link href={~p"/logout"} method="delete" class="btn btn-ghost btn-xs" title="Chiqish">
              🚪
            </.link>
          </div>
        </div>
      </aside>
      
    <!-- Main Content -->
      <main class="flex-1 flex flex-col">
        <header class="h-14 px-4 flex items-center justify-between border-b border-base-content/10 bg-base-100">
          <div class="flex items-center gap-2">
            <span class="text-xl">{@current_channel && @current_channel.icon}</span>
            <div>
              <h2 class="font-semibold">{@current_channel && @current_channel.name}</h2>
              <p class="text-xs text-base-content/50">
                {@current_channel && @current_channel.description}
              </p>
            </div>
          </div>
          <div class="flex items-center gap-2">
            <.link href={~p"/servers"} class="btn btn-ghost btn-sm gap-1">
              🖥️ <span class="hidden sm:inline">Serverlar</span>
            </.link>
            <%= if @current_user.role == "admin" do %>
              <.link href={~p"/audit"} class="btn btn-ghost btn-sm gap-1">
                📊 <span class="hidden sm:inline">Audit</span>
              </.link>
            <% end %>
          </div>
        </header>
        
    <!-- Messages -->
        <div
          class="flex-1 overflow-y-auto p-4 space-y-1 bg-base-100"
          id="messages"
          phx-hook="ScrollBottom"
        >
          <%= if @show_channel_form do %>
            <.channel_form />
          <% end %>

          <%= for message <- @messages do %>
            <.message_item
              message={message}
              current_user={@current_user}
              editing={@editing_message_id == message.id}
              edit_content={@edit_content}
            />
          <% end %>

          <%= if Enum.empty?(@messages) do %>
            <div class="text-center py-12 text-base-content/50">
              <p class="text-4xl mb-2">{@current_channel && @current_channel.icon}</p>
              <p class="font-medium">
                #{@current_channel && @current_channel.name} kanaliga xush kelibsiz!
              </p>
              <p class="text-sm mt-1">Bu yerda hali xabarlar yo'q. Birinchi bo'lib yozing!</p>
            </div>
          <% end %>
        </div>
        
    <!-- Input -->
        <div class="p-4 border-t border-base-content/10 bg-base-100">
          <form phx-submit="send_message" id="message-form" phx-hook="ClearInput" class="flex gap-3">
            <input
              type="text"
              name="message"
              id="message-input"
              placeholder={"##{@current_channel && @current_channel.name} ga xabar yozing..."}
              autocomplete="off"
              class="input input-bordered flex-1 bg-base-200"
              phx-keydown="typing"
            />
            <button type="submit" class="btn btn-primary" title="Yuborish">
              📤
            </button>
          </form>
          <div class="mt-2 text-base-content/40 text-xs">
            /help - buyruqlar | /servers - serverlar | /r &lt;server&gt; &lt;cmd&gt; - remote buyruq
          </div>
        </div>
      </main>
    </div>
    """
  end

  # Components
  defp channel_item(assigns) do
    ~H"""
    <.link
      patch={~p"/chat/#{@channel.slug}"}
      class={"flex items-center gap-2 px-2 py-1.5 rounded-lg text-sm transition-colors #{if @current && @current.id == @channel.id, do: "bg-primary/10 text-primary font-medium", else: "hover:bg-base-200 text-base-content/70"}"}
    >
      <span>{@channel.icon}</span>
      <span class="truncate">{@channel.name}</span>
    </.link>
    """
  end

  defp message_item(assigns) do
    ~H"""
    <div class="flex gap-3 group hover:bg-base-200/50 rounded-lg p-2 -mx-2 transition-colors">
      <div class="avatar placeholder flex-shrink-0">
        <div class={message_avatar_class(@message.type)}>
          <span class="text-sm">
            {if @message.type == "bot",
              do: "🤖",
              else: (@message.user && String.first(@message.user.username) |> String.upcase()) || "?"}
          </span>
        </div>
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex items-baseline gap-2">
          <span class={message_username_class(@message.type)}>
            {if @message.type == "bot",
              do: "Bot",
              else: (@message.user && @message.user.username) || "System"}
          </span>
          <span class="text-xs text-base-content/40">{format_time(@message.inserted_at)}</span>
          
    <!-- Message Actions -->
          <%= if !@editing && @message.type == "user" do %>
            <div class="opacity-0 group-hover:opacity-100 transition-opacity flex gap-1 ml-auto">
              <%= if can_edit?(@message, @current_user) do %>
                <button
                  phx-click="start_edit"
                  phx-value-id={@message.id}
                  class="btn btn-ghost btn-xs"
                  title="Tahrirlash"
                >
                  ✏️
                </button>
                <button
                  phx-click="delete_message"
                  phx-value-id={@message.id}
                  class="btn btn-ghost btn-xs text-error"
                  title="O'chirish"
                  data-confirm="Xabarni o'chirmoqchimisiz?"
                >
                  🗑️
                </button>
              <% end %>
              <%= if @current_user.role == "admin" && !can_edit?(@message, @current_user) do %>
                <button
                  phx-click="delete_message"
                  phx-value-id={@message.id}
                  class="btn btn-ghost btn-xs text-error"
                  title="O'chirish (admin)"
                  data-confirm="Xabarni o'chirmoqchimisiz?"
                >
                  🗑️
                </button>
              <% end %>
            </div>
          <% end %>
        </div>

        <%= if @editing do %>
          <form phx-submit="save_edit" class="mt-1 flex gap-2">
            <input type="hidden" name="message_id" value={@message.id} />
            <input
              type="text"
              name="content"
              value={@edit_content}
              class="input input-bordered input-sm flex-1"
              phx-keydown="cancel_edit_on_escape"
              autofocus
            />
            <button type="submit" class="btn btn-primary btn-sm">💾</button>
            <button type="button" phx-click="cancel_edit" class="btn btn-ghost btn-sm">❌</button>
          </form>
        <% else %>
          <div class={message_content_class(@message.type)}>
            <pre class="whitespace-pre-wrap font-mono text-sm"><%= @message.content %></pre>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp channel_form(assigns) do
    ~H"""
    <div class="card bg-base-200 mb-4">
      <div class="card-body p-4">
        <h3 class="font-semibold mb-2">Yangi kanal yaratish</h3>
        <form phx-submit="create_channel" class="flex gap-2">
          <input
            type="text"
            name="name"
            placeholder="Kanal nomi"
            class="input input-bordered input-sm flex-1"
            required
          />
          <input
            type="text"
            name="icon"
            placeholder="📌"
            class="input input-bordered input-sm w-16"
            value="💬"
          />
          <button type="submit" class="btn btn-primary btn-sm">Yaratish</button>
          <button type="button" phx-click="toggle_channel_form" class="btn btn-ghost btn-sm">
            Bekor
          </button>
        </form>
      </div>
    </div>
    """
  end

  defp message_avatar_class("bot"), do: "bg-neutral text-neutral-content rounded-full w-10"
  defp message_avatar_class("alert"), do: "bg-error text-error-content rounded-full w-10"
  defp message_avatar_class(_), do: "bg-primary text-primary-content rounded-full w-10"

  defp message_username_class("bot"), do: "font-semibold text-info"
  defp message_username_class("alert"), do: "font-semibold text-error"
  defp message_username_class(_), do: "font-semibold text-base-content"

  defp message_content_class("bot"), do: "mt-1 bg-neutral/10 rounded-lg p-3 text-base-content"
  defp message_content_class("alert"), do: "mt-1 bg-error/10 rounded-lg p-3 text-error"
  defp message_content_class(_), do: "mt-1"

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M")
  end

  defp can_edit?(message, current_user) do
    message.user_id == current_user.id
  end

  # Event Handlers
  @impl true
  def handle_params(%{"channel" => channel_slug}, _uri, socket) do
    case Chat.get_channel_by_slug(channel_slug) do
      nil ->
        {:noreply, push_navigate(socket, to: ~p"/chat")}

      channel ->
        if socket.assigns.current_channel do
          Phoenix.PubSub.unsubscribe(OpsChat.PubSub, "chat:#{socket.assigns.current_channel.id}")
        end

        Phoenix.PubSub.subscribe(OpsChat.PubSub, "chat:#{channel.id}")
        messages = Chat.list_messages(channel.id)

        {:noreply,
         socket
         |> assign(:current_channel, channel)
         |> assign(:messages, messages)
         |> assign(:editing_message_id, nil)}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("send_message", %{"message" => content}, socket) do
    content = String.trim(content)

    if content != "" do
      channel_id = socket.assigns.current_channel.id
      user = socket.assigns.current_user

      {:ok, message} = Chat.create_channel_message(channel_id, user.id, content)
      broadcast_message(channel_id, message)

      if String.starts_with?(content, "/") do
        bot_response = Bot.execute_command(content, user)
        {:ok, bot_message} = Chat.create_bot_message(bot_response, user.id, channel_id)
        broadcast_message(channel_id, bot_message)
      end

      {:noreply, push_event(socket, "clear-input", %{})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("typing", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle_channel_form", _, socket) do
    {:noreply, assign(socket, :show_channel_form, !socket.assigns.show_channel_form)}
  end

  @impl true
  def handle_event("create_channel", %{"name" => name, "icon" => icon}, socket) do
    icon = if icon == "", do: "💬", else: icon

    case Chat.create_channel(%{
           name: name,
           slug: name |> String.downcase() |> String.replace(~r/[^a-z0-9]/, "-"),
           icon: icon,
           type: "custom",
           user_id: socket.assigns.current_user.id
         }) do
      {:ok, channel} ->
        channels = Chat.list_channels()

        {:noreply,
         socket
         |> assign(:channels, channels)
         |> assign(:show_channel_form, false)
         |> push_navigate(to: ~p"/chat/#{channel.slug}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Kanal yaratishda xatolik")}
    end
  end

  @impl true
  def handle_event("start_edit", %{"id" => id}, socket) do
    message = Enum.find(socket.assigns.messages, &(to_string(&1.id) == id))

    if message && can_edit?(message, socket.assigns.current_user) do
      {:noreply,
       socket
       |> assign(:editing_message_id, message.id)
       |> assign(:edit_content, message.content)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply,
     socket
     |> assign(:editing_message_id, nil)
     |> assign(:edit_content, "")}
  end

  @impl true
  def handle_event("cancel_edit_on_escape", %{"key" => "Escape"}, socket) do
    {:noreply,
     socket
     |> assign(:editing_message_id, nil)
     |> assign(:edit_content, "")}
  end

  def handle_event("cancel_edit_on_escape", _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("save_edit", %{"message_id" => id, "content" => content}, socket) do
    content = String.trim(content)

    if content != "" do
      case Chat.update_message(String.to_integer(id), %{content: content}) do
        {:ok, updated_message} ->
          messages =
            Enum.map(socket.assigns.messages, fn m ->
              if m.id == updated_message.id, do: updated_message, else: m
            end)

          Phoenix.PubSub.broadcast(
            OpsChat.PubSub,
            "chat:#{socket.assigns.current_channel.id}",
            {:message_updated, updated_message}
          )

          {:noreply,
           socket
           |> assign(:messages, messages)
           |> assign(:editing_message_id, nil)
           |> assign(:edit_content, "")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Xabarni tahrirlashda xatolik")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_message", %{"id" => id}, socket) do
    message_id = String.to_integer(id)
    message = Enum.find(socket.assigns.messages, &(&1.id == message_id))

    can_delete =
      message &&
        (can_edit?(message, socket.assigns.current_user) ||
           socket.assigns.current_user.role == "admin")

    if can_delete do
      case Chat.delete_message(message_id) do
        {:ok, _} ->
          messages = Enum.reject(socket.assigns.messages, &(&1.id == message_id))

          Phoenix.PubSub.broadcast(
            OpsChat.PubSub,
            "chat:#{socket.assigns.current_channel.id}",
            {:message_deleted, message_id}
          )

          {:noreply, assign(socket, :messages, messages)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Xabarni o'chirishda xatolik")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    {:noreply, assign(socket, :messages, socket.assigns.messages ++ [message])}
  end

  @impl true
  def handle_info({:message_updated, updated_message}, socket) do
    messages =
      Enum.map(socket.assigns.messages, fn m ->
        if m.id == updated_message.id, do: updated_message, else: m
      end)

    {:noreply, assign(socket, :messages, messages)}
  end

  @impl true
  def handle_info({:message_deleted, message_id}, socket) do
    messages = Enum.reject(socket.assigns.messages, &(&1.id == message_id))
    {:noreply, assign(socket, :messages, messages)}
  end

  defp broadcast_message(channel_id, message) do
    Phoenix.PubSub.broadcast(OpsChat.PubSub, "chat:#{channel_id}", {:new_message, message})
  end
end
