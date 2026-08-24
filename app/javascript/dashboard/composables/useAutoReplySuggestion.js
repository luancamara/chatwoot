import { computed, ref } from 'vue';
import { useCaptain } from 'dashboard/composables/useCaptain';
import { useTrack } from 'dashboard/composables';
import { CAPTAIN_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import {
  CAPTAIN_ERROR_TYPES,
  CAPTAIN_GENERATION_FAILURE_REASONS,
} from 'dashboard/composables/captain/constants';

const GENERATION_DELAY = 300;

export function useAutoReplySuggestion() {
  const { captainTasksEnabled, getReplySuggestion } = useCaptain();

  const isGenerating = ref(false);
  const suggestion = ref('');
  const activeContextKey = ref(null);
  const targetMessageId = ref(null);

  const processedContexts = new Map();
  let debounceTimer = null;
  let abortController = null;
  let activeConversationId = null;

  const isVisible = computed(() => suggestion.value.length > 0);
  const isActive = computed(() => isGenerating.value || isVisible.value);

  const clearDebounce = () => {
    if (!debounceTimer) return;

    clearTimeout(debounceTimer);
    debounceTimer = null;
  };

  const abortRequest = () => {
    if (!abortController) return;

    abortController.abort();
    abortController = null;
  };

  const clearState = () => {
    const contextKey = activeContextKey.value;
    if (processedContexts.get(contextKey)?.status === 'generating') {
      processedContexts.set(contextKey, { status: 'cancelled' });
    }
    clearDebounce();
    abortRequest();
    isGenerating.value = false;
    suggestion.value = '';
    activeContextKey.value = null;
    targetMessageId.value = null;
    activeConversationId = null;
  };

  const track = event => {
    useTrack(event, {
      conversationId: activeConversationId,
      entryPoint: 'automatic',
      targetMessageId: targetMessageId.value,
    });
  };

  const generate = async context => {
    const requestController = new AbortController();
    abortController = requestController;
    isGenerating.value = true;
    processedContexts.set(context.contextKey, { status: 'generating' });

    try {
      const { message, errorType } = await getReplySuggestion({
        signal: requestController.signal,
        silent: true,
      });

      if (
        requestController.signal.aborted ||
        activeContextKey.value !== context.contextKey
      ) {
        if (
          processedContexts.get(context.contextKey)?.status === 'generating'
        ) {
          processedContexts.set(context.contextKey, { status: 'cancelled' });
        }
        return;
      }

      if (message) {
        suggestion.value = message;
        processedContexts.set(context.contextKey, {
          status: 'ready',
          suggestion: message,
        });
        track(CAPTAIN_EVENTS.REPLY_SUGGESTION_USED);
        return;
      }

      processedContexts.set(context.contextKey, { status: 'failed' });
      useTrack(CAPTAIN_EVENTS.GENERATION_FAILED, {
        conversationId: context.conversationId,
        entryPoint: 'automatic',
        targetMessageId: context.targetMessageId,
        stage: 'initial',
        reason: errorType || CAPTAIN_GENERATION_FAILURE_REASONS.EMPTY_RESPONSE,
      });
    } catch (error) {
      if (
        requestController.signal.aborted ||
        error?.name === CAPTAIN_ERROR_TYPES.ABORT_ERROR ||
        error?.name === CAPTAIN_ERROR_TYPES.CANCELED_ERROR
      ) {
        if (
          processedContexts.get(context.contextKey)?.status === 'generating'
        ) {
          processedContexts.set(context.contextKey, { status: 'cancelled' });
        }
        return;
      }

      processedContexts.set(context.contextKey, { status: 'failed' });
      useTrack(CAPTAIN_EVENTS.GENERATION_FAILED, {
        conversationId: context.conversationId,
        entryPoint: 'automatic',
        targetMessageId: context.targetMessageId,
        stage: 'initial',
        reason: error?.name || CAPTAIN_GENERATION_FAILURE_REASONS.EXCEPTION,
      });
    } finally {
      if (abortController === requestController) {
        abortController = null;
      }
      if (activeContextKey.value === context.contextKey) {
        isGenerating.value = false;
      }
    }
  };

  const schedule = context => {
    if (!context?.contextKey) {
      clearState();
      return;
    }

    const cached = processedContexts.get(context.contextKey);
    if (cached?.status === 'ready') {
      clearState();
      activeContextKey.value = context.contextKey;
      targetMessageId.value = context.targetMessageId;
      activeConversationId = context.conversationId;
      suggestion.value = cached.suggestion;
      return;
    }

    if (cached) {
      if (activeContextKey.value !== context.contextKey) clearState();
      return;
    }
    if (activeContextKey.value === context.contextKey) return;

    clearState();
    activeContextKey.value = context.contextKey;
    targetMessageId.value = context.targetMessageId;
    activeConversationId = context.conversationId;
    debounceTimer = setTimeout(() => {
      debounceTimer = null;
      generate(context);
    }, GENERATION_DELAY);
  };

  const dismiss = () => {
    const contextKey = activeContextKey.value;
    const hadSuggestion = isVisible.value;

    if (contextKey) {
      processedContexts.set(contextKey, { status: 'dismissed' });
    }
    if (hadSuggestion) {
      track(CAPTAIN_EVENTS.REPLY_SUGGESTION_DISMISSED);
    }
    clearState();
  };

  const accept = () => {
    if (!suggestion.value) return null;

    const acceptedSuggestion = {
      message: suggestion.value,
      targetMessageId: targetMessageId.value,
    };
    if (activeContextKey.value) {
      processedContexts.set(activeContextKey.value, { status: 'applied' });
    }
    track(CAPTAIN_EVENTS.REPLY_SUGGESTION_APPLIED);
    clearState();

    return acceptedSuggestion;
  };

  return {
    captainTasksEnabled,
    isGenerating,
    suggestion,
    isVisible,
    isActive,
    schedule,
    clear: clearState,
    dismiss,
    accept,
  };
}
