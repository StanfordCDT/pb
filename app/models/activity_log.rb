class ActivityLog < ApplicationRecord
  belongs_to :user, optional: true
end
