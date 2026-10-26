require "test_helper"
require "open3"
require "tmpdir"

# The git hooks are the check every commit goes through, so their logic is tested in a
# throwaway repository, where test/fixtures/files/stand_in.sh replaces bin/rubocop and bin/rails.
class PreCommitHookTest < ActiveSupport::TestCase
  HOOKS = Rails.root.join(".githooks")
  SUITE = [ "db:test:prepare", "test" ].freeze

  setup do
    @repo = Dir.mktmpdir("pre-commit-test")
    git "init", "-q", "-b", "feature/probe"
    install_stand_in "rubocop"
    install_stand_in "rails"
  end

  teardown { FileUtils.rm_rf(@repo) }

  test "refuses commits on main, merge commits too" do
    git "checkout", "-q", "-b", "main"
    stage "NOTES.md"

    %w[pre-commit pre-merge-commit].each do |hook|
      status, error = run_hook(hook)

      assert_equal 1, status
      assert_match "main deploys to production", error
    end
    assert_empty calls
  end

  test "a Markdown-only commit runs neither RuboCop nor the tests" do
    stage "NOTES.md", "docs/guide.md"

    assert_equal 0, run_hook.first
    assert_empty calls
  end

  test "RuboCop offenses refuse the commit before the tests run" do
    stage "app/models/probe.rb"
    make_fail "rubocop"

    status, error = run_hook

    assert_equal 1, status
    assert_match "fix the RuboCop offenses", error
    assert_equal [ "app/models/probe.rb" ], linted_files
    assert_empty calls_of("rails")
  end

  # Without -z git would print the non-ASCII name quoted and escaped, as "caf\303\251.rb".
  test "RuboCop gets each staged Ruby file as one argument, renames included, deletions not" do
    stage "app/models/old.rb", "app/models/gone.rb"
    commit "base"
    git "mv", "app/models/old.rb", "app/models/new name.rb"
    git "rm", "-q", "app/models/gone.rb"
    stage "app/models/café probe.rb", "README.md"

    assert_equal 0, run_hook.first
    assert_equal [ "app/models/café probe.rb", "app/models/new name.rb" ], linted_files.sort
  end

  test "a green suite lets the commit through" do
    stage "app/models/probe.rb"

    assert_equal 0, run_hook.first
    assert_equal [ SUITE ], calls_of("rails")
  end

  test "a red suite refuses the commit and shows the counts" do
    stage "app/models/probe.rb"
    make_fail "rails", "1 runs, 1 failures"

    status, error = run_hook

    assert_equal 1, status
    assert_match "the test suite is red", error
    assert_match "1 runs, 1 failures", error
  end

  test "names Postgres when the database is down" do
    stage "app/models/probe.rb"
    make_fail "rails", "ActiveRecord::ConnectionNotEstablished"

    status, error = run_hook

    assert_equal 1, status
    assert_match "Postgres is not reachable", error
  end

  # Piped straight into `grep -q`, a long list of staged names ended in SIGPIPE and the suite
  # was skipped silently. Ruby comes first in the list, so grep stops early.
  test "a long staged list still runs the suite" do
    stage "app/models/probe.rb", *Array.new(5_000) { |i| "docs/note_#{i}.md" }

    assert_equal 0, run_hook.first
    assert_equal [ SUITE ], calls_of("rails")
  end

  private

  def install_stand_in(name)
    FileUtils.mkdir_p(File.join(@repo, "bin"))
    FileUtils.install(file_fixture("stand_in.sh"), File.join(@repo, "bin", name), mode: 0o755)
  end

  def make_fail(name, output = "")
    File.write(File.join(@repo, "bin", "#{name}.fails"), output)
  end

  # Distinct content per file: identical (say, empty) files would let git's rename detection
  # pair a deletion with an unrelated new file, and the deletion would never show as one.
  def stage(*paths)
    paths.each do |path|
      file = File.join(@repo, path)
      FileUtils.mkdir_p(File.dirname(file))
      File.write(file, "# #{SecureRandom.hex(32)}\n")
    end
    git "add", "--", *paths
  end

  def commit(message)
    git "-c", "user.name=test", "-c", "user.email=test@example.invalid", "commit", "-q", "-m", message
  end

  def run_hook(name = "pre-commit")
    _output, error, status = Open3.capture3(clean_git_env, "bash", HOOKS.join(name).to_s, chdir: @repo)
    [ status.exitstatus, error ]
  end

  def calls
    log = File.join(@repo, "calls.log")
    return [] unless File.exist?(log)

    File.readlines(log, chomp: true).map { |line| line.split("\t") }
  end

  def calls_of(command)
    calls.filter_map { |name, *args| args if name == command }
  end

  def linted_files
    calls_of("rubocop").flatten.grep(/\.rb\z/)
  end

  def git(*args)
    _output, error, status = Open3.capture3(clean_git_env, "git", *args, chdir: @repo)
    assert status.success?, "git #{args.join(" ")} failed: #{error}"
  end

  # When the real pre-commit hook runs this suite, git has exported GIT_DIR and GIT_INDEX_FILE.
  # Every git call here is cleared of them, so it can only touch the throwaway repository.
  def clean_git_env
    ENV.keys.grep(/\AGIT_/).to_h { |key| [ key, nil ] }
  end
end
