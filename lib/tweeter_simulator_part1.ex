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

  def maintain_connect_disconnect(no_of_clients, active_users) do
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
        Tweeter.Client.start_client(user_name, password)
        rand_user
      end
    else
      diff = no_of_active_users - rand_active
      diff_users = for _ <- (1..diff) do
        rand_user = Enum.random(active_users)
        user_name = "user" <> to_string(rand_user)
        password = "user" <> to_string(rand_user)
        # TODO Store result
        Tweeter.Client.stop_client(user_name)
        rand_user
      end
    end

    active_users = if rand_active > no_of_active_users do
      active_users ++ diff_users
    else
      active_users -- diff_users
    end
    active_users
  end

  def subscribe_all_user(no_of_clients) do
    list_of_available_users = Enum.to_list(1..no_of_clients)
    harmonic_list = for j <- 1..no_of_clients do
      1/j
    end
    c = (100/get_sum(harmonic_list,0))
    for id <- 1..no_of_clients do
      follower = "user" <> to_string(id)
      num_of_sub = round(Float.floor(c/id))
      subscribe_user(follower, List.delete(list_of_available_users, id), num_of_sub)
    end    
  end

  def subscribe_user(follower, list_of_available_users, num_of_sub) do
    if list_of_available_users != [] do
      rand_id = Enum.random(list_of_available_users)
      user = "user" <> to_string(rand_id)
      GenServer.cast(@name, {:subscribe, follower, user})
      num_of_sub = num_of_sub - 1
      subscribe_user(follower, List.delete(list_of_available_users, rand_id), num_of_sub)
    end
  end

  def start_simulation(no_of_clients, list_of_static_hashtags, active_users) do
    # Maintain connect and disconnect
    active_users = Tweeter.maintain_connect_disconnect(no_of_clients, active_users)

    Process.sleep(500)
    #IO.inspect active_users

    # Send tweets
    for user_id <- active_users do
      user_name = "user" <> to_string(user_id)
      delay = @delay * user_id
      spawn(fn -> Tweeter.Client.send_tweets(user_name, active_users, list_of_static_hashtags, delay) end)
      num_of_retweet_users = (25 * no_of_clients)/100
      if user_id < num_of_retweet_users do
        for _ <- 1..5 do
          retweet_id = Enum.random(active_users)
          retweet_user = "user" <> to_string(retweet_id)
          Tweeter.Client.re_tweets(retweet_user)
        end
      end
    end

    #Process.sleep(15000)
    if active_users != [] do
      user_id = Enum.random(active_users)
      user_name = "@user" <> to_string(user_id)
      spawn(fn-> Tweeter.Client.query_for_usermentions(user_name) end)
      #Process.sleep(5000)
    end

    if active_users != [] do
      user_id = Enum.random(active_users)
      user_name = "@user" <> to_string(user_id)
      hashtag = Enum.random(list_of_static_hashtags)
      spawn(fn-> Tweeter.Client.query_for_hashtags(user_name, hashtag) end)
    end

    #Process.sleep(10000)
    start_simulation(no_of_clients, list_of_static_hashtags, active_users)
  end

  def main(args) do
    [no_of_clients] = args
    no_of_clients = String.to_integer(no_of_clients)

    list_of_static_hashtags = ["#happyme","#gogators ","#cityofjoy","#lifeisgood","#indiacalling"]

    # Start the server
    Tweeter.Server.startlink()
    IO.inspect "Tweeter engine started"

    for n <- 1..no_of_clients do
      user_name = "user" <> to_string(n)
      password = "user" <> to_string(n)
      # TODO Store result
      GenServer.call(@name, {:register_account, user_name, password}, :infinity)
    end

    # Subscribe all users
    subscribe_all_user = Tweeter.subscribe_all_user(no_of_clients)
    # Process.sleep(10000)
    start_simulation(no_of_clients, list_of_static_hashtags, [])

    :timer.sleep(:infinity)
  end
end