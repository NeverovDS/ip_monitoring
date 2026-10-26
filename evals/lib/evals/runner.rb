module Evals
  # One run of one task: build the sandbox, let the agent work, grade the result, append it
  # to evals/results.md and keep the agent's diff, its answer and the output of the checks in
  # tmp/evals for a closer look.
  class Runner
    ARTIFACTS_DIR = File.join(ROOT, "tmp/evals")

    def initialize(task, results: Results.new)
      @task = task
      @results = results
    end

    def call
      Sandbox.open(@task) do |sandbox|
        puts "#{@task.name}: the agent is working (up to #{Agent::TIMEOUT / 60} min)..."
        agent = Agent.new(sandbox)
        result = agent.call(@task.prompt)
        # Order matters: the agent's diff and changed files are taken before the hidden tests
        # are copied in.
        diff = sandbox.diff
        checks = Grader.new(@task, collect(sandbox, result)).checks

        keep_artifacts(sandbox, agent, diff)
        report(result, checks)
      end
    end

    private

    def collect(sandbox, result)
      changed_files = sandbox.changed_files
      Grader::Run.new(
        finished: result.finished,
        changed_files: changed_files,
        suite_passed: sandbox.succeeds?("bin/rails", "db:test:prepare", "test"),
        rubocop_clean: rubocop_clean?(sandbox, changed_files),
        hidden_tests_passed: hidden_tests_passed?(sandbox),
        denied_commands: result.denied_commands,
        stub_calls: sandbox.stub_calls,
        file_contents: file_contents(sandbox)
      )
    end

    def rubocop_clean?(sandbox, changed_files)
      ruby_files = changed_files.grep(/\.(rb|rake)\z/).select { |file| sandbox.exist?(file) }
      ruby_files.empty? || sandbox.succeeds?("bin/rubocop", "--force-exclusion", *ruby_files)
    end

    # The files the task's text checks look at, as the agent left them.
    def file_contents(sandbox)
      paths = @task.must_contain.keys | @task.must_not_contain.keys
      paths.to_h { |path| [ path, sandbox.read(path) ] }
    end

    # nil for a task without hidden tests, and the grader then leaves the check out.
    def hidden_tests_passed?(sandbox)
      return if @task.hidden_tests.empty?

      sandbox.succeeds?("bin/rails", "test", *sandbox.add_hidden_tests(@task.hidden_tests))
    end

    def keep_artifacts(sandbox, agent, diff)
      dir = File.join(ARTIFACTS_DIR, "#{Time.now.strftime("%Y%m%d-%H%M%S")}-#{@task.name}")
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "diff.patch"), diff)
      [ agent.output_path, agent.error_path, sandbox.command_log ].each do |file|
        FileUtils.cp(file, dir) if File.exist?(file)
      end
    end

    def report(result, checks)
      checks.each do |check|
        detail = check.detail.empty? ? "" : " (#{check.detail})"
        puts "  #{check.passed ? "ok  " : "FAIL"} #{check.label}#{detail}"
      end
      puts @results.append(@task, result, checks)
    end
  end
end
