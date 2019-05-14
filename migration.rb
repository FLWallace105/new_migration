#migration.rb
require 'dotenv'
Dotenv.load
require 'httparty'
require 'resque'
require 'sinatra'
require 'active_record'
require "sinatra/activerecord"
require_relative 'models/subscription'
require_relative 'models/sub_line_item'
require_relative 'models/staging_subscription_migration'
require_relative 'models/migration_product_information'
require_relative 'lib/recharge_limit'
require 'stripe'
require 'recharge'
require 'shopify_api'




module MigrationSub
    class SubUpdater
      include ReChargeLimits


      def initialize
        Dotenv.load
        recharge_regular = ENV['RECHARGE_ACCESS_TOKEN']
        @recharge_key = ENV['RECHARGE_ACCESS_TOKEN']
        @sleep_recharge = ENV['RECHARGE_SLEEP_TIME']
        @my_header = {
          "X-Recharge-Access-Token" => recharge_regular
        }
        @my_change_charge_header = {
          "X-Recharge-Access-Token" => recharge_regular,
          "Accept" => "application/json",
          "Content-Type" =>"application/json"
        }
        recharge_staging = ENV['RECHARGE_STAGING_TOKEN']
        @customer_stripe = ENV['STRIPE_CUSTOMER_TOKEN_STAGING']
        @my_staging_change_header = {
          "X-Recharge-Access-Token" => recharge_staging,
          "Accept" => "application/json",
          "Content-Type" =>"application/json"
        }
  
        @api_key = ENV['SHOPIFY_API_KEY']
        @password = ENV['SHOPIFY_PASSWORD']
        @shop_name = ENV['SHOPIFY_SHOP_NAME']
        
      end


      def get_all_subscribers
        puts "Doing something"
        my_subs = Subscription.all
        puts my_subs.inspect
        my_subs.each do |sub|
          puts sub.inspect
        end
        puts "Done doing something"
      end


      def setup_live_subs_migration
        puts "Setting up live subs to be migrated"
        #All active subs
        StagingSubscriptionMigration.delete_all
        # Now reset index
        ActiveRecord::Base.connection.reset_pk_sequence!('staging_subscriptions_migration')

        staging_subs_migration = "insert into staging_subscriptions_migration (subscription_id, customer_id, address_id, created_at, updated_at, next_charge_scheduled_at, product_title, price, quantity, status, sku, shopify_product_id, shopify_variant_id, raw_line_item_properties, order_interval_unit, order_interval_frequency, charge_interval_frequency, order_day_of_month, order_day_of_week, expire_after_specific_number_charges) select subscription_id, customer_id, address_id, created_at, updated_at, next_charge_scheduled_at, product_title, price, quantity, status, sku, shopify_product_id, shopify_variant_id, raw_line_item_properties, order_interval_unit, order_interval_frequency, charge_interval_frequency, order_day_of_month, order_day_of_week, expire_after_specific_number_charges from subscriptions where status = 'ACTIVE'  and (shopify_product_id = \'2339797532730\' or shopify_product_id = \'2340064526394\' or shopify_product_id = \'2372785340474\' or shopify_product_id = \'2294128738362\' or shopify_product_id = \'2294131458106\' or shopify_product_id = \'2294127558714\' or shopify_product_id = \'2372787535930\' or shopify_product_id = \'2294127558714\'  or shopify_product_id = \'2294130999354\' or shopify_product_id = \'2372783145018\' or shopify_product_id = \'2339796320314\' or shopify_product_id = \'2339790127162\' or shopify_product_id = \'2372785438778\' or shopify_product_id = \'2372785340474\' or shopify_product_id = \'2267637678138\' or shopify_product_id = \'2294123954234\' or shopify_product_id = \'2372780752954\' or shopify_product_id = \'9175678162\' or shopify_product_id = \'2372785438778\' or shopify_product_id = \'2340063969338\' or shopify_product_id = \'2372783145018\' or shopify_product_id = \'2339789013050\' or shopify_product_id = \'2372786290746\' or shopify_product_id = \'2338694234170\' or shopify_product_id = \'2294130999354\' or shopify_product_id = \'2372786290746\' or shopify_product_id = \'2267622539322\' or shopify_product_id = \'23729012754\'  or shopify_product_id = \'23729012754\' or shopify_product_id = \'2294128738362\'  or shopify_product_id = \'8204555081\' or shopify_product_id = \'2267632697402\' or shopify_product_id = \'2372780916794\'  or shopify_product_id = \'2294128738362\' or shopify_product_id = \'2340061052986\'  or shopify_product_id = \'2372780752954\' or shopify_product_id = \'2294123954234\' or shopify_product_id = \'2372787535930\' or shopify_product_id = \'2372782751802\' or shopify_product_id = \'2267625160762\' or shopify_product_id = \'2209786298426\' or shopify_product_id = \'2209789771834\' or shopify_product_id = \'2340064526394\')"

        ActiveRecord::Base.connection.execute(staging_subs_migration)
        puts "All done setting up subs table for migration to EllieStaging"
      
      end


      def recharge_create_customer(sub)
        customer_id = sub.customer_id
        #puts customer_id
        my_customer = Customer.find_by_customer_id(customer_id)
        #puts my_customer.inspect
        real_email = my_customer.email
        fake_email = real_email.gsub(/@\S+/i, "@zobha.com")
        #puts "#{real_email} --> #{fake_email}"
        #create customer object 
        mybody = {"email" => fake_email,
          "first_name" => my_customer.first_name,
          "last_name" => my_customer.last_name,
          "billing_first_name" => my_customer.first_name,
          "billing_last_name" => my_customer.last_name,
          "billing_address1" => my_customer.billing_address1,
          "billing_address2" => my_customer.billing_address2,
          "billing_zip" => my_customer.billing_zip,
          "billing_city" => my_customer.billing_city,
          "billing_province" => my_customer.billing_province,
          "billing_country" => my_customer.billing_country,
          "billing_phone" => my_customer.billing_phone,
          "stripe_customer_token" => @customer_stripe}.to_json

          create_customer = HTTParty.post("https://api.rechargeapps.com/customers", :body => mybody, :headers => @my_staging_change_header)
          recharge_limit = create_customer.response["x-recharge-limit"]
          determine_limits(recharge_limit, 0.65)

          puts create_customer.inspect
          
          if create_customer.code == 200
            customer_id = create_customer.parsed_response['customer']['id']
            customer_creation_status = {"status" => true, "real_email" => real_email, "customer_id" => customer_id}
            return customer_creation_status
          else
            customer_creation_status = {"status" => false}
            return customer_creation_status

          end

      end

      def recharge_create_addess(mysub, customer_id)
        #POST /customers/<int:customer_id>/addresses
        local_customer_id = mysub.customer_id
        #puts customer_id
        my_customer = Customer.find_by_customer_id(local_customer_id)

        my_address = {"address1" => my_customer.billing_address1,
          "address2" => my_customer.billing_address2,
          "city" => my_customer.billing_city,
          "province" => my_customer.billing_province,
          "first_name" => my_customer.first_name,
          "last_name" => my_customer.last_name,
          "zip" => my_customer.billing_zip,
          "company" => my_customer.billing_company,
          "phone" => my_customer.billing_phone,
          "country" => my_customer.billing_country,
          "shipping_lines_override" => nil }.to_json
  
          create_address = HTTParty.post("https://api.rechargeapps.com/customers/#{customer_id}/addresses", :body => my_address, :headers => @my_staging_change_header)
          recharge_limit = create_address.response["x-recharge-limit"]
          determine_limits(recharge_limit, 0.65)
          puts "--- Address Creation ---"
          puts create_address.inspect
          puts "------------------------"

          if create_address.code == 200
            address_id = create_address.parsed_response['address']['id']
            address_creation_status = {"status" => true, "address_id" => address_id}
            return address_creation_status
          else
            address_creation_status = {"status" => false}
            return customer_creation_status

          end
  
      end

      def determine_next_charge(scheduled_at)
        puts "scheduled_at = #{scheduled_at}"
        scheduled_at_str = scheduled_at.strftime('%Y-%m-%d %H:%M:%S %Z')
        puts scheduled_at_str
        
        new_scheduled_at = DateTime.strptime(scheduled_at_str, '%Y-%m-%d %H:%M:%S %Z')
        puts new_scheduled_at.class
        my_now = DateTime.now
        #new_scheduled_at = DateTime.parse(scheduled_at.to_s)
        if new_scheduled_at <= my_now
          puts "Need to adjust"
          new_scheduled_at = new_scheduled_at >> 1
        else
          puts "Don't need to adjust"
          new_scheduled_at = new_scheduled_at
        end
        return new_scheduled_at

      end

      def determine_product_info(my_sub)
        puts my_sub.inspect
        new_product_information = MigrationProductInformation.find_by_shopify_product_id(my_sub.shopify_product_id)
        if !new_product_information.nil?
          #puts new_product_information.inspect
          return new_product_information
        else
          puts "Can't find product info"
          return nil
        end


      end

      def update_sub_properties(local_properties, local_product_information, real_email)
        local_properties = local_properties << {"name" => "real_email", "value" => real_email}
        puts local_properties.inspect
        puts local_product_information.inspect
        my_index = 0
        
        local_properties.map do |stuff|
          if stuff['name'] == 'product_collection'
            stuff['value'] = local_product_information.staging_product_collection
            
          end

          if stuff['name'] == "product_id"
            local_properties.delete_at(my_index)

          end
          my_index += 1


          #puts stuff.inspect
        end
        #puts local_properties.inspect
        return local_properties

      end


      def recharge_create_subscription(my_sub, address_id, customer_id, real_email)
        #POST /addresses/<address_id>/subscriptions
        
        puts my_sub.inspect
        local_next_charge_scheduled_at = determine_next_charge(my_sub.next_charge_scheduled_at)
        puts "New Scheduled_at = #{local_next_charge_scheduled_at}"

        local_product_information = determine_product_info(my_sub)
        if !local_product_information.nil?
          puts local_product_information.inspect
        else
          puts "Not proceeding with creating this subscription lacking product info for staging"
        end
        #puts my_sub.price
        new_sub_properties = update_sub_properties(my_sub.raw_line_item_properties, local_product_information, real_email)
        puts new_sub_properties.inspect

        exit
  
        new_sub = { "address_id": address_id,
          "customer_id": customer_id,
          "next_charge_scheduled_at": local_next_charge_scheduled_at,      
          "product_title": local_product_information.staging_product_title,
          "price": my_sub.price,
          "quantity": my_sub.quantity,
          "status": "ACTIVE",
          "shopify_product_id": local_product_information.staging_product_id,
          "shopify_variant_id": local_product_information.staging_variant_id,
          "sku" => local_product_information.staging_sku,
          "sku_override" => false,
          "order_interval_unit" => my_sub.order_interval_unit,
          "order_interval_frequency" => my_sub.order_interval_frequency,
          
          "charge_interval_frequency" => my_sub.charge_interval_frequency,
          "properties" => new_sub_properties }.to_json
        
        create_sub = HTTParty.post("https://api.rechargeapps.com/addresses/#{address_id}/subscriptions", :body => new_sub, :headers => @my_staging_change_header)
        recharge_limit = create_sub.response["x-recharge-limit"]
        determine_limits(recharge_limit, 0.65)
        puts create_sub.inspect
        if create_sub.code == 200
          sub_id = create_address.parsed_response['subscription']['id']
          sub_creation_status = {"status" => true, "subscription_id" => sub_id}
          return sub_creation_status
        else
          sub_creation_status = {"status" => false}
          return sub_creation_status

        end
  
  
      end


      def migrate_live_subs
        my_start_time = Time.now
        my_subs_to_migrate = StagingSubscriptionMigration.where("migrated = ?", false)
        my_subs_to_migrate.each do |mysub|
          puts mysub.inspect
          customer_creation_status = recharge_create_customer(mysub)
          puts customer_creation_status
          if customer_creation_status['status'] == true
            real_email = customer_creation_status['real_email']
            customer_id = customer_creation_status['customer_id']
            address_creation_status = recharge_create_addess(mysub, customer_id)
            puts address_creation_status
            if address_creation_status['status'] == true
              address_id = address_creation_status['address_id']
              subscription_creation_status = recharge_create_subscription(mysub, address_id, customer_id, real_email)
              #mark subscription as done
              mysub.migrated = true
              time_updated = DateTime.now
              time_updated_str = time_updated.strftime("%Y-%m-%d %H:%M:%S")
              mysub.date_migrated = time_updated_str
              mysub.save


              my_duration = (Time.now - my_start_time ).ceil
                puts "Been running #{my_duration}"
                if my_duration > 480
                    puts "Ran 8 minutes, exiting"
                    break
                end

            else
              puts "can't create address, skipping this subscription"
            end

          else
            puts "could not create customer, skipping this subscription"
          end
          exit
        end


      end

      
      def test_recharge_create_sub
        mysub = StagingSubscriptionMigration.where("migrated = ? ", false).first
        address_id = 32578108
        customer_id = 28944513
        real_email = "jshima12@gmail.com"
        subscription_creation_status = recharge_create_subscription(mysub, address_id, customer_id, real_email)


      end

      def load_migration_product_information
        MigrationProductInformation.delete_all
        ActiveRecord::Base.connection.reset_pk_sequence!('migration_product_information')

        CSV.foreach('migration_set_up.csv', :encoding => 'ISO-8859-1', :headers => true) do |row|
          puts row.inspect
          MigrationProductInformation.create(product_title: row['product_title'], shopify_product_id: row['shopify_product_id'], staging_product_title: row['staging_product_title'], staging_product_id: row['staging_product_id'], staging_variant_id: row['staging_variant_id'], staging_sku: row['staging_sku'],  staging_product_collection: row['staging_product_collection'])
        end


      end
      



    end
end