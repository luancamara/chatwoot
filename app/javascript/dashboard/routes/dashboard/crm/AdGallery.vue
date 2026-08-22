<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import AdReportsAPI from 'dashboard/api/adReports';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();

const ads = ref([]);
const isLoading = ref(true);
const search = ref('');

const visibleAds = computed(() => {
  const term = search.value.trim().toLowerCase();
  if (!term) return ads.value;

  return ads.value.filter(ad =>
    [ad.ad_name, ad.campaign_name, ad.headline, ad.body]
      .filter(Boolean)
      .some(field => field.toLowerCase().includes(term))
  );
});

const formatDate = epoch =>
  new Date(epoch * 1000).toLocaleDateString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });

onMounted(async () => {
  try {
    const { data } = await AdReportsAPI.getGallery();
    ads.value = data.payload;
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex items-center justify-between gap-4">
      <h1 class="text-lg font-medium text-n-slate-12">
        {{ t('CRM.AD_GALLERY.TITLE') }}
      </h1>
      <Input
        v-model="search"
        class="w-64"
        size="sm"
        :placeholder="t('CRM.AD_GALLERY.SEARCH')"
      />
    </div>

    <div v-if="isLoading" class="flex justify-center py-10">
      <Spinner />
    </div>

    <div
      v-else-if="!visibleAds.length"
      class="py-10 text-sm text-center text-n-slate-11"
    >
      {{ t('CRM.AD_GALLERY.EMPTY') }}
    </div>

    <div
      v-else
      class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-5"
    >
      <article
        v-for="ad in visibleAds"
        :key="ad.ad_id"
        class="flex flex-col overflow-hidden rounded-lg bg-n-alpha-1"
      >
        <video
          v-if="ad.creative_type?.startsWith('video/')"
          :src="ad.creative_url"
          :poster="ad.thumbnail_url"
          controls
          preload="none"
          class="object-cover w-full aspect-[9/16] bg-n-alpha-2"
        />
        <img
          v-else-if="ad.creative_url || ad.thumbnail_url"
          :src="ad.creative_url || ad.thumbnail_url"
          :alt="ad.ad_name || ad.headline"
          class="object-cover w-full aspect-[9/16] bg-n-alpha-2"
        />

        <div class="flex flex-col gap-2 p-4">
          <h2 class="text-sm font-medium text-n-slate-12">
            {{ ad.ad_name || ad.headline || ad.ad_id }}
          </h2>

          <p v-if="ad.body" class="text-sm whitespace-pre-line text-n-slate-11">
            {{ ad.body }}
          </p>

          <dl class="mt-1 text-xs text-n-slate-11">
            <div v-if="ad.campaign_name" class="flex gap-1">
              <dt>{{ t('CRM.AD_GALLERY.CAMPAIGN') }}</dt>
              <dd class="truncate text-n-slate-12">{{ ad.campaign_name }}</dd>
            </div>
            <div class="flex gap-1">
              <dt>{{ t('CRM.AD_GALLERY.RUNNING_SINCE') }}</dt>
              <dd class="text-n-slate-12">
                {{ formatDate(ad.first_seen_at) }}
              </dd>
            </div>
            <div class="flex gap-1">
              <dt>{{ t('CRM.AD_GALLERY.LAST_LEAD') }}</dt>
              <dd class="text-n-slate-12">{{ formatDate(ad.last_seen_at) }}</dd>
            </div>
          </dl>

          <div class="flex gap-3 mt-1">
            <a
              v-if="ad.source_url"
              :href="ad.source_url"
              target="_blank"
              rel="noopener noreferrer"
              class="text-xs text-n-brand hover:underline"
            >
              {{ t('CRM.AD_GALLERY.VIEW_ON_META') }}
            </a>
          </div>
        </div>
      </article>
    </div>
  </div>
</template>
