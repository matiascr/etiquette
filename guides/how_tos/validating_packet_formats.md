# Validating Packet Formats

For demonstration purposes, let's move to a different example. Let's say we have
an existing packet format, one that we would like to be able to extend in the
future by providing different format IDs or types. Now, let's define an initial
structure:

<style>
  table { border-collapse: collapse; table-layout: fixed; width: 100%; font-family: ui-monospace, monospace; }
  caption { "margin-bottom: 8px; font-weight: bold;" }
  th { border: 1px solid currentColor; width: 6.25%; }
  td { border: 1px solid currentColor; }
</style>
<table aria-label="My Salute Format">
  <caption>My Salute Format</caption>
  <tr>
    <th colspan="8">Byte 0</th>
    <th colspan="8">Byte 1</th>
  </tr>
  <tr>
    <td colspan="8">Source Port</td>
    <td colspan="8">Destination Port</td>
  </tr>
  <tr>
    <td colspan="2">Packet Type</td>
    <td colspan="6">Payload Type</td>
    <td colspan="8">Payload</td>
  </tr>
</table>

Now, to start, let's say we want to define a "Hello" and a "Goodbye" packet. To
differentiate between them, we can specify the value of their type. Let's make
the "Hello" a Packet Type binary "00" and the "Goodbye" packet a "11":

<style>
  table { border-collapse: collapse; table-layout: fixed; width: 100%; font-family: ui-monospace, monospace; }
  caption { "margin-bottom: 8px; font-weight: bold;" }
  th { border: 1px solid currentColor; width: 6.25%; }
  td { border: 1px solid currentColor; }
</style>
<table aria-label="Hello Format">
  <caption>Hello Format</caption>
  <tr>
    <th colspan="8">Byte 0</th>
    <th colspan="8">Byte 1</th>
  </tr>
  <tr>
    <td colspan="8">Source Port</td>
    <td colspan="8">Destination Port</td>
  </tr>
  <tr>
    <td colspan="2">Packet Type = 0b00</td>
    <td colspan="6">Payload Type</td>
    <td colspan="8">Payload</td>
  </tr>
</table>

<style>
  table { border-collapse: collapse; table-layout: fixed; width: 100%; font-family: ui-monospace, monospace; }
  caption { "margin-bottom: 8px; font-weight: bold;" }
  th { border: 1px solid currentColor; width: 6.25%; }
  td { border: 1px solid currentColor; }
</style>
<table aria-label="Goodbye Format">
  <caption>Goodbye Format</caption>
  <tr>
    <th colspan="8">Byte 0</th>
    <th colspan="8">Byte 1</th>
  </tr>
  <tr>
    <td colspan="8">Source Port</td>
    <td colspan="8">Destination Port</td>
  </tr>
  <tr>
    <td colspan="2">Packet Type = 0b11</td>
    <td colspan="6">Payload Type</td>
    <td colspan="8">Payload</td>
  </tr>
</table>

To make this straightforward to represent, [`Etiquette`](Etiquette.Spec.html)
allows specifying a `fixed: value` argument to each
[`field`](Etiquette.Spec.html#field/3). So let's proceed and create their
definitions:

```elixir
defmodule SaluteSpec do
  use Etiquette.Spec

  packet "My Salute Packet", id: :salute do
    field "Source Port", 8
    field "Destination Port", 8
    field "Packet Type", 2
    field "Payload Type", 6
    field "Payload", 8
  end

  packet "Hello Packet", id: :hello do
    field "Source Port", 8
    field "Destination Port", 8
    field "Packet Type", 2, fixed: 0b00
    field "Payload Type", 6
    field "Payload", 8
  end

  packet "Goodbye Packet", id: :goodbye do
    field "Source Port", 8
    field "Destination Port", 8
    field "Packet Type", 2, fixed: 0b11
    field "Payload Type", 6
    field "Payload", 8
  end
end
```

Now that we have created a packet containing an identifying element (the Packet
Type), the generated functions for the Hello and Goodbye packets will use that
information to validate the structure of provided data.

For example, we can now use

```elixir
iex> SaluteSpec.is_hello?(<<0::8, 0::8, 0b00::2, 0x3F::6, "somedata">>)
true
iex> SaluteSpec.is_hello?(<<0::8, 0::8, 0b11::2, 0x3F::6, "somedata">>)
false
```

Which is using the expected fixed values to validate that the packets follow the
defined specification.

Continue through the [Packet Types and Subtypes](packet_types_and_subtypes.html)
guide to learn about other [`field`](Etiquette.Spec.html#field/3) arguments that
can help you streamline the creation of packet variants.
