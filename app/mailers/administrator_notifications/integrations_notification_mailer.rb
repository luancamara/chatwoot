class AdministratorNotifications::IntegrationsNotificationMailer < AdministratorNotifications::BaseMailer
  def slack_disconnect
    subject = I18n.t('mailers.subjects.slack_disconnect')
    action_url = settings_url('integrations/slack')
    send_notification(subject, action_url: action_url)
  end

  def dialogflow_disconnect
    subject = I18n.t('mailers.subjects.dialogflow_disconnect')
    send_notification(subject)
  end

  def openai_disconnect
    subject = I18n.t('mailers.subjects.openai_disconnect')
    action_url = settings_url('integrations/openai')
    send_notification(subject, action_url: action_url)
  end
end
