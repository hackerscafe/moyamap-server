class RenameUserHash < ActiveRecord::Migration
  def up
    rename_column :users, :hash, :user_hash
  end

  def down
    rename_column :users, :user_hash, :hash
  end
end
