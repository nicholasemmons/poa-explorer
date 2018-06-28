defmodule EthereumJSONRPCTest do
  use ExUnit.Case, async: true

  setup do
    %{
      json_rpc_named_arguments: [
        transport: EthereumJSONRPC.HTTP,
        transport_options: [
          http: EthereumJSONRPC.HTTP.HTTPoison,
          url: "https://sokol-trace.poa.network",
          http_options: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :ethereum_jsonrpc]]
        ]
      ]
    }
  end

  doctest EthereumJSONRPC

  describe "fetch_balances/1" do
    test "with all valid hash_data returns {:ok, addresses_params}", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      assert EthereumJSONRPC.fetch_balances(
               [%{block_quantity: "0x1", hash_data: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"}],
               json_rpc_named_arguments
             ) ==
               {:ok,
                [
                  %{
                    fetched_balance: 1,
                    fetched_balance_block_number: 1,
                    hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
                  }
                ]}
    end

    test "with all invalid hash_data returns {:error, reasons}", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      assert EthereumJSONRPC.fetch_balances([%{block_quantity: "0x1", hash_data: "0x0"}], json_rpc_named_arguments) ==
               {:error,
                [
                  %{
                    "blockNumber" => "0x1",
                    "code" => -32602,
                    "hash" => "0x0",
                    "message" =>
                      "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."
                  }
                ]}
    end

    test "with a mix of valid and invalid hash_data returns {:error, reasons}", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
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
                    "blockNumber" => "0x2",
                    "code" => -32602,
                    "hash" => "0x3",
                    "message" =>
                      "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."
                  },
                  %{
                    "blockNumber" => "0x4",
                    "code" => -32602,
                    "hash" => "0x5",
                    "message" =>
                      "Invalid params: invalid length 1, expected a 0x-prefixed, padded, hex-encoded hash with length 40."
                  }
                ]}
    end
  end

  describe "fetch_block_number_by_tag" do
    test "with earliest", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      assert {:ok, 0} = EthereumJSONRPC.fetch_block_number_by_tag("earliest", json_rpc_named_arguments)
    end

    test "with latest", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      assert {:ok, number} = EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments)
      assert number > 0
    end

    test "with pending", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      assert {:ok, number} = EthereumJSONRPC.fetch_block_number_by_tag("pending", json_rpc_named_arguments)
      assert number > 0
    end
  end

  describe "json_rpc/2" do
    # regression test for https://github.com/poanetwork/poa-explorer/issues/254
    #
    # this test triggered a DoS with CloudFlare reporting 502 Bad Gateway
    # (see https://github.com/poanetwork/poa-explorer/issues/340), so it can't be run against the real Sokol chain and
    # must use `mox` to fake it.
    test "transparently splits batch payloads that would trigger a 413 Request Entity Too Large", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block_numbers = 0..13000

      payload =
        block_numbers
        |> Stream.with_index()
        |> Enum.map(&get_block_by_number_request/1)

      assert_payload_too_large(payload, json_rpc_named_arguments)

      assert {:ok, responses} = EthereumJSONRPC.json_rpc(payload, json_rpc_named_arguments)
      assert Enum.count(responses) == Enum.count(block_numbers)

      block_number_set = MapSet.new(block_numbers)

      response_block_number_set =
        Enum.into(responses, MapSet.new(), fn %{"result" => %{"number" => quantity}} ->
          EthereumJSONRPC.quantity_to_integer(quantity)
        end)

      assert MapSet.equal?(response_block_number_set, block_number_set)
    end
  end

  defp assert_payload_too_large(payload, json_rpc_named_arguments) do
    assert Keyword.fetch!(json_rpc_named_arguments, :transport) == EthereumJSONRPC.HTTP

    transport_options = Keyword.fetch!(json_rpc_named_arguments, :transport_options)

    http = Keyword.fetch!(transport_options, :http)
    url = Keyword.fetch!(transport_options, :url)
    json = Jason.encode_to_iodata!(payload)
    http_options = Keyword.fetch!(transport_options, :http_options)

    assert {:ok, %{body: body, status_code: 413}} = http.json_rpc(url, json, http_options)
    assert body =~ "413 Request Entity Too Large"
  end

  defp get_block_by_number_request({block_number, id}) do
    %{
      "id" => id,
      "jsonrpc" => "2.0",
      "method" => "eth_getBlockByNumber",
      "params" => [EthereumJSONRPC.integer_to_quantity(block_number), true]
    }
  end
end
