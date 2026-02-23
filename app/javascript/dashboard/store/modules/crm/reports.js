import CrmReportsAPI from 'dashboard/api/crmReports';
import camelcaseKeys from 'camelcase-keys';

export const initialState = {
  funnel: {},
  pipelineSummary: [],
  agentPerformance: [],
  dispositionBreakdown: {},
  uiFlags: {
    isFetchingFunnel: false,
    isFetchingPipelineSummary: false,
    isFetchingAgentPerformance: false,
    isFetchingDispositionBreakdown: false,
  },
};

export const getters = {
  getFunnel: state => state.funnel,
  getPipelineSummary: state => state.pipelineSummary,
  getAgentPerformance: state => state.agentPerformance,
  getDispositionBreakdown: state => state.dispositionBreakdown,
  getUIFlags: state => state.uiFlags,
};

export const actions = {
  async fetchFunnel({ commit }, params) {
    try {
      commit('setUIFlags', { isFetchingFunnel: true });
      const response = await CrmReportsAPI.getFunnel(params);
      commit('setFunnel', camelcaseKeys(response.data, { deep: true }));
    } catch (error) {
      // Handle error
    } finally {
      commit('setUIFlags', { isFetchingFunnel: false });
    }
  },

  async fetchPipelineSummary({ commit }, params) {
    try {
      commit('setUIFlags', { isFetchingPipelineSummary: true });
      const response = await CrmReportsAPI.getPipelineSummary(params);
      commit(
        'setPipelineSummary',
        camelcaseKeys(response.data, { deep: true })
      );
    } catch (error) {
      // Handle error
    } finally {
      commit('setUIFlags', { isFetchingPipelineSummary: false });
    }
  },

  async fetchAgentPerformance({ commit }, params) {
    try {
      commit('setUIFlags', { isFetchingAgentPerformance: true });
      const response = await CrmReportsAPI.getAgentPerformance(params);
      commit(
        'setAgentPerformance',
        camelcaseKeys(response.data, { deep: true })
      );
    } catch (error) {
      // Handle error
    } finally {
      commit('setUIFlags', { isFetchingAgentPerformance: false });
    }
  },

  async fetchDispositionBreakdown({ commit }, params) {
    try {
      commit('setUIFlags', { isFetchingDispositionBreakdown: true });
      const response = await CrmReportsAPI.getDispositionBreakdown(params);
      commit(
        'setDispositionBreakdown',
        camelcaseKeys(response.data, { deep: true })
      );
    } catch (error) {
      // Handle error
    } finally {
      commit('setUIFlags', { isFetchingDispositionBreakdown: false });
    }
  },
};

export const mutations = {
  setFunnel(state, data) {
    state.funnel = data;
  },
  setPipelineSummary(state, data) {
    state.pipelineSummary = data;
  },
  setAgentPerformance(state, data) {
    state.agentPerformance = data;
  },
  setDispositionBreakdown(state, data) {
    state.dispositionBreakdown = data;
  },
  setUIFlags(state, uiFlag) {
    state.uiFlags = { ...state.uiFlags, ...uiFlag };
  },
};

export default {
  namespaced: true,
  state: initialState,
  getters,
  actions,
  mutations,
};
