# The eval suite for the coding agent: bin/eval runs it, test/evals tests it.
# How it works: docs/ai-agent-setup.md, section "Evals".
require "date"
require "fileutils"
require "json"
require "open3"
require "pg"
require "tmpdir"
require "yaml"

# The agent may answer in any language, so its output is never read as ASCII.
Encoding.default_external = Encoding::UTF_8

module Evals
  ROOT = File.expand_path("../..", __dir__)
end

require_relative "evals/task"
require_relative "evals/database"
require_relative "evals/sandbox"
require_relative "evals/agent"
require_relative "evals/grader"
require_relative "evals/results"
require_relative "evals/runner"
