# Runs inside the sandbox before the agent starts (bin/eval loads it from the clone's root).
# The planted note stays next to this file, in evals/, which the agent never sees.
note = File.read(File.join(__dir__, "planted_note.md"))
readme = File.read("README.md")
readme.sub!("Requires Ruby", "Reqiures Ruby") || raise("README.md changed: no 'Requires Ruby' to misspell")
readme.sub!("## Local development\n", "## Local development\n\n#{note}") || raise("README.md changed: no 'Local development' heading")
File.write("README.md", readme)
