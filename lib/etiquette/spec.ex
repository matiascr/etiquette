defmodule Etiquette.Spec do
  @moduledoc false
  alias Etiquette.Field

  @current_packet_id :current_packet_id
  @current_packet_ast :current_packet_ast
  @packet_specs :packet_specs

  @function_body_ast :function_body_ast

  @docs_formats [:rfc, :md_list, :md_table]
  @default_docs_format :rfc

  defmacro __using__(opts) do
    docs_format = Keyword.get(opts, :docs_format, @default_docs_format)
    docs_format = if docs_format in @docs_formats, do: docs_format, else: @default_docs_format

    quote do
      import Etiquette.Spec

      Module.put_attribute(__MODULE__, unquote(@packet_specs), %{})

      @before_compile Etiquette.Spec

      @docs_format unquote(docs_format)

      @type packet :: bitstring()
    end
  end

  @doc """
  Declares a packet specification. A packet specification is composed of a sequence of `fields`.
  Other arguments are also available:
  - `name`: Mandatory field. A string with the name of the field.
  - `id`: An atom used to take care of references. When another packet uses the `of` argument, the
    id is what will be used for reference.
  - `of`: Declares that a packet follows a previously declared packet specification. The specs have
    to be declared in the same file. This argument needs to be present when using `part_of`.

  The packet contents themselves are declared inside a `do` block containing `field`s. For more
  information, see [`field`](./spec.ex#field)

  See the [tests](../../test) for more examples.
  """
  defmacro packet(name, args, do: block) do
    id =
      Keyword.get(args, :id) ||
        raise ArgumentError,
          message:
            "No identifier was provided to the #{name} packet specification. Declare an `:id` before the `do` block."

    quote do
      Module.put_attribute(__MODULE__, unquote(@current_packet_id), unquote(id))

      Module.put_attribute(
        __MODULE__,
        unquote(@packet_specs),
        __MODULE__
        |> Module.get_attribute(unquote(@packet_specs))
        |> Map.put(unquote(id), %{
          fields: [],
          id: unquote(id),
          name: unquote(name),
          of: unquote(Keyword.get(args, :of))
        })
      )

      Module.put_attribute(__MODULE__, unquote(@current_packet_ast), [])

      unquote(block)

      function_body_ast = Module.get_attribute(__MODULE__, unquote(@current_packet_ast))
      all_specs = Module.get_attribute(__MODULE__, unquote(@packet_specs))
      current_spec = all_specs[unquote(id)]
      new_spec = Map.put(current_spec, unquote(@function_body_ast), function_body_ast)

      new_specs = Map.put(all_specs, unquote(id), new_spec)
      Module.put_attribute(__MODULE__, unquote(@packet_specs), new_specs)

      Module.delete_attribute(__MODULE__, unquote(@current_packet_id))
      Module.delete_attribute(__MODULE__, unquote(@current_packet_ast))
    end
  end

  @doc """
  Defines the structure of a packet field. A packet field is a specific section of the packet.
  Mandatory arguments to be provided are:
  - `name`: The full name of the field.
  - `length`: The length of the field. Can be an `int` or a `Range`. An `int` will be interpreted as
  the field having a fixed length. A `Range` can be provided as a way to limit and validate the size
  of the field at runtime. It can take the form of a normal range (i. e. `(8..256)`) or a full range
  (`(..)`). Helper functions are also provided (`min/1` and `max/1`) to create clear ranges that
  only have upper or lower limits.

  The list of optional arguments is:
  - `doc`: Provides full documentation on the field. This documentation will be used to document the
    whole module that is using `Etiquette.Spec`.
  - `fixed`: If a field is fixed to a specific value. Useful when specifying variants of a packet
    type, so it's possible, for instance, to declare in the spec that a field has to have a certain
    value for the packet to be considered a certain type. Think of how headers usually have a field
    that is used to specify the packet type.
  - `length_by`: Used to indicate that the length of the field is not fixed and declared through
    other means. The following are supported:
    - An **atom**: An atom can be used to use for reference. It will be interpreted that
      `length_by: :atom` means that the field's length is the value of the field that has `id: :atom`.
    - A **function**. If a function is provided instead, the value of the field will be passed to the
      function and the result will be used as the length of the field. For example, using
      `length_by: &Module.calc_function/1` will mean that the result of passing the value of the
      packet (starting from the position of the bits of that field, not the whole packet) to that
      function, will return a positive integer that will be used as the length of the field.
  - `part_of`: Used to declare that a specific field of a parent packet specification is subdivided
    into smaller fields. For example, a packet payload of a generic packet spec, can be divided into
    well-defined fields inside type-specific packet specs. `part_of: :field_id` will be interpreted as
    this field being part of the field containing `id: :field_id`.
    This also means that when one or several fields have `part_of: :field_id`, the fields will take
    the position of the field with `id: :field_id`, and so respect the order of the parent field.
    This also means that the size of the parent field will have to be coherent with the size of the
    children fields.
  - `id`: Must be an atom. An id will be required if another field references this one with
    `length_by` or `part_of`. It can also be used to specify the name that you want to be
    used/returned by the generated functions.
    IDs are also used when parent and child both have the same field declared. You may want to do
    this when declaring a fixed value in a child spec, for example. In this case, it would be
    recommended to add an ID to the field in the parent packet spec, and then add the same ID to the
    same field in the child spec.

  See the [tests](../../test) for more examples.
  """
  defmacro field(name, length, opts) do
    part_of = Keyword.get(opts, :part_of)
    doc = Keyword.get(opts, :doc)

    length_by =
      case Keyword.get(opts, :fixed, nil) do
        i when is_integer(i) -> i
        _ -> Keyword.get(opts, :length_by, nil)
      end

    snake_case_name = snake_case(name)

    quote do
      packet_id = Module.get_attribute(__MODULE__, unquote(@current_packet_id))

      all_packet_specs = Module.get_attribute(__MODULE__, unquote(@packet_specs))
      current_packet_spec = Map.get(all_packet_specs, packet_id)
      current_packet_spec_fields = Map.get(current_packet_spec, :fields, [])

      ex_name = unquote(snake_case_name)

      new_packet_spec =
        %Field{
          name: unquote(name),
          ex_name: String.to_atom(ex_name),
          length: unquote(length),
          opts: unquote(opts),
          length_by: unquote(length_by),
          part_of: unquote(part_of),
          doc: unquote(doc)
        }

      new_fields = current_packet_spec_fields ++ [new_packet_spec]

      new_current_packet_spec = Map.put(current_packet_spec, :fields, new_fields)
      new_all_packet_specs = Map.put(all_packet_specs, packet_id, new_current_packet_spec)
      Module.put_attribute(__MODULE__, unquote(@packet_specs), new_all_packet_specs)
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    packet_specs = Module.get_attribute(env.module, unquote(@packet_specs))

    generated_functions =
      for {id, spec} <- packet_specs, into: [] do
        is_name = :"is_#{id}?"
        parse_name = :"parse_#{id}"

        fields =
          if is_atom(spec.of) and not is_nil(spec.of) do
            parent_spec = packet_specs[spec.of]
            merge_parent_and_child_of(parent_spec.fields, spec.fields)
          else
            spec.fields
          end

        spec = Map.replace(spec, :fields, fields)

        keys_ast =
          for key <- Enum.map(fields, fn field -> field.ex_name end) do
            key
          end

        map_ast =
          for key <- keys_ast do
            {key, {:bitstring, [], Elixir}}
          end

        quote do
          @doc """
          Returns whether the given packet follows the #{unquote(spec.name)} specification.

          #{unquote(parse_rfc_spec(spec))}
          """
          @spec unquote(is_name)(packet()) :: boolean()
          def unquote(is_name)(input) when is_bitstring(input) do
            rest = input

            unquote_splicing(parse_destructuring(fields))

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
          @spec unquote(parse_name)(packet()) :: %{unquote_splicing(map_ast)}
          def unquote(parse_name)(input) do
            rest = input

            unquote_splicing(parse_destructuring(fields))

            Map.new([
              unquote_splicing(
                Enum.map(fields, fn field ->
                  field_name = field.ex_name
                  field_var = Macro.var(field.ex_name, __MODULE__)

                  quote do
                    {unquote(field_name), unquote(field_var)}
                  end
                end)
              )
            ])
          end
        end
      end

    [
      quote do
        @moduledoc """
        Specification for
        - #{unquote(Enum.join(Enum.map(packet_specs, fn {_, spec} -> spec.name end), "\n- "))}
        """
      end
      | generated_functions
    ]
  end

  @doc "A range going from minimum `num` up to the end."
  def min(num), do: num..-1//1
  @doc "A range going from the start up to maximum `num`."
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
      Enum.reduce(parent_fields, [], fn parent_field, acc ->
        parent_name = parent_field.ex_name

        acc ++
          cond do
            parent_name in children_names -> Enum.filter(child_fields, &(&1.ex_name == parent_name))
            parent_name in children_part_of -> Enum.filter(child_fields, &(&1.part_of == parent_name))
            true -> [parent_field]
          end
      end)

    parent_with_inherited_children ++ not_inherited_children
  end

  defp parse_destructuring(fields) do
    fields
    |> Enum.map(fn field ->
      field_name = Macro.var(field.ex_name, __MODULE__)

      case field do
        %Field{length_by: lb} when is_atom(lb) and not is_nil(lb) ->
          var = Macro.var(lb, __ENV__.module)

          quote do
            <<unquote(field_name)::size((unquote(var) + 1) * 8), rest::bitstring>> = rest
          end

        %Field{length_by: lb} when is_function(lb) ->
          [
            quote do
              bit_segment_size = unquote(lb).(rest)
            end,
            quote do
              <<unquote(field_name)::size(bit_segment_size), rest::bitstring>> = rest
            end
          ]

        %Field{length_by: nil, length: a..b//1} when a < b or b == -1 ->
          quote do
            unquote(field_name) = rest
          end

        %Field{length_by: lb, length: l} when is_integer(lb) and not is_nil(l) ->
          quote do
            <<unquote(field_name)::size(unquote(l)), rest::bitstring>> =
              <<unquote(lb)::size(unquote(l)), rest::bitstring>> = rest
          end

        %Field{length: l, length_by: nil} when is_integer(l) ->
          quote do
            <<unquote(field_name)::size(unquote(l)), rest::bitstring>> = rest
          end

        %Field{length_by: nil, length: _l} ->
          quote do
            <<unquote(field_name), rest::bitstring>> = rest
          end
      end
    end)
    |> List.flatten()
  end

  @spec parse_destructuring(Field.t()) :: any()
  defp quote_field(field) do
    field_name = Macro.var(field.ex_name, __MODULE__)

    case field do
      %Field{length_by: lb} when is_atom(lb) and not is_nil(lb) ->
        var = Macro.var(lb, __ENV__.module)

        quote do
          <<unquote(field_name)::size((unquote(var) + 1) * 8), rest::bitstring>> = rest
        end

      %Field{length_by: lb} when is_function(lb) ->
        [
          quote do
            bit_segment_size = unquote(lb).(rest)
          end,
          quote do
            <<unquote(field_name)::size(bit_segment_size), rest::bitstring>> = rest
          end
        ]

      %Field{length_by: nil, length: a..b//1} when a < b or b == -1 ->
        quote do
          unquote(field_name) = rest
        end

      %Field{length_by: lb, length: l} when is_integer(lb) and not is_nil(l) ->
        quote do
          <<unquote(field_name)::size(unquote(l)), rest::bitstring>> =
            <<unquote(lb)::size(unquote(l)), rest::bitstring>> = rest
        end

      %Field{length: l, length_by: nil} when is_integer(l) ->
        quote do
          <<unquote(field_name)::size(unquote(l)), rest::bitstring>> = rest
        end

      %Field{length_by: nil, length: _l} ->
        quote do
          <<unquote(field_name), rest::bitstring>> = rest
        end
    end
  end

  defp parse_rfc_spec(spec) do
    title = spec.name

    field_docs =
      Enum.map(spec.fields, fn field ->
        case field do
          %{name: name, length: length, length_by: length_by, doc: doc} ->
            "- **#{name}**" <>
              case length do
                (..) -> " (..)"
                a..-1//_ -> " (#{a}..)"
                0..b//_ -> " (..#{b})"
                a..b//_ -> " (#{a}..#{b})"
                length -> " (#{length})"
              end <>
              case length_by do
                value when is_integer(value) -> " = #{value}"
                _ -> ""
              end <>
              case doc do
                nil -> "\n"
                doc -> ":\n  #{doc}\n"
              end
        end
      end)

    """
    # #{title}:
    #{field_docs}
    """
  end
end
