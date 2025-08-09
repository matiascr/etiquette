defmodule Etiquette.Field do
  @moduledoc false

  @type t :: %__MODULE__{
          name: String.t(),
          ex_name: atom(),
          length: pos_integer() | Range.t(),
          opts: keyword(),
          length_by: function() | atom(),
          part_of: atom(),
          doc: String.t()
        }
  @enforce_keys [:name, :ex_name]
  defstruct [:name, :ex_name, :length, :opts, :length_by, :part_of, :doc]
end
