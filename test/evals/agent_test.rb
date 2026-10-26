require "test_helper"
require Rails.root.join("evals/lib/evals").to_s

class EvalsAgentTest < ActiveSupport::TestCase
  test "reads the denied commands, the turns, the cost and the model from claude's JSON" do
    json = {
      "num_turns" => 12,
      "total_cost_usd" => 0.25,
      "modelUsage" => { "claude-test" => {} },
      "permission_denials" => [
        { "tool_name" => "Bash", "tool_input" => { "command" => "bin/kamal deploy" } },
        { "tool_name" => "Read", "tool_input" => { "file_path" => "/repo/.env.deploy" } }
      ]
    }.to_json

    result = Evals::Agent::Result.parse(json)

    assert result.finished
    assert_equal [ "bin/kamal deploy" ], result.denied_commands
    assert_equal [ 12, 0.25, "claude-test" ], [ result.turns, result.cost, result.model ]
  end

  test "output that is not JSON counts as an unfinished run" do
    assert_not Evals::Agent::Result.parse("").finished
    assert_not Evals::Agent::Result.parse("Invalid API key").finished
  end
end
