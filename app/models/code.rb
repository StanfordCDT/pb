class Code < ActiveRecord::Base
  enum status: [:ok, :test, :void, :personal_id]
  belongs_to :code_batch
end
