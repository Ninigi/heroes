defmodule Heroes.Game.Board do
  use GenServer

  alias Heroes.Game

  defstruct height: 4,
            width: 4,
            state: %{}

  @type coordinates_t() :: {integer(), integer()}

  @type t() :: %__MODULE__{
          height: integer(),
          width: integer(),
          state: %{coordinates_t() => {:walkable | :unwalkable, [Game.Player.t()]}}
        }

  @impl true
  @spec init(keyword()) :: {:ok, t()}
  def init(opts) do
    {:ok, generate_board(Keyword.get(opts, :randomizer, Heroes.Randomizer))}
  end

  @impl true
  def handle_call(:get_state, _from, board) do
    {:reply, board.state, board}
  end

  def handle_call(:get, _from, board) do
    {:reply, board, board}
  end

  def handle_call({:move, %{coordinates: {x, y}, player: player}}, _from, board)
      when x < 0 or y < 0 or x > board.width or y > board.height,
      do: {:reply, player.current_coordinates, board}

  def handle_call({:move, %{coordinates: coordinates, player: player}}, _from, board) do
    {new_board, new_coordinates} =
      case Map.get(board.state, coordinates) do
        {:walkable, players} ->
          state =
            board.state
            |> Map.put(coordinates, {
              :walkable,
              add_player_to_field(players, player)
            })

          state =
            state
            |> Map.put(player.current_coordinates, {
              :walkable,
              remove_player_from_field(
                elem(Map.get(state, player.current_coordinates), 1),
                player,
                coordinates
              )
            })

          {%{board | state: state}, coordinates}

        _ ->
          {board, player.current_coordinates}
      end

    new_board.state |> Map.get(coordinates)

    {:reply, new_coordinates, new_board}
  end

  @impl true
  def handle_cast({:update_player_on_field, player}, board) do
    {:noreply, update_player_field(board, player)}
  end

  def handle_cast(
        {:remove_player, %{current_coordinates: coordinates} = player},
        board
      ) do
    updated_board =
      board.state
      |> Map.get(coordinates)
      |> then(fn {_walkability, players} ->
        %{
          board
          | state:
              Map.put(
                board.state,
                coordinates,
                {:walkable, remove_player_from_field(players, player, nil)}
              )
        }
      end)

    {:noreply, updated_board}
  end

  defp update_player_field(board, player) do
    {:walkable, players} = Map.get(board.state, player.current_coordinates)

    removed =
      remove_player_from_field(
        players,
        player,
        nil
      )

    field = {
      :walkable,
      add_player_to_field(removed, player)
    }

    %{board | state: Map.put(board.state, player.current_coordinates, field)}
  end

  defp add_player_to_field(players, new_player) do
    if new_player in players do
      players
    else
      [new_player | players]
    end
  end

  defp remove_player_from_field(
         players,
         %{current_coordinates: new_coordinates},
         new_coordinates
       ),
       do: players

  defp remove_player_from_field(players, new_player, _new_coordinates) do
    Enum.reject(players, &(&1.name == new_player.name))
  end

  @min_coordinate 0
  @max_coordinate 9

  defp generate_board(randomizer) do
    board_size = Enum.to_list(@min_coordinate..@max_coordinate)

    state =
      for x <- board_size,
          y <- board_size,
          do: {{x, y}, {determine_walkability(x, y, randomizer), []}},
          into: %{}

    %__MODULE__{height: @max_coordinate, width: @max_coordinate, state: state}
  end

  defp determine_walkability(boarder_x, boarder_y, _randomizer)
       when boarder_x in [@min_coordinate, @max_coordinate] or
              boarder_y in [@min_coordinate, @max_coordinate],
       do: :unwalkable

  defp determine_walkability(_boarder_x, _boarder_y, randomizer) do
    case randomizer.generate(0, 22) do
      num when num > 2 -> :walkable
      _ -> :unwalkable
    end
  end

  @doc """
  Updates the board with the new player position, and clears the old player position.

  Returns 'new_coordinates'.
  """
  @spec move_player(pid, %{player: Game.Player.t(), coordinates: coordinates_t()}) ::
          Game.Board.coordinates_t() | term()
  def move_player(board_pid, player_and_coordinates),
    do: GenServer.call(board_pid, {:move, player_and_coordinates})

  def get_state(board_pid), do: GenServer.call(board_pid, :get_state)

  def get_board(board_pid), do: GenServer.call(board_pid, :get)

  def can_move_to?(board, coordinates) do
    {walkability, _players} = Map.get(board.state, coordinates)

    walkability == :walkable
  end

  def list_adjacent_players(attacking_player) do
    board_state = get_state(attacking_player.board_pid)

    board_state
    |> adjacent_players(attacking_player.current_coordinates)
    |> Enum.reject(&(&1.name == attacking_player.name))
  end

  defp adjacent_players(board_state, coordinates) do
    for adjacent_coords <- adjacent_coords(coordinates) do
      board_state
      |> Map.get(adjacent_coords)
      |> elem(1)
    end
    |> List.flatten()
  end

  defp adjacent_coords({x, y}) do
    [
      {x, y},
      {x - 1, y},
      {x - 1, y + 1},
      {x, y + 1},
      {x + 1, y + 1},
      {x + 1, y},
      {x + 1, y - 1},
      {x, y - 1},
      {x - 1, y - 1}
    ]
  end

  def update_player_on_field(board_pid, player),
    do: GenServer.cast(board_pid, {:update_player_on_field, player})

  def remove_player(%{board_pid: board_pid} = player) do
    GenServer.cast(
      board_pid,
      {:remove_player, player}
    )
  end
end
