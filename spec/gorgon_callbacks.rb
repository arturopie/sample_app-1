class MyCallbacks < Gorgon::DefaultCallbacks
  def before_originate
    puts "before job starts was called"
    "job1"
  end

  BUNDLE_LOG_FILE||="/tmp/gorgon-bundle-install.log "
  def after_sync
    require 'bundler'
    require 'open4'

    Bundler.with_clean_env do

      pid, stdin, stdout, stderr = Open4::popen4 "bundle install > #{BUNDLE_LOG_FILE} 2>&1 "

      ignore, status = Process.waitpid2 pid

      if status.exitstatus != 0
        raise "ERROR: 'bundle install' failed.\n#{stderr.read}"
      end
    end
  end

  def before_creating_workers
    ENV["TEST_ENV_NUMBER"] = Process.pid.to_s
    ENV["RAILS_ENV"] = 'remote_test'

    pid, stdin, stdout, stderr = Open4::popen4 "TEST_ENV_NUMBER=#{Process.pid.to_s} RAILS_ENV='remote_test' bundle exec rake db:setup"
    ignore, status = Process.waitpid2 pid

    if status.exitstatus != 0
      raise "ERROR: 'rake db:setup' failed.\n#{stderr.read}\n#{stdout.read}"
    end

    spec_helper_file = File.expand_path('../spec_helper.rb', __FILE__)
    test_helper_file = File.expand_path('../test_helper.rb', __FILE__)

    require spec_helper_file if File.exist?(spec_helper_file)
    require test_helper_file if File.exist?(test_helper_file)
  end

  def before_start
    require 'rake'
    load './Rakefile'

    begin
      Rails.env = 'remote_test'
      ENV['TEST_ENV_NUMBER'] = Process.pid.to_s

      Rake::Task['db:reset'].invoke
    end
  end

  def after_creating_workers
    require 'rake'
    load './Rakefile'

    begin
      if Rails.env = 'remote_test'
        Rake::Task['db:drop'].execute
      end
    rescue Exception => ex
      puts "Error dropping test database:\n  #{ex}"
    end
  end

  def after_complete
    puts "after complete callback"
  end

  def after_job_finishes
    puts "running after_job_finishes"
  end
end

Gorgon.callbacks = MyCallbacks.new