defmodule OpsChatWeb.Router do
  use OpsChatWeb, :router

  import OpsChatWeb.Plugs.Auth, only: [call: 2, require_auth: 2]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OpsChatWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug OpsChatWeb.Plugs.Auth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Public routes
  scope "/", OpsChatWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/login", SessionController, :new
    post "/login", SessionController, :create
    delete "/logout", SessionController, :delete
  end

  # Protected routes
  scope "/", OpsChatWeb do
    pipe_through [:browser, :require_auth]

    live "/chat", ChatLive
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:ops_chat, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: OpsChatWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
