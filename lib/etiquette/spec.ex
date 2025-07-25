defmodule Etiquette.Spec do
  @moduledoc false

  @current_packet_id :current_packet_id
  @packet_specs :packet_specs

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
        raise CompileError,
          message:
            "No identifier was provided to the #{name} packet specification. Declare an `:id` before the `do` block."

    quote do
      # Register current id
      Module.put_attribute(__MODULE__, unquote(@current_packet_id), unquote(id))

      # Update map with packet spec
      Module.put_attribute(
        __MODULE__,
        unquote(@packet_specs),
        __MODULE__
        |> Module.get_attribute(unquote(@packet_specs))
        |> Map.put(unquote(id), %{fields: []})
      )

      unquote(block)

      Module.delete_attribute(__MODULE__, unquote(@current_packet_id))
    end
  end

  defmacro field(name, length, opts) do
    quote do
      packet_id = Module.get_attribute(__MODULE__, unquote(@current_packet_id))
      all_packet_specs = Module.get_attribute(__MODULE__, unquote(@packet_specs))
      current_packet_spec = Map.get(all_packet_specs, packet_id)
      current_packet_spec_fields = Map.get(current_packet_spec, :fields, [])

      new_fields =
        current_packet_spec_fields ++
          [%{name: unquote(name), ex_name: unquote(snake_case(name)), length: unquote(length), opts: unquote(opts)}]

      new_current_packet_spec = Map.put(current_packet_spec, :fields, new_fields)
      new_all_packet_specs = Map.put(all_packet_specs, packet_id, new_current_packet_spec)
      Module.put_attribute(__MODULE__, unquote(@packet_specs), new_all_packet_specs)
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      __MODULE__ |> Module.get_attribute(unquote(@packet_specs)) |> IO.inspect(label: :packet_specs)
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
end
