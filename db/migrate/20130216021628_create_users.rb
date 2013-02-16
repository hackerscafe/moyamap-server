class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :name
      t.string :fb_token
      t.text :hash

      t.timestamps
    end
  end
end
