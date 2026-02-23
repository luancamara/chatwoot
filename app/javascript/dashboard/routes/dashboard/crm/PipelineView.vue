<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';
import Draggable from 'vuedraggable';
import ConversationApi from 'dashboard/api/inbox/conversation';
import CrmFilters from './components/CrmFilters.vue';
import PipelineCard from './components/PipelineCard.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const FUNNEL_STAGES = [
  'Lead',
  'Qualificado',
  'Orcamento',
  'Negociacao',
  'Venda',
  'Perda',
];

const { t } = useI18n();
const router = useRouter();
const { accountScopedRoute } = useAccount();

const isLoading = ref(false);
const columns = ref(
  FUNNEL_STAGES.reduce((acc, stage) => {
    acc[stage] = [];
    return acc;
  }, {})
);
const filterParams = ref({});

const fetchConversations = async () => {
  isLoading.value = true;
  try {
    const promises = FUNNEL_STAGES.map(stage => {
      const queryData = {
        payload: [
          {
            attribute_key: 'crm_funnel_stage',
            attribute_model: 'custom_attribute',
            filter_operator: 'equal_to',
            values: [stage],
            custom_attribute_type: 'conversation_attribute',
            query_operator: null,
          },
        ],
      };
      return ConversationApi.filter({
        queryData,
        page: 1,
        ...filterParams.value,
      }).then(res => ({ stage, data: res.data?.data?.payload || [] }));
    });

    const results = await Promise.all(promises);
    const newColumns = {};
    results.forEach(({ stage, data }) => {
      newColumns[stage] = data;
    });
    columns.value = newColumns;
  } catch {
    // Handle error silently
  } finally {
    isLoading.value = false;
  }
};

const onFilterChange = params => {
  filterParams.value = params;
  fetchConversations();
};

const updateConversationStage = async (conversation, toStage) => {
  try {
    await ConversationApi.updateCustomAttributes({
      conversationId: conversation.id,
      customAttributes: {
        crm_funnel_stage: toStage,
        crm_stage_changed_at: new Date().toISOString(),
      },
    });
  } catch {
    fetchConversations();
  }
};

const onColumnChange = (stage, event) => {
  if (event.added) {
    updateConversationStage(event.added.element, stage);
  }
};

const openConversation = conversation => {
  const route = accountScopedRoute('conversation', {
    id: conversation.display_id,
  });
  router.push(route);
};

const hasConversations = () =>
  Object.values(columns.value).some(c => c.length > 0);

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

    <div v-else-if="hasConversations()" class="flex gap-4 overflow-x-auto pb-4 flex-1">
      <div
        v-for="stage in FUNNEL_STAGES"
        :key="stage"
        class="flex flex-col w-72 flex-shrink-0"
      >
        <div
          class="flex items-center justify-between px-3 py-2 mb-2 rounded-lg bg-n-solid-2"
        >
          <span class="text-sm font-semibold text-n-slate-12">
            {{ stage }}
          </span>
          <span
            class="flex items-center justify-center min-w-[22px] h-5 px-1.5 text-xs font-medium rounded-full bg-n-solid-3 text-n-slate-11"
          >
            {{ columns[stage]?.length || 0 }}
          </span>
        </div>
        <Draggable
          :list="columns[stage]"
          group="pipeline"
          animation="200"
          item-key="id"
          ghost-class="opacity-50"
          class="flex flex-col gap-2 flex-1 p-1 min-h-[100px] rounded-lg"
          @change="event => onColumnChange(stage, event)"
        >
          <template #item="{ element }">
            <div @dblclick="openConversation(element)">
              <PipelineCard :conversation="element" />
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
