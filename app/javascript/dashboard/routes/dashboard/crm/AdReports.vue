<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import AdReportsAPI from 'dashboard/api/adReports';
import CrmFilters from './components/CrmFilters.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();

const rows = ref([]);
const isLoading = ref(false);

const totalLeads = computed(() =>
  rows.value.reduce((sum, row) => sum + Number(row.leads), 0)
);

const campaigns = computed(() => {
  const grouped = rows.value.reduce((acc, row) => {
    const key = row.campaign_name || t('CRM.AD_REPORTS.UNKNOWN_CAMPAIGN');
    acc[key] = (acc[key] || 0) + Number(row.leads);
    return acc;
  }, {});

  return Object.entries(grouped)
    .map(([name, leads]) => ({ name, leads }))
    .sort((a, b) => b.leads - a.leads);
});

const maxCampaignLeads = computed(() =>
  Math.max(...campaigns.value.map(campaign => campaign.leads), 1)
);

const money = value =>
  value == null
    ? '—'
    : Number(value).toLocaleString('pt-BR', {
        style: 'currency',
        currency: 'BRL',
        maximumFractionDigits: 0,
      });

const onFilterChange = async params => {
  isLoading.value = true;
  try {
    const { data } = await AdReportsAPI.getPerformance(params);
    rows.value = data.payload;
  } finally {
    isLoading.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col gap-4 p-4">
    <CrmFilters
      :show-agent="false"
      :show-team="false"
      @filter-change="onFilterChange"
    />

    <div v-if="isLoading" class="flex justify-center py-10">
      <Spinner />
    </div>

    <div
      v-else-if="!rows.length"
      class="py-10 text-sm text-center text-n-slate-11"
    >
      {{ t('CRM.AD_REPORTS.EMPTY') }}
    </div>

    <template v-else>
      <div class="p-4 rounded-lg bg-n-alpha-1">
        <span class="block text-sm text-n-slate-11">
          {{ t('CRM.AD_REPORTS.TOTAL_LEADS') }}
        </span>
        <span class="text-2xl font-semibold text-n-slate-12">
          {{ totalLeads }}
        </span>
      </div>

      <div class="p-4 rounded-lg bg-n-alpha-1">
        <h3 class="mb-3 text-sm font-medium text-n-slate-12">
          {{ t('CRM.AD_REPORTS.BY_CAMPAIGN') }}
        </h3>
        <div
          v-for="campaign in campaigns"
          :key="campaign.name"
          class="mb-2 last:mb-0"
        >
          <div class="flex justify-between mb-1 text-sm">
            <span class="truncate text-n-slate-12">{{ campaign.name }}</span>
            <span class="ml-2 shrink-0 text-n-slate-11">
              {{ campaign.leads }}
            </span>
          </div>
          <div class="h-2 rounded-full bg-n-alpha-2">
            <div
              class="h-2 rounded-full bg-n-brand"
              :style="{
                width: `${(campaign.leads / maxCampaignLeads) * 100}%`,
              }"
            />
          </div>
        </div>
      </div>

      <div class="overflow-x-auto rounded-lg bg-n-alpha-1">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-n-slate-11">
              <th class="p-3 font-medium">{{ t('CRM.AD_REPORTS.AD') }}</th>
              <th class="p-3 font-medium">
                {{ t('CRM.AD_REPORTS.CAMPAIGN') }}
              </th>
              <th class="p-3 font-medium">{{ t('CRM.AD_REPORTS.ADSET') }}</th>
              <th class="p-3 font-medium">{{ t('CRM.AD_REPORTS.LEADS') }}</th>
              <th class="p-3 font-medium">{{ t('CRM.AD_REPORTS.SPEND') }}</th>
              <th class="p-3 font-medium">{{ t('CRM.AD_REPORTS.CPL') }}</th>
              <th class="p-3 font-medium">{{ t('CRM.AD_REPORTS.ORDERS') }}</th>
              <th class="p-3 font-medium">{{ t('CRM.AD_REPORTS.REVENUE') }}</th>
              <th class="p-3 font-medium">{{ t('CRM.AD_REPORTS.ROAS') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="row in rows"
              :key="row.ad_id"
              class="border-t border-n-weak"
            >
              <td class="p-3">
                <div class="flex items-center gap-2">
                  <img
                    v-if="row.thumbnail_url"
                    :src="row.thumbnail_url"
                    :alt="row.ad_name"
                    class="object-cover w-8 h-8 rounded shrink-0"
                  />
                  <span class="text-n-slate-12">
                    {{ row.ad_name || row.ad_id }}
                  </span>
                </div>
              </td>
              <td class="p-3 text-n-slate-11">
                {{ row.campaign_name || '—' }}
              </td>
              <td class="p-3 text-n-slate-11">{{ row.adset_name || '—' }}</td>
              <td class="p-3 text-n-slate-12">{{ row.leads }}</td>
              <td class="p-3 text-n-slate-11">{{ money(row.spend) }}</td>
              <td class="p-3 text-n-slate-11">
                {{ money(row.cost_per_lead) }}
              </td>
              <td class="p-3 text-n-slate-12">{{ row.orders }}</td>
              <td class="p-3 text-n-slate-12">{{ money(row.revenue) }}</td>
              <td
                class="p-3 font-medium"
                :class="row.roas >= 1 ? 'text-n-teal-11' : 'text-n-slate-11'"
              >
                {{ row.roas ? `${row.roas.toFixed(1)}x` : '—' }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>
  </div>
</template>
