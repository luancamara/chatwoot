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

// An ads_read token cannot download the video file — Meta omits `source` — and
// the Facebook reel player refuses these creatives because they are dark posts,
// published only as ads. The Instagram permalink the webhook carries points at
// the public post, which does embed, so that is what plays here.
const playingAdId = ref(null);

const embedUrl = ad => {
  const post = ad.source_url?.match(/instagram\.com\/(p|reel)\/([\w-]+)/);
  return post ? `https://www.instagram.com/${post[1]}/${post[2]}/embed/` : null;
};

const isPlayable = ad => ad.media_type === 'video' && Boolean(embedUrl(ad));

// Loaded only on click: mounting fifty Instagram iframes up front would be slow
// and would call out to Meta for every ad on screen.
const play = adId => {
  playingAdId.value = adId;
};

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
        <iframe
          v-else-if="playingAdId === ad.ad_id"
          :src="embedUrl(ad)"
          :title="ad.ad_name || ad.headline"
          class="w-full border-0 aspect-[9/16] bg-n-alpha-2"
          allow="autoplay; encrypted-media; picture-in-picture; web-share"
          allowfullscreen
        />
        <button
          v-else-if="isPlayable(ad)"
          type="button"
          class="relative w-full group aspect-[9/16] bg-n-alpha-2"
          :aria-label="t('CRM.AD_GALLERY.WATCH_VIDEO')"
          @click="play(ad.ad_id)"
        >
          <img
            v-if="ad.creative_url || ad.thumbnail_url"
            :src="ad.creative_url || ad.thumbnail_url"
            :alt="ad.ad_name || ad.headline"
            class="object-cover w-full h-full"
          />
          <span
            class="absolute inset-0 flex items-center justify-center transition-colors bg-black/25 group-hover:bg-black/40"
          >
            <span
              class="grid rounded-full size-14 place-items-center bg-white/90"
            >
              <span class="text-black size-7 i-lucide-play" />
            </span>
          </span>
        </button>
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
