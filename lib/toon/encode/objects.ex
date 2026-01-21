defmodule Toon.Encode.Objects do
  @moduledoc """
  Encoding of TOON objects (maps).
  """

  alias Toon.Constants
  alias Toon.Encode.{Arrays, Primitives, Strings, Writer}
  alias Toon.Utils

  @identifier_segment_pattern ~r/^[A-Za-z_][A-Za-z0-9_]*$/

  @doc """
  Encodes a map to TOON format.

  ## Examples

      iex> opts = %{indent: 2, delimiter: ",", length_marker: nil}
      iex> map = %{"name" => "Alice", "age" => 30}
      iex> Toon.Encode.Objects.encode(map, 0, opts)

  """
  @spec encode(map(), non_neg_integer(), map()) :: [iodata()]
  def encode(map, depth, opts) when is_map(map) do
    writer = Writer.new(opts.indent)

    # Get the keys in the correct order
    keys = get_ordered_keys(map, Map.get(opts, :key_order), [])

    # At root level (depth 0), collect dotted keys as forbidden fold paths
    opts =
      if depth == 0 and not Map.has_key?(opts, :forbidden_fold_paths) do
        forbidden = collect_forbidden_fold_paths(keys)
        Map.put(opts, :forbidden_fold_paths, forbidden)
      else
        opts
      end

    # Get current path prefix for collision detection
    path_prefix = Map.get(opts, :current_path_prefix, "")

    writer =
      keys
      |> Enum.reduce(writer, fn key, acc ->
        value = Map.get(map, key)
        encode_entry(acc, key, value, depth, opts, path_prefix)
      end)

    Writer.to_iodata(writer)
  end

  # Collect all dotted keys that should prevent folding
  defp collect_forbidden_fold_paths(keys) do
    Enum.reduce(keys, MapSet.new(), fn key, acc ->
      if String.contains?(key, "."), do: MapSet.put(acc, key), else: acc
    end)
  end

  # Get keys in the correct order based on key_order option
  # Pattern 1: key_order is a map with path-specific ordering
  defp get_ordered_keys(map, key_order, path) when is_map(key_order) do
    case Map.fetch(key_order, path) do
      {:ok, ordered} ->
        Enum.filter(ordered, &Map.has_key?(map, &1))

      :error ->
        Map.keys(map) |> Enum.sort()
    end
  end

  # Pattern 2: key_order is a list at root level
  defp get_ordered_keys(map, key_order, [])
       when is_list(key_order) and key_order != [] do
    existing_keys = Map.keys(map)
    ordered_existing = Enum.filter(key_order, &(&1 in existing_keys))

    if length(ordered_existing) == length(existing_keys) do
      ordered_existing
    else
      Enum.sort(existing_keys)
    end
  end

  # Pattern 3: No key_order or not applicable - sort alphabetically
  defp get_ordered_keys(map, _key_order, _path) do
    Map.keys(map) |> Enum.sort()
  end

  @doc """
  Encodes a single key-value pair.
  """
  @spec encode_entry(Writer.t(), String.t(), term(), non_neg_integer(), map(), String.t()) ::
          Writer.t()
  def encode_entry(writer, key, value, depth, opts, path_prefix \\ "") do
    # Check for key folding
    if should_fold?(key, value, opts, path_prefix) do
      encode_folded_entry(writer, key, value, depth, opts)
    else
      encode_regular_entry(writer, key, value, depth, opts)
    end
  end

  # Pattern match on value types for better clarity
  defp encode_regular_entry(writer, key, value, depth, opts)
       when is_nil(value) or is_boolean(value) or is_number(value) or is_binary(value) do
    encode_primitive_entry(writer, key, value, depth, opts)
  end

  defp encode_regular_entry(writer, key, value, depth, opts) when is_list(value) do
    array_lines = Arrays.encode(key, value, depth, opts)
    append_lines(writer, array_lines, depth)
  end

  defp encode_regular_entry(writer, key, value, depth, opts) when is_map(value) do
    encode_map_entry(writer, key, value, depth, opts)
  end

  defp encode_regular_entry(writer, key, _value, depth, opts) do
    encode_null_entry(writer, key, depth, opts)
  end

  # Helper functions for each entry type
  defp encode_primitive_entry(writer, key, value, depth, opts) do
    encoded_key = Strings.encode_key(key)

    line = [
      encoded_key,
      Constants.colon(),
      Constants.space(),
      Primitives.encode(value, opts.delimiter)
    ]

    Writer.push(writer, line, depth)
  end

  defp encode_map_entry(writer, key, value, depth, opts) do
    encoded_key = Strings.encode_key(key)
    header = [encoded_key, Constants.colon()]
    writer = Writer.push(writer, header, depth)

    current_prefix = Map.get(opts, :current_path_prefix, "")
    new_prefix = build_path_prefix(current_prefix, key)
    nested_opts = Map.put(opts, :current_path_prefix, new_prefix)
    nested_lines = encode(value, depth + 1, nested_opts)

    append_iodata(writer, nested_lines, depth + 1)
  end

  defp encode_null_entry(writer, key, depth, _opts) do
    encoded_key = Strings.encode_key(key)
    line = [encoded_key, Constants.colon(), Constants.space(), Constants.null_literal()]
    Writer.push(writer, line, depth)
  end

  defp build_path_prefix("", key), do: key
  defp build_path_prefix(prefix, key), do: prefix <> "." <> key

  # Check if we should fold this key-value pair into a dotted path
  defp should_fold?(key, value, opts, path_prefix) do
    case Map.get(opts, :key_folding, "off") do
      "safe" ->
        # Only fold single-key maps with valid identifier segments
        Utils.map?(value) and
          map_size(value) == 1 and
          valid_identifier_segment?(key) and
          flatten_depth_allows?(opts, 1) and
          not has_collision?(key, value, opts, path_prefix)

      _ ->
        false
    end
  end

  # Check if folding would create a collision with forbidden fold paths
  defp has_collision?(key, value, opts, path_prefix) do
    forbidden = Map.get(opts, :forbidden_fold_paths, MapSet.new())

    # Compute what the full folded path would be
    {path, _final_value} = collect_fold_path([key], value, %{flatten_depth: :infinity}, 1)
    local_folded = Enum.join(path, ".")

    # Build the full path from root
    full_folded_key =
      if path_prefix == "" do
        local_folded
      else
        path_prefix <> "." <> local_folded
      end

    # Check if the full folded path collides with any forbidden path
    MapSet.member?(forbidden, full_folded_key)
  end

  defp valid_identifier_segment?(key) do
    Regex.match?(@identifier_segment_pattern, key)
  end

  defp flatten_depth_allows?(opts, current_depth) do
    case Map.get(opts, :flatten_depth, :infinity) do
      :infinity -> true
      max when is_integer(max) -> current_depth <= max
    end
  end

  # Encode a folded key-value pair (collapse single-key chains)
  # Pattern match on final value type for clarity
  defp encode_folded_entry(writer, key, value, depth, opts) do
    {path, final_value} = collect_fold_path([key], value, opts, 1)
    folded_key = Enum.join(path, ".")

    encode_folded_value(writer, folded_key, final_value, depth, opts)
  end

  # Primitive final value
  defp encode_folded_value(writer, folded_key, final_value, depth, opts)
       when is_nil(final_value) or is_boolean(final_value) or is_number(final_value) or
              is_binary(final_value) do
    line = [
      folded_key,
      Constants.colon(),
      Constants.space(),
      Primitives.encode(final_value, opts.delimiter)
    ]

    Writer.push(writer, line, depth)
  end

  # Array final value
  defp encode_folded_value(writer, folded_key, final_value, depth, opts)
       when is_list(final_value) do
    array_lines = Arrays.encode(folded_key, final_value, depth, opts)
    append_lines(writer, array_lines, depth)
  end

  # Empty map final value
  defp encode_folded_value(writer, folded_key, final_value, depth, _opts)
       when is_map(final_value) and map_size(final_value) == 0 do
    line = [folded_key, Constants.colon()]
    Writer.push(writer, line, depth)
  end

  # Non-empty map final value
  defp encode_folded_value(writer, folded_key, final_value, depth, opts)
       when is_map(final_value) do
    nested_opts = Map.put(opts, :flatten_depth, 0)
    header = [folded_key, Constants.colon()]
    writer = Writer.push(writer, header, depth)
    nested_lines = encode(final_value, depth + 1, nested_opts)
    append_iodata(writer, nested_lines, depth + 1)
  end

  # Unsupported type
  defp encode_folded_value(writer, folded_key, _final_value, depth, _opts) do
    line = [folded_key, Constants.colon(), Constants.space(), Constants.null_literal()]
    Writer.push(writer, line, depth)
  end

  # Recursively collect the path for folding
  # Pattern 1: Not a map - stop folding
  defp collect_fold_path(path, value, _opts, _current_depth) when not is_map(value) do
    {path, value}
  end

  # Pattern 2: Map with size != 1 - stop folding
  defp collect_fold_path(path, value, _opts, _current_depth)
       when is_map(value) and map_size(value) != 1 do
    {path, value}
  end

  # Pattern 3: Continue folding if conditions are met
  defp collect_fold_path(path, value, opts, current_depth) when is_map(value) do
    if flatten_depth_allows?(opts, current_depth + 1) do
      [{next_key, next_value}] = Map.to_list(value)

      if valid_identifier_segment?(next_key) do
        collect_fold_path(path ++ [next_key], next_value, opts, current_depth + 1)
      else
        {path, value}
      end
    else
      {path, value}
    end
  end

  # Private helpers

  defp append_lines(writer, [header | data_rows], depth) do
    # For arrays, the first line is the header at current depth
    # Subsequent lines (data rows for tabular format) should be one level deeper
    writer = Writer.push(writer, header, depth)

    Enum.reduce(data_rows, writer, fn row, acc ->
      Writer.push(acc, row, depth + 1)
    end)
  end

  defp append_iodata(writer, iodata, _base_depth) do
    # Convert iodata to string, split by lines, and add to writer
    iodata
    |> IO.iodata_to_binary()
    |> String.split("\n")
    |> Enum.reduce(writer, fn line, acc ->
      # Lines from nested encode already have relative indentation,
      # but we need to add them without additional depth since encode()
      # already handles depth
      if line == "" do
        acc
      else
        # Extract existing indentation and preserve it
        Writer.push(acc, line, 0)
      end
    end)
  end
end
