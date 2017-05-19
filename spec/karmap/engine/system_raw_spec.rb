# encoding: UTF-8

require 'spec_helper'

describe Karma::Engine::SystemRaw do

  let(:watchdog) { Karma::Watchdog.new }

  before(:each) { Karma.engine = 'system_raw' }
  before(:each) { Karma.engine_instance.remove_service(TestService) }

  context 'manage service instances' do

    after(:each) do
      status = Karma.engine_instance.show_all_services
      status.values.each do |s|
        Karma.engine_instance.stop_service(s.pid)
        sleep(1)
      end
    end

    it 'engine starts service instance' do
      Karma.engine_instance.start_service(TestService)
      wait_for {Karma.engine_instance.show_service(TestService)}.to_not be_empty
      status = Karma.engine_instance.show_service(TestService)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000')
      expect(status.values[0].name).to eq('karma-spec-test-service')
      expect(status.values[0].port).to eq(33000)
      expect(status.values[0].status).to eq('running')
      expect(status.values[0].pid).to be > 1
    end

    it 'engine stops service instance' do
      Karma.engine_instance.start_service(TestService)
      wait_for {Karma.engine_instance.show_service(TestService)}.to_not be_empty
      status = Karma.engine_instance.show_service(TestService)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000')
      expect(status.values[0].status).to eq('running')
      pid = status.values[0].pid

      Karma.engine_instance.stop_service(pid)
      wait_for{Karma.engine_instance.show_service(TestService)}.to be_empty
      status = Karma.engine_instance.show_service(TestService)
      expect(status.size).to eq(0)
    end

    it 'engine restarts service instance' do
      Karma.engine_instance.start_service(TestService)
      wait_for {Karma.engine_instance.show_service(TestService)}.to_not be_empty
      status = Karma.engine_instance.show_service(TestService)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000')
      expect(status.values[0].status).to eq('running')
      old_pid = status.values[0].pid

      Karma.engine_instance.restart_service(old_pid, { service: TestService })
      wait_for {Karma.engine_instance.show_service(TestService)}.to_not be_empty
      status = Karma.engine_instance.show_service(TestService)
      expect(status.size).to eq(1)
      expect(status.keys[0]).to eq('karma-spec-test-service@33000')
      expect(status.values[0].status).to eq('running')
      new_pid = status.values[0].pid

      expect(new_pid).to_not eq(old_pid)
    end

  end

end
