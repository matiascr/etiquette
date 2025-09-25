defmodule TestSpec do
  @moduledoc false

  # ============================================================================

  defmodule P do
    @moduledoc false
    use Etiquette.Spec

    packet "p" do
      field "x", 4
      field "y", 4, id: :y
      field "z", (..), length_by: :y
    end

    packet "x" do
      field "x", 1
    end
  end

  # ============================================================================

  defmodule Pack do
    @moduledoc false
    use Etiquette.Spec

    packet "Pack", id: :pack do
      field "Type", 2
      field "Data Length", 2, id: :length
      field "Data", (..), length_by: :length
    end
  end

  # ============================================================================

  defmodule Example.Spec do
    @moduledoc false
    use ExUnit.Case
    use Etiquette.Spec

    packet "Header Packet", id: :header_packet do
      field "Header Fixed", 1, fixed: 1, doc: "Whether the packet is a header."
      field "Packet Type", 2, doc: "The type of the payload. Can be any 0-3 integer."
      field "Type-Specific fields", (..), id: :type_specific_fields, doc: "The packet payload."
    end

    packet "Hello Packet", of: :header_packet do
      field "Packet Type", 2, fixed: 0b00
      field "Hello-specific payload", 8, part_of: :type_specific_fields
    end

    packet "Conversation Packet", of: :header_packet do
      field "Packet Type", 2, fixed: 0b01
      field "Conversation-specific payload", 8, part_of: :type_specific_fields
    end

    packet "Bye Packet", of: :header_packet do
      field "Packet Type", 2, fixed: 0b11
      field "Bye-specific payload", 8, part_of: :type_specific_fields
    end

    test "compile test" do
      exports = __MODULE__.module_info()[:exports]
      assert {:is_header_packet?, 1} in exports
      assert {:is_hello_packet?, 1} in exports
      assert {:is_conversation_packet?, 1} in exports
      assert {:is_bye_packet?, 1} in exports
      assert {:parse_header_packet, 1} in exports
      assert {:parse_hello_packet, 1} in exports
      assert {:parse_conversation_packet, 1} in exports
      assert {:parse_bye_packet, 1} in exports
      assert {:build_header_packet, 2} in exports
      assert {:build_hello_packet, 1} in exports
      assert {:build_conversation_packet, 1} in exports
      assert {:build_bye_packet, 1} in exports
    end
  end

  # ============================================================================

  defmodule Spec do
    @moduledoc false
    use ExUnit.Case
    use Etiquette.Spec

    packet "Header", id: :header do
      field "Type", 2
      field "Data", (..)
    end

    packet "Type 0", id: :type_0, of: :header do
      field "Type", 2, fixed: 0b00
      field "Data", (..)
    end

    packet "Type 1", id: :type_1, of: :header do
      field "Type", 2, fixed: 0b01
      field "Data", (..)
    end

    test "compile test" do
      exports = __MODULE__.module_info()[:exports]
      assert {:is_header?, 1} in exports
      assert {:parse_header, 1} in exports
      assert {:build_header, 2} in exports

      assert {:is_type_0?, 1} in exports
      assert {:parse_type_0, 1} in exports
      assert {:build_type_0, 1} in exports

      assert {:is_type_1?, 1} in exports
      assert {:parse_type_1, 1} in exports
      assert {:build_type_1, 1} in exports
    end
  end
end
