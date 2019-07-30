defmodule Mix.Tasks.PreCommit do
  use Mix.Task

  @moduledoc """
    This file contains the functions that will be run when `mix pre_commit` is
    run. (we run it in the script in the `pre-commit` file in your `.git/hooks` directory but you can run it yourself if you want to see the output without committing).

    In here we just run all of the mix commands that you have put in your config file, and if they're succesful, print a success message to the
    the terminal, and if they fail we halt the process with a `1` error code (
    meaning that the command has failed), which will trigger the commit to stop,
    and print the error message to the terminal.
  """
  @commands Application.get_env(:pre_commit, :commands) || []
  @verbose Application.get_env(:pre_commit, :verbose) || false

  def run(_) do
    IO.puts("\e[95mPre-commit running...\e[0m")

    stash_changes(should_stash_changes?())

    @commands
    |> Enum.each(&run_cmds/1)

    stash_pop_changes(should_stash_changes?())
    System.halt(0)
  end

  defp stash_changes(false), do: nil

  defp stash_changes(true) do
    {_, 0} = System.cmd("git", String.split("stash push --keep-index --message pre_commit", " "))
  end

  defp stash_pop_changes(false), do: nil

  defp stash_pop_changes(true) do
    System.cmd("git", String.split("stash pop", " "), stderr_to_stdout: true)
    |> case do
      {_, 0} ->
        "\e[32mPre-commit passed!\e[0m"

      {"No stash entries found.", 1} ->
        "\e[32mPre-commit passed!\e[0m"

      {error, _} ->
        error
    end
    |> IO.puts()
  end

  defp run_cmds(cmd) do
    into =
      case @verbose do
        true -> IO.stream(:stdio, :line)
        _ -> ""
      end

    System.cmd("mix", String.split(cmd, " "), stderr_to_stdout: true, into: into)
    |> case do
      {_result, 0} ->
        IO.puts("mix #{cmd} ran successfully.")

      {result, _} ->
        if !@verbose, do: IO.puts(result)

        IO.puts(
          "\e[31mPre-commit failed on `mix #{cmd}`.\e[0m \nCommit again with --no-verify to live dangerously and skip pre-commit."
        )

        {_, 0} = System.cmd("git", String.split("stash pop", " "))
        System.halt(1)
    end
  end

  defp should_stash_changes?() do
    case(Application.get_env(:pre_commit, :stash_changes)) do
      false -> false
      _ -> true
    end
  end
end
