defmodule HeroesWeb.BoardLive.Show do
  use HeroesWeb, :live_view

  alias Heroes.Game

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, game: %{}, board_state: %{}, player_name: nil, disabled: true)}
  end

  @impl true
  def handle_params(%{"name" => name}, _, socket) do
    if connected?(socket) do
      game = Game.join_as(name)

      board_state = Game.get_board_state(game.board_pid)

      {:noreply,
       assign(socket, game: game, board_state: board_state, player_name: name, disabled: false)}
    else
      {:noreply, socket}
    end
  end

  defp page_title(:show), do: "Show Board"

  defp disabled?(game, player_name) do
    player =
      game
      |> get_in([Access.key(:players), player_name])
      |> Game.get_player()

    player && player.prone
  end

  @impl true
  def handle_event(
        "move",
        %{"direction" => direction},
        %{assigns: %{player_name: player_name}} = socket
      ) do
    Game.get_game()
    |> Game.move_player(player_name, direction)

    {:noreply, socket}
  end

  def handle_event("attack", _unsigned_params, %{assigns: %{player_name: player_name}} = socket) do
    Game.get_game()
    |> Game.player_attack(player_name)

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:redraw_board, board_pid},
        %{assigns: %{game: game, board_state: board_state, player_name: player_name}} = socket
      ) do
    updated_board_state =
      if game.board_pid == board_pid do
        Game.get_board_state(board_pid)
      else
        board_state
      end

    updated_game = Game.get_game()

    {:noreply,
     assign(socket,
       game: updated_game,
       board_state: updated_board_state,
       disabled: disabled?(game, player_name)
     )}
  end
end
