module Evals
  # The sandbox's own Postgres database. The test suite's parallel workers add theirs, named
  # <name>_0, <name>_1 and so on, so drop removes every database whose name starts with it.
  class Database
    # The Postgres from docker-compose.yml.
    SERVER = { host: "localhost", port: 5433, user: "postgres", password: "password" }.freeze

    attr_reader :name

    def initialize(name, server: SERVER)
      @name = name
      @server = server
    end

    def url
      "postgres://#{@server[:user]}:#{@server[:password]}@#{@server[:host]}:#{@server[:port]}/#{name}"
    end

    def drop
      connection = PG.connect(**@server, dbname: "postgres")
      names = connection.exec_params("SELECT datname FROM pg_database WHERE starts_with(datname, $1)", [ name ])
      # DROP DATABASE takes no bind parameters, so the name goes in quoted as an identifier.
      names.column_values(0).each { |database| connection.exec("DROP DATABASE #{connection.quote_ident(database)}") }
    rescue PG::Error => error
      warn "Could not drop the sandbox databases #{name}*: #{error.message}"
    ensure
      connection&.close
    end
  end
end
