# Etiquette

Library for creating and following protocol.

Following the example:

```elixir
defmodule Example.Spec do
  use Etiquette.Spec

  packet "Header Packet", id: :header_packet do
    field "Packet Type", (2), doc: """
    The type of the payload. Can be any 0-3 integer.
    """
    field "Payload Length", (4), id: :payload_length, doc: """
    The size of the payload in number of bytes.
    """
    field "Payload", (..), length_by: :payload_length, doc: """
    The packet payload.
    """
  end

  packet "Hello Packet", of: :header_packet do
    field "First Payload Field", (1), fixed: 0
    field "Second Payload Field", (1), fixed: 0
  end

  packet "Bye Packet", of: :header_packet do
    field "First Payload Field", (1), fixed: 1
    field "Second Payload Field", (1), fixed: 1
  end
end
```

Now we have a specification such that:

    iex> Example.Spec.is_header_packet?(<<1::2, 30::4, "A random string inside 30 bytes"::30>>)
    true

    iex> Example.Spec.is_hello_packet?(<<1::2, 2::4, 0::2>>)
    true

    iex> Example.Spec.is_hello_packet?(<<1::2, 2::4, 3::2>>)
    false

    iex> Example.Spec.is_bye_packet?(<<1::2, 2::4, 3::2>>)
    true


## TODO

- [ ] Generate pretty markdown documentation from the spec module
- [ ] Generate pretty markdown documentation for each function
- [ ] Generate complete typespecs in functions for easier use
- [ ] Implement `generate_x_packet(field1, field2, ...) :: <<...>>`
- [ ] Implement `parse_x_packet(<<>>) :: %{field1: ..., field2: ..., ...}`
- [ ] Improve inheritance between packet specs (for using the same header, for fixing values of previously defined fields, etc...)
- [ ] Add sigils for concise specs?