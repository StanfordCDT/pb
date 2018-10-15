class CreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :password_digest
      t.string :salt
      t.boolean :is_superadmin, default: false, null: false
      t.boolean :confirmed, default: false, null: false
      t.string :confirmation_id
      t.datetime :confirmation_id_created_at

      t.timestamps null: false
    end

    add_index(:users, :username, unique: true)
  end
end
