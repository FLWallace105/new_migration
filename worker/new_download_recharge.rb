#new_download_recharge.rb

require_relative 'background_full_subs'
require_relative 'background_full_customers'

require 'dotenv'
require 'resque'
require 'pg'
require "sinatra/activerecord"
require 'active_record'
#require 'pg'
require_relative '../models/subscription'
require_relative '../models/sub_line_item'
require_relative '../models/customer'


Dotenv.load




module DownloadRecharge
    class GetRechargeInfo
        def initialize
            recharge_regular = ENV['RECHARGE_ACCESS_TOKEN']
            @sleep_recharge = ENV['RECHARGE_SLEEP_TIME']
            @my_header = {
              "X-Recharge-Access-Token" => recharge_regular
            }
            
            @uri = URI.parse(ENV['DATABASE_URL'])
            #@conn = PG.connect(@uri.hostname, @uri.port, nil, nil, @uri.path[1..-1], @uri.user, @uri.password)
          end

          

          def get_full_subscriptions
            params = {"uri" => @uri, "headers" => @my_header}
            Resque.enqueue(SubsFullBackground, params)

          end


          class SubsFullBackground
            extend FullBackgroundSubs
            @queue = "subs_background_full"
            def self.perform(params)
              get_all_subs(params)
            end


          end

          def get_full_customers
            params = {"uri" => @uri, "headers" => @my_header}
            Resque.enqueue(CustFullBackground, params)

          end

          class CustFullBackground
            extend FullBackgroundCustomers
            @queue = "customers_background_full"
            def self.perform(params)
              get_background_full_customers(params)
            end

          end


    end
end