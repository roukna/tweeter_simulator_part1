defmodule Tweeter.Server do
  use GenServer
  @name :tweeter_engine

  # API
  def startlink() do
    users = :ets.new(:users, [:set, :public, :named_table])
    tweets = :ets.new(:tweets, [:set, :public, :named_table])
    followers = :ets.new(:followers, [:set, :public, :named_table])
    following = :ets.new(:following, [:set, :public, :named_table])
    hashtags = :ets.new(:hashtags, [:set, :public, :named_table])
    user_mentions = :ets.new(:user_mentions, [:set, :public, :named_table])
    list_of_active_users = []

    #server_ip = get_ip(0)
    #server = "tweeter_engine@" <> to_string(server_ip)
    #Node.start(String.to_atom(server))
    #Node.set_cookie(:tweeter)

    # Registers the GenServer process ID globally.
    {:ok, pid} = GenServer.start_link(__MODULE__, {users, tweets, followers, following, hashtags, user_mentions, list_of_active_users, 0}, name: @name)
    #:global.register_name(@name, pid)
  end

  @doc """
  Code to return the IP address of the machine.
  """
  def get_ip(iter) do
    list = Enum.at(:inet.getif() |> Tuple.to_list, 1)
    if (elem(Enum.at(list, iter), 0) == {127, 0, 0, 1}) do
      get_ip(iter+1)
    else
      elem(Enum.at(list, iter), 0) |> Tuple.to_list |> Enum.join(".")
    end
  end

  # Handle calls

  # Register account
  def handle_call({:register_account, user_name, password}, _from, state) do
    {users, tweets, followers, following, hashtags, user_mentions, list_of_active_users, tweet_id} = state
    current_time = DateTime.utc_now()
    register_success = :ets.insert_new(users, {user_name, password, current_time})

    if (register_success == true) do
      {:reply, "Register successful!", state}
    else
      {:reply, "Register unsuccessful!", state}
    end
  end

  # Login
  def handle_call({:login, user_name, password}, _from, state) do
    {users, tweets, followers, following, hashtags, user_mentions, list_of_active_users, tweet_id} = state
    login_pwd = elem(List.first(:ets.lookup(users, user_name)), 1)
    if login_pwd == password do
      list_of_active_users = [user_name] ++ list_of_active_users
      {:reply, "Login successful!", {users, tweets, followers, following, hashtags, user_mentions, list_of_active_users, tweet_id}}
    else 
      {:reply, "Login unsuccessful!", state}
    end
  end
  
  # Logout
  def handle_call({:logout, user_name}, _from, state) do
    {users, tweets, followers, following, hashtags, user_mentions, list_of_active_users, tweet_id} = state
    list_of_active_users = List.delete(list_of_active_users, user_name)
    login_pwd = elem(List.first(:ets.lookup(users, user_name)), 1)
    {:reply, "Logged out!", state}
  end
  
  
  # Subscribe
  def handle_cast({:subscribe, follower, user}, state) do
    {users, tweets, followers, following, hashtags, user_mentions, list_of_active_users, tweet_id} = state
    
    subscribers = if :ets.lookup(followers, user) == [] do
      []
    else
      elem(List.first(:ets.lookup(followers, user)), 1)
    end
    subscribers =  [follower] ++ subscribers
    :ets.insert(followers, {user, subscribers})

    subscribing = if :ets.lookup(following, follower) == [] do
      []
    else
      elem(List.first(:ets.lookup(following, follower)), 1)
    end
    subscribing =  [user] ++ subscribing
    :ets.insert(following, {follower, subscribing})

    {:noreply, {users, tweets, followers, following, hashtags, user_mentions, list_of_active_users, tweet_id}}
  end

  # Tweet
  def handle_cast({:tweet, user_name, tweet}, state) do
    {users, tweets, followers, following, hashtags, user_mentions, list_of_active_users, tweet_id} = state
    tweet_id = tweet_id + 1
    current_time = DateTime.utc_now()
    :ets.insert_new(tweets, {tweet_id, user_name, tweet, current_time})

    hashtags_in_tweet = String.split(tweet, " ") |> Enum.filter(fn word -> String.contains?(word, "#") end)
    for h_tag <- hashtags_in_tweet do
      tweet_ids_of_htag = if :ets.lookup(hashtags, h_tag) == [] do
        []
      else
        elem(List.first(:ets.lookup(hashtags, h_tag)), 1)
      end
      tweet_ids_of_htag = [tweet_id] ++ tweet_ids_of_htag
      :ets.insert(hashtags, {h_tag, tweet_ids_of_htag})
    end

    mentions_in_tweet = String.split(tweet, " ") |> Enum.filter(fn word -> String.contains?(word, "@") end)
    for u_mentions <- mentions_in_tweet do
      tweet_ids_of_umen = if :ets.lookup(user_mentions, u_mentions) == [] do
        []
      else
        elem(List.first(:ets.lookup(user_mentions, u_mentions)), 1)
      end
      tweet_ids_of_umen = [tweet_id] ++ tweet_ids_of_umen
      :ets.insert(user_mentions, {u_mentions, tweet_ids_of_umen})
    end

    GenServer.cast(String.to_atom("tweeter_engine"), {:broadcast_live_tweets, user_name, tweet})

    {:noreply, {users, tweets, followers, following, hashtags, user_mentions, list_of_active_users, tweet_id}}
  end

  # Broadcast live tweets
  def handle_cast({:broadcast_live_tweets, user_name, tweet}, state) do
    {users, tweets, followers, following, hashtags, user_mentions, list_of_active_users, tweet_id} = state
    subscribers = if :ets.lookup(followers, user_name) == [] do
      []
    else
      elem(List.first(:ets.lookup(followers, user_name)), 1)
    end
    
    for f_user <- subscribers do
      pid = GenServer.whereis(String.to_atom(f_user))
      if(pid != nil and Process.alive?(pid) == true) do
        GenServer.cast(String.to_atom(f_user), {:live_tweets, user_name, tweet})
      end
    end
    {:noreply, {users, tweets, followers, following, hashtags, user_mentions, list_of_active_users, tweet_id}}
  end

    # Query user tweets
  def handle_call({:query_user_tweets, user_name}, _from, state) do
    {users, tweets, followers, following, hashtags, user_mentions, list_of_active_users, tweet_id} = state
    subscribing = if :ets.lookup(following, user_name) == [] do
      []
    else
      elem(List.first(:ets.lookup(following, user_name)), 1)
    end

    IO.inspect subscribing

    result = for f_user <- subscribing do
      list_of_tweets = List.flatten(:ets.match(tweets, {:_, f_user, :"$1", :_}))
      Enum.map(list_of_tweets, fn tweet -> {f_user, tweet} end)
    end
    result = List.flatten(result)
    #IO.inspect result
    {:reply, result, state}
  end

  # Query user tweets
  def handle_call({:query_user_mentions, user_name}, _from, state) do
    {users, tweets, followers, following, hashtags, user_mentions, list_of_active_users, tweet_id} = state
    user_men = "@" <> user_name
    list_of_tweet_ids = if :ets.lookup(user_mentions, user_men) == [] do
      []
    else
      elem(List.first(:ets.lookup(user_mentions, user_men)), 1)
    end

    result = for u_tweet_id <- list_of_tweet_ids do
      list_of_tweets = List.flatten(:ets.match(tweets, {u_tweet_id, :"$1", :"$2", :_}))
    end
    result = List.flatten(result)
    IO.inspect result
    {:reply, result, state}
  end

  # Get Tweets from Hashtags
  def handle_call({:get_tweets_hashtag, hashtag}, _from, state) do
    {users, tweets, followers, following, hashtags, user_mentions, list_of_active_users, tweet_id} = state
    tweet_ids = if :ets.lookup(hashtags, hashtag) == [] do
      []
    else
      elem(List.first(:ets.lookup(hashtags, hashtag)), 1)
    end
    
    result = for tweet_id <- tweet_ids do
      list_of_tweets = List.flatten(:ets.match(tweets, {tweet_id, :"$1", :"$2", :_}))
    end
    result = List.flatten(result)

    {:reply, result, state}
  end

end