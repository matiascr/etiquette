defmodule LengthTest do
  use ExUnit.Case, async: true
  use Etiquette.Spec

  packet "Pack", id: :pack do
    field "Type", 2
    field "Length", 2, id: :length
    field "Data", (..), length_by: :length
  end

  # Tests

  test "parse pack" do
    pack = <<0::size(2), 3::size(2), "data", 0::size(2), 1::size(2), "data">>

    {parsed_pack, rest} = parse_pack(pack)

    assert parsed_pack == %{
             type: 0,
             length: 3,
             data: :binary.decode_unsigned("data")
           }

    assert rest == <<0b00::size(2), 0b01::size(2), "data">>

    {parsed_rest, rest} = parse_pack(rest)

    assert parsed_rest == %{
             type: 0,
             length: 1,
             data: :binary.decode_unsigned("da")
           }

    assert rest == "ta"
  end
end
