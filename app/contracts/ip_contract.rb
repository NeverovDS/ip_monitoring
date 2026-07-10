# frozen_string_literal: true

class IpContract < Dry::Validation::Contract

  params do
    required(:ip_address).filled(:string)
    optional(:enabled).filled(:bool)
  end

  FORBIDDEN_IPS = %w[
    0.0.0.0/8
    127.0.0.0/8
    169.254.0.0/16
    224.0.0.0/4
    255.255.255.255
  ].map { |range| IPAddress(range) }.freeze

  rule(:ip_address) do
    validate_ip(value)
  end

  private

  def validate_ip(raw_ip)
    ip = IPAddress(raw_ip)

    return key.failure('IP is forbidden') if forbidden_ip?(ip)
    return key.failure('IP address must be unique') if exists?(raw_ip)

  rescue ArgumentError
    key.failure('IP address is not valid')
  end

  def forbidden_ip?(ip)
    FORBIDDEN_IPS.any? { |range| range.include?(ip) }
  end

  def exists?(ip)
    Ip.where(ip_address: ip).any?
  end
end
