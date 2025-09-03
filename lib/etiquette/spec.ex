defmodule Etiquette.Spec do
  @moduledoc """
  Module containing the utilities needed to use the Etiquette library.

  Add `use Etiquette.Spec` to your module for the best experience.
  """

  alias Etiquette.Field

  defguard is_range(range) when is_struct(range, Range)

  @debug false

  # Module attribute names
  @current_packet_id :current_packet_id
  @current_packet_ast :current_packet_ast
  @packet_specs :packet_specs

  # Spec field names
  @function_body_ast :function_body_ast

  defmacro __using__(_) do
    quote do
      import Bitwise, only: [<<<: 2]
      import Etiquette.Spec

      Module.put_attribute(__MODULE__, unquote(@packet_specs), %{})

      @before_compile Etiquette.Spec

      @type packet :: bitstring()
    end
  end

  @doc """
  Declares a packet specification. A packet specification is composed of a sequence of [`field`](#field/3)s.

  The available arguments are:

  - `name`: Mandatory field. A string with the name of the field.

  - `id`: An atom used to take care of references. When another packet uses the `of` argument, the
    id is what will be used for reference. By default, the id will be the name converted to an snake
    case atom, but if the name has a long or weird structure, this id can override it for its
    references and function names.

  - `of`: Declares that a packet follows a previously declared packet specification. The specs have
    to be declared in the same file. This argument needs to be present when using `part_of`.

  The packet contents themselves are declared inside a `do` block containing `field`s. For more
  information, see [`field`](#field/3)
  """
  @spec packet(String.t(), id: atom(), of: atom(), do: Macro.t()) :: Macro.t()
  defmacro packet(name, args \\ [], do: block) do
    env = __CALLER__

    id =
      Keyword.get(args, :id) || String.to_atom(snake_case(name)) ||
        raise CompileError,
          file: env.file,
          line: env.line,
          description: """
          No identifier was provided to the #{name} packet specification. Declare an `:id` before the `do` block.
          """

    if not is_atom(id) do
      raise ArgumentError, "The ID provided to a packet declaration must be an atom."
    end

    quote do
      # Add ID and AST
      Module.put_attribute(__MODULE__, unquote(@current_packet_id), unquote(id))
      Module.put_attribute(__MODULE__, unquote(@current_packet_ast), [])

      # Create empty spec
      Module.put_attribute(
        __MODULE__,
        unquote(@packet_specs),
        __MODULE__
        |> Module.get_attribute(unquote(@packet_specs))
        |> Map.put(unquote(id), %{
          fields: [],
          id: unquote(id),
          name: unquote(name),
          of: unquote(Keyword.get(args, :of)),
          file: unquote(env.file),
          line: unquote(env.line)
        })
      )

      unquote(block)

      # Update specs with AST and ID
      function_body_ast = Module.get_attribute(__MODULE__, unquote(@current_packet_ast))
      all_specs = Module.get_attribute(__MODULE__, unquote(@packet_specs))
      current_spec = all_specs[unquote(id)]

      if current_spec.fields == [] do
        raise CompileError,
          file: current_spec.file,
          line: current_spec.line,
          description: """
          To declare a packet specification, it needs to have one or multiple field/3 declarations as part of it.
          """
      end

      new_spec = Map.put(current_spec, unquote(@function_body_ast), function_body_ast)

      new_specs = Map.put(all_specs, unquote(id), new_spec)
      Module.put_attribute(__MODULE__, unquote(@packet_specs), new_specs)

      # Delete ID and AST
      Module.delete_attribute(__MODULE__, unquote(@current_packet_id))
      Module.delete_attribute(__MODULE__, unquote(@current_packet_ast))
    end
  end

  @doc """
  Defines the structure of a packet field. A packet field is a specific section of the packet. Must
  be inside the `do` block of a [`packet`](#packet/3).

  For example:

      packet "Packet spec", id: :spec do
        field "First field", 4
        field "Second field", 4
      end

  Mandatory arguments to be provided are:

  - `name`: The full name of the field.

  - `length`: The length of the field. Can be an `int` or a `Range`. An `int` will be interpreted as
  the field having a fixed length. A `Range` can be provided as a way to limit and validate the size
  of the field at runtime. It can take the form of a normal range (i. e. `(8..256)`) or a full range
  (`(..)`). Helper functions are also provided (`min/1` and `max/1`) to create clear ranges that
  only have upper or lower limits.

  The list of optional arguments is:

  - `fixed`: If a field is fixed to a specific value. Useful when specifying variants of a packet
    type. Using this, it's possible, for instance, to declare in the spec that a field has to have a
    certain value for the packet to be considered a certain type. Think of how headers usually have a
    field that is used to specify the packet type depending on it's value. Setting this option is
    most relevant to determine the result of the `is_header?/1` function that would be generated
    following the example above.

    ## Example
        iex> defmodule Spec do
        ...>   use Etiquette.Spec
        ...>   packet "Header", id: :header do
        ...>     field "Type", 2
        ...>     field "Data", (..)
        ...>   end
        ...>   packet "Type 0", id: :type_0, of: :header do
        ...>     field "Type", 2, fixed: 0b00
        ...>     field "Data", (..)
        ...>   end
        ...>   packet "Type 1", id: :type_1, of: :header do
        ...>     field "Type", 2, fixed: 0b01
        ...>     field "Data", (..)
        ...>   end
        ...> end
        iex> packet_0 = <<0b00::2, "this is data">>
        iex> packet_1 = <<0b01::2, "this is data">>
        iex> Spec.is_header?(packet_0)
        true
        iex> Spec.is_header?(packet_1)
        true
        iex> Spec.is_type_0?(packet_0)
        true
        iex> Spec.is_type_1?(packet_0)
        false
        iex> Spec.is_type_0?(packet_1)
        false
        iex> Spec.is_type_1?(packet_1)
        true

    See the tests and section [Validating Packet Formats](../../guides/how_tos/validating_packet_formats.md) for more examples.

  - `length_by`: Used to indicate that the length of the field is not fixed and declared through
    other means. The following are supported:
    - An **atom**: An atom can be used to use for reference. It will be interpreted that
      `length_by: :atom` means that the field's length is the value of the field that has `id: :atom`.

  - `length_in`: Used to indicate the format of the length. It can be specified with `:bits` or
    `:bytes`. 

  - `part_of`: Used to declare that a specific field of a parent packet specification is subdivided
    into smaller fields. For example, a packet payload of a generic packet spec, can be divided into
    well-defined fields inside type-specific packet specs. `part_of: :field_id` will be interpreted as
    this field being part of the field containing `id: :field_id`.
    This also means that when one or several fields have `part_of: :field_id`, the fields will take
    the position of the field with `id: :field_id`, and so respect the order of the parent field.
    This also means that the size of the parent field will have to be coherent with the size of the
    children fields.

  - `id`: Must be an atom. An id will be used if another field references this one with
    `length_by` or `part_of`. It can also be used to specify the name that you want to be
    used by the generated functions and the maps they results return.
    IDs are also used when parent and child both have the same field declared. You may want to do
    this when declaring a fixed value in a child spec, for example. In this case, it would be
    recommended to add an ID to the field in the parent packet spec, and then add the same ID to the
    same field in the child spec.

  - `doc`: Provides full documentation on the field. This documentation will be used to document the
    whole module that is using `Etiquette.Spec`. Alternatively, use `@fdoc` to document a field
    before the declaration. For example:

          packet "Header", id: :header do
            field "Type", 2, doc: "Determines the packet type"
            # is equivalent to
            @fdoc "Determines the packet type"
            field "Type", 2
          end

  """
  @spec field(String.t(), pos_integer() | Range.t(),
          length_by: atom(),
          length_in: :bits | :bytes,
          part_of: atom(),
          id: atom(),
          doc: String.t()
        ) :: Macro.t()
  defmacro field(name, length, opts \\ []) do
    {length, _bindings} = Code.eval_quoted(length, [], __CALLER__)
    {opts, _bindings} = Code.eval_quoted(opts, [], __CALLER__)
    if not is_binary(name), do: raise(ArgumentError, "`name` must be a string.")

    __field__(__CALLER__, name, length, opts)
  end

  defp __field__(env, name, length, opts) when is_integer(length) do
    Field.validate_integer_length_field(env, length, opts)

    id = Keyword.get(opts, :id)

    part_of = Keyword.get(opts, :part_of)
    fixed_value = Keyword.get(opts, :fixed, nil)
    length_in = Keyword.get(opts, :length_in, :bits)

    snake_case_name = snake_case(name)

    quote bind_quoted: [
            file: env.file,
            line: env.line,
            current_packet_id: @current_packet_id,
            snake_case_name: snake_case_name,
            packet_specs: @packet_specs,
            part_of: part_of,
            name: name,
            id: id,
            length: length,
            length_in: length_in,
            fixed_value: fixed_value,
            doc: Keyword.get(opts, :doc)
          ] do
      Module.register_attribute(__MODULE__, :fdoc, accumulate: false, persist: false)

      packet_id =
        Module.get_attribute(__MODULE__, current_packet_id) ||
          raise CompileError,
            file: file,
            line: line,
            description: "To use field/3, it has to be used inside the `do` block of a packet/3 call."

      all_packet_specs = Module.get_attribute(__MODULE__, packet_specs)
      current_packet_spec = Map.get(all_packet_specs, packet_id)
      current_packet_spec_fields = Map.get(current_packet_spec, :fields, [])

      ex_name = snake_case_name

      new_packet_spec =
        %Field{
          name: name,
          ex_name: id || String.to_atom(ex_name),
          length: length,
          length_in: length_in,
          part_of: part_of,
          doc: doc || @fdoc || nil,
          file: file,
          line: line
        }

      new_packet_spec =
        if is_nil(fixed_value), do: new_packet_spec, else: %{new_packet_spec | fixed_value: fixed_value}

      new_fields = current_packet_spec_fields ++ [new_packet_spec]

      new_current_packet_spec = Map.put(current_packet_spec, :fields, new_fields)
      new_all_packet_specs = Map.put(all_packet_specs, packet_id, new_current_packet_spec)
      Module.put_attribute(__MODULE__, packet_specs, new_all_packet_specs)
      Module.delete_attribute(__MODULE__, :fdoc)
    end
  end

  defp __field__(env, name, length, opts) when is_range(length) do
    Field.validate_range_length_field(env, length, opts)

    id = Keyword.get(opts, :id)

    part_of = Keyword.get(opts, :part_of)
    length_by = Keyword.get(opts, :length_by, nil)
    length_in = Keyword.get(opts, :length_in, :bits)
    decoder = Keyword.get(opts, :decoder, nil)

    snake_case_name = snake_case(name)

    first..last//step = length

    quote bind_quoted: [
            file: env.file,
            line: env.line,
            current_packet_id: @current_packet_id,
            snake_case_name: snake_case_name,
            packet_specs: @packet_specs,
            part_of: part_of,
            name: name,
            id: id,
            first: first,
            last: last,
            step: step,
            length_by: length_by,
            length_in: length_in,
            decoder: decoder,
            doc: Keyword.get(opts, :doc)
          ] do
      Module.register_attribute(__MODULE__, :fdoc, accumulate: false, persist: false)

      packet_id =
        Module.get_attribute(__MODULE__, current_packet_id) ||
          raise CompileError,
            file: file,
            line: line,
            description: "To use field/3, it has to be used inside the `do` block of a packet/3 call."

      all_packet_specs = Module.get_attribute(__MODULE__, packet_specs)
      current_packet_spec = Map.get(all_packet_specs, packet_id)
      current_packet_spec_fields = Map.get(current_packet_spec, :fields, [])

      ex_name = snake_case_name

      new_packet_spec =
        %Field{
          name: name,
          ex_name: id || String.to_atom(ex_name),
          length: first..last//step,
          length_in: length_in,
          decoder: decoder,
          part_of: part_of,
          doc: doc || @fdoc || nil,
          file: file,
          line: line
        }

      new_packet_spec =
        case length_by do
          lb when not is_nil(lb) and is_atom(lb) -> %{new_packet_spec | length_by_variable: lb}
          _ -> new_packet_spec
        end

      new_fields = current_packet_spec_fields ++ [new_packet_spec]

      new_current_packet_spec = Map.put(current_packet_spec, :fields, new_fields)
      new_all_packet_specs = Map.put(all_packet_specs, packet_id, new_current_packet_spec)
      Module.put_attribute(__MODULE__, packet_specs, new_all_packet_specs)
      Module.delete_attribute(__MODULE__, :fdoc)
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    packet_specs = Module.get_attribute(env.module, unquote(@packet_specs))

    generated_functions =
      for {id, spec} <- packet_specs, into: [] do
        is_name = :"is_#{id}?"
        parse_name = :"parse_#{id}"
        build_name = :"build_#{id}"

        fields =
          if is_atom(spec.of) and not is_nil(spec.of) do
            parent_spec = packet_specs[spec.of]
            merge_parent_and_child_of(parent_spec.fields, spec.fields)
          else
            spec.fields
          end

        spec = Map.replace(spec, :fields, fields)

        map_spec_ast = Field.build_map_spec_ast(fields)
        args_spec_ast = Field.build_args_spec_ast(fields)
        args_ast = Field.build_args_ast(fields)
        args_guard_ast = Field.build_args_guard_ast(fields)
        bit_string_ast = Field.build_bit_string_ast(fields)

        quote do
          @doc """
          Returns whether the given packet follows the #{unquote(spec.name)} specification.

          #{unquote(parse_rfc_spec(spec))}
          """
          @spec unquote(is_name)(packet()) :: boolean()
          def unquote(is_name)(input) when is_bitstring(input) do
            rest = input

            unquote_splicing(parse_field_destructuring(fields))

            true
          rescue
            MatchError -> false
          end

          def unquote(is_name)(input), do: false

          @doc """
          Given a #{unquote(spec.name)} packet in binary, returns the parsed arguments in a map with
          each field.

          #{unquote(parse_rfc_spec(spec))}
          """
          @spec unquote(parse_name)(packet()) :: {%{unquote_splicing(map_spec_ast)}, packet()}
          def unquote(parse_name)(input) do
            rest = input

            unquote_splicing(parse_field_destructuring(fields))

            parsed_packet =
              Map.new([
                unquote_splicing(
                  Enum.map(fields, fn %Field{ex_name: ex_name} ->
                    quote do
                      {unquote(ex_name), unquote(Macro.var(ex_name, __MODULE__))}
                    end
                  end)
                )
              ])

            {parsed_packet, rest}
          end

          @doc """
          Builds a #{unquote(spec.name)} packet given it's field values.

          #{unquote(parse_rfc_spec(spec))}
          """
          @spec unquote(build_name)(unquote_splicing(args_ast)) :: bitstring() when unquote(args_spec_ast)
          def unquote({:when, [], [{build_name, [], args_ast}, args_guard_ast]}) do
            unquote(bit_string_ast)
          end
        end
      end

    [
      quote do
        @moduledoc """
        Contains the specification#{unquote(if(Enum.count(packet_specs) == 1, do: "", else: "s"))} for
        - #{unquote(Enum.join(Enum.map(packet_specs, fn {_, spec} -> spec.name end), "\n- "))}
        """
      end
      | generated_functions
    ]

    if @debug do
      Enum.map(generated_functions, fn x ->
        x |> Macro.to_string() |> IO.puts()
        x
      end)
    else
      generated_functions
    end
  end

  @doc "A range going from minimum `num` up to the end. Equivalent to `num..`"
  def min(num), do: num..-1//1
  @doc "A range going from the start up to maximum `num`. Equivalent to `..num`"
  def max(num), do: 0..num//1

  defp snake_case(string) do
    string
    |> String.split(" ")
    |> Enum.map_join(&String.capitalize/1)
    |> String.replace(" ", "")
    |> Macro.underscore()
    |> String.replace("-", "_")
    |> String.replace("-", "")
  end

  defp merge_parent_and_child_of(parent_fields, child_fields) do
    parent_names = Enum.map(parent_fields, & &1.ex_name)

    children_names = Enum.map(child_fields, & &1.ex_name)
    children_part_of = Enum.map(child_fields, & &1.part_of)

    not_inherited_children =
      Enum.filter(child_fields, fn child_field ->
        is_nil(child_field.part_of) and child_field.ex_name not in parent_names
      end)

    parent_with_inherited_children =
      parent_fields
      |> Enum.reduce([], fn %Field{} = parent_field, acc ->
        parent_name = parent_field.ex_name

        updated_field =
          cond do
            parent_name in children_names ->
              child_fields
              |> Enum.find(&(&1.ex_name == parent_name))
              |> case do
                %Field{doc: nil} = field -> [%{field | doc: parent_field.doc}]
                field -> [field]
              end

            parent_name in children_part_of ->
              Enum.filter(child_fields, &(&1.part_of == parent_name))

            true ->
              [parent_field]
          end

        acc ++ updated_field
      end)
      |> List.flatten()

    parent_with_inherited_children ++ not_inherited_children
  end

  defp parse_field_destructuring(fields) do
    Field.validate_destructured_fields(fields)
    Field.validate_field_order(fields)

    fields
    |> Enum.map(&quote_field/1)
    |> List.flatten()
  end

  defp quote_field(%Field{ex_name: ex_name} = field) do
    field_name = Macro.var(ex_name, __MODULE__)

    case field do
      %Field{decoder: decoder, length_in: :bits} when not is_nil(decoder) ->
        [
          quote do
            {unquote(field_name), rest} = then(rest, unquote(decoder))
          end
        ]

      %Field{length_by_variable: lb, length_in: :bits} when is_atom(lb) and not is_nil(lb) ->
        # TODO: take into account if variable has been defined using function or if it's raw value
        var = Macro.var(lb, __ENV__.module)

        quote do
          <<unquote(field_name)::size(unquote(var)), rest::bitstring>> = rest
        end

      %Field{length_by_variable: lb, length_in: :bytes} when is_atom(lb) and not is_nil(lb) ->
        # TODO: take into account if variable has been defined using function or if it's raw value
        var = Macro.var(lb, __ENV__.module)

        quote do
          <<unquote(field_name)::size(unquote(var) * 8), rest::bitstring>> = rest
        end

      %Field{fixed_value: fv, length: l, length_in: :bits} when is_integer(fv) and is_integer(l) ->
        quote do
          <<unquote(field_name)::size(unquote(l)), rest::bitstring>> =
            <<unquote(fv)::size(unquote(l)), _::bitstring>> = rest
        end

      %Field{length: length} when is_range(length) ->
        quote do
          unquote(field_name) = rest
        end

      %Field{length: l, length_in: :bits} when is_integer(l) ->
        quote do
          <<unquote(field_name)::size(unquote(l)), rest::bitstring>> = rest
        end
    end
  end

  defp parse_rfc_spec(spec) do
    title = spec.name

    field_docs =
      Enum.map(spec.fields, fn field ->
        case field do
          %Field{name: name, length: length, fixed_value: fixed_value, doc: doc} ->
            "- **#{name}**" <>
              case length do
                (..) -> " (..)"
                a..-1//_ -> " (#{a}..)"
                0..b//_ -> " (..#{b})"
                a..b//_ -> " (#{a}..#{b})"
                length -> " (#{length})"
              end <>
              case fixed_value do
                value when is_integer(value) -> " = #{value}"
                _ -> ""
              end <>
              case doc do
                nil -> "\n"
                doc -> ":\n  #{doc}\n\n"
              end
        end
      end)

    """
    # #{title}:
    #{field_docs}
    """
  end
end
