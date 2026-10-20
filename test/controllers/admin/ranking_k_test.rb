require 'test_helper'

# Regression tests for the "k not set" bug in
# Admin::ElectionsController#analytics_ranking: when no project limit is
# configured, k was read from ranking.max_n_projects (config default 4), so
# rankings beyond position 4 were dropped and the table truncated to 4 columns.
class Admin::RankingKTest < ActiveSupport::TestCase
  setup { I18n.locale = :en }

  def stubbed_controller
    controller = Admin::ElectionsController.new
    user = Object.new
    def user.can_see_exact_results?(_e); true; end
    def user.can_see_voter_data?(_e); true; end
    controller.define_singleton_method(:current_user) { user }
    controller
  end

  def run_ranking(election)
    data, = stubbed_controller.send(:analytics_ranking, election)
    data[:project_ranked_votes]
  end

  def winner(matrix); matrix.first[0]; end

  def make_project(election, title, cost: 100)
    p = Project.new(election: election, number: title, cost: cost)
    p.title = title
    p.save!
    p
  end

  def rank_votes(election, project, rank, count, tag)
    count.times do |i|
      voter = Voter.create!(election: election, authentication_method: 'test',
                            authentication_id: "#{tag}-#{project.id}-#{rank}-#{i}",
                            stage: 'ranking', void: false)
      VoteRanking.create!(voter: voter, project: project, rank: rank, cost: project.cost)
    end
  end

  test 'no project limit uses the real max rank instead of the default k=4' do
    yaml = <<~YAML
      workflow: [ranking]
      stop_accepting_votes: false
      ranking:
        has_n_project_limit: false
    YAML
    election = Election.create!(name: 'k76', slug: 'k76', budget: 100000, config_yaml: yaml)
    assert_equal 4, election.config[:ranking][:max_n_projects], 'precondition: config default is 4'

    projects = (1..5).map { |i| make_project(election, "P#{i}") }
    3.times do |i|
      voter = Voter.create!(election: election, authentication_method: 'test',
                            authentication_id: "k-#{i}", stage: 'ranking', void: false)
      projects.each_with_index { |p, idx| VoteRanking.create!(voter: voter, project: p, rank: idx + 1, cost: 100) }
    end

    matrix = run_ranking(election)
    p5 = matrix.find { |r| r[0] == 'P5' }

    # [title, cost, rank1..rankK, total] -> K rank columns between cost and total
    rank_columns = p5.length - 3
    assert_equal 5, rank_columns, 'table must widen to 5 rank columns, not truncate to 4'
    assert p5.last > 0, "P5 was ranked 5th by every voter; its rank-5 votes must not be dropped (got #{p5.last})"
  end

  test 'limited ranking election still honours the configured k' do
    yaml = <<~YAML
      workflow: [ranking]
      stop_accepting_votes: false
      ranking:
        has_n_project_limit: true
        max_n_projects: 2
    YAML
    election = Election.create!(name: 'plain', slug: 'plain', budget: 100000, config_yaml: yaml)
    a = make_project(election, 'A'); b = make_project(election, 'B')
    rank_votes(election, a, 1, 7, 'p')
    rank_votes(election, b, 2, 3, 'p')

    matrix = run_ranking(election)
    assert_equal 2, matrix.first.length - 3, 'k must stay at the configured 2'
    assert_equal 'A', winner(matrix)
  end
end
