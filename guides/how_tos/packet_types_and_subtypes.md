# Packet types and subtypes

As we have seen, in the [salute example](/guides/how_tos/validating_packet_formats.md), it's
possible to define the same packet structure for multiple packet types, and use
a field that contains a fixed value to differentiate between them.

Since this is a very common pattern in protocol specifications, some niceties
from [`Etiquette.Spec`](`Etiquette.Spec`) let us create them in an even more
concise manner.

If you read the [`packet`](`Etiquette.Spec.packet/3`) documentation, there's
an available `:of` argument. This lets us inherit the structure of a previously
defined packet, and reuse it in a way where we only need to specify the
differences.

Let's take our "salute" specification from
[before](/guides/how_tos/validating_packet_formats.md):

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

In this case, it quickly becomes apparent that most fields are declared multiple
times. For reusing fields from an existing structure, let's use the `:of`
argument:

```elixir
defmodule SaluteSpec do
  use Etiquette.Spec

  packet "My Salute Packet", id: :salute do
    ...
  end

  packet "Hello Packet", id: :hello, of: :salute do
    ...
  end

  packet "Goodbye Packet", id: :goodbye, of: :salute do
    ...
  end
end
```

Now that "Hello" and "Goodbye" are using the structure from "Salute", let's
start removing fields, starting with "Source Port":

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

  packet "Hello Packet", id: :hello, of: :salute do
    field "Destination Port", 8
    field "Packet Type", 2, fixed: 0b00
    field "Payload Type", 6
    field "Payload", 8
  end

  packet "Goodbye Packet", id: :goodbye, of: :salute do
    field "Destination Port", 8
    field "Packet Type", 2, fixed: 0b11
    field "Payload Type", 6
    field "Payload", 8
  end
end
```

When inspecting the module, we will see the same structure as before:

```elixir
iex(1)> SaluteSpec.module_info[:exports]
[
  ...
  is_goodbye?: 1,
  is_hello?: 1,
  is_salute?: 1,
  parse_goodbye: 1,
  parse_hello: 1,
  parse_salute: 1,
  ...
]
```

Looking at the `parse_hello` function, we can see that the field we removed
(Source Port), is still there, and in the same order.

![parse_hello_h](https://github.com/user-attachments/assets/fabf4f1c-fbf7-4703-82d4-197d257cc82d)

Knowing that we can remove redundant fields from "children" specifications,
keeping the field and having the order be respected, let's create the finished
specification:

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

  packet "Hello Packet", id: :hello, of: :salute do
    field "Packet Type", 2, fixed: 0b00
  end

  packet "Goodbye Packet", id: :goodbye, of: :salute do
    field "Packet Type", 2, fixed: 0b11
  end
end
```

This is only one way you can use the `:of` argument in
[`packet`](`Etiquette.Spec.packet/3`). Continue reading to learn about how
you can create bespoke documentation for variants of the same field, or even
split the same field of a parent specification into several fields in children
specifications.
