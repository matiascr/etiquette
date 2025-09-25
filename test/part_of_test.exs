defmodule PartOfTest do
  use ExUnit.Case
  use Etiquette.Spec

  packet "Packet" do
    field "id", 2
    field "type-specific field", 14, id: :type_specific_field
    field "payload", 8
  end

  packet "Type 0", id: :type_0, of: :packet do
    field "id", 2, fixed: 0
    field "first field", 4, part_of: :type_specific_field
    field "second field", 10, part_of: :type_specific_field
  end

  packet "Type 1", id: :type_1, of: :packet do
    field "id", 2, fixed: 3
    field "different first field", 9, part_of: :type_specific_field
    field "different second field", 5, part_of: :type_specific_field
  end

  # Tests

  test "undefined variant" do
    packet = <<1::2, 8190::14, 0xFFFF>>

    assert is_packet?(packet)
    refute is_type_0?(packet)
    refute is_type_1?(packet)

    {parsed_packet, _} = parse_packet(packet)

    assert parsed_packet == %{
             id: 1,
             type_specific_field: 8190,
             payload: 255
           }
  end

  test "type 0 variant" do
    type_0_packet = <<0::2, 14::4, 1022::10, 0xFFFF>>

    assert is_packet?(type_0_packet)
    assert is_type_0?(type_0_packet)
    refute is_type_1?(type_0_packet)

    {parsed_packet, _} = parse_type_0(type_0_packet)

    assert parsed_packet == %{
             id: 0,
             first_field: 14,
             second_field: 1022,
             payload: 255
           }
  end

  test "type 1 variant" do
    type_1_packet = <<3::2, 510::9, 30::5, 0xFFFF>>

    assert is_packet?(type_1_packet)
    refute is_type_0?(type_1_packet)
    assert is_type_1?(type_1_packet)

    {parsed_packet, _} = parse_type_1(type_1_packet)

    assert parsed_packet == %{
             id: 3,
             different_first_field: 510,
             different_second_field: 30,
             payload: 255
           }
  end
end
