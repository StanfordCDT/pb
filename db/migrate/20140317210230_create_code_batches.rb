class CreateCodeBatches < ActiveRecord::Migration[5.2]
  def change
    create_table :code_batches do |t|
      t.references :election, null: false
      t.references :user, null: false
      t.integer :status

      t.timestamps null: false
    end
  end
end
