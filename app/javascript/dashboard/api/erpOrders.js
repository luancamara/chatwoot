/* global axios */
import ApiClient from './ApiClient';

class ErpOrdersAPI extends ApiClient {
  constructor() {
    super('contacts', { apiVersion: 'v2', accountScoped: true });
  }

  getHistory(contactId) {
    return axios.get(`${this.url}/${contactId}/erp_orders`);
  }
}

export default new ErpOrdersAPI();
