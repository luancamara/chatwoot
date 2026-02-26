<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import ConversationInsightAPI from 'dashboard/api/conversationInsight';
import ConversationInsightModal from './ConversationInsightModal.vue';

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
const isModalOpen = ref(false);
const isRegenerating = ref(false);

const scoreColor = computed(() => {
  const score = insight.value?.final_score;
  if (score == null) return 'bg-n-slate-6';
  if (score >= 7) return 'bg-n-teal-9';
  if (score >= 4) return 'bg-n-amber-9';
  return 'bg-n-ruby-9';
});

const scoreTextColor = computed(() => {
  const score = insight.value?.final_score;
  if (score == null) return 'text-n-slate-11';
  if (score >= 7) return 'text-n-teal-11';
  if (score >= 4) return 'text-n-amber-11';
  return 'text-n-ruby-11';
});

const scoreLabel = computed(() => {
  const score = insight.value?.final_score;
  if (score == null) return '';
  if (score >= 7) return t('CRM.CONVERSATION_INSIGHT.SCORE_LABELS.HIGH');
  if (score >= 4) return t('CRM.CONVERSATION_INSIGHT.SCORE_LABELS.MEDIUM');
  return t('CRM.CONVERSATION_INSIGHT.SCORE_LABELS.LOW');
});

const classificationLabel = computed(() => {
  const cls = insight.value?.conversation_classification;
  if (!cls) return '';
  return t(`CRM.CONVERSATION_INSIGHT.CLASSIFICATION_LABELS.${cls}`);
});

const hasPenalties = computed(() => {
  return insight.value?.penalties?.length > 0;
});

const hasNoResponse = computed(() => {
  return insight.value?.no_response === true;
});

const hasAbandonment = computed(() => {
  return !!insight.value?.abandonment_severity;
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

const regenerateInsight = async () => {
  isRegenerating.value = true;
  try {
    await ConversationInsightAPI.regenerate(props.conversationId);
    useAlert(t('CRM.CONVERSATION_INSIGHT.REGENERATE_SUCCESS'));
  } catch {
    useAlert(t('CRM.CONVERSATION_INSIGHT.REGENERATE_ERROR'));
  } finally {
    isRegenerating.value = false;
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
      <!-- Final Score -->
      <div class="flex flex-col gap-1.5">
        <div class="flex items-center justify-between">
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('CRM.CONVERSATION_INSIGHT.FINAL_SCORE') }}
          </span>
          <span class="text-sm font-semibold" :class="scoreTextColor">
            <template v-if="insight.final_score != null">
              {{
                t('CRM.CONVERSATION_INSIGHT.PENALTIES.SCORE_DISPLAY', {
                  score: insight.final_score,
                })
              }}
              <span class="text-xs font-normal">{{ scoreLabel }}</span>
            </template>
            <template v-else>--</template>
          </span>
        </div>
        <div class="h-1.5 w-full rounded-full bg-n-slate-3">
          <div
            class="h-1.5 rounded-full transition-all"
            :class="scoreColor"
            :style="{ width: `${(insight.final_score || 0) * 10}%` }"
          />
        </div>
      </div>

      <!-- Classification Badge -->
      <div v-if="classificationLabel" class="flex items-center gap-2">
        <span
          class="rounded-md bg-n-alpha-2 px-1.5 py-0.5 text-xs text-n-slate-12"
        >
          {{ classificationLabel }}
        </span>
      </div>

      <!-- Alert Flags -->
      <div
        v-if="hasNoResponse || hasAbandonment || hasPenalties"
        class="flex flex-wrap gap-1.5"
      >
        <span
          v-if="hasNoResponse"
          class="flex items-center gap-1 rounded-md bg-n-ruby-3 px-1.5 py-0.5 text-xs text-n-ruby-11"
        >
          <span class="i-lucide-alert-circle size-3" />
          {{ t('CRM.CONVERSATION_INSIGHT.NO_RESPONSE_LABEL') }}
        </span>
        <span
          v-if="hasAbandonment"
          class="flex items-center gap-1 rounded-md bg-n-amber-3 px-1.5 py-0.5 text-xs text-n-amber-11"
        >
          <span class="i-lucide-clock size-3" />
          {{ t('CRM.CONVERSATION_INSIGHT.ABANDONMENT_LABEL') }}
        </span>
      </div>

      <!-- Actions -->
      <div class="flex flex-wrap items-center gap-2">
        <button
          class="flex items-center gap-1 rounded-md bg-n-alpha-2 px-2 py-1 text-xs font-medium text-n-slate-12 hover:bg-n-alpha-3 transition-colors whitespace-nowrap"
          @click="isModalOpen = true"
        >
          <span class="i-lucide-bar-chart-3 size-3.5 shrink-0" />
          {{ t('CRM.CONVERSATION_INSIGHT.VIEW_FULL_ANALYSIS') }}
        </button>
        <button
          class="flex items-center gap-1 rounded-md px-2 py-1 text-xs text-n-slate-11 hover:bg-n-alpha-2 transition-colors whitespace-nowrap"
          :disabled="isRegenerating"
          @click="regenerateInsight"
        >
          <span
            class="size-3.5 shrink-0"
            :class="
              isRegenerating
                ? 'i-lucide-loader-circle animate-spin'
                : 'i-lucide-refresh-cw'
            "
          />
          {{ t('CRM.CONVERSATION_INSIGHT.REGENERATE') }}
        </button>
      </div>
    </div>

    <!-- Full Analysis Modal -->
    <ConversationInsightModal
      v-if="isModalOpen"
      :insight="insight"
      @close="isModalOpen = false"
    />
  </div>
</template>
