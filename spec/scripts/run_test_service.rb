require './spec/karmap/models/test_service'

Karma.logger = Logger.new(STDOUT)
Karma.configuration do |config|
  config.home_path =              ENV['TRAVIS_BUILD_DIR']
  config.project_name =           'karma-spec'
  config.karma_project_id =       'fake'
  config.karma_user_id =          'fake'
  config.aws_access_key_id =      'fake'
  config.aws_secret_access_key =  'fake'
  config.services =               [TestService]
  config.log_folder =             'spec/log'
  config.notifier =               'logger'
end

TestService.new.run
