defmodule EthereumJSONRPC.ReceiptsTest do
  use ExUnit.Case, async: true
  use EthereumJSONRPC.Case

  import EthereumJSONRPC, only: [integer_to_quantity: 1]
  import Mox

  alias EthereumJSONRPC.Receipts

  setup :verify_on_exit!

  doctest Receipts

  describe "fetch/2" do
    test "with receipts and logs", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      cumulative_gas_used = 50450
      gas_used = 50450
      address_hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      block_number = 37
      data = "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef"
      index = 0
      first_topic = "0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22"
      type = "mined"
      transaction_hash = "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"
      transaction_index = 0

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               id: 0,
               result: %{
                 "cumulativeGasUsed" => integer_to_quantity(cumulative_gas_used),
                 "gasUsed" => integer_to_quantity(gas_used),
                 "logs" => [
                   %{
                     "address" => address_hash,
                     "blockNumber" => integer_to_quantity(block_number),
                     "data" => data,
                     "logIndex" => integer_to_quantity(index),
                     "topics" => [first_topic],
                     "transactionHash" => transaction_hash,
                     "type" => type
                   }
                 ],
                 "status" => "0x1",
                 "transactionHash" => transaction_hash,
                 "transactionIndex" => integer_to_quantity(transaction_index)
               }
             }
           ]}
        end)
      end

      assert Receipts.fetch(
               [
                 transaction_hash
               ],
               json_rpc_named_arguments
             ) ==
               {:ok,
                %{
                  logs: [
                    %{
                      address_hash: address_hash,
                      block_number: block_number,
                      data: data,
                      first_topic: first_topic,
                      fourth_topic: nil,
                      index: index,
                      second_topic: nil,
                      third_topic: nil,
                      transaction_hash: transaction_hash,
                      type: type
                    }
                  ],
                  receipts: [
                    %{
                      cumulative_gas_used: cumulative_gas_used,
                      gas_used: gas_used,
                      status: :ok,
                      transaction_hash: transaction_hash,
                      transaction_index: transaction_index
                    }
                  ]
                }}
    end
  end
end
