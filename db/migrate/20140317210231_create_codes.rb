class CreateCodes < ActiveRecord::Migration[5.2]
  def change
    create_table :codes do |t|
      t.references :code_batch, null: false
      t.string :code, null: false
      t.integer :status  # 0 = ok, 1 = test, 2 = void

      t.timestamps null: false
    end

    # FIXME: the scope should be election_id, not code_batch_id
    add_index(:codes, [:code_batch_id, :code], unique: true)
  end
end
