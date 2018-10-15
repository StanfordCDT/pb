class CreateCategories < ActiveRecord::Migration[5.2]
  def up
    create_table :categories do |t|
      t.references :election, null: false
      t.string :image
      t.integer :sort_order
      t.boolean :pinned, default: false
      t.integer :category_group, default: 1

      t.timestamps null: false
    end
    Category.create_translation_table! ({
      :name => :string,
    })
  end

  def down
    drop_table :categories
    Category.drop_translation_table!
  end
end
