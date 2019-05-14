#require_relative 'config/environment'
require 'sinatra/activerecord/rake'
require 'resque/tasks'
require 'active_record'
require 'pg'
require_relative 'migration'
#require_relative 'models/sub_line_item'


Dir['worker/**/*.rb'].each do |file|
  require_relative file
end



namespace :subsdownload do



desc 'do testing full pull of all subscriptions'
task :test_subscription_pull_full do |t|
  DownloadRecharge::GetRechargeInfo.new.get_full_subscriptions
end

desc 'do full background pull of customers'
task :background_customer_pull do |t|
  DownloadRecharge::GetRechargeInfo.new.get_full_customers
end

desc 'model testing active record'
task :active_record_test do |t|
    MigrationSub::SubUpdater.new.get_all_subscribers

end

desc 'setup subs table for migration to EllieStaging'
task :setup_subs_table do |t|
  MigrationSub::SubUpdater.new.setup_live_subs_migration
end

desc 'migrate subscriptions to EllieStaging'
task :migrate_subs do |t|
  MigrationSub::SubUpdater.new.migrate_live_subs
end

desc 'test method create subs'
task :test_create_subs do |t|
  MigrationSub::SubUpdater.new.test_recharge_create_sub
end

desc 'load migration product information table from csv'
task :load_migration_info do |t|
  MigrationSub::SubUpdater.new.load_migration_product_information
end

desc 'get info on a subscription'
task :get_info_subscription, [:args] do |t, args|
  MigrationSub::SubUpdater.new.retrieve_subscription_info(*args)

end


end

