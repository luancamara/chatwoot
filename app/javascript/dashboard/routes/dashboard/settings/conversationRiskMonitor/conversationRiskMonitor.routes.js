import { frontendURL } from '../../../../helper/URLHelper';
import { INSTALLATION_TYPES } from 'dashboard/constants/installationTypes';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/conversation-monitor'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'conversation_risk_monitor_settings',
          component: Index,
          meta: {
            permissions: ['administrator'],
            installationTypes: [INSTALLATION_TYPES.ENTERPRISE],
          },
        },
      ],
    },
  ],
};
