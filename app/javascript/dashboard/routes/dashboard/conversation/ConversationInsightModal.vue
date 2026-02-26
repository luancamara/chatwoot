<script setup>
import { computed, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  insight: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close']);
const { t } = useI18n();

const onKeydown = e => {
  if (e.key === 'Escape') emit('close');
};

onMounted(() => document.addEventListener('keydown', onKeydown));
onUnmounted(() => document.removeEventListener('keydown', onKeydown));

const CRITERIA_MAX_SCORES = {
  needs_qualification: 5,
  closing_conduct: 5,
  media_usage: 3,
  personalization: 3,
  alternatives_offered: 3,
  tone_communication: 3,
  return_client_continuity: 3,
  cross_sell: 2,
};

const CRITERIA_WEIGHTS = {
  needs_qualification: '20%',
  closing_conduct: '20%',
  media_usage: '10%',
  personalization: '10%',
  alternatives_offered: '5%',
  tone_communication: '10%',
  return_client_continuity: '5%',
  cross_sell: '5%',
};

const ORDERED_CRITERIA = [
  'needs_qualification',
  'closing_conduct',
  'media_usage',
  'personalization',
  'unfulfilled_promises',
  'alternatives_offered',
  'tone_communication',
  'return_client_continuity',
  'cross_sell',
];

const scoreColor = computed(() => {
  const score = props.insight.final_score;
  if (score == null) return 'text-n-slate-11';
  if (score >= 7) return 'text-n-teal-11';
  if (score >= 4) return 'text-n-amber-11';
  return 'text-n-ruby-11';
});

const scoreBgColor = computed(() => {
  const score = props.insight.final_score;
  if (score == null) return 'bg-n-slate-3';
  if (score >= 7) return 'bg-n-teal-3';
  if (score >= 4) return 'bg-n-amber-3';
  return 'bg-n-ruby-3';
});

const scoreBarColor = computed(() => {
  const score = props.insight.final_score;
  if (score == null) return 'bg-n-slate-6';
  if (score >= 7) return 'bg-n-teal-9';
  if (score >= 4) return 'bg-n-amber-9';
  return 'bg-n-ruby-9';
});

const classificationLabel = computed(() => {
  const cls = props.insight.conversation_classification;
  if (!cls) return '';
  return t(`CRM.CONVERSATION_INSIGHT.CLASSIFICATION_LABELS.${cls}`);
});

const sentimentLabel = computed(() => {
  const s = props.insight.customer_sentiment;
  if (!s) return '';
  return t(`CRM.CONVERSATION_INSIGHT.SENTIMENT_LABELS.${s}`);
});

const formattedValue = computed(() => {
  const val = props.insight.estimated_value;
  if (!val || Number(val) === 0) return null;
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(val);
});

const criteriaEntries = computed(() => {
  const breakdown = props.insight.quality_breakdown;
  if (!breakdown) return [];
  return ORDERED_CRITERIA.map(key => {
    const data = breakdown[key];
    if (key === 'unfulfilled_promises') {
      return {
        key,
        label: t(`CRM.CONVERSATION_INSIGHT.CRITERIA_LABELS.${key}`),
        isFlag: true,
        flagged: data?.flagged === true,
        justification: data?.justification || '',
        isNA: !data,
      };
    }
    return {
      key,
      label: t(`CRM.CONVERSATION_INSIGHT.CRITERIA_LABELS.${key}`),
      isFlag: false,
      score: data?.score,
      max: CRITERIA_MAX_SCORES[key],
      weight: CRITERIA_WEIGHTS[key],
      justification: data?.justification || '',
      isNA: !data || data.score == null,
    };
  });
});

const penalties = computed(() => {
  return props.insight.penalties || [];
});

const metrics = computed(() => {
  return props.insight.automatic_metrics || {};
});

const formatDuration = seconds => {
  if (seconds == null) return '--';
  const mins = Math.round(seconds / 60);
  if (mins < 60)
    return `${mins} ${t('CRM.CONVERSATION_INSIGHT.AUTOMATIC_METRICS.MINUTES')}`;
  const hours = (seconds / 3600).toFixed(1);
  return `${hours} ${t('CRM.CONVERSATION_INSIGHT.AUTOMATIC_METRICS.HOURS')}`;
};

const tprColor = computed(() => {
  const s = metrics.value.tpr_seconds;
  if (s == null) return 'text-n-slate-11';
  if (s <= 900) return 'text-n-teal-11'; // <15min
  if (s <= 3600) return 'text-n-amber-11'; // <60min
  return 'text-n-ruby-11';
});

const tmerColor = computed(() => {
  const s = metrics.value.tmer_seconds;
  if (s == null) return 'text-n-slate-11';
  if (s <= 600) return 'text-n-teal-11'; // <10min
  if (s <= 1800) return 'text-n-amber-11'; // <30min
  return 'text-n-ruby-11';
});

const criterionBarPercent = (score, max) => {
  if (score == null || max == null || max === 0) return 0;
  return Math.round((score / max) * 100);
};

const criterionBarColor = (score, max) => {
  if (score == null) return 'bg-n-slate-4';
  const pct = score / max;
  if (pct >= 0.7) return 'bg-n-teal-9';
  if (pct >= 0.4) return 'bg-n-amber-9';
  return 'bg-n-ruby-9';
};
</script>

<template>
  <Teleport to="body">
    <div class="fixed inset-0 z-50 flex justify-end">
      <!-- Backdrop -->
      <div class="absolute inset-0 bg-n-alpha-black4" @click="emit('close')" />

      <!-- Panel -->
      <div
        class="relative z-10 flex h-full w-full max-w-[480px] flex-col overflow-hidden bg-n-background shadow-xl"
      >
        <!-- Header -->
        <div
          class="flex items-center justify-between border-b border-n-weak px-6 py-4"
        >
          <h2 class="text-base font-semibold text-n-slate-12">
            {{ t('CRM.CONVERSATION_INSIGHT.TITLE') }}
          </h2>
          <button
            class="flex items-center justify-center rounded-md p-1 text-n-slate-11 hover:bg-n-alpha-2"
            @click="emit('close')"
          >
            <span class="i-lucide-x size-5" />
          </button>
        </div>

        <!-- Scrollable Content -->
        <div class="flex-1 overflow-y-auto px-6 py-4">
          <div class="flex flex-col gap-6">
            <!-- Score Header -->
            <div class="flex items-center gap-4">
              <div
                class="flex size-16 items-center justify-center rounded-2xl"
                :class="scoreBgColor"
              >
                <span class="text-2xl font-bold" :class="scoreColor">
                  {{ insight.final_score != null ? insight.final_score : '--' }}
                </span>
              </div>
              <div class="flex flex-col gap-1">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ t('CRM.CONVERSATION_INSIGHT.FINAL_SCORE') }}
                </span>
                <div class="flex items-center gap-2">
                  <span
                    v-if="classificationLabel"
                    class="rounded-md bg-n-alpha-2 px-1.5 py-0.5 text-xs text-n-slate-12"
                  >
                    {{ classificationLabel }}
                  </span>
                  <span
                    v-if="sentimentLabel"
                    class="rounded-md bg-n-alpha-2 px-1.5 py-0.5 text-xs text-n-slate-11"
                  >
                    {{ sentimentLabel }}
                  </span>
                </div>
              </div>
            </div>

            <!-- Score bar -->
            <div class="h-2 w-full rounded-full bg-n-slate-3">
              <div
                class="h-2 rounded-full transition-all"
                :class="scoreBarColor"
                :style="{ width: `${(insight.final_score || 0) * 10}%` }"
              />
            </div>

            <!-- Section 1: Automatic Metrics -->
            <div class="flex flex-col gap-3">
              <h3 class="text-sm font-semibold text-n-slate-12">
                {{ t('CRM.CONVERSATION_INSIGHT.AUTOMATIC_METRICS.TITLE') }}
              </h3>
              <div class="grid grid-cols-2 gap-3">
                <!-- TPR -->
                <div class="flex flex-col gap-1 rounded-lg bg-n-alpha-1 p-3">
                  <span class="text-xs text-n-slate-11">
                    {{
                      t('CRM.CONVERSATION_INSIGHT.AUTOMATIC_METRICS.TPR_SHORT')
                    }}
                  </span>
                  <span class="text-sm font-semibold" :class="tprColor">
                    {{ formatDuration(metrics.tpr_seconds) }}
                  </span>
                </div>

                <!-- TMER -->
                <div class="flex flex-col gap-1 rounded-lg bg-n-alpha-1 p-3">
                  <span class="text-xs text-n-slate-11">
                    {{
                      t('CRM.CONVERSATION_INSIGHT.AUTOMATIC_METRICS.TMER_SHORT')
                    }}
                  </span>
                  <span class="text-sm font-semibold" :class="tmerColor">
                    {{ formatDuration(metrics.tmer_seconds) }}
                  </span>
                </div>

                <!-- Messages count -->
                <div class="flex flex-col gap-1 rounded-lg bg-n-alpha-1 p-3">
                  <span class="text-xs text-n-slate-11">
                    {{
                      t('CRM.CONVERSATION_INSIGHT.AUTOMATIC_METRICS.MESSAGES')
                    }}
                  </span>
                  <span class="text-sm font-semibold text-n-slate-12">
                    {{ metrics.message_count || 0 }}
                  </span>
                </div>

                <!-- Human responses -->
                <div class="flex flex-col gap-1 rounded-lg bg-n-alpha-1 p-3">
                  <span class="text-xs text-n-slate-11">
                    {{
                      t(
                        'CRM.CONVERSATION_INSIGHT.AUTOMATIC_METRICS.HUMAN_RESPONSES'
                      )
                    }}
                  </span>
                  <span class="text-sm font-semibold text-n-slate-12">
                    {{ metrics.human_response_count || 0 }}
                  </span>
                </div>
              </div>

              <!-- Flags row -->
              <div class="flex flex-wrap gap-2">
                <span
                  v-if="insight.no_response"
                  class="flex items-center gap-1 rounded-md bg-n-ruby-3 px-2 py-1 text-xs text-n-ruby-11"
                >
                  <span class="i-lucide-alert-circle size-3" />
                  {{
                    t('CRM.CONVERSATION_INSIGHT.AUTOMATIC_METRICS.NO_RESPONSE')
                  }}
                </span>
                <span
                  v-if="insight.abandonment_severity === 'severe'"
                  class="flex items-center gap-1 rounded-md bg-n-ruby-3 px-2 py-1 text-xs text-n-ruby-11"
                >
                  <span class="i-lucide-alert-triangle size-3" />
                  {{
                    t(
                      'CRM.CONVERSATION_INSIGHT.AUTOMATIC_METRICS.ABANDONMENT_SEVERE'
                    )
                  }}
                </span>
                <span
                  v-if="insight.abandonment_severity === 'light'"
                  class="flex items-center gap-1 rounded-md bg-n-amber-3 px-2 py-1 text-xs text-n-amber-11"
                >
                  <span class="i-lucide-clock size-3" />
                  {{
                    t(
                      'CRM.CONVERSATION_INSIGHT.AUTOMATIC_METRICS.ABANDONMENT_LIGHT'
                    )
                  }}
                </span>
                <span
                  v-if="insight.media_sent"
                  class="flex items-center gap-1 rounded-md bg-n-teal-3 px-2 py-1 text-xs text-n-teal-11"
                >
                  <span class="i-lucide-image size-3" />
                  {{
                    t('CRM.CONVERSATION_INSIGHT.AUTOMATIC_METRICS.MEDIA_SENT')
                  }}
                </span>
              </div>
            </div>

            <!-- Section 2: Qualitative Criteria -->
            <div class="flex flex-col gap-3">
              <h3 class="text-sm font-semibold text-n-slate-12">
                {{ t('CRM.CONVERSATION_INSIGHT.CRITERIA_LABELS.TITLE') }}
              </h3>
              <div class="flex flex-col gap-2">
                <div
                  v-for="entry in criteriaEntries"
                  :key="entry.key"
                  class="group"
                >
                  <!-- Flag type: unfulfilled_promises -->
                  <details
                    v-if="entry.isFlag"
                    class="rounded-lg"
                    :class="entry.isNA ? 'opacity-50' : ''"
                  >
                    <summary
                      class="flex cursor-pointer items-center justify-between rounded-lg p-2"
                      :class="
                        entry.isNA
                          ? ''
                          : entry.flagged
                            ? 'bg-n-ruby-2'
                            : 'bg-n-alpha-1 hover:bg-n-alpha-2'
                      "
                    >
                      <span class="text-xs text-n-slate-12">{{
                        entry.label
                      }}</span>
                      <span
                        v-if="entry.isNA"
                        class="rounded bg-n-slate-3 px-1.5 py-0.5 text-[10px] text-n-slate-11"
                      >
                        {{ t('CRM.CONVERSATION_INSIGHT.NOT_APPLICABLE') }}
                      </span>
                      <span
                        v-else-if="entry.flagged"
                        class="flex items-center gap-1 text-xs font-medium text-n-ruby-11"
                      >
                        <span class="i-lucide-alert-triangle size-3" />
                        {{
                          t('CRM.CONVERSATION_INSIGHT.PENALTIES.PENALTY_VALUE')
                        }}
                      </span>
                      <span v-else class="text-xs text-n-teal-11">
                        <span class="i-lucide-check size-3" />
                      </span>
                    </summary>
                    <div
                      v-if="entry.justification"
                      class="mx-2 mb-2 rounded-md bg-n-alpha-1 p-2 text-xs text-n-slate-11"
                    >
                      {{ entry.justification }}
                    </div>
                  </details>

                  <!-- Score type criteria -->
                  <details
                    v-else
                    class="rounded-lg"
                    :class="entry.isNA ? 'opacity-50' : ''"
                  >
                    <summary
                      class="flex cursor-pointer items-center gap-2 rounded-lg p-2 hover:bg-n-alpha-1 min-w-0"
                    >
                      <span
                        class="min-w-0 flex-1 truncate text-xs text-n-slate-12"
                        >{{ entry.label }}</span
                      >
                      <span
                        v-if="entry.isNA"
                        class="rounded bg-n-slate-3 px-1.5 py-0.5 text-[10px] text-n-slate-11"
                      >
                        {{ t('CRM.CONVERSATION_INSIGHT.NOT_APPLICABLE') }}
                      </span>
                      <template v-else>
                        <span class="shrink-0 text-[10px] text-n-slate-10">{{
                          entry.weight
                        }}</span>
                        <div
                          class="h-1.5 w-16 shrink-0 rounded-full bg-n-slate-3"
                        >
                          <div
                            class="h-1.5 rounded-full transition-all"
                            :class="criterionBarColor(entry.score, entry.max)"
                            :style="{
                              width: `${criterionBarPercent(entry.score, entry.max)}%`,
                            }"
                          />
                        </div>
                        <span
                          class="w-8 shrink-0 text-right text-xs font-medium text-n-slate-12"
                        >
                          {{
                            t(
                              'CRM.CONVERSATION_INSIGHT.PENALTIES.SCORE_FRACTION',
                              { score: entry.score, max: entry.max }
                            )
                          }}
                        </span>
                      </template>
                    </summary>
                    <div
                      v-if="entry.justification"
                      class="mx-2 mb-2 rounded-md bg-n-alpha-1 p-2 text-xs text-n-slate-11"
                    >
                      {{ entry.justification }}
                    </div>
                  </details>
                </div>
              </div>
            </div>

            <!-- Section 3: Penalties -->
            <div v-if="penalties.length" class="flex flex-col gap-3">
              <h3 class="text-sm font-semibold text-n-ruby-11">
                {{ t('CRM.CONVERSATION_INSIGHT.PENALTIES.TITLE') }}
              </h3>
              <div class="flex flex-col gap-2">
                <div
                  v-for="(penalty, idx) in penalties"
                  :key="idx"
                  class="flex items-center justify-between gap-3 rounded-lg bg-n-ruby-2 p-3"
                >
                  <div class="flex min-w-0 flex-1 items-center gap-2">
                    <span
                      class="i-lucide-alert-triangle size-4 shrink-0 text-n-ruby-11"
                    />
                    <span class="truncate text-xs text-n-ruby-11">
                      {{ penalty.description }}
                    </span>
                  </div>
                  <span
                    v-if="penalty.value !== 0"
                    class="shrink-0 text-xs font-semibold text-n-ruby-11"
                  >
                    {{ penalty.value > 0 ? '+' : '' }}{{ penalty.value }}
                  </span>
                </div>
              </div>
            </div>

            <!-- Section 4: Feedback -->
            <div v-if="insight.feedback_summary" class="flex flex-col gap-3">
              <h3 class="text-sm font-semibold text-n-slate-12">
                {{ t('CRM.CONVERSATION_INSIGHT.FEEDBACK.TITLE') }}
              </h3>
              <div
                class="rounded-lg border border-n-weak bg-n-alpha-1 p-4 text-sm text-n-slate-12"
              >
                {{ insight.feedback_summary }}
              </div>
            </div>

            <!-- Section 5: Commercial Info -->
            <div class="flex flex-col gap-3">
              <h3 class="text-sm font-semibold text-n-slate-12">
                {{ t('CRM.CONVERSATION_INSIGHT.COMMERCIAL_INFO.TITLE') }}
              </h3>
              <div class="grid grid-cols-2 gap-3">
                <div v-if="formattedValue" class="flex flex-col gap-0.5">
                  <span class="text-xs text-n-slate-11">
                    {{ t('CRM.CONVERSATION_INSIGHT.ESTIMATED_VALUE') }}
                  </span>
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ formattedValue }}
                  </span>
                </div>
                <div
                  v-if="insight.product_category"
                  class="flex flex-col gap-0.5"
                >
                  <span class="text-xs text-n-slate-11">
                    {{ t('CRM.CONVERSATION_INSIGHT.PRODUCT_CATEGORY') }}
                  </span>
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ insight.product_category }}
                  </span>
                </div>
              </div>

              <!-- Key Topics -->
              <div
                v-if="insight.key_topics?.length"
                class="flex flex-col gap-1"
              >
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
            </div>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>
