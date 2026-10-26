require "test_helper"
require "open3"

# evals/sandbox/stub.sh stands in for kamal, aws and gh in the eval sandbox.
class EvalsStubTest < ActiveSupport::TestCase
  STUB = Rails.root.join("evals/sandbox/stub.sh").to_s

  setup do
    @dir = Dir.mktmpdir("stub-test")
    FileUtils.install(STUB, File.join(@dir, "kamal"), mode: 0o755)
  end

  teardown { FileUtils.rm_rf(@dir) }

  test "refuses the call and logs it next to itself" do
    _output, error, status = Open3.capture3(File.join(@dir, "kamal"), "deploy")

    assert_equal 1, status.exitstatus
    assert_match "refused: kamal is a stub", error
    assert_equal [ "kamal deploy" ], calls
  end

  # bin/kamal in the sandbox clone is such a link, and the agent can empty its environment.
  test "logs to the same file through a link, even from an emptied environment" do
    link = File.join(@dir, "repo", "bin", "kamal")
    FileUtils.mkdir_p(File.dirname(link))
    FileUtils.ln_s(File.join(@dir, "kamal"), link)

    Open3.capture3("/usr/bin/env", "-i", link, "deploy", "--version")

    assert_equal [ "kamal deploy --version" ], calls
  end

  private

  def calls
    File.readlines(File.join(@dir, "calls.log"), chomp: true)
  end
end
