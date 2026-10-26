require "test_helper"
require Rails.root.join("evals/lib/evals").to_s

# A whole sandbox clones the repository, so this runs a command in an empty one instead.
class EvalsSandboxTest < ActiveSupport::TestCase
  SECRETS = { "GH_TOKEN" => "gh-test-token", "SSH_AUTH_SOCK" => "/tmp/agent.sock", "AWS_PROFILE" => "production" }.freeze

  setup do
    @dir = Dir.mktmpdir("sandbox-test")
    FileUtils.mkdir_p(File.join(@dir, "repo"))
    @sandbox = Evals::Sandbox.new(Evals::Task.new("example", {}), @dir)
  end

  teardown { FileUtils.rm_rf(@dir) }

  test "a command sees only the allowlisted environment, and its output goes to the command log" do
    with_env(SECRETS) { assert @sandbox.succeeds?("env") }

    names = File.readlines(@sandbox.command_log, chomp: true).drop(1).map { |line| line.split("=").first }
    assert_empty names & SECRETS.keys
    assert_includes names, "HOME"
    assert_includes names, "DATABASE_URL"
  end

  private

  def with_env(variables)
    previous = ENV.to_h.slice(*variables.keys)
    variables.each { |name, value| ENV[name] = value }
    yield
  ensure
    variables.each_key { |name| ENV[name] = previous[name] }
  end
end
