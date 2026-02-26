/* global axios */

class AgentWorkingHoursAPI {
  constructor() {
    this.apiVersion = '/api/v1';
  }

  get accountUrl() {
    const accountId = window.location.pathname.split('/')[3];
    return `${this.apiVersion}/accounts/${accountId}`;
  }

  index(userId) {
    return axios.get(`${this.accountUrl}/agent_working_hours`, {
      params: { user_id: userId },
    });
  }

  update(userId, workingHours) {
    return axios.patch(`${this.accountUrl}/agent_working_hours`, {
      user_id: userId,
      working_hours: workingHours,
    });
  }
}

export default new AgentWorkingHoursAPI();
