require 'test_helper'

class ElectionTest < ActiveSupport::TestCase
  test 'fresh election reads config updated by another process' do
    election = Election.create!(
      name: 'Cache test',
      slug: 'cache-test',
      config_yaml: "stop_accepting_votes: true\n"
    )

    assert election.config[:stop_accepting_votes]

    # This simulates the database being updated by another Passenger worker,
    # whose callback cannot clear this process's memory.
    Election.where(id: election.id).update_all(config_yaml: "stop_accepting_votes: false\n")

    fresh_election = Election.find(election.id)
    assert_not fresh_election.config[:stop_accepting_votes]
  end

  test 'config cache clears when election is updated' do
    election = Election.create!(
      name: 'Cache update test',
      slug: 'cache-update-test',
      config_yaml: "stop_accepting_votes: true\n"
    )

    assert election.config[:stop_accepting_votes]

    election.update!(config_yaml: "stop_accepting_votes: false\n")

    assert_not election.config[:stop_accepting_votes]
  end
end
