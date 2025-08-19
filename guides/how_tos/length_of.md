# Using dynamic lengths

Let's continue to look at the UDP Header Format:

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

Taking a look at [`field`](Etiquette.Spec.html#field/3), you will see that the
signature is `field(name, length, opts)`. The second argument is mandatory, but
with room for some flexibility. We have determined the first four fields to have
16 bits of length, however, the size of the "Data" that the packet contains can
be of variable length.

When calling [`field`](Etiquette.Spec.html#field/3), it lets you specify the
length of the field in different ways. The first one is a fixed length, using an
integer. This will fix the length of the field (in bits) to that number.

The other one is to use a `Range`. Using a `Range` we can specify a minimum
length using `8..` or `min(8)`, a maximum length using `..256` or `max(256)`,
and an indefinite length using `(..)` like in the example above. Whenever we use
a `Range` as the length, we need to provide an additional field `length_by`.
`length_by` can be used one of two ways:

- Providing an `atom`: When we provide `length_by: :field_x`, we're saying that
  the length of the field is determined by the value (in number of bytes) of the
  field with id `id: :field_x`. This is why we used the `id` in field "Length"
  and not in the others.
- Providing a function capture: By providing a function capture that takes one
  argument and returns an positive integer, the field length (in bytes) is
  determined by that result.

It is important to know the length of each of the fields, if not at
compile-time, at least derive it from some other value at runtime. Say we
received a long string of bytes and we want to parse it into the different
packets it contains. We would need to know where each ends to know where to
start parsing the next one. It is not necessarily the case that we will receive
and parse packets one at a time. This is the main reason why the result of the
generated `UDPSpec.parse_udp_header/1` will be a map containing a key `:rest`
containing the data that falls out of the "Data" field, to be able to continue
parsing the remaining bits.
