class User < ApplicationRecord
  # TODO: rename username to email?
  # TODO: use a proper regex for email
  validates :username, presence: true, uniqueness: true, format: {with: /\A[a-zA-Z0-9\.@_+\-]+\Z/}
  # FIXME: set allowed characters
  validates :password, presence: true, confirmation: true, length: {in: 8..64},
                       exclusion: {in: ['12345678', 'password', 'abcdefgh'], message: "is too weak"},
                       if: :password_required?

  has_many :election_users, dependent: :destroy
  has_many :elections, through: :election_users

  def password
    @password
  end

  def password=(unencrypted_password)
    @password = unencrypted_password
    self.salt = SecureRandom.hex(8)
    self.password_digest = Digest::SHA1.hexdigest(unencrypted_password + self.salt)
  end

  def authenticate(unencrypted_password)
    self.password_digest == Digest::SHA1.hexdigest(unencrypted_password + self.salt)
  end

  def superadmin?
    self.is_superadmin
  end

  def admin?(election)
    superadmin? || (election && ElectionUser.find_by(user_id: self.id, election_id: election.id, status: ElectionUser.statuses[:admin]))
  end

  def volunteer?(election)
    superadmin? || (election && ElectionUser.find_by(user_id: self.id, election_id: election.id, status: ElectionUser.statuses[:volunteer]))
  end

  def admin_or_volunteer?(election)
    admin?(election) || volunteer?(election)
  end

  def can_update_election?(election)
    superadmin? || (admin?(election) && election.allow_admins_to_update_election?)
  end

  def can_see_voter_data?(election)
    superadmin? || (admin?(election) && election.allow_admins_to_see_voter_data?)
  end

  def can_see_exact_results?(election)
    superadmin? || (admin?(election) && election.allow_admins_to_see_exact_results?)
  end

  private

  def password_required?
    !password.nil? || !password_confirmation.nil?
  end
end
