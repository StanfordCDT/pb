# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

require 'csv'

# Add a sample election

election = Election.new
election.name = "PB Sample"
election.slug = 'sample'
election.budget = 1100000
election.time_zone = 'Pacific Time (US & Canada)'
election.config_yaml = File.read(Rails.root.join('db', 'seed_data', 'sample_election_config.yml'))
election.save!

# Add sample users

user = User.new
user.username = "s@s"
user.password = "superadmin123"
user.is_superadmin = true
user.confirmed = true
user.save!

user = User.new
user.username = "a@a"
user.password = "admin123"
user.is_superadmin = false
user.confirmed = true
user.save!

eu = ElectionUser.new
eu.election = election
eu.user = user
eu.status = :admin
eu.save!

# Add sample categories

categories = ['Parks & Environment', 'Arts & Innovation', 'Bikes & Transit', 'Sidewalks, Streets and Alleys'].map do |category_name|
  category = Category.new
  category.election = election
  Globalize.with_locale(:en) do
    category.name = category_name
  end
  category.save!
  category
end

# Add sample projects

csv_en = CSV.read(Rails.root.join('db', 'seed_data', 'sample_projects.csv'), headers: :true)
csv_en.each_with_index do |row, i|
  project = Project.new
  project.election = election
  project.number = (i + 1).to_s
  Globalize.with_locale(:en) do
    project.title = row[0]
    project.description = row[2]
    project.address = row[3]
  end
  project.category = categories[i / 4]
  project.cost = row[1].gsub(/[,\t $]/, '').to_i
  project.sort_order = i
  project.save!
end
