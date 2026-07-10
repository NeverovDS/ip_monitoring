# frozen_string_literal: true

loader = Zeitwerk::Loader.new
loader.push_dir(File.expand_path('../', __dir__))
loader.collapse([
                  File.expand_path('../app/models', __dir__),
                  File.expand_path('../app/services', __dir__),
                  File.expand_path('../app/blueprints', __dir__),
                  File.expand_path('../app/contracts', __dir__),
                  File.expand_path('../app/workers', __dir__),
                  File.expand_path('../app/serializers', __dir__)
                ])
loader.setup
