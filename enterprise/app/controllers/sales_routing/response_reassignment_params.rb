module SalesRouting::ResponseReassignmentParams
  extend ActiveSupport::Concern

  prepended do
    before_action :validate_response_reassignment_params, if: -> { action_name.in?(%w[create update]) }
  end

  private

  def validate_response_reassignment_params
    mode = params[:response_reassignment_mode]
    user_id = params[:response_reassignment_notify_user_id]
    valid_mode = !params.key?(:response_reassignment_mode) || (mode.is_a?(String) && Inbox.response_reassignment_modes.key?(mode))
    valid_user = valid_response_manager?(user_id)
    return if valid_mode && valid_user

    render json: { error: I18n.t('errors.response_reassignment.invalid_settings') }, status: :unprocessable_entity
  end

  def valid_response_manager?(user_id)
    return true if !params.key?(:response_reassignment_notify_user_id) || user_id.nil?

    user_id.is_a?(Integer) && Current.account.account_users.administrator.exists?(user_id: user_id)
  end
end
