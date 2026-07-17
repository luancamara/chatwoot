import ApiClient from './ApiClient';

class ConversationRiskMonitorsAPI extends ApiClient {
  constructor() {
    super('conversation_risk_monitors', { accountScoped: true });
  }

  update(inboxId, data) {
    return super.update(inboxId, { conversation_risk_monitor: data });
  }
}

export default new ConversationRiskMonitorsAPI();
