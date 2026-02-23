/* global axios */

class ConversationInsightAPI {
  constructor() {
    this.apiVersion = '/api/v1';
  }

  get accountUrl() {
    const accountId = window.location.pathname.split('/')[3];
    return `${this.apiVersion}/accounts/${accountId}`;
  }

  show(conversationId) {
    return axios.get(
      `${this.accountUrl}/conversations/${conversationId}/insight`
    );
  }
}

export default new ConversationInsightAPI();
