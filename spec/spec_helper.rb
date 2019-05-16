# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'karmap'
require 'karmap/models/test_service'
require 'karmap/models/mock_service'
require 'rspec'
require 'rspec/wait'
require 'byebug'

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
  config.wait_timeout = 15 # seconds

  config.before(:each) do
    Karma.logger = Logger.new(
      'spec/log/test.log',
      Karma::LOGGER_SHIFT_AGE,
      Karma::LOGGER_SHIFT_SIZE,
      level: Logger::DEBUG,
      progname: 'karma-spec'
    )

    Karma.configuration do |config|
      config.env =                    'test'
      config.home_path =              ENV['TRAVIS_HOME_DIR'] || '/home/meox'
      config.project_name =           'karma-spec'
      config.karma_project_id =       'fake'
      config.karma_user_id =          'fake'
      config.aws_access_key_id =      'fake'
      config.aws_secret_access_key =  'fake'
      config.services =               %w[TestService MockService InvalidService]
      config.log_folder =             'spec/log'
      config.notifier =               'logger'
    end
  end

  config.before(:suite) do
    puts 'Clean log dir spec/log'
    begin
      FileUtils.rm_r('spec/log')
    rescue StandardError
      false
    end
    FileUtils.mkdir_p('spec/log')
    sleep 1
  end

  config.after(:suite) do
    File.delete('watchdog.run')
    File.delete('test_service.run')
  end
end
