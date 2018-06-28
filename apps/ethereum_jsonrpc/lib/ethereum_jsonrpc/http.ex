defmodule EthereumJSONRPC.HTTP do
  @moduledoc """
  JSONRPC over HTTP
  """

  alias EthereumJSONRPC.Transport

  require Logger

  @behaviour Transport

  @callback json_rpc(url :: String.t(), json :: iodata(), options :: term()) ::
              {:ok, %{body: body :: String.t(), status_code: status_code :: pos_integer()}}
              | {:error, reason :: term}

  @impl Transport

  def json_rpc(request, options) when is_map(request) do
    json = encode_json(request)
    http = Keyword.fetch!(options, :http)
    url = Keyword.fetch!(options, :url)
    http_options = Keyword.fetch!(options, :http_options)

    with {:ok, %{body: body, status_code: code}} <- http.json_rpc(url, json, http_options) do
      body
      |> decode_json(code, json, url)
      |> handle_response(code)
    end
  end

  def json_rpc(batch_request, options) when is_list(batch_request) do
    chunked_json_rpc([batch_request], options, [])
  end

  defp chunked_json_rpc([], _options, decoded_response_bodies) when is_list(decoded_response_bodies) do
    list =
      decoded_response_bodies
      |> Enum.reverse()
      |> List.flatten()

    {:ok, list}
  end

  defp chunked_json_rpc([batch | tail] = chunks, options, decoded_response_bodies)
       when is_list(batch) and is_list(tail) and is_list(decoded_response_bodies) do
    http = Keyword.fetch!(options, :http)
    url = Keyword.fetch!(options, :url)
    http_options = Keyword.fetch!(options, :http_options)

    json = encode_json(batch)

    with {:ok, response} <- http.json_rpc(url, json, http_options) do
      case response do
        %{status_code: 413} ->
          rechunk_json_rpc(chunks, options, response, decoded_response_bodies)

        %{body: body, status_code: status_code} ->
          decoded_body = decode_json(body, status_code, json, url)
          chunked_json_rpc(tail, options, [decoded_body | decoded_response_bodies])
      end
    end
  end

  defp rechunk_json_rpc([batch | tail], options, response, decoded_response_bodies) do
    case length(batch) do
      # it can't be made any smaller
      1 ->
        Logger.error(fn ->
          "413 Request Entity Too Large returned from single request batch.  Cannot shrink batch further."
        end)

        {:error, response}

      batch_size ->
        split_size = div(batch_size, 2)
        {first_chunk, second_chunk} = Enum.split(batch, split_size)
        new_chunks = [first_chunk, second_chunk | tail]
        chunked_json_rpc(new_chunks, options, decoded_response_bodies)
    end
  end

  defp encode_json(data), do: Jason.encode_to_iodata!(data)

  defp decode_json(response_body, response_status_code, request_body, request_url) do
    Jason.decode!(response_body)
  rescue
    Jason.DecodeError ->
      Logger.error(fn ->
        """
        failed to decode json payload:

            request url: #{inspect(request_url)}

            request body: #{inspect(request_body)}

            response status code: #{inspect(response_status_code)}

            response body: #{inspect(response_body)}
        """
      end)

      raise("bad jason")
  end

  defp handle_response(resp, 200) do
    case resp do
      %{"error" => error} -> {:error, error}
      %{"result" => result} -> {:ok, result}
    end
  end

  defp handle_response(resp, _status) do
    {:error, resp}
  end
end
