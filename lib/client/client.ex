defmodule Tweeter.Client do
    use GenServer
    @name :tweeter_engine
  
    def start_client(user_name, password) do
      GenServer.start_link(__MODULE__, {}, name: String.to_atom(user_name))
      message = GenServer.call(@name, {:login, user_name, password})
    end

    def query_for_hashtags(hashtag) do
      result = GenServer.call(@name, {:get_tweets_hashtag, hashtag})
      IO.inspect result
    end

    def query_for_usermentions(user_name) do
      result = GenServer.call(@name, {:query_user_mentions, user_name})
      IO.inspect result
    end

    def send_tweets(username, tweet, delay) do
      GenServer.cast(@name, {:tweet, username, tweet})
      Process.sleep(delay)
      send_tweets(username, tweet, delay)
    end

    def stop_client(user_name) do
      GenServer.call(String.to_atom(user_name), {:stop})
    end

    def handle_cast({:live_tweets, user_name, tweet}, state) do
    IO.inspect "#{user_name} ::: #{tweet}"
    {:noreply, state}
    end

    def handle_call(:stop, _from, status) do
      {:stop, :normal, status}
    end
end