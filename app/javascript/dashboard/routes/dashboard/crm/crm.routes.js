import { frontendURL } from 'dashboard/helper/URLHelper';

const CrmWrapper = () => import('./CrmWrapper.vue');
const PipelineView = () => import('./PipelineView.vue');
const FunnelAnalytics = () => import('./FunnelAnalytics.vue');
const SalesReports = () => import('./SalesReports.vue');
const EvaluationReports = () => import('./EvaluationReports.vue');
const AdReports = () => import('./AdReports.vue');
const AdGallery = () => import('./AdGallery.vue');

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
      {
        path: 'evaluation-reports',
        name: 'crm_evaluation_reports',
        meta: {
          permissions: ['administrator'],
        },
        component: EvaluationReports,
      },
      {
        path: 'ad-reports',
        name: 'crm_ad_reports',
        meta: {
          permissions: ['administrator'],
        },
        component: AdReports,
      },
      {
        // Reference material for the sales floor, so agents get in too.
        path: 'ad-gallery',
        name: 'crm_ad_gallery',
        meta: {
          permissions: ['administrator', 'agent', 'custom_role'],
        },
        component: AdGallery,
      },
    ],
  },
];
