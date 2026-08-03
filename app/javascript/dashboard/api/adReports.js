/* global axios */
import ApiClient from './ApiClient';

class AdReportsAPI extends ApiClient {
  constructor() {
    super('ad_reports', { apiVersion: 'v2', accountScoped: true });
  }

  getPerformance(params) {
    return axios.get(`${this.url}/performance`, { params });
  }
}

export default new AdReportsAPI();
