defmodule Tweeter.Client do
    use GenServer
    @name :master
  
    def start_client(user_name, password) do
      GenServer.start_link(__MODULE__, {}, name: String.to_atom(user_name))
      x = GenServer.whereis(String.to_atom(user_name))
      IO.inspect x
      message = GenServer.call(String.to_atom("tweeter_engine"), {:login, user_name, password})
      IO.puts message
    end
end