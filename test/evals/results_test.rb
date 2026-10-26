require "test_helper"
require "tempfile"
require Rails.root.join("evals/lib/evals").to_s

class EvalsResultsTest < ActiveSupport::TestCase
  ROW = "| 2026-10-27 | example | claude-test | FAIL 1/2 | 7 | $0.43 | only allowed files changed: a/b |".freeze

  test "a row shows the verdict, the cost and the failed checks" do
    assert_equal ROW, Evals::Results.new.row(task, result, checks, date: Date.new(2026, 10, 27))
  end

  test "a run appends its row and leaves the rest of the file as it was" do
    Tempfile.create("results.md") do |file|
      file.write("| Date | Task |\n")
      file.close

      Evals::Results.new(file.path).append(task, result, checks, date: Date.new(2026, 10, 27))

      assert_equal [ "| Date | Task |", ROW ], File.readlines(file.path, chomp: true)
    end
  end

  private

  def task
    Evals::Task.new("example", { "prompt" => "Fix it.", "allowed_paths" => [ "app/" ] })
  end

  def result
    Evals::Agent::Result.new(finished: true, denied_commands: [], turns: 7, cost: 0.4321, model: "claude-test")
  end

  def checks
    [
      Evals::Grader::Check.new(key: :suite_green, label: "full suite green", passed: true, detail: ""),
      Evals::Grader::Check.new(key: :only_allowed_files, label: "only allowed files changed", passed: false, detail: "a|b")
    ]
  end
end
