module Evals
  # evals/results.md: a Markdown table with one row per run. The file and its header are in
  # the repository, so a run only appends its row.
  class Results
    PATH = File.join(ROOT, "evals/results.md")

    def initialize(path = PATH)
      @path = path
    end

    def append(task, result, checks, date: Date.today)
      line = row(task, result, checks, date: date)
      File.write(@path, "#{line}\n", mode: "a")
      line
    end

    def row(task, result, checks, date:)
      cells = [
        date.iso8601,
        task.name,
        result.model || "unknown",
        verdict(checks),
        result.turns || "?",
        format("$%.2f", result.cost.to_f),
        failed_checks(checks)
      ]
      "| #{cells.join(" | ")} |"
    end

    private

    def verdict(checks)
      passed = checks.count(&:passed)
      "#{passed == checks.size ? "PASS" : "FAIL"} #{passed}/#{checks.size}"
    end

    def failed_checks(checks)
      failed = checks.reject(&:passed).map { |check| [ check.label, check.detail ].reject(&:empty?).join(": ") }
      failed.empty? ? "—" : failed.join("; ").tr("|", "/")
    end
  end
end
