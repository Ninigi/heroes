defmodule Heroes.GameTest do
  use ExUnit.Case, async: false

  alias Heroes.Game

  import Mox

  describe "Game" do
    setup do
      {:ok, _pid} = GenServer.start_link(Game, [])
      game = Game.get_game()

      %{game: game}
    end

    test "starting the game server sets up a board", %{game: game} do
      refute game.board_pid |> is_nil()

      board_state = Game.get_board_state(game.board_pid)
      refute Enum.empty?(board_state)
    end
  end

  describe "Game.join_as/1" do
    setup do
      {:ok, pid} = GenServer.start_link(Game, [], name: :join_as_test)

      name = "test player"
      game = Game.join_as(pid, name)

      %{game: game, name: name, pid: pid}
    end

    test "adds a player with the given name to the game", %{game: game, name: name} do
      assert name in Map.keys(game.players)

      player =
        game.players
        |> Map.get(name)
        |> Game.get_player()

      refute player == nil
    end

    test "puts the player on a random, walkable field on the board", %{
      game: game,
      name: name
    } do
      player =
        game.players
        |> Map.get(name)
        |> Game.get_player()

      assert {_x, _y} = player.current_coordinates

      board_state = Game.get_board_state(game.board_pid)

      assert {:walkable, [^player]} = Map.get(board_state, player.current_coordinates)
    end
  end

  describe "Game.move_player/3" do
    setup :set_mox_from_context

    setup do
      {:ok, pid} =
        GenServer.start_link(Game, [randomizer: Heroes.RandomizerMock], name: :move_player_test)

      stub(Heroes.RandomizerMock, :generate, fn
        0, 9 ->
          # this should ensure that the initial player coordinates are {5, 5}
          5

        _min, max ->
          # this should ensure that the board does not have any unwalkable tiles, except for the boarder
          max
      end)

      name = "test player"
      game = Game.join_as(pid, name)

      player =
        game.players
        |> Map.get(name)
        |> Game.get_player()

      %{game: game, player: player}
    end

    test "moves the player in the given direction", %{game: game, player: player} do
      %{current_coordinates: {new_x, new_y}} = Game.move_player(game, player.name, "left")
      {initial_x, initial_y} = player.current_coordinates

      assert new_x == initial_x - 1
      assert new_y == initial_y
    end

    test "sends a redraw message", %{game: game, player: player} do
      Game.move_player(game, player.name, "left")

      assert_receive {:redraw_board, _board_pid}, 200
    end
  end

  describe "Game.player_attack/3" do
    setup :set_mox_from_context

    setup do
      {:ok, pid} =
        GenServer.start_link(Game, [randomizer: Heroes.RandomizerMock], name: :player_attack_test)

      stub(Heroes.RandomizerMock, :generate, fn
        0, 9 ->
          # this should ensure that the initial player coordinates are {5, 5}
          5

        _min, max ->
          # this should ensure that the board does not have any unwalkable tiles, except for the boarder
          max
      end)

      name1 = "test player"
      name2 = "test player 2"
      Game.join_as(pid, name1)
      game = Game.join_as(pid, name2)

      player1 =
        game.players
        |> Map.get(name1)
        |> Game.get_player()

      player2 =
        game.players
        |> Map.get(name2)
        |> Game.get_player()

      %{game: game, players: [player1, player2]}
    end

    test "attacking a player sets the attacked player prone", %{
      game: game,
      players: [attacker, p2]
    } do
      Game.player_attack(game, attacker.name)

      p2 =
        game.players
        |> Map.get(p2.name)
        |> Game.get_player()

      assert p2.prone
    end

    test "sends a redraw message", %{game: game, players: [attacker, _]} do
      Game.player_attack(game, attacker.name)

      assert_receive {:redraw_board, _board_pid}, 200
    end
  end
end
