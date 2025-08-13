defmodule Etiquette do
  @moduledoc """
  Define packet specifications using [`Spec`](Etiquette.Spec.html).

  A packet consists of formatted data. Declaring a specification, it's possible to define the
  structure of a packet and the different forms it can take. In essence, a packet is a sequence of
  fields, so [`Etiquette.Spec`](Etiquette.Spec.html) can be used to import everything that is needed
  to create a specification:

    use Etiquette.Spec

  Once [`Etiquette.Spec`](Etiquette.Spec.html) is used, the macros
  [`packet`](Etiquette.Spec.html#packet/3) and [`field`](Etiquette.Spec.html#field/3) are
  imported.
  """
end
