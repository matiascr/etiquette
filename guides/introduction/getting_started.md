# Getting started

This guide is an introduction to the [`Etiquette`](Etiquette.html) library and, more specifically,
to how to use the [`Etiquette.Spec`](Etiquette.Spec.html) module to create packet specifications.

## Adding Etiquette to a project

Adding [`Etiquette`](Etiquette.html) as a dependency is very straightforward. Simply add`:etiquette`
to the `mix.exs` file in your project.

```elixir
defp deps do
  [
    {:etiquette, "~> 0.1.0"}
  ]
end
```

Next, install the dependencies by running

```
mix deps.get

```

After that, to use the formatter rules of the library, add the following to the `.formatter.exs`
file in your project:

```
[
  # Add this line to enable the Etiquette formatter rules.
  import_deps: [:etiquette],

  # Default Elixir project rules
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
```

With all that done, now all it takes to use the [`Etiquette.Spec`](Etiquette.Spec.html) is to use 
[`Etiquette.Spec`](Etiquette.Spec.html) in a module:

```elixir
defmodule PacketSpec do
  use Etiquette.Spec

  packet "Example packet", id: :example_packet, do
    field "First field", (4)
    field "Second field", (4)
  end
end
```

To learn about all the possibilities provided by [`Etiquette.Spec`](Etiquette.Spec.html), keep
reading the guides that follow.