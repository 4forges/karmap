require './spec/karmap/models/test_service'

Karma.logger = Logger.new(
  'spec/log/test.log',
  Karma::LOGGER_SHIFT_AGE,
  Karma::LOGGER_SHIFT_SIZE,
  level: Logger::DEBUG,
  progname: 'karma-spec'
)
Karma.configuration do |config|
  config.home_path =              ENV['TRAVIS_BUILD_DIR'] || '/home/extendi'
  config.project_name =           'karma-spec'
  config.engine =                 'system_raw'
  config.karma_project_id =       'fake'
  config.karma_user_id =          'fake'
  config.aws_access_key_id =      'fake'
  config.aws_secret_access_key =  'fake'
  config.services =               [TestService]
  config.log_folder =             'spec/log'
  config.notifier =               'logger'
end

TestService.new.run
