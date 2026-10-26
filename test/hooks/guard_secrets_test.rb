require "test_helper"
require "open3"

# The secrets guard is a Claude Code PreToolUse hook: it reads the tool call as JSON on stdin
# and prints a deny decision, or prints nothing to let the call run.
class GuardSecretsTest < ActiveSupport::TestCase
  GUARD = Rails.root.join(".claude/hooks/guard_secrets.sh").to_s

  SECRET_READS = [
    "cat .env.deploy",
    "cat .ENV.DEPLOY",
    "wc -c config/master.key",
    "head config/credentials/production.key",
    "git show HEAD:.env.deploy",
    "bin/rails credentials:show",
    "cat ~/.ssh/id_ed25519",
    "cat ~/.aws/credentials"
  ].freeze

  test "denies shell commands that read a secret, in any letter case" do
    SECRET_READS.each { |command| assert_denied bash(command) }
  end

  test "denies file tools aimed at a secret" do
    assert_denied tool("Read", file_path: "/repo/config/master.key")
    assert_denied tool("Write", file_path: "config/master.key", content: "x")
    assert_denied tool("Glob", pattern: "config/master.key")
    assert_denied tool("Grep", pattern: "x", path: "config/master.key")
    assert_denied tool("Grep", pattern: "x", glob: "**/master.key")
  end

  test "lets the template and ordinary work through" do
    assert_allowed bash("cat .env.deploy.example")
    assert_allowed bash("bin/rails test")
    # File contents are not inspected, so docs that mention the key can still be edited.
    assert_allowed tool("Edit", file_path: "CLAUDE.md", old_string: "a", new_string: "master.key")
  end

  test "is a tripwire: a glob that never names the file gets through" do
    assert_allowed bash("cat .env.d*")
  end

  test "refuses every tool call when its input is broken" do
    status, error = run_guard('{"tool_name":')

    assert_equal 2, status
    assert_match "refusing the tool call", error
  end

  test "refuses every tool call when jq is missing" do
    status, error = run_guard(bash("ls").to_json, env: { "PATH" => "/var/empty" })

    assert_equal 2, status
    assert_match "jq is not installed", error
  end

  private

  def assert_denied(call)
    assert_equal "deny", decision(call), "expected #{call} to be denied"
  end

  def assert_allowed(call)
    assert_nil decision(call), "expected #{call} to pass"
  end

  # "deny", or nil when the guard prints nothing and lets the call run.
  def decision(call)
    status, _error, output = run_guard(call.to_json)

    assert_equal 0, status
    JSON.parse(output).dig("hookSpecificOutput", "permissionDecision") unless output.empty?
  end

  def run_guard(input, env: {})
    output, error, status = Open3.capture3(env, "/bin/bash", GUARD, stdin_data: input)
    [ status.exitstatus, error, output ]
  end

  def bash(command)
    tool("Bash", command: command)
  end

  def tool(name, **input)
    { tool_name: name, tool_input: input }
  end
end
