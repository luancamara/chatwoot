<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { dynamicTime } from 'shared/helpers/timeHelper';
import ContactDetailsItem from './ContactDetailsItem.vue';

const { t } = useI18n();

const currentChat = useMapGetter('getSelectedChat');
const adReferral = computed(() => currentChat.value?.ad_referral ?? {});

const isAd = computed(() => adReferral.value.source_type === 'ad');

// Until the ad is resolved against the Graph API we only have what the webhook
// carried, so fall back to the ad headline and then to the raw id.
const title = computed(
  () =>
    adReferral.value.ad_name ||
    adReferral.value.headline ||
    adReferral.value.ad_id
);

const detailItems = computed(() =>
  [
    {
      label: t('CONVERSATION_SIDEBAR.AD_SOURCE.ADSET'),
      value: adReferral.value.adset_name,
    },
    {
      label: t('CONVERSATION_SIDEBAR.AD_SOURCE.CAMPAIGN'),
      value: adReferral.value.campaign_name,
    },
    {
      label: t('CONVERSATION_SIDEBAR.AD_SOURCE.HEADLINE'),
      value: adReferral.value.ad_name ? adReferral.value.headline : null,
    },
    {
      label: t('CONVERSATION_SIDEBAR.AD_SOURCE.REFERRED_AT'),
      value: adReferral.value.referred_at
        ? dynamicTime(adReferral.value.referred_at)
        : null,
    },
  ].filter(item => item.value)
);
</script>

<template>
  <div class="px-4 py-3">
    <div class="flex gap-3 mb-3">
      <img
        v-if="adReferral.thumbnail_url"
        :src="adReferral.thumbnail_url"
        :alt="title"
        class="object-cover w-16 h-16 rounded-lg shrink-0 bg-n-alpha-2"
      />
      <div class="min-w-0">
        <span class="block text-xs font-medium uppercase text-n-slate-11">
          {{
            isAd
              ? t('CONVERSATION_SIDEBAR.AD_SOURCE.AD')
              : t('CONVERSATION_SIDEBAR.AD_SOURCE.POST')
          }}
        </span>
        <span class="block text-sm font-medium break-words text-n-slate-12">
          {{ title }}
        </span>
      </div>
    </div>

    <ContactDetailsItem
      v-for="item in detailItems"
      :key="item.label"
      compact
      class="mb-2"
      :title="item.label"
      :value="item.value"
    />

    <a
      v-if="adReferral.source_url"
      :href="adReferral.source_url"
      target="_blank"
      rel="noopener noreferrer"
      class="inline-block mt-1 text-sm text-n-brand hover:underline"
    >
      {{ t('CONVERSATION_SIDEBAR.AD_SOURCE.VIEW_ON_META') }}
    </a>

    <p v-if="adReferral.sync_error" class="mt-2 text-xs text-n-slate-11">
      {{ t('CONVERSATION_SIDEBAR.AD_SOURCE.SYNC_ERROR') }}
    </p>
  </div>
</template>
