# encoding: UTF-8

require 'spec_helper'

describe Karma::Engine::Base do

  [Karma::Engine::Systemd, Karma::Engine::SystemRaw].each do |engine_class|
    let(:engine) { ret = engine_class.new; Karma.engine = ret.config_name; ret }

    before(:each) { engine.export_service(TestService) }
    after(:each) do
      status = engine.show_all_services
      status.values.each do |s|
        engine.stop_service(s.pid)
        sleep(2)
      end
    end
    before(:each) { engine.remove_service(TestService) }

    it 'build service status message' do
      engine.start_service(TestService)
      wait_for {engine.show_service(TestService)}.to_not be_empty
      status = engine.show_service(TestService)
      pid = status.values[0].pid
      message = engine.get_process_status_message(TestService, pid)
      expect(message.service).to eq('TestService')
      expect(message.pid).to eq(pid)
      expect(message.status).to eq('running')

      engine.stop_service(pid)
      wait_for{engine.show_service(TestService)}.to be_empty
      message = engine.get_process_status_message(TestService, pid)
      expect(message.status).to eq('dead')
    end
  end

end
