defmodule SaluteSpec do
  @moduledoc false
  use ExUnit.Case
  use Etiquette.Spec

  # Replicates the refined guides/how_tos/packet_types_and_subtypes.md spec

  packet "My Salute Packet", id: :salute do
    field "Source Port", 8
    field "Destination Port", 8
    field "Packet Type", 2
    field "Payload Type", 6
    field "Payload", 8
  end

  packet "Hello Packet", id: :hello, of: :salute do
    field "Destination Port", 8
    field "Packet Type", 2, fixed: 0b00
    field "Payload Type", 6
    field "Payload", 8
  end

  packet "Goodbye Packet", id: :goodbye, of: :salute do
    field "Destination Port", 8
    field "Packet Type", 2, fixed: 0b11
    field "Payload Type", 6
    field "Payload", 8
  end

  test "hello goodbye" do
    assert is_hello?(<<0::8, 0::8, 0b00::2, 0x3F::6, "somedata">>)
    refute is_goodbye?(<<0::8, 0::8, 0b00::2, 0x3F::6, "somedata">>)

    refute is_hello?(<<0::8, 0::8, 0b11::2, 0x3F::6, "somedata">>)
    assert is_goodbye?(<<0::8, 0::8, 0b11::2, 0x3F::6, "somedata">>)
  end
end
