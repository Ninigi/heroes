defmodule Heroes.Game.Player do
  use GenServer

  alias Heroes.Game

  defstruct [:name, :randomizer, :board_pid, :game_pid, :current_coordinates, :prone]

  @type t() :: %__MODULE__{
          name: String.t(),
          randomizer: atom(),
          board_pid: pid(),
          game_pid: pid(),
          current_coordinates: Game.Board.coordinates_t(),
          prone: true | false
        }

  @impl true
  @spec init(keyword) :: {:ok, t()}
  def init(opts) do
    board_pid = Keyword.get(opts, :board_pid)

    board = Game.Board.get_board(board_pid)

    player =
      opts
      |> Keyword.get(:name)
      |> generate_player(board, opts)

    Game.Board.move_player(board_pid, %{player: player, coordinates: player.current_coordinates})

    {:ok, player}
  end

  defp calculate_new_coordinates({x, y}, "left"), do: {x - 1, y}
  defp calculate_new_coordinates({x, y}, "right"), do: {x + 1, y}
  defp calculate_new_coordinates({x, y}, "up"), do: {x, y - 1}
  defp calculate_new_coordinates({x, y}, "down"), do: {x, y + 1}

  @impl true
  def handle_call({:move_in_direction, direction}, _from, player) do
    move_to_coords = calculate_new_coordinates(player.current_coordinates, direction)

    new_coordinates =
      Game.Board.move_player(player.board_pid, %{
        player: player,
        coordinates: move_to_coords
      })

    updated_player = %{player | current_coordinates: new_coordinates}
    {:reply, updated_player, updated_player}
  end

  def handle_call({:move, coordinates}, _from, player) do
    new_coordinates =
      Game.Board.move_player(player.board_pid, %{player: player, coordinates: coordinates})

    {:reply, new_coordinates, %{player | current_coordinates: new_coordinates}}
  end

  def handle_call(:get, _from, player), do: {:reply, player, player}

  def handle_call(:remove_from_board, _from, player),
    do: {:reply, Game.Board.remove_player(player), player}

  @impl true
  def handle_cast(:attack, player) do
    updated_player = %{player | prone: true}

    Game.Board.update_player_on_field(
      updated_player.board_pid,
      updated_player
    )

    Process.send_after(self(), :respawn, 5000)
    {:noreply, updated_player}
  end

  @impl true
  def handle_info(:respawn, player) do
    random_coordinates =
      player.board_pid
      |> Game.Board.get_board()
      |> random_valid_coordinates(player.randomizer)

    updated_player = %{player | prone: false}

    new_coordinates =
      Game.Board.move_player(updated_player.board_pid, %{
        player: updated_player,
        coordinates: random_coordinates
      })

    Process.send_after(player.game_pid, :redraw, 100)

    {:noreply, %{updated_player | prone: false, current_coordinates: new_coordinates}}
  end

  defp generate_player(name, board, opts) do
    randomizer = Keyword.get(opts, :randomizer, Heroes.Randomizer)
    board_pid = Keyword.get(opts, :board_pid)
    game_pid = Keyword.get(opts, :game_pid)

    %__MODULE__{
      name: name,
      randomizer: randomizer,
      board_pid: board_pid,
      game_pid: game_pid,
      current_coordinates: random_valid_coordinates(board, randomizer),
      prone: false
    }
  end

  defp random_valid_coordinates(board, randomizer) do
    coords = {randomizer.generate(0, board.width), randomizer.generate(0, board.height)}

    if Game.Board.can_move_to?(board, coords) do
      coords
    else
      random_valid_coordinates(board, randomizer)
    end
  end

  @doc """
  Moves a player on the board, and updates the player's current coordinates.

  Returns '{:ok, new_coordinates}', or an error tuple, according to 'GenServer.call/3' specs.
  """
  @spec move(pid(), Game.Board.coordinates_t()) :: Game.Board.coordinates_t() | term()
  def move(player_pid, coordinates), do: GenServer.call(player_pid, {:move, coordinates})

  def move_in_direction(player_pid, direction),
    do: GenServer.call(player_pid, {:move_in_direction, direction})

  def attack(player_pid), do: GenServer.cast(player_pid, :attack)

  def get_player(player_pid), do: GenServer.call(player_pid, :get)

  def remove(player_pid) do
    GenServer.call(player_pid, :remove_from_board)
    GenServer.stop(player_pid)
  end
end
