require "sequel"
require "pact_broker"

# pact_broker logs to stdout through SemanticLogger by default
app = PactBroker::App.new do |config|
  config.database_connection = Sequel.connect(ENV.fetch("PACT_BROKER_DATABASE_URL"), encoding: "utf8")
end

run app
