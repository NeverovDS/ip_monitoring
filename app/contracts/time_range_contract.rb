# frozen_string_literal: true

class TimeRangeContract < Dry::Validation::Contract
  params do
    optional(:time_from).maybe(:string)
    optional(:time_to).maybe(:string)
  end

  rule(:time_from) do
    parse_iso_and_report(value, :time_from)
  end

  rule(:time_to) do
    parse_iso_and_report(value, :time_to)
  end

  rule(:time_from, :time_to) do
    if values[:time_from] && values[:time_to]
      begin
        from = DateTime.iso8601(values[:time_from].strip)
        to   = DateTime.iso8601(values[:time_to].strip)
        key(:time_from).failure('must be earlier than time_to') if from > to
      rescue Date::Error
      end
    end
  end

  private

  def parse_iso_and_report(value, field)
    return if value.nil?

    DateTime.iso8601(value.strip)
  rescue Date::Error
    key(field).failure('must be in ISO8601 format, e.g. 2025-12-04T12:00:00')
    nil
  end
end
