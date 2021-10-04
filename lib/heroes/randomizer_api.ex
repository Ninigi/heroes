defmodule Heroes.RandomizerAPI do
  @callback generate(integer(), integer()) :: integer()
  @callback generate_name() :: String.t()
end
