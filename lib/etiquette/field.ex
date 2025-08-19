defmodule Etiquette.Field do
  @moduledoc false

  @type t :: %__MODULE__{
          name: String.t(),
          ex_name: atom(),
          length: pos_integer() | Range.t(),
          length_by_variable: atom(),
          length_by_function: atom(),
          fixed_value: atom(),
          opts: keyword(),
          part_of: atom(),
          doc: String.t(),
          file: any(),
          line: pos_integer()
        }
  @enforce_keys [:name, :ex_name]
  defstruct [
    :name,
    :ex_name,
    :length,
    :length_by_variable,
    :length_by_function,
    :fixed_value,
    :opts,
    :part_of,
    :doc,
    :file,
    :line
  ]
end
