require './app'

namespace :user do
  task :remove_inactive do
    feedback = Grocer.feedback(
      certificate: settings.certificate_path
    )

    feedback.each do |attempt|
      user = User.first(:device_tokens => attempt.device_token)
      next unless user

      puts "Removing token from #{user.email}: #{attempt.device_token}"

      if ARGS['NOOP']
        print ' (NOOP)'
      else
        user.remove_token!(attempt.device_token)
      end
    end
  end
end