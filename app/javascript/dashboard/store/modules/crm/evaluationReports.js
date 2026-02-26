import EvaluationReportsAPI from 'dashboard/api/evaluationReports';

const state = {
  agentEvaluation: null,
  managementEvaluation: null,
  evaluationReports: [],
  uiFlags: {
    isFetchingAgent: false,
    isFetchingManagement: false,
    isFetchingReports: false,
  },
};

const getters = {
  getAgentEvaluation: $state => $state.agentEvaluation,
  getManagementEvaluation: $state => $state.managementEvaluation,
  getEvaluationReports: $state => $state.evaluationReports,
  getUIFlags: $state => $state.uiFlags,
};

const mutations = {
  SET_AGENT_EVALUATION($state, data) {
    $state.agentEvaluation = data;
  },
  SET_MANAGEMENT_EVALUATION($state, data) {
    $state.managementEvaluation = data;
  },
  SET_EVALUATION_REPORTS($state, data) {
    $state.evaluationReports = data;
  },
  SET_UI_FLAG($state, flag) {
    $state.uiFlags = { ...$state.uiFlags, ...flag };
  },
};

const actions = {
  async fetchAgentEvaluation({ commit }, { agentId, params }) {
    commit('SET_UI_FLAG', { isFetchingAgent: true });
    try {
      const { data } = await EvaluationReportsAPI.getAgentEvaluation(
        agentId,
        params
      );
      commit('SET_AGENT_EVALUATION', data);
    } catch (error) {
      // handle silently
    } finally {
      commit('SET_UI_FLAG', { isFetchingAgent: false });
    }
  },

  async fetchManagementEvaluation({ commit }, params = {}) {
    commit('SET_UI_FLAG', { isFetchingManagement: true });
    try {
      const { data } =
        await EvaluationReportsAPI.getManagementEvaluation(params);
      commit('SET_MANAGEMENT_EVALUATION', data);
    } catch (error) {
      // handle silently
    } finally {
      commit('SET_UI_FLAG', { isFetchingManagement: false });
    }
  },

  async fetchEvaluationReports({ commit }, params = {}) {
    commit('SET_UI_FLAG', { isFetchingReports: true });
    try {
      const { data } = await EvaluationReportsAPI.getEvaluationReports(params);
      commit('SET_EVALUATION_REPORTS', data);
    } catch (error) {
      // handle silently
    } finally {
      commit('SET_UI_FLAG', { isFetchingReports: false });
    }
  },
};

export default {
  namespaced: true,
  state,
  getters,
  mutations,
  actions,
};
