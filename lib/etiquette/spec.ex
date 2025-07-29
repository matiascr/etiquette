defmodule Etiquette.Spec do
  @moduledoc false

  @current_packet_id :current_packet_id
  @current_packet_ast :current_packet_ast
  @packet_specs :packet_specs

  @function_body_ast :function_body_ast

  defmacro __using__(_opts) do
    quote do
      import Etiquette.Spec

      Module.put_attribute(__MODULE__, unquote(@packet_specs), %{})

      @before_compile Etiquette.Spec

      @type packet :: bitstring()
    end
  end

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

  defmacro field(name, length, opts) do
    length_by = Keyword.get(opts, :length_by, nil)
    part_of = Keyword.get(opts, :part_of)

    length_by =
      case Keyword.get(opts, :fixed, nil) do
        i when is_integer(i) -> i
        _ -> length_by
      end

    quote do
      packet_id = Module.get_attribute(__MODULE__, unquote(@current_packet_id))

      all_packet_specs = Module.get_attribute(__MODULE__, unquote(@packet_specs))
      current_packet_spec = Map.get(all_packet_specs, packet_id)
      current_packet_spec_fields = Map.get(current_packet_spec, :fields, [])

      ex_name = unquote(snake_case(name))

      new_packet_spec =
        %{
          name: unquote(name),
          ex_name: String.to_atom(ex_name),
          length: unquote(length),
          opts: unquote(opts),
          length_by: unquote(length_by),
          part_of: unquote(part_of)
        }

      new_fields = current_packet_spec_fields ++ [new_packet_spec]

      new_current_packet_spec = Map.put(current_packet_spec, :fields, new_fields)
      new_all_packet_specs = Map.put(all_packet_specs, packet_id, new_current_packet_spec)
      Module.put_attribute(__MODULE__, unquote(@packet_specs), new_all_packet_specs)

      current_packet_ast = Module.get_attribute(__MODULE__, unquote(@current_packet_ast))
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    packet_specs = Module.get_attribute(env.module, unquote(@packet_specs))

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

      keys_ast =
        for key <- Enum.map(fields, fn f -> f.ex_name end) do
          key
        end

      map_ast =
        for key <- keys_ast do
          {key, {:bitstring, [], Elixir}}
        end

      quote do
        @doc """
        Returns whether the given packet follows the #{unquote(spec.name)} specification.
        """
        @spec unquote(is_name)(packet()) :: boolean()
        def unquote(is_name)(input) when is_bitstring(input) do
          rest = input

          unquote_splicing(
            List.flatten(
              Enum.map(fields, fn f ->
                field_name = Macro.var(f.ex_name, __MODULE__)

                case f do
                  %{length: a..b//1, length_by: nil} when a < b or b == -1 ->
                    quote do
                      unquote(field_name) = rest
                    end

                  %{length: :undefined, length_by: nil} ->
                    quote do
                      unquote(field_name) = rest
                    end

                  %{length_by: lb, length: l} when is_integer(lb) ->
                    quote do
                      <<unquote(field_name)::size(unquote(l)), rest::bitstring>> =
                        <<unquote(lb)::size(unquote(l)), rest::bitstring>> = rest
                    end

                  %{length: l} when is_integer(l) ->
                    quote do
                      <<unquote(field_name)::size(unquote(l)), rest::bitstring>> = rest
                    end

                  %{length_by: lb} when is_function(lb) ->
                    [
                      quote do
                        bit_segment_size = unquote(lb).(rest)
                      end,
                      quote do
                        <<unquote(field_name)::size(bit_segment_size), rest::bitstring>> = rest
                      end
                    ]

                  %{length_by: nil, length: _l} ->
                    quote do
                      <<unquote(field_name), rest::bitstring>> = rest
                    end

                  %{length_by: lb} when is_atom(lb) ->
                    quote do
                      <<unquote(field_name)::size((unquote(Macro.var(lb, __ENV__.module)) + 1) * 8), rest::bitstring>> =
                        rest
                    end
                end
              end)
            )
          )

          true
        rescue
          MatchError -> false
        end

        def unquote(is_name)(input), do: false

        @spec unquote(parse_name)(packet()) :: %{unquote_splicing(map_ast)}
        def unquote(parse_name)(input) do
          rest = input

          unquote_splicing(
            List.flatten(
              Enum.map(fields, fn f ->
                field_name = Macro.var(f.ex_name, __MODULE__)

                case f do
                  %{length: a..b//1, length_by: nil} when a < b or b == -1 ->
                    quote do
                      unquote(field_name) = rest
                    end

                  %{length: :undefined, length_by: nil} ->
                    quote do
                      unquote(field_name) = rest
                    end

                  %{length_by: lb, length: l} when is_integer(lb) ->
                    quote do
                      <<unquote(field_name)::size(unquote(l)), rest::bitstring>> =
                        <<unquote(lb)::size(unquote(l)), rest::bitstring>> = rest
                    end

                  %{length: l} when is_integer(l) ->
                    quote do
                      <<unquote(field_name)::size(unquote(l)), rest::bitstring>> = rest
                    end

                  %{length_by: lb} when is_function(lb) ->
                    [
                      quote do
                        bit_segment_size = unquote(lb).(rest)
                      end,
                      quote do
                        <<unquote(field_name)::size(bit_segment_size), rest::bitstring>> = rest
                      end
                    ]

                  %{length_by: nil, length: _l} ->
                    quote do
                      <<unquote(field_name), rest::bitstring>> = rest
                    end

                  %{length_by: lb} when is_atom(lb) ->
                    quote do
                      <<unquote(field_name)::size((unquote(Macro.var(lb, __ENV__.module)) + 1) * 8), rest::bitstring>> =
                        rest
                    end
                end
              end)
            )
          )

          Map.new([
            unquote_splicing(
              Enum.map(fields, fn f ->
                field_name = f.ex_name
                field_var = Macro.var(f.ex_name, __MODULE__)

                quote do
                  {unquote(field_name), unquote(field_var)}
                end
              end)
            )
          ])
        end
      end
    end
  end

  def min(num), do: num..-1//1
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
end
