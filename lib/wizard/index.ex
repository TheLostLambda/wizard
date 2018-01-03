defmodule Wizard.Index do
  use GenServer

  # Eventually load synced directories from a config file.
  @synced_dirs ["/home/ttl/"]

  ## Client API

  @doc """
  Starts the index as a linked GenServer process.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :rebuild_and_watch, opts)
  end

  ## Server Callbacks

  def init(:rebuild_and_watch) do
    # I should consider monitoring this.
    {:ok, pid} = FileSystem.start_link(dirs: @synced_dirs)
    FileSystem.subscribe(pid)
    rebuild_all(@synced_dirs)
  end

  ## Internal Functions

  defp rebuild_all(dirs) do
    # Map over dirs here, recursively recording all files and their modified dates.
    {:ok, %{}}
  end

end
