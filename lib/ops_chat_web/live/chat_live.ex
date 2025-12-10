defmodule OpsChatWeb.ChatLive do
  use OpsChatWeb, :live_view

  alias OpsChat.Accounts
  alias OpsChat.Bot
  alias OpsChat.Chat

  @impl true
  def mount(_params, session, socket) do
    user = Accounts.get_user(session["user_id"])

    if connected?(socket) do
      Phoenix.PubSub.subscribe(OpsChat.PubSub, "chat:lobby")
    end

    messages = Chat.list_messages(100)

    {:ok,
     socket
     |> assign(:current_user, user)
     |> assign(:messages, messages)
     |> assign(:message_input, "")}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    message = String.trim(message)

    if message != "" do
      user = socket.assigns.current_user

      # Save user message
      {:ok, user_message} = Chat.create_message(%{
        content: message,
        user_id: user.id,
        type: "user"
      })

      broadcast_message(user_message)

      # Check if it's a bot command
      if String.starts_with?(message, "/") do
        Task.start(fn ->
          bot_response = Bot.execute_command(message, user)
          {:ok, bot_message} = Chat.create_bot_message(bot_response, user.id)
          broadcast_message(bot_message)
        end)
      end
    end

    {:noreply, assign(socket, :message_input, "")}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    {:noreply, update(socket, :messages, fn messages -> messages ++ [message] end)}
  end

  defp broadcast_message(message) do
    Phoenix.PubSub.broadcast(OpsChat.PubSub, "chat:lobby", {:new_message, message})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-screen bg-base-300" data-theme="opschat">
      <!-- Header -->
      <header class="navbar bg-base-200 border-b border-base-content/10">
        <div class="flex-1">
          <span class="text-success font-bold text-xl">🖥️ OpsChat</span>
          <span class="text-base-content/50 text-sm ml-2">DevOps Command Center</span>
        </div>
        <div class="flex-none gap-2">
          <.link href={~p"/servers"} class="btn btn-ghost btn-sm">
            📡 Serverlar
          </.link>
          <div class="dropdown dropdown-end">
            <div tabindex="0" role="button" class="btn btn-ghost">
              <span class="text-success"><%= @current_user.username %></span>
              <span class="badge badge-sm"><%= @current_user.role %></span>
            </div>
            <ul tabindex="0" class="dropdown-content menu bg-base-200 rounded-box z-1 w-52 p-2 shadow">
              <li>
                <.link href={~p"/logout"} method="delete" class="text-error">
                  Chiqish
                </.link>
              </li>
            </ul>
          </div>
        </div>
      </header>

      <!-- Messages -->
      <div class="flex-1 overflow-y-auto p-4 space-y-3" id="messages" phx-hook="ScrollBottom">
        <%= for message <- @messages do %>
          <div class={"chat #{chat_position(message.type)}"}>
            <div class="chat-header">
              <span class={username_color(message.type)}>
                <%= if message.type == "bot", do: "🤖 Bot", else: message.user.username %>
              </span>
              <time class="text-xs opacity-50 ml-1"><%= format_time(message.inserted_at) %></time>
            </div>
            <div class={"chat-bubble #{bubble_style(message.type)}"}>
              <pre class={"whitespace-pre-wrap text-sm #{if message.type == "bot", do: "font-mono", else: ""}"}><%= message.content %></pre>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Input -->
      <div class="bg-base-200 border-t border-base-content/10 p-4">
        <form phx-submit="send_message" class="flex gap-3">
          <input
            type="text"
            name="message"
            value={@message_input}
            placeholder="Xabar yozing yoki /help buyrug'ini kiriting..."
            autocomplete="off"
            class="input input-bordered flex-1"
          />
          <button type="submit" class="btn btn-success">
            Yuborish
          </button>
        </form>
        <div class="mt-2 text-base-content/50 text-xs">
          /help - barcha buyruqlar | /servers - serverlar | /ssh add web1 root@192.168.1.10 - server qo'shish
        </div>
      </div>
    </div>
    """
  end

  defp chat_position("bot"), do: "chat-start"
  defp chat_position("system"), do: "chat-start"
  defp chat_position(_), do: "chat-end"

  defp bubble_style("bot"), do: "bg-neutral text-neutral-content"
  defp bubble_style("system"), do: "chat-bubble-warning"
  defp bubble_style(_), do: "chat-bubble-primary"

  defp username_color("bot"), do: "text-info"
  defp username_color("system"), do: "text-warning"
  defp username_color(_), do: "text-success"

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M")
  end
end
