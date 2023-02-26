defmodule Mcex.Adapter.KvPostgresCache do
  use Agent
  require Logger

  @behaviour Mc.Behaviour.KvAdapter

  def start_link(opts \\ []) do
    cache = Keyword.fetch!(opts, :cache)
    db_table = Keyword.fetch!(opts, :db_table)
    Agent.start_link(fn -> %{cache: cache, db_table: db_table} end, name: __MODULE__)
  end

  def get_cache do
    {:ok,
      Map.keys(state().cache)
      |> Enum.join("\n")
    }
  end

  @impl true
  def get(db_pid, key) do
    if Map.has_key?(state().cache, key) do
      {:ok, Map.get(state().cache, key)}
    else
      Logger.info("===== CACHE MISS: #{key}")

      case db_get(db_pid, key) do
        {:ok, value} ->
          Agent.update(__MODULE__, fn state -> update_cache(state, key, value) end)
          {:ok, value}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @impl true
  def set(db_pid, key, value) do
    upsert = "ON CONFLICT(key) DO UPDATE SET key = $1, value = $2"
    Postgrex.query(db_pid, "INSERT INTO #{state().db_table} (key, value) VALUES ($1, $2) #{upsert}", [key, value])
    Agent.update(__MODULE__, fn state -> update_cache(state, key, value) end)
    {:ok, value}
  end

  @impl true
  def findk(db_pid, regex_str) do
    tupleize_regex_query(db_pid, ["key", regex_str])
  end

  @impl true
  def findv(db_pid, regex_str) do
    tupleize_regex_query(db_pid, ["value", regex_str])
  end

  defp tupleize_regex_query(db_pid, vars) do
    case Postgrex.query(db_pid, "SELECT * FROM #{state().db_table} WHERE $1 ~ $2", vars) do
      {:ok, %Postgrex.Result{num_rows: row_count, rows: rows_list}} when row_count > 0 ->
        tupleize_rows_list(rows_list)

      result ->
        tupleize_result(result)
    end
  end

  defp tupleize_rows_list(rows_list) do
    {:ok,
      rows_list
      |> Enum.map(fn [key, _value] -> key end)
      |> Enum.join("\n")
    }
  end

  defp db_get(db_pid, key) do
    case Postgrex.query(db_pid, "SELECT * FROM #{state().db_table} WHERE key = $1", [key]) do
      {:ok, %Postgrex.Result{num_rows: 1, rows: [[_key, value]]}} ->
        {:ok, value}

      result ->
        tupleize_result(result)
    end
  end

  defp tupleize_result(result) do
    case result do
      {:ok, %Postgrex.Result{num_rows: 0}} ->
        {:ok, ""}

      {:error, %Postgrex.Error{postgres: %{message: reason}}} ->
        {:error, reason}

      error ->
        {:error, inspect(error)}
    end
  end

  defp state do
    Agent.get(__MODULE__, &(&1))
  end

  defp update_cache(%{cache: cache} = state, key, new_value) do
    {_, new_cache} = Map.get_and_update(cache, key, fn current_value -> {current_value, new_value} end)
    Map.put(state, :cache, new_cache)
  end
end
