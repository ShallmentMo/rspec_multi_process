# put this file in rails_project/lib/tasks/rspec_multi_process.rake
# run as "rake rspec:multi_process RAILS_ENV=test"

namespace :rspec do
  desc "run rspec test by multi process"
  task :multi_process => :environment do
    start_time = Time.now()
    puts "start_time: #{start_time}"
    N_PROCESSES = 2
    specs = (Dir["./spec/**/*_spec.rb"]).sort.in_groups_of(N_PROCESSES)
    processes = []

    interrupt_handler = lambda do
      STDERR.puts "caught keyboard interrupt, exiting gracefully ..."
      processes.each { |process| Process.kill "KILL", process }
      exit 1
    end
    Signal.trap 'SIGINT', interrupt_handler
    files = {}

    1.upto(N_PROCESSES) do |j|
      processes << Process.fork {
        # connecting to in-memory database ...
        ActiveRecord::Base.establish_connection({'database' => ':memory:', 'adapter' => 'sqlite3'})
        # building in-memory database from db/schema.rb ...
        load "#{Rails.root}/db/schema.rb"
        # use migrations
        ActiveRecord::Migrator.up('db/migrate')

        files[j] = []
        specs.each do |array|
          if array[j-1]
            files[j] << array[j-1]
          end
        end
        puts files[j].size
        RSpec::Core::Runner.run(files[j], $stderr, $stdout)
      }
    end
    1.upto(N_PROCESSES) do |pid|
      puts "parent, pid #{Process.pid}, waiting on child pid #{processes[pid-1]}"
      Process.wait

      puts "end_time: #{Time.now}"
      puts "time: " + (Time.now() - start_time).to_s
    end
  end
end
