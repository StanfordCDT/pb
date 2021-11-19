class ChangeConfigYamlInElections < ActiveRecord::Migration[5.2]
  def change
    change_column :elections, :config_yaml, :longtext
  end
end
