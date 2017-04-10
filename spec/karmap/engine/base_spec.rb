# encoding: UTF-8

require 'spec_helper'

describe Karma::Engine::Base do

  [Karma::Engine::Systemd, Karma::Engine::SystemRaw].each do |engine_class|
    let(:service) { TestService.new }
    let(:engine) { engine_class.new }

    before(:each) { engine.export_service(service) }
    after(:each) do
      status = engine.show_all_services
      status.values.each do |s|
        engine.stop_service(s.pid)
        sleep(1)
      end
    end

    it 'build service status message from instance' do
      engine.start_service(service)
      wait_for {engine.show_service(service)}.to_not be_empty
      status = engine.show_service(service)
      pid = status.values[0].pid
      message = engine.get_process_status_message(service, pid)
      expect(message.service).to eq('TestService')
      expect(message.pid).to eq(pid)
      expect(message.status).to eq('running')

      engine.stop_service(pid)
      wait_for{engine.show_service(service)}.to be_empty
      message = engine.get_process_status_message(service, pid)
      expect(message.status).to eq('dead')
    end

    it 'build service status message from string' do
      service_name = service.full_name
      expect(service_name).to eq('karma-spec-test-service')
      message = engine.get_process_status_message(service_name, 1234)
      expect(message.service).to eq('TestService')
      expect(message.status).to eq('dead')
    end
  end

end
