<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import ErpOrdersAPI from 'dashboard/api/erpOrders';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();

const currentChat = useMapGetter('getSelectedChat');
const contactId = computed(() => currentChat.value?.meta?.sender?.id);

const history = ref(null);
const isLoading = ref(false);

const orders = computed(() => history.value?.pedidos ?? []);
const totalSpent = computed(() => history.value?.total_gasto ?? 0);

const money = value =>
  Number(value || 0).toLocaleString('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    maximumFractionDigits: 0,
  });

const formatDate = value =>
  value ? new Date(value).toLocaleDateString('pt-BR') : '';

const fetchHistory = async id => {
  if (!id) return;
  isLoading.value = true;
  try {
    const { data } = await ErpOrdersAPI.getHistory(id);
    history.value = data;
  } catch {
    history.value = null;
  } finally {
    isLoading.value = false;
  }
};

watch(contactId, id => fetchHistory(id), { immediate: true });
</script>

<template>
  <div class="px-4 py-3">
    <div v-if="isLoading" class="flex justify-center py-4">
      <Spinner />
    </div>

    <p v-else-if="!orders.length" class="text-sm text-n-slate-11">
      {{ t('CONVERSATION_SIDEBAR.ERP_ORDERS.EMPTY') }}
    </p>

    <template v-else>
      <div class="flex justify-between mb-3 text-sm">
        <span class="text-n-slate-11">
          {{ t('CONVERSATION_SIDEBAR.ERP_ORDERS.TOTAL') }}
        </span>
        <span class="font-medium text-n-slate-12">{{ money(totalSpent) }}</span>
      </div>

      <div
        v-for="order in orders"
        :key="order.pedido"
        class="flex items-start justify-between gap-2 py-2 border-t border-n-weak"
      >
        <div class="min-w-0">
          <span class="block text-sm truncate text-n-slate-12">
            {{ order.pedido }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ formatDate(order.data) }}
          </span>
        </div>
        <div class="text-right shrink-0">
          <span class="block text-sm text-n-slate-12">
            {{ money(order.valor) }}
          </span>
          <span
            v-if="order.status === 'cancelado'"
            class="text-xs text-n-ruby-11"
          >
            {{ t('CONVERSATION_SIDEBAR.ERP_ORDERS.CANCELLED') }}
          </span>
        </div>
      </div>
    </template>
  </div>
</template>
