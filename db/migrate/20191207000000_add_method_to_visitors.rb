class AddMethodToVisitors < ActiveRecord::Migration[5.2]
  def change
    add_column :visitors, :method, :string, null: false
  end
end
