module Hurl
  class User < Model
    attr_accessor :email, :password, :crypted_password

    # change this in your app
    SALT = '==asdaga3hg8hwg98w4h9hg8ohsrg8hsklghsdgl=='

    # find_by_email
    index :email

    #
    # each user has an associated list
    # of hurls
    #

    def add_hurl(hurl)
      redis.sadd(key, hurl)
      redis.set(key(hurl), Time.now.to_i)
    end

    def remove_hurl(hurl)
      redis.srem(key, hurl)
      redis.del(key(hurl))
    end

    def unsorted_hurls
      redis.smembers(key)
    end

    def any_hurls?
      redis.scard(key).to_i > 0
    end

    def latest_hurl
      hurls(0, 1).first
    end

    def second_to_last_hurl_id
      any_hurls? and hurls(0, 2).size == 2 and hurls(0, 2)[1]['id']
    end

    def latest_hurl_id
      any_hurls? and latest_hurl['id']
    end

    def hurls(start = 0, limit = 100)
      @hurls ||= hurls!(start, limit)
    end

    def hurls!(start = 0, limit = 100)
      return [] unless any_hurls?

      hurls = redis.sort key,
        :by    => "#{key}:*",
        :order => 'DESC',
        :get   => "*",
        :limit => [start, limit]

      # convert hurls to ruby objects
      hurls.map! { |hurl| Hurl.decode(hurl) }

      # find and set the corresponding timestamps for
      # each hurl (scoped to this user)
      keys = hurls.map { |h| key(h['id']) }
      redis.mget(keys).each_with_index do |date, i|
        hurls[i]['date'] = Time.at(date.to_i)
      end
      hurls
    end


    #
    # authentication
    #

    def self.authenticate(email, password)
      return unless user = find_by_email(email)

      if user.crypted_password == crypted_password(password)
        user
      end
    end

    def self.crypted_password(password)
      Digest::SHA1.hexdigest("--#{password}-#{SALT}--")
    end

    def password=(password)
      @password = password
      @crypted_password = self.class.crypted_password(password)
    end


    #
    # instance methods
    #

    def to_s
      email
    end

    def validate
      if email.to_s.strip.empty?
        errors[:email] = " is empty"
      elsif password.to_s.strip.empty?
        errors[:password] = " is empty"
      elsif self.class.find_by_email(email)
        errors[:email] = " already exists"
      elsif email !~ /^[^@]+@[^@]+$/
        errors[:email] = " isn't an email address"
      end

      errors.empty?
    end

    def to_hash
      return {
        'id'               => id,
        'email'            => email,
        'crypted_password' => crypted_password
      }
    end

    def key(*parts)
      super(*[id, :hurls, parts].flatten)
    end
  end
end
