defmodule Toon.Types do
  @moduledoc """
  Type definitions for TOON encoder and decoder.

  This module defines all the types used throughout the TOON library,
  ensuring type safety and better documentation.
  """

  @typedoc """
  A JSON-compatible primitive value.
  """
  @type primitive :: nil | boolean() | number() | String.t()

  @typedoc """
  Any value that can be passed to the encoder.

  The `Toon.Encoder` protocol normalizes input before encoding:
  - Structs via `@derive Toon.Encoder` or explicit implementations
  - Maps with atom keys are converted to string keys
  - Custom types implement the protocol to define their encoding

  This is `term()` because any type with an Encoder implementation is valid.
  """
  @type input :: term()

  @typedoc """
  A normalized JSON-compatible value (output of encoding).

  After the Encoder protocol processes input, the result is:
  - Primitives: `nil`, `boolean()`, `number()`, `String.t()`
  - Maps with string keys: `%{optional(String.t()) => encodable()}`
  - Lists: `[encodable()]`
  """
  @type encodable ::
          nil
          | boolean()
          | number()
          | String.t()
          | %{optional(String.t()) => encodable()}
          | [encodable()]

  @typedoc """
  Options for encoding TOON format.

  ## Options

    * `:indent` - Number of spaces for indentation (default: 2)
    * `:delimiter` - Delimiter for array values (default: ",")
    * `:length_marker` - Prefix for array length marker (default: nil)

  ## Examples

      Toon.encode!(data, indent: 4)
      Toon.encode!(data, delimiter: "\\t")
      Toon.encode!(data, length_marker: "#")
  """
  @type encode_opts :: [encode_opt()]

  @typedoc """
  A single encoding option.
  """
  @type encode_opt ::
          {:indent, pos_integer()}
          | {:delimiter, delimiter()}
          | {:length_marker, String.t() | nil}

  @typedoc """
  Valid delimiters for array values.

  Can be comma, tab, or pipe character.
  """
  @type delimiter :: binary()

  @typedoc """
  Options for decoding TOON format.

  ## Options

    * `:keys` - How to decode map keys (default: `:strings`)

  ## Examples

      Toon.decode!(toon, keys: :strings)
      Toon.decode!(toon, keys: :atoms)
  """
  @type decode_opts :: [decode_opt()]

  @typedoc """
  A single decoding option.
  """
  @type decode_opt :: {:keys, :strings | :atoms | :atoms!}

  @typedoc """
  Indentation depth level.
  """
  @type depth :: non_neg_integer()

  @typedoc """
  IO data that can be efficiently concatenated.
  """
  @type iodata_result :: iodata()
end
