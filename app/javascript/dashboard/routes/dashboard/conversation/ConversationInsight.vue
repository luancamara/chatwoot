<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import ConversationInsightAPI from 'dashboard/api/conversationInsight';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const insight = ref(null);
const isLoading = ref(false);
const hasError = ref(false);

const scoreColor = computed(() => {
  if (!insight.value?.quality_score) return 'bg-n-slate-6';
  const score = insight.value.quality_score * 10;
  if (score >= 70) return 'bg-n-teal-9';
  if (score >= 40) return 'bg-n-amber-9';
  return 'bg-n-ruby-9';
});

const scoreTextColor = computed(() => {
  if (!insight.value?.quality_score) return 'text-n-slate-11';
  const score = insight.value.quality_score * 10;
  if (score >= 70) return 'text-n-teal-11';
  if (score >= 40) return 'text-n-amber-11';
  return 'text-n-ruby-11';
});

const scoreLabel = computed(() => {
  if (!insight.value?.quality_score) return '';
  const score = insight.value.quality_score * 10;
  if (score >= 70) return t('CRM.CONVERSATION_INSIGHT.SCORE_LABELS.HIGH');
  if (score >= 40) return t('CRM.CONVERSATION_INSIGHT.SCORE_LABELS.MEDIUM');
  return t('CRM.CONVERSATION_INSIGHT.SCORE_LABELS.LOW');
});

const sentimentLabel = computed(() => {
  const sentiment = insight.value?.customer_sentiment;
  if (!sentiment) return '';
  return t(`CRM.CONVERSATION_INSIGHT.SENTIMENT_LABELS.${sentiment}`);
});

const formattedValue = computed(() => {
  const val = insight.value?.estimated_value;
  if (!val || Number(val) === 0) return null;
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(val);
});

const breakdownEntries = computed(() => {
  const breakdown = insight.value?.quality_breakdown;
  if (!breakdown) return [];
  return Object.entries(breakdown).map(([key, value]) => ({
    key,
    label: t(`CRM.CONVERSATION_INSIGHT.BREAKDOWN_LABELS.${key}`),
    value,
  }));
});

const fetchInsight = async conversationId => {
  if (!conversationId) return;
  isLoading.value = true;
  hasError.value = false;
  try {
    const { data } = await ConversationInsightAPI.show(conversationId);
    insight.value = data?.id ? data : null;
  } catch {
    hasError.value = true;
    insight.value = null;
  } finally {
    isLoading.value = false;
  }
};

watch(
  () => props.conversationId,
  newId => fetchInsight(newId)
);

onMounted(() => fetchInsight(props.conversationId));
</script>

<template>
  <div class="px-4 py-2">
    <div
      v-if="isLoading"
      class="flex items-center gap-2 text-sm text-n-slate-11"
    >
      <span class="i-lucide-loader-circle animate-spin" />
      {{ t('CRM.CONVERSATION_INSIGHT.LOADING') }}
    </div>

    <div v-else-if="hasError" class="text-sm text-n-ruby-11">
      {{ t('CRM.CONVERSATION_INSIGHT.ERROR') }}
    </div>

    <div v-else-if="!insight" class="text-sm text-n-slate-11">
      {{ t('CRM.CONVERSATION_INSIGHT.EMPTY') }}
    </div>

    <div v-else class="flex min-w-0 flex-col gap-3 overflow-hidden">
      <!-- Quality Score -->
      <div class="flex flex-col gap-1.5">
        <div class="flex items-center justify-between">
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('CRM.CONVERSATION_INSIGHT.SCORE') }}
          </span>
          <span class="text-sm font-semibold" :class="scoreTextColor">
            {{ `${insight.quality_score}/10` }}
            <span class="text-xs font-normal">{{ scoreLabel }}</span>
          </span>
        </div>
        <div class="h-1.5 w-full rounded-full bg-n-slate-3">
          <div
            class="h-1.5 rounded-full transition-all"
            :class="scoreColor"
            :style="{ width: `${insight.quality_score * 10}%` }"
          />
        </div>
      </div>

      <!-- Key Info Grid -->
      <div class="grid grid-cols-2 gap-2">
        <div v-if="formattedValue" class="flex flex-col gap-0.5">
          <span class="text-xs text-n-slate-11">
            {{ t('CRM.CONVERSATION_INSIGHT.ESTIMATED_VALUE') }}
          </span>
          <span class="text-sm font-medium text-n-slate-12">
            {{ formattedValue }}
          </span>
        </div>
        <div v-if="insight.product_category" class="flex flex-col gap-0.5">
          <span class="text-xs text-n-slate-11">
            {{ t('CRM.CONVERSATION_INSIGHT.PRODUCT_CATEGORY') }}
          </span>
          <span class="text-sm font-medium text-n-slate-12">
            {{ insight.product_category }}
          </span>
        </div>
        <div v-if="insight.customer_sentiment" class="flex flex-col gap-0.5">
          <span class="text-xs text-n-slate-11">
            {{ t('CRM.CONVERSATION_INSIGHT.SENTIMENT') }}
          </span>
          <span class="text-sm font-medium text-n-slate-12">
            {{ sentimentLabel }}
          </span>
        </div>
      </div>

      <!-- Key Topics -->
      <div v-if="insight.key_topics?.length" class="flex flex-col gap-1">
        <span class="text-xs text-n-slate-11">
          {{ t('CRM.CONVERSATION_INSIGHT.KEY_TOPICS') }}
        </span>
        <div class="flex flex-wrap gap-1">
          <span
            v-for="topic in insight.key_topics"
            :key="topic"
            class="rounded-md bg-n-alpha-2 px-1.5 py-0.5 text-xs text-n-slate-12"
          >
            {{ topic }}
          </span>
        </div>
      </div>

      <!-- Quality Breakdown -->
      <div v-if="breakdownEntries.length" class="flex flex-col gap-1.5">
        <span class="text-xs text-n-slate-11">
          {{ t('CRM.CONVERSATION_INSIGHT.QUALITY_BREAKDOWN') }}
        </span>
        <div class="flex flex-col gap-1">
          <div
            v-for="entry in breakdownEntries"
            :key="entry.key"
            class="flex items-center justify-between"
          >
            <span class="text-xs text-n-slate-11">{{ entry.label }}</span>
            <div class="flex gap-0.5">
              <span
                v-for="i in 2"
                :key="i"
                class="h-2 w-2 rounded-full"
                :class="i <= entry.value ? 'bg-n-teal-9' : 'bg-n-slate-4'"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
