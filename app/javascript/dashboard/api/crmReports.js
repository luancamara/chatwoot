/* global axios */
import ApiClient from './ApiClient';

class CrmReportsAPI extends ApiClient {
  constructor() {
    super('crm_reports', { apiVersion: 'v2', accountScoped: true });
  }

  getFunnel(params) {
    return axios.get(`${this.url}/funnel`, { params });
  }

  getPipelineSummary(params) {
    return axios.get(`${this.url}/pipeline_summary`, { params });
  }

  getAgentPerformance(params) {
    return axios.get(`${this.url}/agent_performance`, { params });
  }

  getDispositionBreakdown(params) {
    return axios.get(`${this.url}/disposition_breakdown`, { params });
  }
}

export default new CrmReportsAPI();
