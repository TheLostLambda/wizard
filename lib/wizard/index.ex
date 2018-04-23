require Logger

defmodule Wizard.Index do
  use GenServer

  # Eventually load synced directories from a config file.
  @synced_dirs ["/home/ttl/Downloads"]

  ## Client API

  @doc """
  Starts the index as a linked GenServer process.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :rebuild_and_watch, opts)
  end

  @doc """
  Fetches the index and returns a map.
  """
  def get_map(pid) do
    GenServer.call(pid, :get_map)
  end

  @doc """
  Compares this index to another and creates a diff
  """
  def gen_diff(pid, map) do
    GenServer.call(pid, {:gen_diff, map})
  end

  ## Server Callbacks

  def init(:rebuild_and_watch) do
    # I should consider monitoring this.
    {:ok, pid} = FileSystem.start_link(dirs: @synced_dirs)
    FileSystem.subscribe(pid)
    dex = Enum.reduce(@synced_dirs, %{}, &crawl_and_index/2)
    Logger.info "Finished Indexing: #{@synced_dirs}"
    {:ok, dex}
  end

  def handle_call(:get_map, _from, dex) do
    {:reply, dex, dex}
  end

  # This diff is currently only one way. Make it two way by starting with the local
  # index as opposed to an empty map. It currently misses files that are added.
  def handle_call({:gen_diff, remote}, _from, local) do
    diff = Enum.reduce(remote, %{}, fn(entry, diff) ->
      {file, time} = entry
      if Map.has_key?(local, file) do
        comp = compare(Map.get(local, file), time)
        if comp != 0 do
          Map.put(diff, file, comp)
        else
          diff
        end
      else
        Map.put(diff, file, 0)
      end
    end)
    {:reply, diff, local}
  end

  def handle_info({:file_event, _pid, {path, actions}}, dex) do
    new_dex = cond do
      contains_any?(actions, [:modified, :created]) ->
        dex |> Map.merge(index(path)) |> Map.merge(index(Path.dirname(path)))
      contains_any?(actions, [:deleted]) ->
        dex |> clean_delete(path) |> Map.merge(index(Path.dirname(path)))
      true ->
        dex
    end
    {:noreply, new_dex}
  end

  ## Internal Functions (make these all defp)

  # This is overzealous. Make sure it only deletes paths starting from root and
  # that are within the synced directories. This also applies to indexing.
  defp clean_delete(dex, key) do
    old_keys = Map.keys(dex) |> Enum.filter(&(&1 =~ key))
    Map.drop(dex, old_keys)
  end

  defp crawl_and_index(dir, dex) do
    Enum.reduce(File.ls!(dir), dex, fn(file, map) ->
      path = Path.join(dir, file)
      if File.dir?(path) and not symlink?(path) do
        map |> Map.merge(index(path)) |> Map.merge(crawl_and_index(path, %{}))
      else
        Map.merge(map, index(path))
      end
    end)
  end

  defp index(file) do
    case File.stat(file, time: :posix) do
      {:ok, stat} -> %{file => stat.mtime}
      {:error, reason} ->
        Logger.info "Failed to index #{file}: #{reason}"
        %{}
    end
  end

  defp symlink?(file) do
    File.lstat!(file).type == :symlink
  end

  defp contains_any?(lst, test_lst) do
    Enum.any?(test_lst, fn v -> Enum.member?(lst, v) end)
  end

  defp compare(a, b) do
    cond do
      a < b -> -1
      a > b -> 1
      true -> 0
    end
  end
end
