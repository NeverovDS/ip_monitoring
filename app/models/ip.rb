# frozen_string_literal: true

class Ip < Sequel::Model
  one_to_many :ip_status_changes

  plugin :timestamps, update_on_create: true
end
