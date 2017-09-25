# encoding: UTF-8

require 'spec_helper'

describe Karma::Thread::ThreadPool do

  ['file', 'tcp'].shuffle.each do |config_engine|

    before(:each) do
      Karma.reset_engine_instance
      Karma.engine = 'systemd'
      Karma.config_engine = config_engine
      allow(Karma.engine_instance).to receive(:running_instances_for_service).and_return({ "karma-spec-test-service@8899.service" => Karma::Engine::ServiceStatus.new(nil, 8899, nil, $$) })
      new_config = TestService.set_process_config({num_threads: 2})
      Karma::ConfigEngine::ConfigImporterExporter.export_config(TestService, new_config)
    end

    def set_num_threads(service, num)
      new_config = service.class.set_process_config({num_threads: num})
      Karma::ConfigEngine::ConfigImporterExporter.export_config(service.class, new_config)
      Karma.config_engine_class.send_config(service.class)
    end  

    it 'spawns 2 threads and change at runtime' do
      service = TestService.new
      allow(service).to receive(:notify_status).and_return(true)
      ::Thread.new do
        service.run
      end
      wait_for{File.exists?('spec/log/testservice-after_start.log')}.to be_truthy
      wait_for{service.running_thread_count}.to eq(2)

      set_num_threads(service, 3)
      wait_for{service.running_thread_count}.to eq(3)

      set_num_threads(service, 1)
      wait_for{service.running_thread_count}.to eq(1)

      service.stop
      wait_for{service.running_thread_count}.to eq(0)
      wait_for{File.exists?('spec/log/testservice-after_stop.log')}.to be_truthy
    end

  end


end
