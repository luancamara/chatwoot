import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { describe, expect, it, vi } from 'vitest';
import Select from 'dashboard/components-next/select/Select.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ResponseReassignmentSettings from './ResponseReassignmentSettings.vue';

const { dispatch, alert } = vi.hoisted(() => ({
  dispatch: vi.fn().mockResolvedValue({}),
  alert: vi.fn(),
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: alert }));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
  useMapGetter: () => ({
    value: [
      { id: 2, name: 'Manager', role: 'administrator' },
      { id: 10, name: 'Seller', role: 'agent' },
    ],
  }),
}));

describe('ResponseReassignmentSettings', () => {
  it('loads the current mode and saves the all-response choice with a numeric recipient', async () => {
    const wrapper = mount(ResponseReassignmentSettings, {
      props: {
        inbox: {
          id: 20,
          response_reassignment_mode: 'first_response',
          response_reassignment_notify_user_id: 2,
        },
      },
      global: { stubs: { Button: true } },
    });
    const selects = wrapper.findAllComponents(Select);
    expect(selects[0].props('modelValue')).toBe('first_response');
    expect(selects[1].props('options')).toEqual([
      { value: 2, label: 'Manager' },
    ]);
    selects[0].vm.$emit('update:modelValue', 'all_responses');
    await nextTick();
    wrapper.findComponent(Button).vm.$emit('click');
    expect(dispatch).toHaveBeenCalledWith('inboxes/updateInbox', {
      id: 20,
      formData: false,
      response_reassignment_mode: 'all_responses',
      response_reassignment_notify_user_id: 2,
    });
  });

  it('requires a manager when enabling the rule and allows disabling without one', async () => {
    const wrapper = mount(ResponseReassignmentSettings, {
      props: { inbox: { id: 20, response_reassignment_mode: 'disabled' } },
      global: { stubs: { Button: true } },
    });
    expect(wrapper.findComponent(Button).props('disabled')).toBe(false);
    wrapper
      .findComponent(Select)
      .vm.$emit('update:modelValue', 'first_response');
    await nextTick();
    expect(wrapper.findComponent(Button).props('disabled')).toBe(true);
  });
});
