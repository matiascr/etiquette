# Etiquette

Library for creating and following protocol.

Following the example:

```elixir
defmodule Example.Spec do
  use Etiquette.Spec

  packet "Header Packet", id: :header_packet do
    field("Header Fixed", 1, fixed: 1, doc: "Whether the packet is a header.")
    field("Packet Type", 2, doc: "The type of the payload. Can be any 0-3 integer.")
    field("Type-Specific fields", .., doc: "The packet payload.")
  end

  packet "Hello Packet", id: :hello_packet, of: :header_packet do
    field("Packet Type", 2, fixed: 0b00, doc: "The type of the payload. Can be any 0-3 integer.")
    field("Hello-specific payload", .., doc: "Type specific payload")
  end

  packet "Conversation Packet", id: :conversation_packet, of: :header_packet do
    field("Packet Type", 2, fixed: 0b01, doc: "The type of the payload. Can be any 0-3 integer.")
    field("Conversation-specific payload", .., doc: "Type specific payload")
  end

  packet "Bye Packet", id: :bye_packet, of: :header_packet do
    field("Packet Type", 2, fixed: 0b11, doc: "The type of the payload. Can be any 0-3 integer.")
    field("Bye-specific payload", .., doc: "Type specific payload")
  end
end
```

Now we have a specification such that:

    iex> Example.Spec.is_header_packet?(<<1::1, "A random string inside 30 bytes"::30>>)
    true

    iex> Example.Spec.is_hello_packet?(<<1::1, 0b00::2, "rest">>)
    true

    iex> Example.Spec.is_hello_packet?(<<1::1, 0b10::2, "rest">>)
    false

    iex> Example.Spec.is_bye_packet?(<<1::1, 0b11::2, "rest">>)
    true


## TODO

- [ ] Generate pretty markdown documentation from the spec module
- [ ] Generate pretty markdown documentation for each function
- [x] Generate complete typespecs in functions for easier use
- [ ] Implement `generate_x_packet(field1, field2, ...) :: <<...>>`
- [x] Implement `parse_x_packet(<<>>) :: %{field1: ..., field2: ..., ...}`
- [ ] Improve inheritance between packet specs (for using the same header, for fixing values of previously defined fields, etc...)
    TODO: Add more tests to cover corner cases of inheritance (order changes, last field injection, validation of lengths).
- [ ] Add sigils for concise specs?