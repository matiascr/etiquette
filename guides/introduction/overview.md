# Overview

Etiquette is a library for creating packet specifications. The usage of packets
is standard across most network communications but it can have other uses and be
a good way to efficiently store data and move it around.

Let's take a simple packet specification. The UDP header format:

<style>
  table { border-collapse: collapse; table-layout: fixed; width: 100%; font-family: ui-monospace, monospace; }
  caption { "margin-bottom: 8px; font-weight: bold;" }
  th { border: 1px solid currentColor; width: 6.25%; }
  td { border: 1px solid currentColor; }
</style>
<table aria-label="UDP Header Format">
  <caption>UDP Header Format</caption>
  <tr>
    <th colspan="8">Byte 0</th>
    <th colspan="8">Byte 1</th>
    <th colspan="8">Byte 2</th>
    <th colspan="8">Byte 3</th>
  </tr>
  <tr>
    <td colspan="16">Source Port</td>
    <td colspan="16">Destination Port</td>
  </tr>
  <tr>
    <td colspan="16">Length</td>
    <td colspan="16">Checksum</td>
  </tr>
  <tr>
    <td colspan="32">Data</td>
  </tr>
</table>

From this specification we can gather that the packet has five fields, the first
with a fixed length of two bytes and the last with an indefinite length. Using
[`Etiquette.Spec`](Etiquette.Spec.html), we can create the specification as
follows:

```elixir
defmodule UDPSpec do
  use Etiquette.Spec

  packet "UDP Header Format", id: :udp_header do
    field "Source Port", 16, doc: "This field identifies the sender's port." 
    field "Destination Port", 16, doc: "This field identifies the receiver's port and is required." 
    field "Length", 16, id: :length, doc: "This field specifies the length in bytes of the UDP datagram." 
    field "Checksum", 16, doc: "The checksum field may be used for error-checking of the header and data." 
    field "Data", (..), length_by: :length, doc: "The payload of the UDP packet." 
  end
end
```

Using the information provided, [`Etiquette.Spec`](Etiquette.Spec.html) will
generate the following:

- `UDPSpec.is_udp_header?/1`: Will return `true` if the binary data conforms to
  the specification.
- `UDPSpec.parse_udp_header/1`: Will parse the binary data into a map with the
  fields names as keys and the values as the parsed data according to the spec.
- `UDPSpec.create_udp_header/5`: (TODO) Will create the binary from the given
  arguments. Depending on the spec, the function will have a different number of
  arguments, one for each field.

Above we used a very simple example. To define more complex specifications,
there are more arguments and options for
[`packet`](Etiquette.Spec.html#packet/3) and
[`field`](Etiquette.Spec.html#field/3). Continue reading the guides to learn how
to use the to your advantage.
