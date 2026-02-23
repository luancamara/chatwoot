/* global axios */

class FollowUpReminderAPI {
  constructor() {
    this.apiVersion = '/api/v1';
  }

  get accountUrl() {
    const accountId = window.location.pathname.split('/')[3];
    return `${this.apiVersion}/accounts/${accountId}`;
  }

  url(conversationId) {
    return `${this.accountUrl}/conversations/${conversationId}/follow_up_reminders`;
  }

  index(conversationId) {
    return axios.get(this.url(conversationId));
  }

  create(conversationId, data) {
    return axios.post(this.url(conversationId), data);
  }

  update(conversationId, reminderId, data) {
    return axios.patch(`${this.url(conversationId)}/${reminderId}`, data);
  }

  destroy(conversationId, reminderId) {
    return axios.delete(`${this.url(conversationId)}/${reminderId}`);
  }
}

export default new FollowUpReminderAPI();
