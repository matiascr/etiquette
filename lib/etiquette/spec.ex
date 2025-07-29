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
        |> Map.put(unquote(id), %{fields: [], id: unquote(id), name: unquote(name), of: unquote(Keyword.get(args, :of))})
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
          ex_name: ex_name,
          length: unquote(length),
          opts: unquote(opts),
          length_by: unquote(length_by)
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

      fields =
        case spec.of do
          nil ->
            spec.fields

          parent when is_atom(parent) ->
            parent_spec = packet_specs[parent]
            merge_parent_and_child(parent_spec.fields, spec.fields)
        end

      quote do
        @doc """
        Returns whether the given packet follows the #{unquote(spec.name)} specification.
        """
        def unquote(is_name)(input) when is_bitstring(input) do
          rest = input

          unquote_splicing(
            List.flatten(
              Enum.map(fields, fn f ->
                field_name = Macro.var(String.to_atom(f.ex_name), __MODULE__)

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
                      <<unquote(field_name)::size(unquote(Macro.var(lb, __ENV__.module))), rest::bitstring>> = rest
                    end
                end
              end)
            )
          )

          true
        rescue
          MatchError -> false
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
    |> String.replace("-", "")
  end

  def merge_parent_and_child(parent_fields, child_fields) do
    new_parent_fields =
      parent_fields
      |> Enum.reduce([], fn parent_field, acc ->
        acc ++
          [
            if parent_field.ex_name in Enum.map(child_fields, fn f -> f.ex_name end) do
              Enum.filter(child_fields, fn f -> f.ex_name == parent_field.ex_name end)
            else
              parent_field
            end
          ]
      end)
      |> List.flatten()

    new_child_fields =
      child_fields
      |> Enum.filter(fn field ->
        field.ex_name not in Enum.map(parent_fields, fn f -> f.ex_name end)
      end)
      |> List.flatten()

    Enum.slice(new_parent_fields, 0..-2//1) ++ new_child_fields
  end
end
