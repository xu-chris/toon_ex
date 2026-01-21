defmodule Toon.Encode.ObjectsTest do
  use ExUnit.Case, async: true

  alias Toon.Encode.Objects

  describe "encode/3 with key_order" do
    test "uses path-specific key_order from map" do
      opts = %{
        delimiter: ",",
        length_marker: nil,
        indent: 2,
        indent_string: "  ",
        key_order: %{[] => ["name", "age"]},
        key_folding: "off"
      }

      data = %{"age" => 30, "name" => "Alice"}
      result = Objects.encode(data, 0, opts) |> IO.iodata_to_binary()

      # Should use the specified order: name first, then age
      assert result == "name: Alice\nage: 30"
    end

    test "falls back to alphabetical when path not in key_order map" do
      opts = %{
        delimiter: ",",
        length_marker: nil,
        indent: 2,
        indent_string: "  ",
        key_order: %{["nested"] => ["x", "y"]},
        key_folding: "off"
      }

      data = %{"age" => 30, "name" => "Alice"}
      result = Objects.encode(data, 0, opts) |> IO.iodata_to_binary()

      # Should use alphabetical order since [] path is not in key_order
      assert result == "age: 30\nname: Alice"
    end

    test "uses list key_order at root level" do
      opts = %{
        delimiter: ",",
        length_marker: nil,
        indent: 2,
        indent_string: "  ",
        key_order: ["name", "age"],
        key_folding: "off"
      }

      data = %{"age" => 30, "name" => "Alice"}
      result = Objects.encode(data, 0, opts) |> IO.iodata_to_binary()

      assert result == "name: Alice\nage: 30"
    end

    test "falls back to alphabetical when list key_order is partial" do
      opts = %{
        delimiter: ",",
        length_marker: nil,
        indent: 2,
        indent_string: "  ",
        key_order: ["name"],
        key_folding: "off"
      }

      data = %{"age" => 30, "name" => "Alice"}
      result = Objects.encode(data, 0, opts) |> IO.iodata_to_binary()

      # Falls back to alphabetical since key_order doesn't include all keys
      assert result == "age: 30\nname: Alice"
    end

    test "falls back to alphabetical when key_order is empty list" do
      opts = %{
        delimiter: ",",
        length_marker: nil,
        indent: 2,
        indent_string: "  ",
        key_order: [],
        key_folding: "off"
      }

      data = %{"age" => 30, "name" => "Alice"}
      result = Objects.encode(data, 0, opts) |> IO.iodata_to_binary()

      assert result == "age: 30\nname: Alice"
    end

    test "falls back to alphabetical when key_order is nil" do
      opts = %{
        delimiter: ",",
        length_marker: nil,
        indent: 2,
        indent_string: "  ",
        key_order: nil,
        key_folding: "off"
      }

      data = %{"age" => 30, "name" => "Alice"}
      result = Objects.encode(data, 0, opts) |> IO.iodata_to_binary()

      assert result == "age: 30\nname: Alice"
    end
  end
end
