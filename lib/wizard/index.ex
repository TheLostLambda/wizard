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

end
