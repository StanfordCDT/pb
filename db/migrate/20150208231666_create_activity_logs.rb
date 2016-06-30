class CreateActivityLogs < ActiveRecord::Migration
  def change
    create_table :activity_logs do |t|
      t.references :user
      t.string :activity, null: false
      t.string :note
      t.string :ip_address, null: false
      t.text :user_agent

      t.timestamps null: false
    end
  end
end
