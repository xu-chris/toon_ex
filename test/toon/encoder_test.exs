defmodule Toon.EncoderTest do
  use ExUnit.Case, async: true

  alias Toon.Fixtures.{
    CustomDate,
    Person,
    StructWithoutEncoder,
    UserWithExcept,
    UserWithOnly
  }

  describe "Toon.Encoder for Atom" do
    test "encodes nil" do
      assert Toon.Encoder.encode(nil, []) == "null"
    end

    test "encodes true" do
      assert Toon.Encoder.encode(true, []) == "true"
    end

    test "encodes false" do
      assert Toon.Encoder.encode(false, []) == "false"
    end

    test "encodes regular atom as string" do
      assert Toon.Encoder.encode(:hello, []) == "hello"
    end
  end

  describe "Toon.Encoder for BitString" do
    test "encodes simple string unchanged" do
      assert Toon.Encoder.encode("hello", []) == "hello"
    end

    test "encodes string containing delimiter as iodata with quotes" do
      result = Toon.Encoder.encode("a,b", delimiter: ",")
      assert IO.iodata_to_binary(result) == "\"a,b\""
    end
  end

  describe "Toon.Encoder for Integer" do
    test "encodes positive integer" do
      assert Toon.Encoder.encode(42, []) == "42"
    end

    test "encodes negative integer" do
      assert Toon.Encoder.encode(-42, []) == "-42"
    end

    test "encodes zero" do
      assert Toon.Encoder.encode(0, []) == "0"
    end
  end

  describe "Toon.Encoder for Float" do
    test "encodes float" do
      result = Toon.Encoder.encode(3.14, [])
      assert result == "3.14"
    end

    test "encodes negative float" do
      result = Toon.Encoder.encode(-3.14, [])
      assert result == "-3.14"
    end
  end

  describe "Toon.Encoder for List" do
    test "encodes list via Toon.Encode" do
      result = Toon.Encoder.encode([1, 2, 3], [])
      assert result == "[3]: 1,2,3"
    end

    test "encodes empty list" do
      result = Toon.Encoder.encode([], [])
      assert result == "[0]:"
    end
  end

  describe "Toon.Encoder for Map" do
    test "encodes map with atom keys (converted to strings)" do
      result = Toon.Encoder.encode(%{name: "Alice"}, [])
      assert result == "name: Alice"
    end

    test "encodes empty map" do
      result = Toon.Encoder.encode(%{}, [])
      assert result == ""
    end
  end

  describe "Toon.Encoder @derive with except option" do
    test "excludes specified fields from encoding" do
      user = %UserWithExcept{name: "Alice", email: "a@b.com", password: "secret"}
      encoded_map = Toon.Encoder.encode(user, [])

      assert Map.has_key?(encoded_map, "name") == true
      assert Map.has_key?(encoded_map, "email") == true
      assert Map.has_key?(encoded_map, "password") == false
    end
  end

  describe "Toon.Encoder @derive with only option" do
    test "includes only specified fields" do
      user = %UserWithOnly{name: "Alice", email: "a@b.com", password: "secret"}
      encoded_map = Toon.Encoder.encode(user, [])

      assert Map.has_key?(encoded_map, "name") == true
      assert Map.has_key?(encoded_map, "email") == false
      assert Map.has_key?(encoded_map, "password") == false
    end
  end

  describe "Toon.Encoder @derive with no options" do
    test "includes all fields except __struct__" do
      person = %Person{name: "Bob", age: 25}
      encoded_map = Toon.Encoder.encode(person, [])

      assert encoded_map == %{"name" => "Bob", "age" => 25}
    end
  end

  describe "Toon.Encoder explicit implementation" do
    test "uses custom encode function" do
      date = %CustomDate{year: 2024, month: 1, day: 15}
      result = date |> Toon.Encoder.encode([]) |> IO.iodata_to_binary()

      assert result == "2024-01-15"
    end
  end

  describe "Toon.Encoder for unimplemented types" do
    test "raises Protocol.UndefinedError for struct without implementation" do
      struct = %StructWithoutEncoder{id: 1, value: "test"}

      assert_raise Protocol.UndefinedError, ~r/Toon.Encoder protocol must be explicitly/, fn ->
        Toon.Encoder.encode(struct, [])
      end
    end

    test "raises Protocol.UndefinedError for tuple" do
      assert_raise Protocol.UndefinedError, fn ->
        Toon.Encoder.encode({1, 2, 3}, [])
      end
    end

    test "raises Protocol.UndefinedError for pid" do
      assert_raise Protocol.UndefinedError, fn ->
        Toon.Encoder.encode(self(), [])
      end
    end
  end

  describe "Toon.Utils.normalize/1 with structs" do
    test "dispatches to explicit Toon.Encoder implementation" do
      date = %CustomDate{year: 2024, month: 1, day: 15}
      assert Toon.Utils.normalize(date) == "2024-01-15"
    end

    test "dispatches to @derive Toon.Encoder" do
      user = %UserWithExcept{name: "Bob", email: "bob@test.com", password: "secret"}
      assert Toon.Utils.normalize(user) == %{"name" => "Bob", "email" => "bob@test.com"}
    end
  end

  # These tests verify the public API accepts structs and atom-keyed maps.
  # The Encoder protocol handles normalization, so the type specs must accept term().
  describe "Toon.encode!/1 accepts structs (Dialyzer compatibility)" do
    test "encodes struct with @derive Toon.Encoder" do
      person = %Person{name: "Alice", age: 30}
      result = Toon.encode!(person)

      assert result =~ "name: Alice"
      assert result =~ "age: 30"
    end

    test "encodes struct with explicit Encoder implementation" do
      date = %CustomDate{year: 2024, month: 6, day: 15}
      result = Toon.encode!(date)

      assert result == "2024-06-15"
    end
  end

  describe "Toon.encode!/1 accepts maps with atom keys (Dialyzer compatibility)" do
    test "encodes map with atom keys" do
      data = %{name: "Bob", active: true}
      result = Toon.encode!(data)

      assert result =~ "name: Bob"
      assert result =~ "active: true"
    end

    test "encodes nested map with atom keys" do
      data = %{user: %{name: "Charlie", age: 25}}
      result = Toon.encode!(data)

      assert result =~ "name: Charlie"
    end
  end
end
