class ModifyStagingSub < ActiveRecord::Migration[5.2]
  def up
    add_column :staging_subscriptions_migration, :bad_sub, :boolean, default: false
  end

  def down
    add_column :staging_subscriptions_migration, :bad_sub, :boolean, default: false

  end

end
