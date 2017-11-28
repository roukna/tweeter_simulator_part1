defmodule Tweeter.Server do
  use GenServer
  #@name :tweeter_engine

  def startlink(nodeID) do
    users = :ets.new(:users, [:set, :public, :named_table])
    tweets = :ets.new(:tweets, [:set, :public, :named_table])
    followers = :ets.new(:followers, [:set, :public, :named_table])
    hashtags = :ets.new(:hashtags, [:set, :public, :named_table])
    user_mentions = :ets.new(:user_mentions, [:set, :public, :named_table])
    list_of_active_users = []

    #server_ip = get_ip(0)
    #server = "tweeter_engine@" <> to_string(server_ip)
    #Node.start(String.to_atom(server))
    #Node.set_cookie(:tweeter)

    # Registers the GenServer process ID globally.
    {:ok, pid} = GenServer.start_link(__MODULE__, {users, tweets, followers, hashtags, user_mentions, list_of_active_users, 0}, name: :tweeter_engine)
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

  def handle_call({:register_account, user_name, password}, _from, state) do
    {users, tweets, followers, hashtags, user_mentions, list_of_active_users, tweet_id} = state
    current_time = DateTime.utc_now()
    register_success = :ets.insert_new(users, {user_name, password, current_time})

    if (register_success == true) do
      {:reply, "Register successful!", state}
    else
      {:reply, "Register unsuccessful!", state}
    end
  end
  
  def handle_cast({:tweet, user_name, tweet}, state) do
    {users, tweets, followers, hashtags, user_mentions, list_of_active_users, tweet_id} = state
    tweet_id = tweet_id + 1
    current_time = DateTime.utc_now()
    :ets.insert_new(tweets, {tweet_id, user_name, tweet, current_time})

    GenServer.cast(String.to_atom("tweeter_engine"), {:broadcast_live_tweets, user_name, tweet})

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

    {:noreply, {users, tweets, followers, hashtags, user_mentions, list_of_active_users, tweet_id}}
  end

  def handle_cast({:subscribe, from_user, to_user}, state) do
    {users, tweets, followers, hashtags, user_mentions, list_of_active_users, tweet_id} = state
    subscribed_to = if :ets.lookup(followers, from_user) == [] do
      []
    else
      elem(List.first(:ets.lookup(followers, from_user)), 1)
    end
    subscribed_to = [to_user] ++ subscribed_to
    :ets.insert(followers, {from_user, subscribed_to})
    {:noreply, {users, tweets, followers, hashtags, user_mentions, list_of_active_users, tweet_id}}
  end

  def handle_cast({:broadcast_live_tweets, user_name, tweet}, state) do
    {users, tweets, followers, hashtags, user_mentions, list_of_active_users, tweet_id} = state
    subscribed_to = if :ets.lookup(followers, user_name) == [] do
      []
    else
      elem(List.first(:ets.lookup(followers, user_name)), 1)
    end
    
    for f_user <- subscribed_to do
      pid = GenServer.whereis(String.to_atom(f_user))
      if(Process.alive?(pid) == true) do
        IO.puts f_user
        #GenServer.cast(String.to_atom(f_user), {:live_tweets, user_name, tweet})
      end
    end
    {:noreply, {users, tweets, followers, hashtags, user_mentions, list_of_active_users, tweet_id}}
  end

  def handle_call({:login, user_name, password}, _from, state) do
    {users, tweets, followers, hashtags, user_mentions, list_of_active_users, tweet_id} = state
    login_pwd = elem(List.first(:ets.lookup(users, user_name)), 1)
    if login_pwd == password do
      list_of_active_users = [user_name] ++ list_of_active_users
      {:reply, "Login successful!", {users, tweets, followers, hashtags, user_mentions, list_of_active_users, tweet_id}}
    else 
      {:reply, "Login unsuccessful!", state}
    end
  end

  def handle_call({:query_user_tweets, user_name}, _from, state) do
    {users, tweets, followers, hashtags, user_mentions, list_of_active_users, tweet_id} = state
    users_following = if :ets.lookup(followers, user_name) == [] do
      []
    else
      elem(List.first(:ets.lookup(followers, user_name)), 1)
    end

    result = for f_user <- users_following do
      list_of_tweets = List.flatten(:ets.match(tweets, {:_, f_user, :"$1", :_}))
      Enum.map(list_of_tweets, fn tweet -> {f_user, tweet} end)
    end
    result = List.flatten(result)
    IO.inspect result
    {:reply, result, state}
  end

end