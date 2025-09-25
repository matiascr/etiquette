# Etiquette

<a href="https://hex.pm/packages/etiquette"><img alt="Hex Version" src="https://img.shields.io/hexpm/v/etiquette"></a>
<a href="https://hexdocs.pm/etiquette"><img alt="Hex Docs" src="http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat"></a>

<br>

A new way of creating and following a protocol

## Summary

Following an example Header Packet

<table aria-label="Header Packet">
  <tr>
    <th colspan="8">Byte 0</th>
  </tr>
  <tr>
    <td colspan="1">Header Fixed</td>
    <td colspan="2">Packet Type</td>
    <td colspan="5">Type-Specific fields</td>
  </tr>
</table>

We can turn it into

```elixir
defmodule Example.Spec do
  use Etiquette.Spec

  packet "Header Packet", id: :header_packet do
    field "Header Fixed", 1, fixed: 1, doc: "Whether the packet is a header."
    field "Packet Type", 2, doc: "The type of the payload. Can be any 0-3 integer."
    field "Type-Specific fields", (..), id: :type_specific_fields, doc: "The packet payload."
  end

  packet "Hello Packet", of: :header_packet do
    field "Packet Type", 2, fixed: 0b00
    field "Hello-specific payload", 8, part_of: :type_specific_fields
  end

  packet "Conversation Packet", of: :header_packet do
    field "Packet Type", 2, fixed: 0b01
    field "Conversation-specific payload", 8, part_of: :type_specific_fields
  end

  packet "Bye Packet", of: :header_packet do
    field "Packet Type", 2, fixed: 0b11
    field "Bye-specific payload", 8, part_of: :type_specific_fields
  end
end
```

Such that we now have a specification

```elixir
iex> Example.Spec.is_header_packet?(<<1::1, "A random string inside 30 bytes"::30>>)
true

iex> Example.Spec.is_hello_packet?(<<1::1, 0b00::2, "rest">>)
true

iex> Example.Spec.is_hello_packet?(<<1::1, 0b10::2, "rest">>)
false

iex> Example.Spec.is_bye_packet?(<<1::1, 0b11::2, 0xFF, 0xAA>>)
true

iex> Example.Spec.parse_bye_packet(<<1::1, 0b11::2, 0xFF, 0xAA>>)
{
  %{
    header_fixed: 1,
    packet_type: 3,
    bye_specific_payload: 255
  },
  <<170>>
}

iex> # Notice how only the fields that are not fixed need to be provided
iex> Example.Spec.build_bye_packet(0xFF) |> Example.Spec.parse_bye_packet()
{
  %{
    header_fixed: 1,
    packet_type: 3,
    bye_specific_payload: 0xFF
  },
  ""
}


iex> Example.Spec.build_bye_packet(0xFF) |> Example.Spec.is_bye_packet?()
true
```

Not only are the functions available and functional, but the provided
documentation and other arguments are also analyzed to provide in-depth
documentation of each generated function:

![example_function_help](https://github.com/user-attachments/assets/9e50be09-4f6b-401a-bb9c-32ae702ef0db)

![example_function_help_2](https://github.com/user-attachments/assets/fd02b75b-a698-497e-ae2e-65c74a68a0fb)

![example_function_help_3](https://github.com/user-attachments/assets/7f1fe3fa-2134-49ff-98d7-bb970ef8c71d)

# Future work

- [ ] Add support for frames. Add the option to provide a list of frames as part
      of a frames field/payload. It should have a similar structure and options
      to `Etiquette.Spec.packet/3`.
