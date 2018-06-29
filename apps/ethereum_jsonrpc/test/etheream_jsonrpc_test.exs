defmodule EthereumJSONRPCTest do
  use ExUnit.Case, async: true
  use EthereumJSONRPC.Case

  import Mox

  setup :verify_on_exit!

  doctest EthereumJSONRPC

  describe "fetch_balances/1" do
    test "with all valid hash_data returns {:ok, addresses_params}", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      expected_fetched_balance_block_number = 1
      expected_fetched_balance = 1

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok, [%{id: 0, result: EthereumJSONRPC.integer_to_quantity(expected_fetched_balance)}]}
        end)
      end

      hash = "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"

      assert EthereumJSONRPC.fetch_balances(
               [
                 %{
                   block_quantity: EthereumJSONRPC.integer_to_quantity(expected_fetched_balance_block_number),
                   hash_data: hash
                 }
               ],
               json_rpc_named_arguments
             ) ==
               {:ok,
                [
                  %{
                    fetched_balance: expected_fetched_balance,
                    fetched_balance_block_number: expected_fetched_balance_block_number,
                    hash: hash
                  }
                ]}
    end

    test "with all invalid hash_data returns {:error, reasons}", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               id: 0,
               error: %{
                 code: -32602,
                 message:
                   "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."
               }
             }
           ]}
        end)
      end

      assert EthereumJSONRPC.fetch_balances([%{block_quantity: "0x1", hash_data: "0x0"}], json_rpc_named_arguments) ==
               {:error,
                [
                  %{
                    code: -32602,
                    data: %{
                      "blockNumber" => "0x1",
                      "hash" => "0x0"
                    },
                    message:
                      "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."
                  }
                ]}
    end

    test "with a mix of valid and invalid hash_data returns {:error, reasons}", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {
            :ok,
            [
              %{
                id: 0,
                result: "0x0"
              },
              %{
                id: 1,
                result: "0x1"
              },
              %{
                id: 2,
                error: %{
                  code: -32602,
                  message:
                    "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."
                }
              },
              %{
                id: 3,
                result: "0x3"
              },
              %{
                id: 4,
                error: %{
                  code: -32602,
                  message:
                    "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."
                }
              }
            ]
          }
        end)
      end

      assert EthereumJSONRPC.fetch_balances(
               [
                 # start with :ok
                 %{
                   block_quantity: "0x1",
                   hash_data: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
                 },
                 # :ok, :ok clause
                 %{
                   block_quantity: "0x34",
                   hash_data: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
                 },
                 # :ok, :error clause
                 %{
                   block_quantity: "0x2",
                   hash_data: "0x3"
                 },
                 # :error, :ok clause
                 %{
                   block_quantity: "0x35",
                   hash_data: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
                 },
                 # :error, :error clause
                 %{
                   block_quantity: "0x4",
                   hash_data: "0x5"
                 }
               ],
               json_rpc_named_arguments
             ) ==
               {:error,
                [
                  %{
                    code: -32602,
                    data: %{
                      "blockNumber" => "0x2",
                      "hash" => "0x3"
                    },
                    message:
                      "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."
                  },
                  %{
                    code: -32602,
                    data: %{
                      "blockNumber" => "0x4",
                      "hash" => "0x5"
                    },
                    message:
                      "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."
                  }
                ]}
    end
  end

  describe "fetch_block_number_by_tag" do
    test "with earliest", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok, %{"number" => "0x0"}}
        end)
      end

      assert {:ok, 0} = EthereumJSONRPC.fetch_block_number_by_tag("earliest", json_rpc_named_arguments)
    end

    test "with latest", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok, %{"number" => "0x1"}}
        end)
      end

      assert {:ok, number} = EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments)
      assert number > 0
    end

    test "with pending", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok, %{"number" => "0x2"}}
        end)
      end

      assert {:ok, number} = EthereumJSONRPC.fetch_block_number_by_tag("pending", json_rpc_named_arguments)
      assert number > 0
    end
  end
end
