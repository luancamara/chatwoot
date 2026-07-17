class Api::V1::Accounts::ConversationRiskMonitorsController < Api::V1::Accounts::EnterpriseAccountsController
  before_action -> { check_authorization(ConversationRiskMonitorConfig) }
  before_action :ensure_feature_enabled
  before_action :set_inbox, only: :update

  def index
    render json: Current.account.conversation_risk_monitor_configs.order(:inbox_id).map { |config| serialize(config) }
  end

  def update
    config = Current.account.conversation_risk_monitor_configs.find_or_initialize_by(inbox: @inbox)
    config.update!(permitted_params)
    render json: serialize(config)
  end

  private

  def ensure_feature_enabled
    enabled = ActiveModel::Type::Boolean.new.cast(Current.account.conversation_risk_monitor_enabled)
    return if enabled

    render json: { error: 'Conversation risk monitor is not enabled for this account' }, status: :forbidden
  end

  def set_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
  end

  def permitted_params
    params.require(:conversation_risk_monitor).permit(:enabled, :management_team_id, :complaint_label_id, :critical_label_id)
  end

  def serialize(config)
    {
      inbox_id: config.inbox_id,
      enabled: config.enabled,
      management_team_id: config.management_team_id,
      complaint_label_id: config.complaint_label_id,
      critical_label_id: config.critical_label_id
    }
  end
end
