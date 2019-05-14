class CreateMigrationSetupTable < ActiveRecord::Migration[5.2]
  def up
    create_table :migration_product_information do |t|
      t.string :product_title
      t.string :shopify_product_id
      t.string :staging_product_title
      t.string :staging_product_id
      t.string :staging_variant_id
      t.string :staging_sku
      t.string :staging_product_collection

    end

  end

  def down
    drop_table :migration_product_information

  end
end
