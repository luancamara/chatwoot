/* global axios */

class ScheduledMessagesAPI {
  constructor() {
    this.apiVersion = '/api/v1';
  }

  get accountUrl() {
    const accountId = window.location.pathname.split('/')[3];
    return `${this.apiVersion}/accounts/${accountId}`;
  }

  index(conversationId) {
    return axios.get(
      `${this.accountUrl}/conversations/${conversationId}/scheduled_messages`
    );
  }

  create(conversationId, { content, scheduled_at, content_attributes }) {
    return axios.post(
      `${this.accountUrl}/conversations/${conversationId}/scheduled_messages`,
      { content, scheduled_at, content_attributes }
    );
  }

  cancel(conversationId, id) {
    return axios.delete(
      `${this.accountUrl}/conversations/${conversationId}/scheduled_messages/${id}`
    );
  }
}

export default new ScheduledMessagesAPI();
