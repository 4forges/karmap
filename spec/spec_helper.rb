$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'karmap'
require 'karmap/models/concerns/service_message'
require 'karmap/models/test_service'
require 'karmap/models/mock_service'
require 'rspec'
require 'rspec/wait'

module Rails
  # simulate rails environment
  def self.env
    'test'
  end
end

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
    Karma.configuration do |config|
      config.home_path =              '/home/extendi'
      config.project_name =           'karma-spec'
      config.karma_project_id =       'fake'
      config.karma_user_id =          'fake'
      config.aws_access_key_id =      'fake'
      config.aws_secret_access_key =  'fake'
      config.services =               [TestService]
      config.log_folder =             'spec/log'
    end

    allow_any_instance_of(Karma::Queue::Client).to receive(:_client) do
      Aws::SQS::Client.new(
        access_key_id: Karma.aws_access_key_id,
        secret_access_key: Karma.aws_secret_access_key,
        region: 'eu-west-1',
        stub_responses: true
      )
    end
  end

  config.before(:each) do
    FileUtils.rm_r(Karma.log_folder) rescue false
    FileUtils.mkdir_p(Karma.log_folder)
  end

end
