require './spec/karmap/models/test_service'

Karma.logger = Logger.new($stdout)
Karma.configuration do |config|
  config.user = 'extendi'
  config.project_name = 'karmat'
  config.karma_project_id = ''
  config.karma_user_id = ''
  config.aws_access_key_id = ''
  config.aws_secret_access_key = ''
  config.services = [TestService]
  config.log_folder = 'spec/log'
end

TestService.new.run
