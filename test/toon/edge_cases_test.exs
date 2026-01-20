defmodule Toon.EdgeCasesTest do
  @moduledoc """
  Tests for edge cases to ensure behavior is preserved after removing dead code.
  """
  use ExUnit.Case, async: true

  describe "empty input decoding" do
    test "empty string decodes to empty map" do
      assert {:ok, %{}} = Toon.decode("")
    end

    test "whitespace-only string decodes to empty map" do
      assert {:ok, %{}} = Toon.decode("   ")
      assert {:ok, %{}} = Toon.decode("\n\n")
      assert {:ok, %{}} = Toon.decode("  \n  \n  ")
    end
  end

  describe "empty data encoding" do
    test "empty map encodes to empty string" do
      assert "" = Toon.encode!(%{})
    end

    test "empty list encodes with zero-length header" do
      result = Toon.encode!(%{"items" => []})
      assert result =~ "items[0]:"
    end

    test "nested empty structures" do
      # Empty map inside map - produces key with colon
      assert "nested:" = Toon.encode!(%{"nested" => %{}})

      # Empty list inside map
      result = Toon.encode!(%{"items" => []})
      assert result =~ "[0]:"
    end
  end

  describe "decode and encode roundtrip for edge cases" do
    test "empty map roundtrip" do
      original = %{}
      encoded = Toon.encode!(original)
      {:ok, decoded} = Toon.decode(encoded)
      assert decoded == original
    end
  end

  describe "list of maps with primitive values" do
    test "encodes list of maps with same keys using tabular format" do
      data = [
        %{"id" => "1", "name" => "Alice"},
        %{"id" => "2", "name" => "Bob"}
      ]

      encoded = Toon.encode!(data)
      {:ok, decoded} = Toon.decode(encoded)

      assert decoded == data
      # Should use tabular format (braces in header, no hyphen markers)
      assert String.contains?(encoded, "]{")
      refute String.contains?(encoded, "- ")
    end
  end

  describe "list of maps with nested values" do
    test "encodes list of maps containing nested maps" do
      data = [
        %{"id" => "1", "name" => "Alice", "meta" => %{"role" => "admin"}},
        %{"id" => "2", "name" => "Bob", "meta" => %{"role" => "user"}}
      ]

      encoded = Toon.encode!(data)
      assert is_binary(encoded)
    end

    test "encodes list of maps containing nested lists" do
      data = [
        %{"id" => "1", "tags" => ["a", "b"]},
        %{"id" => "2", "tags" => ["c", "d"]}
      ]

      encoded = Toon.encode!(data)
      assert is_binary(encoded)
    end
  end
end
