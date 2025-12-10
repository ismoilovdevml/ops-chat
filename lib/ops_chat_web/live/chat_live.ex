defmodule OpsChatWeb.ChatLive do
  use OpsChatWeb, :live_view

  alias OpsChat.Chat
  alias OpsChat.Accounts
  alias OpsChat.Bot

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
    <div class="flex flex-col h-screen bg-gray-900">
      <!-- Header -->
      <header class="bg-gray-800 border-b border-gray-700 px-4 py-3 flex justify-between items-center">
        <div class="flex items-center gap-3">
          <span class="text-green-400 font-bold text-xl">OpsChat</span>
          <span class="text-gray-500 text-sm">DevOps Command Center</span>
        </div>
        <div class="flex items-center gap-4">
          <span class="text-gray-400">
            <span class="text-green-400"><%= @current_user.username %></span>
            <span class="text-gray-600 text-sm">(<%= @current_user.role %>)</span>
          </span>
          <.link href={~p"/logout"} method="delete" class="text-red-400 hover:text-red-300 text-sm">
            Chiqish
          </.link>
        </div>
      </header>

      <!-- Messages -->
      <div class="flex-1 overflow-y-auto p-4 space-y-3" id="messages" phx-hook="ScrollBottom">
        <%= for message <- @messages do %>
          <div class={"flex #{message_alignment(message.type)}"}>
            <div class={"max-w-2xl rounded-lg px-4 py-2 #{message_style(message.type)}"}>
              <div class="flex items-center gap-2 mb-1">
                <span class={"font-semibold text-sm #{username_color(message.type)}"}>
                  <%= if message.type == "bot", do: "Bot", else: message.user.username %>
                </span>
                <span class="text-gray-500 text-xs">
                  <%= format_time(message.inserted_at) %>
                </span>
              </div>
              <div class={"whitespace-pre-wrap #{content_style(message.type)}"}>
                <%= message.content %>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Input -->
      <div class="bg-gray-800 border-t border-gray-700 p-4">
        <form phx-submit="send_message" class="flex gap-3">
          <input
            type="text"
            name="message"
            value={@message_input}
            placeholder="Xabar yozing yoki /help buyrug'ini kiriting..."
            autocomplete="off"
            class="flex-1 bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-green-500"
          />
          <button
            type="submit"
            class="bg-green-600 hover:bg-green-500 text-white px-6 py-2 rounded-lg font-medium transition-colors"
          >
            Yuborish
          </button>
        </form>
        <div class="mt-2 text-gray-500 text-xs">
          Buyruqlar: /help, /status, /disk, /memory, /uptime, /logs [service]
        </div>
      </div>
    </div>
    """
  end

  defp message_alignment("bot"), do: "justify-start"
  defp message_alignment("system"), do: "justify-center"
  defp message_alignment(_), do: "justify-end"

  defp message_style("bot"), do: "bg-gray-700 border border-gray-600"
  defp message_style("system"), do: "bg-yellow-900/30 border border-yellow-700/50"
  defp message_style(_), do: "bg-green-900/30 border border-green-700/50"

  defp username_color("bot"), do: "text-blue-400"
  defp username_color("system"), do: "text-yellow-400"
  defp username_color(_), do: "text-green-400"

  defp content_style("bot"), do: "text-gray-200 font-mono text-sm"
  defp content_style(_), do: "text-gray-200"

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M")
  end
end
