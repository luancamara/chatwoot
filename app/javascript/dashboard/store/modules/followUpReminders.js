import FollowUpReminderAPI from 'dashboard/api/followUpReminder';

const state = {
  records: {},
  uiFlags: {
    isFetching: false,
    isCreating: false,
  },
};

const getters = {
  getByConversationId: $state => conversationId =>
    $state.records[conversationId] || [],
  getUIFlags: $state => $state.uiFlags,
};

const mutations = {
  SET_REMINDERS(st, { conversationId, reminders }) {
    st.records = { ...st.records, [conversationId]: reminders };
  },
  ADD_REMINDER(st, { conversationId, reminder }) {
    const existing = st.records[conversationId] || [];
    st.records = {
      ...st.records,
      [conversationId]: [...existing, reminder],
    };
  },
  UPDATE_REMINDER(st, { conversationId, reminder }) {
    const existing = st.records[conversationId] || [];
    st.records = {
      ...st.records,
      [conversationId]: existing.map(r =>
        r.id === reminder.id ? reminder : r
      ),
    };
  },
  REMOVE_REMINDER(st, { conversationId, reminderId }) {
    const existing = st.records[conversationId] || [];
    st.records = {
      ...st.records,
      [conversationId]: existing.filter(r => r.id !== reminderId),
    };
  },
  SET_UI_FLAG(st, data) {
    st.uiFlags = { ...st.uiFlags, ...data };
  },
};

const actions = {
  async fetch({ commit }, conversationId) {
    commit('SET_UI_FLAG', { isFetching: true });
    try {
      const { data } = await FollowUpReminderAPI.index(conversationId);
      commit('SET_REMINDERS', { conversationId, reminders: data });
    } catch (error) {
      throw error;
    } finally {
      commit('SET_UI_FLAG', { isFetching: false });
    }
  },
  async create({ commit }, { conversationId, ...params }) {
    commit('SET_UI_FLAG', { isCreating: true });
    try {
      const { data } = await FollowUpReminderAPI.create(
        conversationId,
        params
      );
      commit('ADD_REMINDER', { conversationId, reminder: data });
      return data;
    } catch (error) {
      throw error;
    } finally {
      commit('SET_UI_FLAG', { isCreating: false });
    }
  },
  async update({ commit }, { conversationId, reminderId, ...params }) {
    try {
      const { data } = await FollowUpReminderAPI.update(
        conversationId,
        reminderId,
        params
      );
      commit('UPDATE_REMINDER', { conversationId, reminder: data });
      return data;
    } catch (error) {
      throw error;
    }
  },
  async delete({ commit }, { conversationId, reminderId }) {
    try {
      await FollowUpReminderAPI.destroy(conversationId, reminderId);
      commit('REMOVE_REMINDER', { conversationId, reminderId });
    } catch (error) {
      throw error;
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
