module StripePush
  class User
    include MongoMapper::Document

    key :uid, String, :required => true
    key :publishable_key, String, :required => true
    key :secret_key, String, :required => true
    key :device_ids, Array, :default => []

    def self.from_auth!(auth, device_token)
      user                 = find_by_uid(auth['uid']) || self.new
      user.uid             = auth['uid']
      user.secret_key      = auth['credentials']['token']
      user.publishable_key = auth['info']['stripe_publishable_key']
      user.save!
      user
    end

    def self.pusher
      @pusher ||= Grocer.pusher(
        certificate: settings.certificate_path
      )
    end

    def self.notify(token, options = {})
      notification = Grocer::Notification.new(
        {device_token: token}.merge(options)
      )
      self.pusher.push(notification)
    end

    def notify(options = {})
      self.device_ids.each {|id| self.class.notify(id, options) }
    end

    def notify_charge(charge)
      custom = {amount: charge.amount, description: description}
      notify(alert: 'New charge!', custom: custom)
    end
  end
end