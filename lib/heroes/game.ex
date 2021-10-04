defmodule Heroes.Game do
  @moduledoc """
  The Game context.
  """

  alias Heroes.Game

  use GenServer

  defstruct [:board_pid, players: %{}, connected_clients: %{}, randomizer: Heroes.Randomizer]

  @type t() :: %__MODULE__{
          board_pid: pid(),
          players: %{String.t() => pid()},
          connected_clients: %{pid() => String.t()},
          randomizer: atom()
        }

  @impl true
  @spec init(keyword()) :: {:ok, t()}
  def init(opts) do
    game = start_game(opts)
    {:ok, game}
  end

  def start_link(opts),
    do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))

  @impl true
  def handle_call(:get_game, _from, game) do
    {:reply, game, game}
  end

  def handle_call({:join_as_player, name}, {from_pid, _ref}, game) do
    players =
      Map.put_new_lazy(
        game.players,
        name,
        fn ->
          {:ok, player_pid} =
            GenServer.start_link(Game.Player,
              board_pid: game.board_pid,
              game_pid: self(),
              name: name,
              randomizer: game.randomizer
            )

          player_pid
        end
      )

    updated_game = %{game | players: players}

    updated_game =
      if Map.get(game.connected_clients, from_pid) do
        updated_game
      else
        Process.monitor(from_pid)

        %{updated_game | connected_clients: Map.put(game.connected_clients, from_pid, name)}
        |> tap(&send_redraw(&1, 500))
      end

    {:reply, updated_game, updated_game}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, object, _reason}, game) do
    player_name = Map.get(game.connected_clients, object)
    Process.send_after(self(), {:remove_player, object, player_name}, 6000)
    {:noreply, game}
  end

  def handle_info({:remove_player, object, player_name}, game) do
    updated_game =
      game
      |> maybe_remove_player_from_game(player_name)
      |> then(
        &%{
          &1
          | connected_clients: Map.delete(game.connected_clients, object)
        }
      )

    send_redraw(updated_game, 200)

    {:noreply, updated_game}
  end

  def handle_info(:redraw, game) do
    send_redraw(game)
    {:noreply, game}
  end

  defp maybe_remove_player_from_game(game, player_name) do
    case Enum.filter(game.connected_clients, fn {_pid, name} -> name == player_name end) do
      [_client] ->
        game.players
        |> Map.get(player_name)
        |> Game.Player.remove()

        %{game | players: Map.delete(game.players, player_name)}

      _clients ->
        game
    end
  end

  defp start_game(opts) do
    {:ok, pid} = GenServer.start_link(Game.Board, [])

    %__MODULE__{
      board_pid: pid,
      connected_clients: %{},
      players: %{},
      randomizer: Keyword.get(opts, :randomizer, Heroes.Randomizer)
    }
  end

  def join_as(name_or_pid \\ __MODULE__, name),
    do: GenServer.call(name_or_pid, {:join_as_player, name})

  def move_player(game, name, direction) when direction in ["left", "right", "up", "down"] do
    player_pid = Map.get(game.players, name)

    updated_player = Game.Player.move_in_direction(player_pid, direction)

    send_redraw(game)
    updated_player
  end

  def send_redraw(game) do
    for {pid, _name} <- game.connected_clients do
      send(pid, {:redraw_board, game.board_pid})
    end
  end

  def send_redraw(game, delay) do
    for {pid, _name} <- game.connected_clients do
      Process.send_after(pid, {:redraw_board, game.board_pid}, delay)
    end
  end

  def get_board_state(board_pid), do: Game.Board.get_state(board_pid)

  def get_game(name_or_pid \\ __MODULE__), do: GenServer.call(name_or_pid, :get_game)

  def get_player(nil), do: nil
  def get_player(player_pid), do: Game.Player.get_player(player_pid)

  def player_attack(game, player_name) do
    player_pid = Map.get(game.players, player_name)

    adjacent_players =
      player_pid
      |> Game.Player.get_player()
      |> Game.Board.list_adjacent_players()

    for player <- adjacent_players, !player.prone do
      game.players
      |> Map.get(player.name)
      |> Game.Player.attack()
    end

    send_redraw(game, 100)
  end
end
