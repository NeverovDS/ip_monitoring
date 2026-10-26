namespace :agent do
  desc "Create the read-only database role for the coding agent's Postgres MCP server"
  task role: :environment do
    if AgentRole.applicable?
      AgentRole.apply!
      puts "The agent role ipmon_agent_ro is ready."
    else
      puts "Skipped: the agent role is only created for #{AgentRole::DATABASE} on localhost:#{AgentRole::PORT}."
    end
  end
end
