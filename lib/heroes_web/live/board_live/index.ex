defmodule HeroesWeb.BoardLive.Index do
  use HeroesWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    name = if connected?(socket), do: Heroes.Randomizer.generate_name(), else: nil
    {:ok, assign(socket, :name, name)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2> Join the game!</h2>

      <.form let={f} for={:game} phx-submit="join_game">
        <%= label f, :name %>
        <%= text_input f, :name, value: @name %>
        <%= submit do: "Join" %>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("join_game", %{"game" => %{"name" => name}}, socket) do
    {:noreply, push_redirect(socket, to: Routes.board_show_path(socket, :show, name))}
  end
end
