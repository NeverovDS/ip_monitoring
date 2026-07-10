# frozen_string_literal: true

class IpStatusChange < Sequel::Model
  many_to_one :ip

  plugin :timestamps, update_on_create: true
end
