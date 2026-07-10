# frozen_string_literal: true

require 'roda'
require 'json'
require 'dry-validation'
require 'sidekiq/web'

class API < Roda
  plugin :json
  plugin :json_parser
  plugin :all_verbs
  plugin :error_handler
  plugin :common_logger
  plugin :public

  # Базовые настройки
  plugin :default_headers, {
    'Content-Type' => 'application/json',
    'X-Content-Type-Options' => 'nosniff'
  }

  # Обработка ошибок
  error do |e|
    case e
    when Sequel::NoMatchingRow
      response.status = 404
      ErrorSerializer.new(code: 'not_found', message: 'Resource not found').call
    when JSON::ParserError
      response.status = 400
      ErrorSerializer.new(code: 'bad_request', message: 'Invalid JSON').call
    else
      puts "ERROR: #{e.class} — #{e.message}"
      puts e.backtrace.join("\n")

      response.status = 500
      ErrorSerializer.new(code: 'internal_error', message: e.message).call
    end
  end

  route do |r|
    r.root do
      { app: 'IP Monitor API', version: '1.0' }
    end

    # /ips маршруты
    r.on 'ips' do
      # GET /ips - список всех IP
      r.is do
        r.get do
          Ip.all.map { |ip| IpSerializer.new(ip).call }
        end

        # POST /ips - создать новый IP
        r.post do
          params = r.POST
          contract = IpContract.new.call(params)

          if contract.success?
            ip = Ip.create(contract.to_h)
            IpSerializer.new(ip).call
          else
            response.status = 422
            ErrorSerializer.new(code: 'validation_error', message: contract.errors.to_h).call
          end
        end
      end

      # /ips/:id маршруты
      r.on Integer do |id|
        ip = Ip.first!(id: id)

        r.is do
          # GET /ips/:id - получить IP
          r.get do
            IpSerializer.new(ip).call
          end

          # DELETE /ips/:id - удалить IP
          r.delete do
            ip.destroy
            response.status = 204
            nil
          end
        end

        # POST /ips/:id/enable - включить мониторинг
        r.post 'enable' do
          ip.update(enabled: true)
          response.status = 200
          { id: ip.id, enabled: true }
        end

        # POST /ips/:id/disable - выключить мониторинг
        r.post 'disable' do
          ip.update(enabled: false)
          response.status = 200
          { id: ip.id, disabled: true }
        end

        # GET /ips/:id/stats - статистика
        r.get 'stats' do
          params = r.GET
          contract = TimeRangeContract.new.call(
            time_from: params['time_from'],
            time_to: params['time_to']
          )

          if contract.success?
            stats = IpStatsService.new(ip.id, params['time_from'], params['time_to']).call
            IpStatsSerializer.new(stats).call
          else
            response.status = 422
            ErrorSerializer.new(code: 'validation_error', message: contract.errors.to_h).call
          end
        end
      end
    end
  end
end
