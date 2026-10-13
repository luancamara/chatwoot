import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import Index from '../Index.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const { dispatch, alert } = vi.hoisted(() => ({
  dispatch: vi.fn(),
  alert: vi.fn(),
}));
const inboxes = ref([]);
const isAdmin = ref(true);

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: alert }));
vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({ isAdmin }),
}));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
  useMapGetter: () => inboxes,
  useStoreGetters: () => ({
    'inboxes/getUIFlags': { value: { isFetching: false } },
  }),
}));

const globalOptions = {
  mocks: { $t: key => key },
  directives: { tooltip: () => {} },
  stubs: {
    SettingsLayout: {
      template: '<div><slot name="header" /><slot name="body" /><slot /></div>',
    },
    BaseSettingsHeader: {
      template: '<div><slot name="count" /><slot name="actions" /></div>',
    },
    RouterLink: { template: '<a><slot /></a>' },
    Avatar: true,
    ChannelIcon: true,
    ChannelName: true,
  },
};

describe('Inbox activity settings', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    isAdmin.value = true;
    inboxes.value = [
      {
        id: 1,
        name: 'Atendimento',
        channel_type: 'Channel::Api',
        archived: false,
      },
      {
        id: 2,
        name: 'Canal anterior',
        channel_type: 'Channel::Api',
        archived: true,
      },
    ];
    dispatch.mockImplementation(async (action, payload) => {
      if (action === 'inboxes/updateInbox') {
        inboxes.value.find(inbox => inbox.id === payload.id).archived =
          payload.archived;
      }
    });
  });

  it('lets administrators deactivate, find inactive inboxes, and reactivate with JSON booleans', async () => {
    const wrapper = mount(Index, { global: globalOptions });
    await wrapper.get('[data-test-id="inbox-archive-1"]').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('inboxes/updateInbox', {
      id: 1,
      formData: false,
      archived: true,
    });

    await wrapper.findComponent(Select).find('select').setValue('inactive');
    expect(wrapper.text()).toContain('Atendimento');
    expect(wrapper.text()).toContain('Canal anterior');

    await wrapper.get('[data-test-id="inbox-archive-1"]').trigger('click');
    await flushPromises();
    expect(dispatch).toHaveBeenLastCalledWith('inboxes/updateInbox', {
      id: 1,
      formData: false,
      archived: false,
    });
    expect(wrapper.text()).not.toContain('Atendimento');
    expect(wrapper.text()).toContain('Canal anterior');
  });

  it('keeps the current status on API failure and shows an error', async () => {
    dispatch.mockImplementation(async action => {
      if (action === 'inboxes/updateInbox') throw new Error('Request failed');
    });
    const wrapper = mount(Index, { global: globalOptions });
    await wrapper.get('[data-test-id="inbox-archive-1"]').trigger('click');
    await flushPromises();

    expect(inboxes.value[0].archived).toBe(false);
    expect(alert).toHaveBeenCalledWith('INBOX_MGMT.ARCHIVE.ERROR');
  });

  it('does not expose activity actions to non-administrators', () => {
    isAdmin.value = false;
    const wrapper = mount(Index, { global: globalOptions });
    expect(wrapper.find('[data-test-id="inbox-archive-1"]').exists()).toBe(
      false
    );
    expect(wrapper.find('[data-test-id="inbox-archive-2"]').exists()).toBe(
      false
    );
  });
});
