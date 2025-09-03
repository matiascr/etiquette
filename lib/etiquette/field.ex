defmodule Etiquette.Field do
  @moduledoc false

  import Bitwise, only: [<<<: 2]

  alias __MODULE__

  @type t :: %__MODULE__{
          name: String.t(),
          ex_name: atom(),
          length: pos_integer() | Range.t(),
          length_by_variable: atom(),
          length_in: :bytes | :bits,
          decoder: function(),
          fixed_value: non_neg_integer(),
          part_of: atom(),
          doc: String.t(),
          file: Path.t(),
          line: non_neg_integer()
        }

  @enforce_keys [:name, :ex_name]
  defstruct [
    :name,
    :ex_name,
    :length,
    :length_by_variable,
    :length_in,
    :decoder,
    :fixed_value,
    :part_of,
    :doc,
    :file,
    :line
  ]

  def validate_field_order(fields) when length(fields) != 0 do
    List.foldl(fields, [], fn %Field{ex_name: ex_name, length_by_variable: variable, name: name, file: file, line: line},
                              acc ->
      if not is_nil(variable) and variable not in acc do
        raise CompileError,
          file: file,
          line: line,
          description: """
          Expected field with id "#{variable}" to be declared before field #{name}
          """
      end

      [ex_name | acc]
    end)

    true
  end

  def validate_range_length_field(env, a..b//c = length, opts) do
    if not ((a < b or (a >= 0 and b == -1)) and c == 1) do
      raise CompileError,
        file: env.file,
        line: env.line,
        description: "`length` must be a positive integer, an ascending range or `(..)`, got #{inspect(length)}."
    end

    opts = Keyword.keys(opts)

    if :fixed in opts and :length_by in opts do
      raise CompileError,
        file: env.file,
        line: env.line,
        description: "Using `fixed` option together with `length_by` is not allowed."
    end

    # TODO: Raise only when it's not the last field
  end

  def validate_integer_length_field(env, length, opts) when is_integer(length) do
    fixed_value = Keyword.get(opts, :fixed, nil)

    cond do
      is_integer(fixed_value) ->
        if not fits_unsigned?(fixed_value, length) do
          raise ArgumentError, """
          Fixed value #{fixed_value} won't fit in the given length #{inspect(length)}.
          The highest value you can fit in #{inspect(length)} #{if length == 1, do: "bit", else: "bits"} is #{2 ** length - 1} / 0x#{Integer.to_string(2 ** length - 1, 16)}.
          """
        end

      not is_nil(fixed_value) ->
        raise ArgumentError, "`fixed_value` has to be an non-negative integer."

      true ->
        :noop
    end

    if not (length > 0) do
      raise CompileError,
        file: env.file,
        line: env.line,
        description: "`length` must be a positive integer an ascending range or `(..)`, got #{inspect(length)}."
    end

    if :length_by in Keyword.keys(opts) do
      raise CompileError,
        file: env.file,
        line: env.line,
        description: "`length_by` use is redundant. It is meant to be used when using a `Range` as the length."
    end
  end

  def validate_destructured_fields(fields) do
    all_fields = Enum.map(fields, fn field -> field.ex_name end)

    Enum.each(fields, fn field ->
      case field do
        %Field{length_by_variable: var, file: file, line: line} when is_atom(var) and not is_nil(var) ->
          if var not in all_fields do
            raise CompileError,
              file: file,
              line: line,
              description: """
              Field \"#{field.name}\" references a field (\"#{var}\" or \:#{var}) that does not
              exist.

              Make sure that a field

                  field \"#{var}\", _
              or
                  field _, _, id: :#{var}
                  
              exists in the packet specification. Keep in mind that the `:id` option will override
              the name and the `id` is what has to be referenced.
              """
          end

        _ ->
          :ok
      end
    end)
  end

  defp fits_unsigned?(n, bits) when is_integer(n) and is_integer(bits) and bits > 0 do
    n >= 0 and n < 1 <<< bits
  end

  def build_map_spec_ast(fields) do
    for field <- fields, do: {field.ex_name, {:bitstring, [], Elixir}}
  end

  def build_args_ast(fields) do
    fields
    |> Enum.filter(fn
      %Field{fixed_value: nil} -> true
      _ -> false
    end)
    |> Enum.map(fn field -> {field.ex_name, [], Elixir} end)
  end

  def build_args_spec_ast(fields) do
    fields
    |> Enum.filter(fn
      %Field{fixed_value: nil} -> true
      _ -> false
    end)
    |> Enum.map(fn
      %Field{ex_name: ex_name, length: length} when is_integer(length) ->
        {ex_name, {:.., [], [0, Bitwise.bsl(1, length) - 1]}}

      %Field{ex_name: ex_name} ->
        {ex_name, {:non_neg_integer, [], []}}
    end)
  end

  def build_args_guard_ast(fields) do
    fields
    |> Enum.filter(fn
      %Field{fixed_value: nil} -> true
      _ -> false
    end)
    |> Enum.map(fn
      %Field{ex_name: ex_name, length: length} when is_integer(length) ->
        [
          {:not, [], [{:is_nil, [], [{ex_name, [], Elixir}]}]},
          {:<, [], [{ex_name, [], Elixir}, {:<<<, [], [1, length]}]},
          {:!=, [], [{ex_name, [], Elixir}, ""]}
        ]

      %Field{ex_name: ex_name} ->
        [
          {:not, [], [{:is_nil, [], [{ex_name, [], Elixir}]}]},
          {:!=, [], [{ex_name, [], Elixir}, ""]}
        ]
    end)
    |> List.flatten()
    |> Enum.reduce(fn g, acc ->
      {:and, [], [acc, g]}
    end)
  end

  def build_bit_string_ast(fields) do
    segments =
      Enum.map(fields, fn
        %Field{fixed_value: fixed_value, length: length} when not is_nil(fixed_value) ->
          {:"::", [], [fixed_value, {:size, [], [length]}]}

        %Field{ex_name: ex_name, length: length} when is_integer(length) ->
          {:"::", [], [{ex_name, [], Elixir}, {:size, [], [length]}]}

        %Field{ex_name: ex_name} ->
          {:"::", [], [{ex_name, [], Elixir}, {:bitstring, [], Elixir}]}
      end)

    {:<<>>, [], segments}
  end
end
