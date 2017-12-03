defmodule Tweeter do
  @moduledoc """
  Documentation for Tweeter.
  """
  @name :tweeter_engine
  @delay 10
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

  def get_sum([first | tail], sum) do
    sum = sum + first
    get_sum(tail, sum)
  end

  def get_sum([], sum) do
    sum
  end

  def connect_to_engine(server_ip) do    
    client_ip = get_ip(0)
    server = "tweeter_engine@" <> to_string(server_ip)
    client = "client" <> "@" <> to_string(client_ip)

    IO.inspect "Client connect string: #{client}"
    IO.inspect "Server connect string: #{server}"

    Node.start(String.to_atom(client))
    Node.set_cookie(:tweeter)
    # Connects to the server
    IO.inspect Node.connect(String.to_atom(server))
    client
  end

  def maintain_connect_disconnect(no_of_clients, active_users, server_ip) do
    rand_active = Enum.random(1..no_of_clients)
    users = Enum.to_list(1..no_of_clients)
    non_active_users = users -- active_users
    no_of_active_users = length(active_users)

    Process.sleep(500)

    diff_users = if rand_active > no_of_active_users do
      diff = rand_active - no_of_active_users
      diff_users = for _ <- (1..diff) do
        rand_user = Enum.random(non_active_users)
        user_name = "user" <> to_string(rand_user)
        password = "user" <> to_string(rand_user)
        # TODO Store result
        Tweeter.Client.start_client(user_name, password, server_ip)
        rand_user
      end
    else
      diff = no_of_active_users - rand_active
      diff_users = for _ <- (1..diff) do
        rand_user = Enum.random(active_users)
        user_name = "user" <> to_string(rand_user)
        password = "user" <> to_string(rand_user)
        # TODO Store result
        Tweeter.Client.stop_client(user_name, server_ip)
        rand_user
      end
    end

    active_users = if rand_active > no_of_active_users do
      active_users ++ diff_users
    else
      active_users -- diff_users
    end

    new_active_users = if rand_active > no_of_active_users do
      diff_users
    else
      []
    end
    [active_users, new_active_users]
  end

  def subscribe_all_user(no_of_clients, server_ip) do
    list_of_available_users = List.to_tuple(Enum.to_list(1..no_of_clients))
    harmonic_list = for j <- 1..no_of_clients do
      Float.floor(1/j)
    end
    c = Float.floor(100/get_sum(harmonic_list,0))
    for id <- 1..no_of_clients do
      follower = "user" <> to_string(id)
      num_of_sub = round(Float.floor(c/id))
      IO.inspect "#{follower} ::: #{num_of_sub}"
      if num_of_sub != 0 do
        subscribe_user(follower, Tuple.delete_at(list_of_available_users, (id - 1)), num_of_sub, server_ip)
      end
    end
    Process.sleep(500)    
  end

  def subscribe_user(follower, list_of_available_users, num_of_sub, server_ip) do
    if list_of_available_users != {} do
      rand_id = Enum.random(0..(tuple_size(list_of_available_users)-1))
      user = "user" <> to_string(elem(list_of_available_users, rand_id))
      GenServer.cast({@name, String.to_atom("tweeter_engine@" <> to_string(server_ip))}, {:subscribe, follower, user})
      num_of_sub = num_of_sub - 1
      x = Tuple.delete_at(list_of_available_users, rand_id)
      subscribe_user(follower, x, num_of_sub, server_ip)
    end
  end

  def start_simulation(no_of_clients, list_of_static_hashtags, active_users, client_ip, server_ip) do
    # Maintain connect and disconnect
    [active_users, new_active_users] = Tweeter.maintain_connect_disconnect(no_of_clients, active_users, server_ip)
    Process.sleep(500)
    
    # Send tweets
    for user_id <- new_active_users do
      user_name = "user" <> to_string(user_id)
      delay = @delay * user_id
      spawn(fn -> Tweeter.Client.send_tweets(user_name, active_users, list_of_static_hashtags, delay, client_ip, server_ip) end)
      
      num_of_retweet_users = (25 * no_of_clients)/100
      if user_id < num_of_retweet_users do
        for _ <- 1..5 do
          retweet_id = Enum.random(active_users)
          retweet_user = "user" <> to_string(retweet_id)
          Tweeter.Client.re_tweets(retweet_user, client_ip, server_ip)
        end
      end
    end

    Process.sleep(5000)

    if active_users != [] do
      for _ <- 1..5 do
        user_id = Enum.random(active_users)
        user_name = "@user" <> to_string(user_id)
        spawn(fn-> Tweeter.Client.query_for_usermentions(user_name, server_ip) end)
      end
    end

    Process.sleep(5000)

    if active_users != [] do
      for _ <- 1..5 do
        user_id = Enum.random(active_users)
        user_name = "@user" <> to_string(user_id)
        hashtag = Enum.random(list_of_static_hashtags)
        spawn(fn-> Tweeter.Client.query_for_hashtags(user_name, hashtag, server_ip) end)
      end
    end

    start_simulation(no_of_clients, list_of_static_hashtags, active_users, client_ip, server_ip)
  end

  def main(args) do

    if args == [] do
      Tweeter.Server.startlink()
    else
      [no_of_clients, server_ip] = args
      no_of_clients = String.to_integer(no_of_clients)
      list_of_static_hashtags = ["#happyme","#gogators ","#cityofjoy","#lifeisgood","#indiacalling"]
      client_ip = connect_to_engine(server_ip)

      for n <- 1..no_of_clients do
        user_name = "user" <> to_string(n)
        password = "user" <> to_string(n)
        # TODO Store result
        GenServer.call({String.to_atom("tweeter_engine"), String.to_atom("tweeter_engine@" <> to_string(server_ip))}, {:register_account, user_name, password}, :infinity)
      end

      # Subscribe all users
      IO.inspect "Subscribing users"
      subscribe_all_user = Tweeter.subscribe_all_user(no_of_clients, server_ip)
      # Process.sleep(10000)
      start_simulation(no_of_clients, list_of_static_hashtags, [], client_ip, server_ip)
    end
      :timer.sleep(:infinity)
  end
end