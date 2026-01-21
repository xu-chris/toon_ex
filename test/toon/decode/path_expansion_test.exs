defmodule Toon.Decode.PathExpansionTest do
  use ExUnit.Case, async: true

  describe "expand_paths: safe" do
    test "expands dotted key to nested object" do
      input = "a.b.c: 1"

      result = Toon.decode!(input, expand_paths: "safe")

      assert result == %{"a" => %{"b" => %{"c" => 1}}}
    end

    test "preserves quoted dotted key as literal" do
      input = "a.b: 1\n\"c.d\": 2"

      result = Toon.decode!(input, expand_paths: "safe")

      assert result == %{"a" => %{"b" => 1}, "c.d" => 2}
    end

    test "preserves non-IdentifierSegment keys as literals" do
      # full-name contains hyphen which is not allowed in IdentifierSegment
      input = "full-name.x: 1"

      result = Toon.decode!(input, expand_paths: "safe")

      assert result == %{"full-name.x" => 1}
    end

    test "expands and deep-merges multiple paths" do
      input = "a.b.c: 1\na.b.d: 2\na.e: 3"

      result = Toon.decode!(input, expand_paths: "safe")

      assert result == %{"a" => %{"b" => %{"c" => 1, "d" => 2}, "e" => 3}}
    end

    test "throws on type conflict when strict=true" do
      # a.b: 1 creates {a: {b: 1}}, then a: 2 conflicts (object vs primitive)
      input = "a.b: 1\na: 2"

      assert_raise Toon.DecodeError, fn ->
        Toon.decode!(input, expand_paths: "safe", strict: true)
      end
    end

    test "applies LWW when strict=false (primitive overwrites expanded object)" do
      input = "a.b: 1\na: 2"

      result = Toon.decode!(input, expand_paths: "safe", strict: false)

      assert result == %{"a" => 2}
    end

    test "applies LWW when strict=false (expanded object overwrites primitive)" do
      input = "a: 1\na.b: 2"

      result = Toon.decode!(input, expand_paths: "safe", strict: false)

      assert result == %{"a" => %{"b" => 2}}
    end

    test "expands dotted key with tabular array" do
      input = "a.b.items[2]{id,name}:\n  1,A\n  2,B"

      result = Toon.decode!(input, expand_paths: "safe")

      assert result == %{
               "a" => %{
                 "b" => %{
                   "items" => [
                     %{"id" => 1, "name" => "A"},
                     %{"id" => 2, "name" => "B"}
                   ]
                 }
               }
             }
    end

    test "expands dotted key with inline array" do
      input = "data.meta.items[2]: a,b"

      result = Toon.decode!(input, expand_paths: "safe")

      assert result == %{"data" => %{"meta" => %{"items" => ["a", "b"]}}}
    end
  end

  describe "expand_paths: off" do
    test "preserves literal dotted keys" do
      input = "user.name: Ada"

      result = Toon.decode!(input, expand_paths: "off")

      assert result == %{"user.name" => "Ada"}
    end
  end
end
