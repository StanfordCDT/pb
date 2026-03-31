require 'test_helper'

class MaintenanceModeTest < ActionDispatch::IntegrationTest
  setup do
    @saved_maintenance_mode = ENV['MAINTENANCE_MODE']
    ENV['MAINTENANCE_MODE'] = 'true'
  end

  teardown do
    ENV['MAINTENANCE_MODE'] = @saved_maintenance_mode
  end

  test 'site shows maintenance page when maintenance mode is enabled' do
    get '/'
    assert_response :service_unavailable
    assert_match /Maintenance in progress/i, @response.body
  end

  test 'site works normally when maintenance mode is disabled' do
    ENV['MAINTENANCE_MODE'] = 'false'
    get '/'
    assert_not_equal 503, status
  end
end