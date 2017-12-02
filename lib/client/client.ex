defmodule Tweeter.Client do
    use GenServer
  
    def start_client(user_name, password) do
      GenServer.start_link(__MODULE__, {user_name}, name: String.to_atom(user_name))
      GenServer.cast(String.to_atom("tweeter_engine"), {:login, user_name, password})
    end

    def query_for_hashtags(user_name, hashtag) do
      result = GenServer.call(String.to_atom("tweeter_engine"), {:get_tweets_hashtag, user_name, hashtag}, :infinity)
      IO.inspect "Query for hashtag ::: #{user_name}"
      IO.inspect result
    end

    def query_for_usermentions(user_name) do
      result = GenServer.call(String.to_atom("tweeter_engine"), {:query_user_mentions, user_name}, :infinity)
      IO.inspect "Query for user mentions ::: @#{user_name}"
      IO.inspect result
    end

    def send_tweets(username, active_users, list_of_static_hashtags, delay) do
      u_men_toss = Enum.random([1, -1])
      hash_toss = Enum.random([1, -1])

      # Add user mentions
      user_mention = if (u_men_toss == 1) do
        user_id = Enum.random(active_users)
        " @user" <> to_string(user_id)
      else
        ""
      end
      # Add hash tags
      hashtag = if (hash_toss == 1) do
        " " <> Enum.random(list_of_static_hashtags)
      else
        ""
      end

      tweet = ((:crypto.strong_rand_bytes(5)|> Base.encode16) |> (binary_part(0, 5))) <> " " <> ((:crypto.strong_rand_bytes(6)|> Base.encode16 |> binary_part(0, 6))) <> " " <> ((:crypto.strong_rand_bytes(7)|> Base.encode16 |> binary_part(0, 7)))
      tweet = tweet <> user_mention <> hashtag
      GenServer.cast(String.to_atom("tweeter_engine"), {:tweet, username, tweet})
      Process.sleep(delay)
      send_tweets(username, active_users, list_of_static_hashtags, delay)
    end

    def re_tweets(username) do    
      seen_tweets = GenServer.call(String.to_atom("tweeter_engine"), {:query_user_tweets, username}, :infinity)
      last_searched_htag = GenServer.call(String.to_atom("tweeter_engine"), {:get_recent_hash_tag, username}, :infinity)

      seen_tweets = if last_searched_htag != {} do
        last_searched_htag = elem(last_searched_htag, 1)
        seen_tweets ++ GenServer.call(String.to_atom("tweeter_engine"), {:get_tweets_hashtag, username, last_searched_htag}, :infinity)
      else 
        seen_tweets
      end

      if seen_tweets != [] and seen_tweets != nil do
        rand_seen_tweet = Enum.random(seen_tweets)
        GenServer.cast(String.to_atom("tweeter_engine"), {:retweet, username, elem(rand_seen_tweet, 1), elem(rand_seen_tweet, 0)})
        retweet = elem(rand_seen_tweet, 1)
        from_user = elem(rand_seen_tweet, 0)
        IO.inspect "Retweet::: #{from_user} ::: #{username} ::: #{retweet}"
      end
    end

    def stop_client(user_name) do
      GenServer.cast(String.to_atom("tweeter_engine"), {:logout, user_name})
      GenServer.cast(String.to_atom(user_name), :stop)
    end

    def handle_cast({:live_tweets, user_name, tweet}, state) do
      {client_name} = state
      IO.inspect "#{client_name} ::: #{user_name} ::: #{tweet}"
      {:noreply, state}
    end

    def handle_cast(:stop, status) do
      {:stop, :normal, status}
    end
end