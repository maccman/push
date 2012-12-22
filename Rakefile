require './app'

namespace :user
  task :remove_inactive do
    feedback = Grocer.feedback(
      certificate: settings.certificate_path,
      gateway:     Grocer::PushConnection::SANDBOX_GATEWAY # TODO
    )

    feedback.each do |attempt|
      user = User.first(:device_tokens => attempt.device_token)
      user && user.remove_token!(attempt.device_token)
    end
  end
end