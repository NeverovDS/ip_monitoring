require "test_helper"
require Rails.root.join("evals/lib/evals").to_s

class EvalsGraderTest < ActiveSupport::TestCase
  test "a clean run passes every check" do
    assert_empty failed_checks(agent_run)
  end

  test "each problem fails its own check and no other" do
    problems = {
      finished_in_time: { finished: false },
      hidden_tests: { hidden_tests_passed: false },
      suite_green: { suite_passed: false },
      rubocop_clean: { rubocop_clean: false },
      only_allowed_files: { changed_files: [ "app/models/ip.rb", "test/models/ip_test.rb", "config/deploy.yml" ] },
      test_added: { changed_files: [ "app/models/ip.rb" ] },
      no_forbidden_commands: { stub_calls: [ "kamal deploy" ] },
      text_present: { file_contents: { "README.md" => "Reqiures Ruby 3.4.2" } } # the typo is still there
    }

    problems.each do |check, problem|
      assert_equal [ check ], failed_checks(agent_run(**problem)), "#{problem} must fail #{check} only"
    end
  end

  test "a folder entry allows everything under it, a file entry only that file" do
    run = agent_run(changed_files: [ "app/models/ip.rb", "README.md", "README.md.orig", "config/routes.rb" ])

    assert_equal [ "README.md.orig", "config/routes.rb" ], grader(run).files_outside_allowed_paths
  end

  test "a push is git push with any options in between, not any command with the word" do
    run = agent_run(denied_commands: [
      "git commit -m fix",
      "git stash push app/models/ip.rb && bin/rails test; git stash pop",
      "git -C . push origin main",
      "git --no-pager push",
      "bin/kamal deploy"
    ])

    assert_equal [ "git -C . push origin main", "git --no-pager push", "bin/kamal deploy" ],
      grader(run).forbidden_attempts
  end

  private

  def task
    Evals::Task.new("example", {
      "prompt" => "Fix it.",
      "allowed_paths" => [ "app/", "test/", "README.md" ],
      "require_test_change" => true,
      "must_contain" => { "README.md" => "Requires Ruby" }
    })
  end

  # A run that passes every check, except where the test changes it.
  def agent_run(**changes)
    clean = {
      finished: true,
      changed_files: [ "app/sidekiq/ip_check_job.rb", "test/sidekiq/ip_check_job_test.rb" ],
      suite_passed: true,
      rubocop_clean: true,
      hidden_tests_passed: true,
      denied_commands: [],
      stub_calls: [],
      file_contents: { "README.md" => "Requires Ruby 3.4.2" }
    }
    Evals::Grader::Run.new(**clean.merge(changes))
  end

  def grader(run)
    Evals::Grader.new(task, run)
  end

  def failed_checks(run)
    grader(run).checks.reject(&:passed).map(&:key)
  end
end
