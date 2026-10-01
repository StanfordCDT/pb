require 'test_helper'

class ClosedVoteSubmissionTest < ActionDispatch::IntegrationTest
  CLOSED_MESSAGE = 'Voting has been closed. Your submission was not recorded.'

  test 'closed approval submission is not saved or sent to thanks' do
    election = Election.create!(
      name: 'Closed submission test',
      slug: 'closed-submission-test',
      config_yaml: <<~YAML
        workflow: [approval, thanks]
        allow_remote_voting: true
        remote_voting_free_verification: true
        free_verification_use_captcha: false
        stop_accepting_votes: false
        approval:
          has_n_project_limit: false
          pages: [1]
          shuffle_projects: false
      YAML
    )
    category = Category.create!(election: election, name: 'Test category', category_group: 1)
    project = Project.create!(election: election, category: category, number: '1', cost: 100)

    post "/#{election.slug}/post_free_signup", params: { freeform_text: 'integration test voter' }
    get "/#{election.slug}/approval"
    assert_response :success
    voter = Voter.find_by!(election_id: election.id)
    assert_equal 'approval', voter.stage

    close_voting(election)

    assert_no_difference 'VoteApproval.count' do
      post "/#{election.slug}/submit_approval",
           params: { subpage: 0, project: { project.id.to_s => project.cost } }
    end

    assert_equal 'approval', voter.reload.stage
    assert_redirected_to action: :index

    follow_redirect!
    assert_response :success
    assert_select 'div.alert.alert-danger[role=alert]', text: CLOSED_MESSAGE
  end

  test 'finishing comparisons after close is not sent to thanks' do
    election = Election.create!(
      name: 'Closed comparison test',
      slug: 'closed-comparison-test',
      config_yaml: <<~YAML
        workflow: [comparison, thanks]
        allow_remote_voting: true
        remote_voting_free_verification: true
        free_verification_use_captcha: false
        stop_accepting_votes: false
      YAML
    )
    category = Category.create!(election: election, name: 'Test category', category_group: 1)
    Project.create!(election: election, category: category, number: '1', cost: 100)
    Project.create!(election: election, category: category, number: '2', cost: 200)

    post "/#{election.slug}/post_free_signup", params: { freeform_text: 'integration test voter' }
    get "/#{election.slug}/comparison"
    assert_response :success
    voter = Voter.find_by!(election_id: election.id)
    assert_equal 'comparison', voter.stage

    close_voting(election)

    get "/#{election.slug}/done_comparison"

    assert_equal 'comparison', voter.reload.stage
    assert_redirected_to action: :index

    follow_redirect!
    assert_select 'div.alert.alert-danger[role=alert]', text: CLOSED_MESSAGE
  end

  test 'closed submission message uses the election string override' do
    election = Election.create!(
      name: 'Closed override test',
      slug: 'closed-override-test',
      config_yaml: <<~YAML
        workflow: [approval, thanks]
        allow_remote_voting: true
        remote_voting_free_verification: true
        free_verification_use_captcha: false
        stop_accepting_votes: false
        approval:
          has_n_project_limit: false
          pages: [1]
          shuffle_projects: false
        locales:
          en:
            index:
              submission_not_recorded: 'Custom closed message'
      YAML
    )
    category = Category.create!(election: election, name: 'Test category', category_group: 1)
    project = Project.create!(election: election, category: category, number: '1', cost: 100)

    post "/#{election.slug}/post_free_signup", params: { freeform_text: 'integration test voter' }
    get "/#{election.slug}/approval"
    close_voting(election)

    # A server thread keeps the string overrides of whichever election it served last.
    Thread.current[:i18n_locales] = nil
    post "/#{election.slug}/submit_approval",
         params: { subpage: 0, project: { project.id.to_s => project.cost } }

    assert_redirected_to action: :index
    assert_equal 'Custom closed message', flash[:error]
  end

  { 'ranking' => VoteRanking, 'knapsack' => VoteKnapsack, 'token' => VoteToken }.each do |page, vote_class|
    test "closed #{page} submission is not saved or sent to thanks" do
      election = Election.create!(
        name: "Closed #{page} test",
        slug: "closed-#{page}-test",
        budget: 1000,
        config_yaml: <<~YAML
          workflow: [#{page}, thanks]
          allow_remote_voting: true
          remote_voting_free_verification: true
          free_verification_use_captcha: false
          stop_accepting_votes: false
          #{page}:
            has_n_project_limit: false
            pages: [1]
            shuffle_projects: false
        YAML
      )
      category = Category.create!(election: election, name: 'Test category', category_group: 1)
      project = Project.create!(election: election, category: category, number: '1', cost: 100)

      post "/#{election.slug}/post_free_signup", params: { freeform_text: 'integration test voter' }
      get "/#{election.slug}/#{page}"
      assert_response :success
      voter = Voter.find_by!(election_id: election.id)
      assert_equal page, voter.stage

      close_voting(election)

      assert_no_difference "#{vote_class}.count" do
        post "/#{election.slug}/submit_#{page}",
             params: { subpage: 0, project: { project.id.to_s => project.cost }, project_rank: { project.id.to_s => 1 } }
      end

      assert_equal page, voter.reload.stage
      assert_redirected_to action: :index

      follow_redirect!
      assert_select 'div.alert.alert-danger[role=alert]', text: CLOSED_MESSAGE
    end
  end

  test 'test voter can still go through the ballot after close' do
    election = Election.create!(
      name: 'Closed test voter test',
      slug: 'closed-test-voter-test',
      config_yaml: <<~YAML
        workflow: [approval, thanks]
        allow_remote_voting: true
        stop_accepting_votes: false
        approval:
          has_n_project_limit: false
          pages: [1]
          shuffle_projects: false
      YAML
    )
    category = Category.create!(election: election, name: 'Test category', category_group: 1)
    project = Project.create!(election: election, category: category, number: '1', cost: 100)

    post "/#{election.slug}/authenticate_code", params: { code: { code: '_test' } }
    voter = Voter.find_by!(election_id: election.id)
    assert voter.test?
    get "/#{election.slug}/approval"
    assert_response :success

    close_voting(election)

    assert_no_difference 'VoteApproval.count' do
      post "/#{election.slug}/submit_approval",
           params: { subpage: 0, project: { project.id.to_s => project.cost } }
    end

    assert_redirected_to action: :thanks
    assert_nil flash[:error]
  end

  private

  def close_voting(election)
    election.update!(config_yaml: election.config_yaml.sub('stop_accepting_votes: false', 'stop_accepting_votes: true'))
  end
end
