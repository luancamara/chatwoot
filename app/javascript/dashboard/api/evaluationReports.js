/* global axios */

class EvaluationReportsAPI {
  constructor() {
    this.apiVersion = '/api/v2';
  }

  get accountUrl() {
    const accountId = window.location.pathname.split('/')[3];
    return `${this.apiVersion}/accounts/${accountId}`;
  }

  getEvaluationReports(params = {}) {
    return axios.get(`${this.accountUrl}/crm_reports/evaluation_reports`, {
      params,
    });
  }

  getAgentEvaluation(agentId, params = {}) {
    return axios.get(`${this.accountUrl}/crm_reports/agent_evaluation`, {
      params: { agent_id: agentId, ...params },
    });
  }

  getManagementEvaluation(params = {}) {
    return axios.get(`${this.accountUrl}/crm_reports/management_evaluation`, {
      params,
    });
  }
}

export default new EvaluationReportsAPI();
