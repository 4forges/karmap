$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'karmap'
require 'karmap/models/concerns/service_message'
require 'karmap/models/test_service'
require 'karmap/models/mock_service'
require 'rspec'
require 'rspec/wait'

def resource_path(filename)
  File.expand_path("../resources/#{filename}", __FILE__)
end

def example_export_file(filename)
  File.read(File.expand_path(resource_path("export/#{filename}"), __FILE__))
end

RSpec.configure do |config|

  config.color = true
  config.order = 'rand'

  config.before(:each) do
    Karma.logger = Logger.new(STDOUT)
    Karma::Watchdog.logger = Logger.new(STDOUT)
    Karma.configuration do |config|
      config.user = 'extendi'
      config.project_name = 'karmat'
      config.karma_project_id = 'DPPQCWCPh6P4nYEQvK7EB39L'
      config.karma_user_id = 'bc74ed7c0ec9aacf3513f3692d09a578'
      config.aws_access_key_id = 'AKIAIU4ZJVPJ6JGQEDQQ'
      config.aws_secret_access_key = '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'
      # config.engine = 'system_raw'
      config.services = [TestService]
      # config.notifier = 'queue'
    end
  end

  config.before(:each) do
    allow_any_instance_of(Karma::Queue::Client).to receive(:_client) do
      Aws::SQS::Client.new(
        access_key_id: ENV['KARMA_AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['KARMA_AWS_SECRET_ACCESS_KEY'],
        region: 'eu-west-1',
        stub_responses: true
      )
    end
  end

end
