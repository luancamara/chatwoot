<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import Draggable from 'vuedraggable';
import ConversationApi from 'dashboard/api/inbox/conversation';
import CrmReportsAPI from 'dashboard/api/crmReports';
import CrmFilters from './components/CrmFilters.vue';
import PipelineCard from './components/PipelineCard.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { FUNNEL_STAGES } from './constants';

const { t } = useI18n();
const router = useRouter();
const { accountScopedRoute } = useAccount();

const isLoading = ref(false);
const columns = ref(
  FUNNEL_STAGES.reduce((acc, stage) => {
    acc[stage.value] = [];
    return acc;
  }, {})
);
const filterParams = ref({});

const fetchConversations = async () => {
  isLoading.value = true;
  try {
    const { data } = await CrmReportsAPI.getPipeline(filterParams.value);
    const payload = data?.payload || {};
    columns.value = FUNNEL_STAGES.reduce((acc, stage) => {
      acc[stage.value] = payload[stage.value] || [];
      return acc;
    }, {});
  } catch {
    useAlert(t('CRM.PIPELINE.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const onFilterChange = params => {
  filterParams.value = params;
  fetchConversations();
};

const formatCurrency = value => {
  if (!value) return 'R$ 0';
  return `R$ ${Number(value).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`;
};

const stageTotal = stageValue =>
  (columns.value[stageValue] || []).reduce(
    (sum, conversation) =>
      sum + Number(conversation.custom_attributes?.crm_estimated_value || 0),
    0
  );

const updateConversationStage = async (conversation, toStage) => {
  try {
    await ConversationApi.updateCustomAttributes({
      conversationId: conversation.id,
      customAttributes: {
        ...conversation.custom_attributes,
        crm_funnel_stage: toStage,
        crm_stage_changed_at: new Date().toISOString(),
      },
    });
  } catch {
    fetchConversations();
  }
};

const updateConversationValue = async (conversation, value) => {
  const customAttributes = { ...conversation.custom_attributes };
  if (value === null) {
    delete customAttributes.crm_estimated_value;
  } else {
    customAttributes.crm_estimated_value = value;
  }
  conversation.custom_attributes = customAttributes;
  try {
    await ConversationApi.updateCustomAttributes({
      conversationId: conversation.id,
      customAttributes,
    });
  } catch {
    useAlert(t('CRM.PIPELINE.VALUE_ERROR'));
    fetchConversations();
  }
};

const onColumnChange = (stageValue, event) => {
  if (event.added) {
    updateConversationStage(event.added.element, stageValue);
  }
};

const openConversation = conversation => {
  const route = accountScopedRoute('conversation', {
    id: conversation.display_id,
  });
  router.push(route);
};

const hasConversations = computed(() =>
  Object.values(columns.value).some(c => c.length > 0)
);

onMounted(() => {
  fetchConversations();
});
</script>

<template>
  <div class="flex flex-col gap-6 h-full">
    <div>
      <h1 class="text-xl font-semibold text-n-slate-12">
        {{ t('CRM.PIPELINE.TITLE') }}
      </h1>
      <p class="mt-1 text-sm text-n-slate-11">
        {{ t('CRM.PIPELINE.DESCRIPTION') }}
      </p>
    </div>

    <CrmFilters @filter-change="onFilterChange" />

    <div v-if="isLoading" class="flex justify-center py-12">
      <Spinner />
    </div>

    <div
      v-else-if="hasConversations"
      class="flex gap-4 overflow-x-auto pb-4 flex-1"
    >
      <div
        v-for="stage in FUNNEL_STAGES"
        :key="stage.value"
        class="flex flex-col w-72 flex-shrink-0"
      >
        <div
          class="flex items-center justify-between px-3 py-2 mb-2 rounded-lg bg-n-solid-2"
        >
          <div class="flex items-center gap-2 min-w-0">
            <span class="text-sm font-semibold text-n-slate-12 truncate">
              {{ stage.label }}
            </span>
            <span
              class="flex items-center justify-center min-w-[22px] h-5 px-1.5 text-xs font-medium rounded-full bg-n-solid-3 text-n-slate-11"
            >
              {{ columns[stage.value]?.length || 0 }}
            </span>
          </div>
          <span
            v-if="stageTotal(stage.value) > 0"
            class="text-xs font-medium text-n-teal-11 flex-shrink-0"
          >
            {{ formatCurrency(stageTotal(stage.value)) }}
          </span>
        </div>
        <Draggable
          :list="columns[stage.value]"
          group="pipeline"
          animation="200"
          item-key="id"
          ghost-class="opacity-50"
          class="flex flex-col gap-2 flex-1 p-1 min-h-[100px] rounded-lg"
          @change="event => onColumnChange(stage.value, event)"
        >
          <template #item="{ element }">
            <div @dblclick="openConversation(element)">
              <PipelineCard
                :conversation="element"
                @open="openConversation(element)"
                @update-value="value => updateConversationValue(element, value)"
              />
            </div>
          </template>
        </Draggable>
      </div>
    </div>

    <div
      v-else
      class="flex flex-col items-center justify-center py-16 text-n-slate-10"
    >
      <span class="i-lucide-kanban size-12 mb-3" />
      <p class="text-sm">{{ t('CRM.PIPELINE.NO_DATA') }}</p>
    </div>
  </div>
</template>
