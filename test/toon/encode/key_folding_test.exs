defmodule Toon.Encode.KeyFoldingTest do
  use ExUnit.Case, async: true

  describe "key_folding: safe" do
    test "folds single-key chain to dotted path" do
      input = %{"a" => %{"b" => %{"c" => 1}}}

      result = Toon.encode!(input, key_folding: "safe")

      assert result == "a.b.c: 1"
    end

    test "folds chain with inline array" do
      input = %{"data" => %{"meta" => %{"items" => ["x", "y"]}}}

      result = Toon.encode!(input, key_folding: "safe")

      assert result == "data.meta.items[2]: x,y"
    end

    test "folds chain ending with empty object" do
      input = %{"a" => %{"b" => %{"c" => %{}}}}

      result = Toon.encode!(input, key_folding: "safe")

      assert result == "a.b.c:"
    end

    test "skips folding when segment requires quotes (hyphen)" do
      input = %{"data" => %{"full-name" => %{"x" => 1}}}

      result = Toon.encode!(input, key_folding: "safe")

      # Should NOT fold because full-name has hyphen
      assert result == "data:\n  \"full-name\":\n    x: 1"
    end

    test "skips folding on sibling literal-key collision" do
      input = %{
        "data" => %{"meta" => %{"items" => [1, 2]}},
        "data.meta.items" => "literal"
      }

      result = Toon.encode!(input, key_folding: "safe")

      # Should NOT fold because "data.meta.items" exists as literal key
      # This would create a collision
      assert result == "data:\n  meta:\n    items[2]: 1,2\ndata.meta.items: literal"
    end
  end

  describe "key_folding: off" do
    test "does not fold (standard nesting)" do
      input = %{"a" => %{"b" => %{"c" => 1}}}

      result = Toon.encode!(input, key_folding: "off")

      assert result == "a:\n  b:\n    c: 1"
    end
  end

  describe "flatten_depth option" do
    test "partial folding with flatten_depth=2" do
      input = %{"a" => %{"b" => %{"c" => %{"d" => 1}}}}

      result = Toon.encode!(input, key_folding: "safe", flatten_depth: 2)

      assert result == "a.b:\n  c:\n    d: 1"
    end

    test "no folding with flatten_depth=0" do
      input = %{"a" => %{"b" => %{"c" => 1}}}

      result = Toon.encode!(input, key_folding: "safe", flatten_depth: 0)

      assert result == "a:\n  b:\n    c: 1"
    end

    test "no effect with flatten_depth=1" do
      input = %{"a" => %{"b" => %{"c" => 1}}}

      result = Toon.encode!(input, key_folding: "safe", flatten_depth: 1)

      # flatten_depth=1 has no practical effect (need at least 2 segments)
      assert result == "a:\n  b:\n    c: 1"
    end
  end
end
