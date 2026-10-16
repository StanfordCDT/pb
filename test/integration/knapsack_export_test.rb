require 'test_helper'
require 'csv'

# Knapsack CSV exports on the analytics page.
# A: "Export into Excel" (table=knapsacks) must produce a real CSV, not "{}".
# B: "Individual votes" (table=knapsacks_individual) rows must line up with the header
#    (equal column counts) and include the voter stage.
class KnapsackExportTest < ActionDispatch::IntegrationTest
  setup do
    @su = User.new(username: 'knapadmin@example.invalid', confirmed: true, is_superadmin: true)
    @su.password = 'knappass123'
    @su.save!
    yaml = "workflow: [knapsack, thanks]\nknapsack:\n  has_budget_limit: true\n"
    @e = Election.create!(name: 'knap', slug: 'knap', budget: 1000, time_zone: 'UTC', config_yaml: yaml)
    @projects = 4.times.map { |i| Project.create!(election: @e, title: "P#{i}", cost: 300, sort_order: i) }
    2.times do |n|
      v = Voter.create!(election: @e, authentication_method: 'remote_code', authentication_id: "kv#{n}", stage: 'thanks')
      VoteKnapsack.create!(voter: v, project: @projects[0], cost: @projects[0].cost)
      VoteKnapsack.create!(voter: v, project: @projects[1], cost: @projects[1].cost)
    end
    post '/admin/users/post_login', params: { user: { username: @su.username, password: 'knappass123' } }
  end

  test 'A: aggregate knapsack CSV is a real CSV, not {}' do
    get "/admin/elections/#{@e.id}/analytics.csv?table=knapsacks"
    assert_equal 200, response.status
    rows = CSV.parse(response.body)
    assert_equal ["Project", "Cost", "Total allocation", "Voters"], rows.first,
                 "expected a header row, got: #{response.body[0, 40].inspect}"
    assert_equal @projects.length, rows.length - 1, 'one data row per project'
  end

  test 'B: individual knapsack CSV columns line up and include stage' do
    get "/admin/elections/#{@e.id}/analytics.csv?table=knapsacks_individual"
    assert_equal 200, response.status
    rows = CSV.parse(response.body)
    widths = rows.map(&:length).uniq
    assert_equal 1, widths.length, "all rows must have the same column count, saw widths #{widths.inspect}"
    assert_equal ['Voter ID', 'Voter Stage'] + @projects.map(&:title), rows[0]
    # a data row (after the two header rows) must carry the stage in column 2
    data_row = rows[2]
    assert_equal 'thanks', data_row[1], "data row should include the voter stage, got #{data_row.inspect}"
  end
end
