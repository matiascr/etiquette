defmodule UDPSpecTest do
  @moduledoc false
  use ExUnit.Case
  use Etiquette.Spec

  packet "UDP Header Format", id: :udp_header do
    field "Source Port", 16, doc: "This field identifies the sender's port."
    field "Destination Port", 16, doc: "This field identifies the receiver's port and is required."
    field "Length", 16, id: :length, doc: "This field specifies the length in bytes of the UDP datagram."
    field "Checksum", 16, doc: "The checksum field may be used for error-checking of the header and data."
    field "Data", (..), length_by: :length, doc: "The payload of the UDP packet."
  end

  test "generated functions exist" do
    exports = __MODULE__.module_info()[:exports]
    assert {:build_udp_header, 5} in exports
    assert {:is_udp_header?, 1} in exports
    assert {:parse_udp_header, 1} in exports
  end
end
