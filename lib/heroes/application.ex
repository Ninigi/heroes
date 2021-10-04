defmodule Heroes.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      HeroesWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Heroes.PubSub},
      # Start the Endpoint (http/https)
      HeroesWeb.Endpoint,
      # Start a worker by calling: Heroes.Worker.start_link(arg)
      Heroes.Game
      # {Heroes.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Heroes.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HeroesWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
