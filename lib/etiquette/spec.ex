defmodule Etiquette.Spec do
  @moduledoc false

  @current_packet_id :current_packet_id
  @packet_specs :packet_specs

  defmacro __using__(_opts) do
    quote do
      import Etiquette.Spec

      Module.put_attribute(__MODULE__, unquote(@packet_specs), %{})
    end
  end

  # Packet ########################################################################################

  defmacro packet(name, args, do: block) do
    module = __CALLER__.module

    id =
      Keyword.get(args, :id) ||
        raise CompileError,
          message:
            "No identifier was provided to the #{name} packet specification. Declare an `:id` before the `do` block."

    packet_id_fun = String.to_atom("#{id}")
    is_packet_fun = String.to_atom("is_#{id}?")

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

      @doc """
      Parses a #{unquote(name)} packet into a map with it's fields.
      """
      def unquote(packet_id_fun)(packet) do
        packet
      end

      @doc """
      Whether or not the packet is a #{unquote(name)} packet.
      """
      @spec unquote(is_packet_fun)(binary()) :: bool()
      def unquote(is_packet_fun)(unquote(IO.inspect(Module.get_attribute(module, @packet_specs), label: :interest))) do
        true
      end

      def unquote(is_packet_fun)(_), do: false

      __MODULE__ |> Module.get_attribute(unquote(@current_packet_id)) |> IO.inspect(label: :current_packet_id)
      __MODULE__ |> Module.get_attribute(unquote(@packet_specs)) |> IO.inspect(label: :packet_specs)
    end
  end

  # Field #########################################################################################

  defmacro field(name, length, opts) do
    __field__(name, length, opts)
  end

  def __field__(name, length, opts) do
    quote do
      packet_id = Module.get_attribute(__MODULE__, unquote(@current_packet_id))
      IO.inspect([unquote(name), unquote(length), unquote(Keyword.delete(opts, :doc))], label: packet_id)
      all_packet_specs = Module.get_attribute(__MODULE__, unquote(@packet_specs))
      current_packet_spec = Map.get(all_packet_specs, packet_id)
      current_packet_spec_fields = Map.get(current_packet_spec, :fields, [])

      new_field = %{name: unquote(name), ex_name: unquote(snake_case(name)), length: unquote(length), opts: unquote(opts)}

      new_fields =
        case current_packet_spec_fields do
          [] -> [new_field]
          [h] -> [h, new_field]
          a -> a ++ [new_field]
        end

      new_current_packet_spec = Map.put(current_packet_spec, :fields, new_fields)
      new_all_packet_specs = Map.put(all_packet_specs, packet_id, new_current_packet_spec)
      Module.put_attribute(__MODULE__, unquote(@packet_specs), new_all_packet_specs)
    end
  end

  def min(num), do: num..-1//1
  def max(num), do: 0..num//1

  defp snake_case(string), do: string |> Macro.underscore() |> String.replace(" ", "") |> String.replace("-", "")
end
