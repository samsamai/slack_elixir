defmodule Slack.ChannelServer do
  @moduledoc false
  use GenServer

  require Logger

  # By default the bot will join all conversations that it has access to.
  # For type options, see: [api](https://api.slack.com/methods/users.conversations).
  # Note, these require the following scopes:
  #   `channels:read`, `groups:read`, `im:read`, `mpim:read`
  @default_channel_types "public_channel,private_channel,mpim,im"

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  def start_link({bot, config}) do
    Logger.info("@@@ [Slack.ChannelServer] starting for #{bot.module}...")

    # This should be a comma-separated string.
    channel_types =
      case Keyword.get(config, :types) do
        nil -> @default_channel_types
        types when is_binary(types) -> types
        types when is_list(types) -> Enum.join(types, ",")
      end

    # channels = fetch_channels(bot.token, channel_types)
    channels = ["C010FUBTF1C"]

    GenServer.start_link(__MODULE__, {bot, channels}, name: via_tuple(bot))
  end

  def join(bot, channel) do
    GenServer.cast(via_tuple(bot), {:join, channel})
  end

  def part(bot, channel) do
    GenServer.cast(via_tuple(bot), {:part, channel})
  end

  # ----------------------------------------------------------------------------
  # GenServer Callbacks
  # ----------------------------------------------------------------------------

  @impl true
  def init({bot, channels}) do
    state = %{
      bot: bot,
      channels: channels
    }

    {:ok, state, {:continue, :join}}
  end

  @impl true
  def handle_continue(:join, state) do
    IO.inspect("@@ handle_continue")

    Enum.each(state.channels, &join(state.bot, &1))
    {:noreply, state}
  end

  @impl true
  def handle_cast({:join, channel}, state) do
    IO.inspect("@@ handle_cast join")

    Logger.info("[Slack.ChannelServer] #{state.bot.module} joining #{channel}...")
    {:ok, _} = Slack.MessageServer.start_supervised(state.bot, channel)
    {:noreply, Map.update!(state, :channels, &[channel | &1])}
  end

  def handle_cast({:part, channel}, state) do
    Logger.info("[Slack.ChannelServer] #{state.bot.module} leaving #{channel}...")
    :ok = Slack.MessageServer.stop(state.bot, channel)
    {:noreply, Map.update!(state, :channels, &List.delete(&1, channel))}
  end

  defp via_tuple(%Slack.Bot{module: bot}) do
    IO.inspect("@@ via_tuple")

    {:via, Registry, {Slack.ChannelServerRegistry, bot}}
  end

  defp fetch_channels(token, types) when is_binary(types) do
    "users.conversations"
    |> Slack.API.stream(token, "channels", types: types)
    |> Enum.map(& &1["id"])
  end
end
