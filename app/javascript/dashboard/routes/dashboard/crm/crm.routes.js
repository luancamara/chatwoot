import { frontendURL } from 'dashboard/helper/URLHelper';

const CrmWrapper = () => import('./CrmWrapper.vue');
const PipelineView = () => import('./PipelineView.vue');
const FunnelAnalytics = () => import('./FunnelAnalytics.vue');
const SalesReports = () => import('./SalesReports.vue');

export const routes = [
  {
    path: frontendURL('accounts/:accountId/crm'),
    component: CrmWrapper,
    children: [
      {
        path: 'pipeline',
        name: 'crm_pipeline',
        meta: {
          permissions: ['administrator'],
        },
        component: PipelineView,
      },
      {
        path: 'funnel',
        name: 'crm_funnel',
        meta: {
          permissions: ['administrator'],
        },
        component: FunnelAnalytics,
      },
      {
        path: 'sales-reports',
        name: 'crm_sales_reports',
        meta: {
          permissions: ['administrator'],
        },
        component: SalesReports,
      },
    ],
  },
];
