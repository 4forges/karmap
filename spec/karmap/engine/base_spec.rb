# encoding: UTF-8

require 'spec_helper'

shared_examples 'messages' do |type|
  before(:each) do
    Karma.reset_engine_instance
    Karma.engine = type
    Karma.engine_instance.export_service(TestService)
  end

  after(:each) do
    status = Karma.engine_instance.show_all_services
    status.values.each do |s|
      Karma.engine_instance.stop_service(s.pid)
    end
    Karma.engine_instance.remove_service(TestService)
  end

  it 'check engine instance' do
    expect(Karma.engine_instance.class).to eq(Karma.engine_class)
  end

  it 'build service status message' do
    Karma.engine_instance.start_service(TestService, check: true)
    status = Karma.engine_instance.show_service(TestService)
    pid = status.values[0].pid
    message = Karma.engine_instance.get_process_status_message(TestService, pid)
    expect(message.service).to eq('TestService')
    expect(message.pid).to eq(pid)
    expect(message.status).to eq('running')

    Karma.engine_instance.stop_service(pid)
    message = Karma.engine_instance.get_process_status_message(TestService, pid)
    expect(message.status).to eq('dead')
  end
end

describe Karma::Engine::Base do

  describe 'using systemd' do
    include_examples 'messages', 'systemd'
  end

  describe 'using system_raw' do
    include_examples 'messages', 'system_raw'
  end

end
