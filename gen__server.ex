defmodule RobotServer do
  use GenServer

  # Starting the robot with a specific task (cleaning room or cooking dinner)
  # The `start_link/1` function is a typical way to start a GenServer. It takes an argument (`task`) 
  # that will be passed to the `init/1` function to initialize the robot's state.
  # The GenServer process is linked to the calling process, meaning if the calling process crashes, this GenServer will also terminate.
  def start_link(task) do
    # `GenServer.start_link/3` starts the server and links it to the current process.
    # We pass `__MODULE__` to indicate this module is the GenServer implementation,
    # `task` is passed as the initial state, and `via_tuple(task)` generates a unique name for this server instance.
    GenServer.start_link(__MODULE__, task, name: via_tuple(task))
  end

  # Public API to send tasks to the robot
  # This function is the public interface for clients to request the robot to do its task.
  # It sends a synchronous message (call) to the GenServer identified by the task name.
  def do_task(task) do
    # `GenServer.call/2` is a synchronous request, meaning the caller will wait until a response
    # is received from the GenServer. We identify the correct GenServer instance using `via_tuple(task)`.
    GenServer.call(via_tuple(task), :do_task)
  end

  # GenServer callback: init/1
  # This function is called when the GenServer is first started. It receives the initial argument (`task`)
  # and sets the state for the server, which can be any value.
  @impl true
  def init(task) do
    # `{:ok, task}` tells the GenServer that it has successfully initialized with the state `task`.
    # The state here is either `:clean_room` or `:cook_dinner`, depending on which robot we’re creating.
    {:ok, task}
  end

  # GenServer callback: handle_call/3
  # This function handles synchronous calls (like `GenServer.call/2`). It takes the message (`:do_task`),
  # the `from` argument (information about the client making the call), and the current state (`task`).
  @impl true
  def handle_call(:do_task, _from, :clean_room) do
    # Here, if the robot's state is `:clean_room`, we respond with "Room is clean!".
    # `{:reply, response, new_state}` is the tuple format used to send a reply to the caller and update the server state.
    {:reply, "Room is clean!", :clean_room}
  end

  @impl true
  def handle_call(:do_task, _from, :cook_dinner) do
    # Similarly, if the robot's state is `:cook_dinner`, we respond with "Dinner is ready!".
    {:reply, "Dinner is ready!", :cook_dinner}
  end

  # Helper function: via_tuple/1
  # This is a helper function that generates a unique name for each robot using Elixir's `Registry`.
  # The `:via` tuple is a way to register and look up a GenServer process by a unique identifier (in this case, the task).
  defp via_tuple(task) do
    # This tells the system to look up the robot's process using the Registry.
    # We pass in the `RobotRegistry` name and the specific `task` (e.g., `:clean_room`, `:cook_dinner`) to identify each robot.
    {:via, Registry, {RobotRegistry, task}}
  end
end


