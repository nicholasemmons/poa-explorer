# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :indexer,
  block_rate: 5_000,
  debug_logs: !!System.get_env("DEBUG_INDEXER"),
  json_rpc_named_arguments: [
    transport: EthereumJSONRPC.HTTP,
    transport_options: [
      http: EthereumJSONRPC.HTTP.HTTPoison,
      url: "https://sokol-trace.poa.network",
      http_options: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :ethereum_jsonrpc]]
    ]
  ]

config :indexer, ecto_repos: [Explorer.Repo]
