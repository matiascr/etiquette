defmodule EtiquetteTest do
  use ExUnit.Case, async: true
  use Etiquette.Spec

  doctest Etiquette

  packet "Header Packet", id: :header_packet do
    field("Header Fixed", 1, fixed: 1, doc: "Whether the packet is a header.")
    field("Packet Type", 2, doc: "The type of the payload. Can be any 0-3 integer.")
    field("Type-Specific fields", .., doc: "The packet payload.")
  end

  packet "Hello Packet", id: :hello_packet, of: :header_packet do
    field("Packet Type", 2, fixed: 0b00, doc: "The type of the payload. Can be any 0-3 integer.")
    field("Hello-specific payload", .., doc: "Type specific payload")
  end

  packet "Conversation Packet", id: :conversation_packet, of: :header_packet do
    field("Packet Type", 2, fixed: 0b01, doc: "The type of the payload. Can be any 0-3 integer.")
    field("Conversation-specific payload", .., doc: "Type specific payload")
  end

  packet "Bye Packet", id: :bye_packet, of: :header_packet do
    field("Packet Type", 2, fixed: 0b11, doc: "The type of the payload. Can be any 0-3 integer.")
    field("Bye-specific payload", .., doc: "Type specific payload")
  end

  # Tests

  describe "validator function" do
    @header_bits <<1::1>>

    test "header packet spec" do
      assert is_header_packet?(<<@header_bits, "random bits"::bitstring>>)
    end

    test "hello packet spec" do
      hello_packet = <<@header_bits, 0b00::2>>
      assert is_hello_packet?(hello_packet)
      assert not is_conversation_packet?(hello_packet)
      assert not is_bye_packet?(hello_packet)
    end

    test "conversation packet spec" do
      conversation_packet = <<@header_bits, 0b01::2>>
      assert not is_hello_packet?(conversation_packet)
      assert is_conversation_packet?(conversation_packet)
      assert not is_bye_packet?(conversation_packet)
    end

    test "bye packet spec" do
      bye_packet = <<@header_bits, 0b11::2>>
      assert not is_hello_packet?(bye_packet)
      assert not is_conversation_packet?(bye_packet)
      assert is_bye_packet?(bye_packet)
    end

    test "undefined packet spec" do
      conversation_packet = <<@header_bits, 0b10::2>>
      assert not is_hello_packet?(conversation_packet)
      assert not is_conversation_packet?(conversation_packet)
      assert not is_bye_packet?(conversation_packet)
    end
  end
end
