defmodule Tweeter.Client do
  use GenServer

  def start_client(user_name, password, server_ip) do
    GenServer.start_link(__MODULE__, {user_name}, name: String.to_atom(user_name))
    
    GenServer.cast({String.to_atom("tweeter_engine"), String.to_atom("tweeter_engine@" <> to_string(server_ip))}, {:login, user_name, password})
    result = GenServer.call({String.to_atom("tweeter_engine"), String.to_atom("tweeter_engine@" <> to_string(server_ip))}, {:query_user_tweets, user_name}, :infinity)
    IO.inspect "Query for user tweets ::: #{user_name}"
    IO.inspect result
  end

  def query_for_hashtags(user_name, hashtag, server_ip) do
    result = GenServer.call({String.to_atom("tweeter_engine"), String.to_atom("tweeter_engine@" <> to_string(server_ip))}, {:get_tweets_hashtag, user_name, hashtag}, :infinity)
    IO.inspect "Query for hashtag ::: #{user_name}"
    IO.inspect result
  end

  def query_for_usermentions(user_name, server_ip) do
    result = GenServer.call({String.to_atom("tweeter_engine"), String.to_atom("tweeter_engine@" <> to_string(server_ip))}, {:query_user_mentions, user_name}, :infinity)
    IO.inspect "Query for user mentions ::: @#{user_name}"
    IO.inspect result
  end

  def send_tweets(username, active_users, list_of_static_hashtags, delay, client_ip, server_ip) do
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
    GenServer.cast({String.to_atom("tweeter_engine"), String.to_atom("tweeter_engine@" <> to_string(server_ip))}, {:tweet, username, tweet, client_ip})
    Process.sleep(delay)
    send_tweets(username, active_users, list_of_static_hashtags, delay, client_ip, server_ip)
  end

  def re_tweets(username, client_ip, server_ip) do 
    seen_tweets = GenServer.call({String.to_atom("tweeter_engine"), String.to_atom("tweeter_engine@" <> to_string(server_ip))}, {:query_user_tweets, username}, :infinity)
    seen_tweets = seen_tweets ++ GenServer.call({String.to_atom("tweeter_engine"), String.to_atom("tweeter_engine@" <> to_string(server_ip))}, {:query_user_mentions, username}, :infinity)

    last_searched_htag = GenServer.call({String.to_atom("tweeter_engine"), String.to_atom("tweeter_engine@" <> to_string(server_ip))}, {:get_recent_hash_tag, username}, :infinity)

    seen_tweets = if last_searched_htag != {} do
      last_searched_htag = elem(last_searched_htag, 1)
      seen_tweets ++ GenServer.call({String.to_atom("tweeter_engine"), String.to_atom("tweeter_engine@" <> to_string(server_ip))}, {:get_tweets_hashtag, username, last_searched_htag}, :infinity)
    else 
      seen_tweets
    end

    seen_tweets = seen_tweets ++ GenServer.call({String.to_atom("tweeter_engine"), String.to_atom("tweeter_engine@" <> to_string(server_ip))}, {:get_tweets_hashtag, username, last_searched_htag}, :infinity)

    if seen_tweets != [] and seen_tweets != nil do
      rand_seen_tweet = Enum.random(seen_tweets)
      GenServer.cast({String.to_atom("tweeter_engine"), String.to_atom("tweeter_engine@" <> to_string(server_ip))}, {:retweet, username, elem(rand_seen_tweet, 1), elem(rand_seen_tweet, 0), client_ip})
      retweet = elem(rand_seen_tweet, 1)
      from_user = elem(rand_seen_tweet, 0)
    end
  end

  def stop_client(user_name, server_ip) do
    GenServer.cast({String.to_atom("tweeter_engine"), String.to_atom("tweeter_engine@" <> to_string(server_ip))}, {:logout, user_name})
    GenServer.cast(String.to_atom(user_name), :stop)
  end

  def handle_cast({:live_tweets, user_name, tweet}, state) do
    {client_name}= state
    IO.inspect "Tweet ::: #{client_name} ::: #{user_name} ::: #{tweet}"
    {:noreply, state}
  end

  def handle_cast(:stop, status) do
    {:stop, :normal, status}
  end
end
