defmodule Indexer.AddressBalanceFetcherTest do
  # MUST be `async: false` so that {:shared, pid} is set for connection to allow AddressBalanceFetcher's self-send to have
  # connection allowed immediately.
  use Explorer.DataCase, async: false

  alias Explorer.Chain.{Address, Hash, Wei}
  alias Indexer.{AddressBalanceFetcher, AddressBalanceFetcherCase}

  @block_number 2_932_838
  @hash %Explorer.Chain.Hash{
    byte_count: 20,
    bytes: <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211, 165, 101, 32, 167, 106, 179, 223, 65, 91>>
  }

  setup do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

    %{
      json_rpc_named_arguments: [
        transport: EthereumJSONRPC.HTTP,
        transport_options: [
          http: EthereumJSONRPC.HTTP.HTTPoison,
          # Sokol only supports historical address balances on trace nodes, not those behind `https://sokol.poa.network`.
          url: "https://sokol-trace.poa.network",
          http_options: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :ethereum_jsonrpc]]
        ]
      ]
    }
  end

  describe "init/1" do
    test "fetches unfetched Block miner balance", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      {:ok, miner_hash} = Hash.Truncated.cast("0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca")
      miner = insert(:address, hash: miner_hash)
      block = insert(:block, miner: miner, number: 34)

      assert miner.fetched_balance == nil
      assert miner.fetched_balance_block_number == nil

      AddressBalanceFetcherCase.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      fetched_address =
        wait(fn ->
          Repo.one!(
            from(address in Address, where: address.hash == ^miner_hash and not is_nil(address.fetched_balance))
          )
        end)

      assert fetched_address.fetched_balance == %Wei{value: Decimal.new(252_460_834_000_000_000_000_000_000)}
      assert fetched_address.fetched_balance_block_number == block.number
    end

    test "fetches unfetched addresses when less than max batch size", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      {:ok, miner_hash} = Hash.Truncated.cast("0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca")
      miner = insert(:address, hash: miner_hash)
      block = insert(:block, miner: miner, number: 34)

      AddressBalanceFetcherCase.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments, max_batch_size: 2)

      fetched_address =
        wait(fn ->
          Repo.one!(
            from(address in Address, where: address.hash == ^miner_hash and not is_nil(address.fetched_balance))
          )
        end)

      assert fetched_address.fetched_balance == %Wei{value: Decimal.new(252_460_834_000_000_000_000_000_000)}
      assert fetched_address.fetched_balance_block_number == block.number
    end
  end

  describe "async_fetch_balances/1" do
    test "fetches balances for address_hashes", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      AddressBalanceFetcherCase.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      assert :ok = AddressBalanceFetcher.async_fetch_balances([%{block_number: @block_number, hash: @hash}])

      address =
        wait(fn ->
          Repo.get!(Address, @hash)
        end)

      assert address.fetched_balance == %Wei{value: Decimal.new(1)}
      assert address.fetched_balance_block_number == @block_number
    end
  end

  describe "run/2" do
    test "duplicate address hashes the max block_quantity", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      hash_data = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"

      assert AddressBalanceFetcher.run(
               [%{block_quantity: "0x1", hash_data: hash_data}, %{block_quantity: "0x2", hash_data: hash_data}],
               0,
               json_rpc_named_arguments
             ) == :ok

      fetched_address = Repo.one!(from(address in Address, where: address.hash == ^hash_data))

      assert fetched_address.fetched_balance == %Explorer.Chain.Wei{
               value: Decimal.new(252_460_802_000_000_000_000_000_000)
             }

      assert fetched_address.fetched_balance_block_number == 2
    end

    test "duplicate address hashes only retry max block_quantity", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      hash_data = "0x000000000000000000000000000000000"

      assert AddressBalanceFetcher.run(
               [%{block_quantity: "0x1", hash_data: hash_data}, %{block_quantity: "0x2", hash_data: hash_data}],
               0,
               json_rpc_named_arguments
             ) ==
               {:retry,
                [
                  %{
                    block_quantity: "0x2",
                    hash_data: "0x000000000000000000000000000000000"
                  }
                ]}
    end
  end

  defp wait(producer) do
    producer.()
  rescue
    Ecto.NoResultsError ->
      Process.sleep(100)
      wait(producer)
  end
end
