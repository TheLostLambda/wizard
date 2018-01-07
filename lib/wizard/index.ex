require Logger

defmodule Wizard.Index do
  use GenServer

  # Eventually load synced directories from a config file.
  @synced_dirs ["/home/ttl/Documents"]

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

  def handle_call(:get_map, _from, state) do
    {:reply, state, state}
  end

  def handle_info(stuff, state) do
    stuff |> Kernel.inspect |> Logger.info
    {:noreply, state}
  end

  ## Internal Functions (make these all defp)

  defp crawl_and_index(dir, dex) do
    Enum.reduce(File.ls!(dir), dex, fn(file, map) ->
      path = Path.join(dir, file)
      if File.dir?(path) and not symlink?(path) do
        Map.merge(map, crawl_and_index(path, %{}))
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

end
