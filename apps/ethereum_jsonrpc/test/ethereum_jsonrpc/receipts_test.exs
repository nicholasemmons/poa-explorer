defmodule EthereumJSONRPC.ReceiptsTest do
  use ExUnit.Case, async: true

  alias EthereumJSONRPC.Receipts

  setup do
    %{
      json_rpc_named_arguments: [
        transport: EthereumJSONRPC.HTTP,
        transport_options: [
          http: EthereumJSONRPC.HTTP.HTTPoison,
          url: "https://sokol.poa.network",
          http_options: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :ethereum_jsonrpc]]
        ]
      ]
    }
  end

  doctest Receipts

  describe "fetch/2" do
    test "with receipts and logs", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      assert {:ok,
              %{
                logs: [
                  %{
                    address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
                    data: "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
                    first_topic: "0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22",
                    fourth_topic: nil,
                    index: 0,
                    second_topic: nil,
                    third_topic: nil,
                    transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
                    type: "mined"
                  }
                ],
                receipts: [
                  %{
                    cumulative_gas_used: 50450,
                    gas_used: 50450,
                    status: :ok,
                    transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
                    transaction_index: 0
                  }
                ]
              }} =
               Receipts.fetch(
                 [
                   "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"
                 ],
                 json_rpc_named_arguments
               )
    end
  end
end
