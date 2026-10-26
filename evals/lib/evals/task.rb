module Evals
  # One task from evals/tasks/<name>/: the prompt, what the agent may change and what the
  # result must contain. Hidden tests and an optional setup.rb sit next to task.yml.
  class Task
    DIR = File.join(ROOT, "evals/tasks")

    attr_reader :name

    def self.all
      Dir.children(DIR).sort.map { |name| new(name) }
    end

    def initialize(name, spec = nil)
      @name = name
      @spec = spec || YAML.load_file(File.join(dir, "task.yml"))
    end

    def prompt
      @spec.fetch("prompt")
    end

    # An entry ending in "/" allows everything under it, any other entry one exact file.
    def allowed_paths
      @spec.fetch("allowed_paths")
    end

    def require_test_change?
      @spec.fetch("require_test_change", false)
    end

    def must_contain
      @spec.fetch("must_contain", {})
    end

    def must_not_contain
      @spec.fetch("must_not_contain", {})
    end

    def hidden_tests
      @spec.fetch("hidden_tests", []).map { |file| File.join(dir, file) }
    end

    def setup_script
      path = File.join(dir, "setup.rb")
      path if File.exist?(path)
    end

    private

    def dir
      File.join(DIR, name)
    end
  end
end
