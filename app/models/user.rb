class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :themes, dependent: :destroy
  has_many :submissions, dependent: :destroy
  has_many :stars, dependent: :destroy
  has_many :starred_themes, through: :stars, source: :theme
  has_many :reviews, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :username, with: ->(u) { u.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :username, presence: true, uniqueness: true, length: { in: 2..30 },
    format: { with: /\A[a-z0-9][a-z0-9-]*\z/, message: "only letters, numbers, and hyphens" }

  generates_token_for :email_verification, expires_in: 2.days do
    email_address
  end

  def verified? = email_verified_at.present?

  def verify_email!
    touch(:email_verified_at) unless verified?
  end
end
