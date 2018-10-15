class CreateVisitors < ActiveRecord::Migration[5.2]
  def change
    create_table :visitors do |t|
      t.string :ip_address, null: false
      t.text :user_agent
      t.text :referrer
      t.text :url

      t.datetime :created_at, null: false
    end
  end
end
