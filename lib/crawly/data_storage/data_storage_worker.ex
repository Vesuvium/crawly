defmodule Crawly.DataStorage.Worker do
  alias Crawly.DataStorage.Worker
  require Logger

  use GenServer

  defstruct fd: nil, stored_items: 0

  def start_link(spider_name: spider_name) do
    GenServer.start_link(__MODULE__, spider_name: spider_name)
  end

  def stats(pid), do: GenServer.call(pid, :stats)

  def store(pid, item) do
    Logger.info("Storing item: #{inspect(pid)}/#{inspect(item)}")
    GenServer.cast(pid, {:store, item})
  end

  def init(spider_name: spider_name) do
    base_path = Application.get_env(:crawly, :base_store_path, "/tmp/")

    {:ok, fd} =
      File.open("#{base_path}#{inspect(spider_name)}.json", [
        :binary,
        :write,
        :delayed_write
      ])

    {:ok, %Worker{fd: fd}}
  end

  def handle_cast({:store, item}, state) do
    pipelines = Application.get_env(:crawly, :pipelines, [])

    state =
      case Crawly.Utils.pipe(pipelines, item, state) do
        {false, new_state} ->
          new_state

        {new_item, new_state} ->
          IO.write(state.fd, Poison.encode!(new_item))

          %Worker{new_state | stored_items: state.stored_items + 1}
      end

    {:noreply, state}
  end

  def handle_call(:stats, _from, state) do
    {:reply, state.stored_items, state}
  end
end