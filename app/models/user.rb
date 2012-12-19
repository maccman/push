module StripePush
  class User
    include MongoMapper::Document

    key :uid, String, :required => true
    key :publishable_key, String, :required => true
    key :secret_key, String, :required => true
    key :device_tokens, Array, :default => []

    def self.from_auth!(auth)
      user                 = find_by_uid(auth['uid']) || self.new
      user.uid             = auth['uid']
      user.secret_key      = auth['credentials']['token']
      user.publishable_key = auth['info']['stripe_publishable_key']
      user.save!
      user
    end

    def self.pusher
      Grocer.pusher(
        certificate: settings.certificate_path,
        gateway:     Grocer::PushConnection::SANDBOX_GATEWAY # TODO
      )
    end

    def self.notify(token, options = {})
      notification = Grocer::Notification.new(
        {device_token: token}.merge(options)
      )
      self.pusher.push(notification)
    end

    def notify(options = {})
      self.device_tokens.each do |id|
        self.class.notify(id, options)
      end
    end

    def notify_charge(charge)
      amount = "$%.2f" % (charge.amount / 100)
      alert  = "Paid #{amount}"
      alert += ": #{charge.description}" if charge.description

      custom = {
        amount:      charge.amount,
        description: charge.description
      }

      notify(alert: alert, custom: custom)
    end
  end
end