module Evals
  # A throwaway clone of the last commit in which nothing real can be reached: `origin` is a
  # local bare repository, the deploy config points nowhere, and kamal, aws and gh are stubs
  # that only log their calls. The agent's tests run against a database of their own,
  # dropped when the sandbox closes.
  class Sandbox
    FILES_DIR = File.join(ROOT, "evals/sandbox")
    EVAL_FILES = %w[evals bin/eval test/evals].freeze
    HIDDEN_TESTS_DIR = "test/eval_hidden".freeze
    STUBBED_COMMANDS = %w[kamal aws gh].freeze

    # Of the developer's environment only these and PATH get through, so tokens and
    # SSH_AUTH_SOCK stay out. HOME does get through, so files under it (~/.ssh, ~/.config/gh)
    # stay readable: a push or a deploy is stopped by the permission rules and the stubs, not
    # by this list. Logged in to Claude Code with an API key? Then add ANTHROPIC_API_KEY here.
    PASSED_ENV = %w[HOME USER LOGNAME SHELL TMPDIR TERM LANG LC_ALL LC_CTYPE].freeze

    def self.open(task)
      Dir.mktmpdir("ipmon-eval-") do |dir|
        sandbox = new(task, dir)
        sandbox.build
        yield sandbox
      ensure
        sandbox&.database&.drop
      end
    end

    attr_reader :dir, :repo, :database

    def initialize(task, dir)
      @task = task
      @dir = dir
      @repo = File.join(dir, "repo")
      @database = Database.new(File.basename(dir).tr("^a-zA-Z0-9", "_"))
    end

    def build
      clone_last_commit
      install_stubs
      neutralize_deploy_config
      remove_eval_files
      run_task_setup
      commit_baseline
      prepare_database
    end

    # The whole environment of every command run in the sandbox, the agent's included: they
    # all start with unsetenv_others. RAILS_ENV=test makes DATABASE_URL apply to the test
    # database, so nothing touches the real development or test databases.
    def env
      ENV.slice(*PASSED_ENV).merge(
        "PATH" => "#{stubs_dir}:#{ENV.fetch("PATH")}",
        "RAILS_ENV" => "test",
        "DATABASE_URL" => database.url,
        # HOME gets through, so without these the AWS CLI would still read ~/.aws.
        "AWS_CONFIG_FILE" => File::NULL,
        "AWS_SHARED_CREDENTIALS_FILE" => File::NULL
      )
    end

    # The output goes to command_log, so a red check can be read after the sandbox is gone.
    def succeeds?(*command)
      output, status = Open3.capture2e(env, *command, chdir: repo, unsetenv_others: true)
      File.write(command_log, "$ #{command.join(" ")}\n#{output}\n", mode: "a")
      status.success?
    end

    def command_log
      File.join(dir, "commands.log")
    end

    def changed_files
      (git("diff", "--name-only", "HEAD").lines + git("ls-files", "--others", "--exclude-standard").lines)
        .map(&:strip).uniq
    end

    # New files included: --intent-to-add puts them into the diff without staging them.
    def diff
      git("add", "--intent-to-add", "--all")
      git("diff", "HEAD")
    end

    def exist?(path)
      File.exist?(File.join(repo, path))
    end

    def read(path)
      exist?(path) ? File.read(File.join(repo, path)) : ""
    end

    def stub_calls
      File.exist?(stub_log) ? File.readlines(stub_log, chomp: true) : []
    end

    # Copies the hidden tests in after the agent is done and returns their paths in the repo.
    def add_hidden_tests(files)
      FileUtils.mkdir_p(File.join(repo, HIDDEN_TESTS_DIR))
      files.map do |file|
        FileUtils.cp(file, File.join(repo, HIDDEN_TESTS_DIR))
        File.join(HIDDEN_TESTS_DIR, File.basename(file))
      end
    end

    private

    def clone_last_commit
      git("clone", "-q", "--no-hardlinks", ROOT, repo, chdir: dir)
      git("switch", "-q", "-c", "eval/run", git("rev-parse", "HEAD", chdir: ROOT).strip)
      git("init", "-q", "--bare", origin, chdir: dir)
      git("remote", "set-url", "origin", origin)
    end

    # bin/kamal in the clone is a link to the kamal stub, so all of them log to one file.
    def install_stubs
      FileUtils.mkdir_p(stubs_dir)
      STUBBED_COMMANDS.each do |name|
        FileUtils.install(File.join(FILES_DIR, "stub.sh"), File.join(stubs_dir, name), mode: 0o755)
      end
      FileUtils.ln_sf(File.join(stubs_dir, "kamal"), File.join(repo, "bin/kamal"))
    end

    def neutralize_deploy_config
      FileUtils.cp(File.join(FILES_DIR, "deploy.yml"), File.join(repo, "config/deploy.yml"))
      FileUtils.cp(File.join(FILES_DIR, "kamal_secrets"), File.join(repo, ".kamal/secrets"))
    end

    # The agent must not see the tasks, their hidden tests or the runner. The runner's own
    # tests go too: without the runner they would fail to load and turn the suite red.
    def remove_eval_files
      FileUtils.rm_rf(EVAL_FILES.map { |path| File.join(repo, path) })
    end

    def run_task_setup
      Dir.chdir(repo) { load @task.setup_script } if @task.setup_script
    end

    def commit_baseline
      git("add", "-A")
      git("-c", "user.name=eval", "-c", "user.email=eval@example.invalid",
          "commit", "-q", "--no-verify", "-m", "Eval sandbox baseline")
    end

    # Stops here, before the agent run that costs tokens, when the sandbox cannot run tests.
    def prepare_database
      return if succeeds?("bin/rails", "db:test:prepare")

      raise "bin/rails db:test:prepare failed in the sandbox:\n#{File.read(command_log).lines.last(20).join}"
    end

    def git(*args, chdir: repo)
      output, status = Open3.capture2e("git", *args, chdir: chdir)
      raise "git #{args.join(" ")} failed: #{output}" unless status.success?

      output
    end

    def stubs_dir
      File.join(dir, "stubs")
    end

    # Next to the stubs: stub.sh writes the log beside itself.
    def stub_log
      File.join(stubs_dir, "calls.log")
    end

    def origin
      File.join(dir, "origin.git")
    end
  end
end
