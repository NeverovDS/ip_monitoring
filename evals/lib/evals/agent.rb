module Evals
  # Runs Claude Code on a task inside the sandbox with no human around (`claude -p`), so every
  # action that would ask for permission is refused and shows up in `denied_commands`.
  class Agent
    MAX_TURNS = 40
    TIMEOUT = 20 * 60
    POLL_INTERVAL = 2

    Result = Data.define(:finished, :denied_commands, :turns, :cost, :model) do
      # What `claude -p --output-format json` prints. Output that is not JSON (claude crashed
      # or could not log in) counts as unfinished, so the run still gets graded.
      def self.parse(json)
        output = JSON.parse(json)
        new(
          finished: true,
          # Only Bash denials have a command; a denied Read or Edit has a file_path instead.
          denied_commands: output.fetch("permission_denials", []).filter_map { |denial| denial.dig("tool_input", "command") },
          turns: output["num_turns"],
          cost: output["total_cost_usd"],
          model: output.fetch("modelUsage", {}).keys.first
        )
      rescue JSON::ParserError
        unfinished
      end

      def self.unfinished
        new(finished: false, denied_commands: [], turns: nil, cost: nil, model: nil)
      end
    end

    def initialize(sandbox)
      @sandbox = sandbox
    end

    def call(prompt)
      pid = Process.spawn(@sandbox.env, *command(prompt),
                          chdir: @sandbox.repo, unsetenv_others: true, pgroup: true,
                          in: File::NULL, out: output_path, err: error_path)
      return Result.unfinished unless finished_in_time?(pid)

      result = Result.parse(File.read(output_path))
      warn "claude printed no JSON result: #{File.read(error_path)[0, 300]}" unless result.finished
      result
    end

    def output_path
      File.join(@sandbox.dir, "agent.json")
    end

    def error_path
      File.join(@sandbox.dir, "agent.err")
    end

    private

    # Only the repository's own settings and CLAUDE.md: the developer's personal ~/.claude
    # instructions would otherwise leak into the run. The clone is a folder Claude Code has
    # never trusted, so it ignores the project's allow rules there ("Ignoring 6
    # permissions.allow entries ... this workspace has not been trusted" on stderr);
    # `--settings` passes the same file again, and its rules apply.
    def command(prompt)
      [ "claude", "-p", prompt,
        "--output-format", "json",
        "--permission-mode", "acceptEdits",
        "--setting-sources", "project,local",
        "--settings", ".claude/settings.json",
        "--max-turns", MAX_TURNS.to_s ]
    end

    def finished_in_time?(pid)
      deadline = Time.now + TIMEOUT
      until Process.wait(pid, Process::WNOHANG)
        return stop(pid) if Time.now > deadline

        sleep POLL_INTERVAL
      end
      true
    end

    def stop(pid)
      Process.kill("TERM", -pid)
      Process.wait(pid)
      false
    end
  end
end
