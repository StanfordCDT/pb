require 'test_helper'

class ClosedVoteSubmissionTest < ActionDispatch::IntegrationTest
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

    election.update!(config_yaml: election.config_yaml.sub('stop_accepting_votes: false', 'stop_accepting_votes: true'))

    assert_no_difference 'VoteApproval.count' do
      post "/#{election.slug}/submit_approval",
           params: { subpage: 0, project: { project.id.to_s => project.cost } }
    end

    assert_equal 'approval', voter.reload.stage
    assert_redirected_to action: :index

    follow_redirect!
    assert_response :success
    assert_select 'div.alert.alert-danger[role=alert]', text: 'Your submission was not recorded since voting has been closed.'
  end
end
