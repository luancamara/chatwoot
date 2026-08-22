import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { ATTRIBUTE_TYPES } from 'dashboard/components-next/ConversationWorkflow/constants';

/**
 * Evaluates whether a condition is met based on current form values.
 *
 * Supports two formats:
 * - Simple: { depends_on, when_value } (equals check)
 * - Extended: { depends_on, operator, value } (equals/not_equals)
 *
 * @param {Object} condition - The condition definition
 * @param {Object} formValues - Current form values keyed by attribute key
 * @returns {boolean} - Whether the condition is satisfied
 */
const isConditionMet = (condition, formValues) => {
  if (!condition) return true;
  const {
    depends_on: dependsOn,
    when_value: whenValue,
    operator,
    value,
  } = condition;
  const currentValue = formValues[dependsOn];

  // Simple format: { depends_on, when_value }
  if (whenValue !== undefined) return currentValue === whenValue;
  // Extended format: { depends_on, operator, value }
  if (operator === 'equals') return currentValue === value;
  if (operator === 'not_equals') return currentValue !== value;
  return true;
};

/**
 * Composable for managing conversation required attributes workflow
 *
 * This handles the logic for checking if conversations have all required
 * custom attributes filled before they can be resolved.
 * Supports conditional attributes that only appear when a parent attribute
 * has a specific value.
 */
export function useConversationRequiredAttributes() {
  const { currentAccount } = useAccount();
  const conversationAttributes = useMapGetter(
    'attributes/getConversationAttributes'
  );

  const requiredAttributeKeys = computed(() => {
    return (
      currentAccount.value?.settings?.conversation_required_attributes || []
    );
  });

  const requiredAttributeConditions = computed(() => {
    return (
      currentAccount.value?.settings
        ?.conversation_required_attribute_conditions || {}
    );
  });

  const allAttributeOptions = computed(() =>
    (conversationAttributes.value || []).map(attribute => ({
      ...attribute,
      value: attribute.attributeKey,
      label: attribute.attributeDisplayName,
      type: attribute.attributeDisplayType,
      attributeValues: attribute.attributeValues,
    }))
  );

  /**
   * All attribute keys that participate in the required workflow.
   * Combines the base required keys with any conditionally-required keys.
   */
  const allRequiredKeys = computed(() => {
    const baseKeys = requiredAttributeKeys.value;
    const conditionKeys = Object.keys(requiredAttributeConditions.value);
    const combined = new Set([...baseKeys, ...conditionKeys]);
    return [...combined];
  });

  /**
   * Get the full attribute definitions for all required/conditional attributes
   */
  const requiredAttributes = computed(() =>
    allRequiredKeys.value
      .map(key =>
        allAttributeOptions.value.find(attribute => attribute.value === key)
      )
      .filter(Boolean)
  );

  /**
   * Get visible attributes based on current form values and conditions.
   * Unconditional attributes are always visible; conditional attributes
   * are only visible when their condition is met.
   *
   * @param {Object} formValues - Current form values keyed by attribute key
   * @returns {Object} - { unconditional: [], conditional: [] }
   */
  const getVisibleAttributes = (formValues = {}) => {
    const conditions = requiredAttributeConditions.value;
    const unconditional = [];
    const conditional = [];

    requiredAttributes.value.forEach(attr => {
      const condition = conditions[attr.value];
      if (!condition) {
        unconditional.push(attr);
      } else if (isConditionMet(condition, formValues)) {
        conditional.push(attr);
      }
    });

    return { unconditional, conditional };
  };

  /**
   * Check if a conversation is missing any required attributes
   *
   * @param {Object} conversationCustomAttributes - Current conversation's custom attributes
   * @returns {Object} - Analysis result with missing attributes info
   */
  const checkMissingAttributes = (conversationCustomAttributes = {}) => {
    // If no attributes are required, conversation can be resolved
    if (!requiredAttributes.value.length) {
      return { hasMissing: false, missing: [] };
    }

    // Only check attributes that are currently visible given existing values
    const { unconditional, conditional } = getVisibleAttributes(
      conversationCustomAttributes
    );
    const visibleAttrs = [...unconditional, ...conditional];

    // Find attributes that are missing or empty
    const missing = visibleAttrs.filter(attribute => {
      const value = conversationCustomAttributes[attribute.value];

      // A checkbox is filled once true or false is picked. An explicit null is
      // an unanswered prompt, which is how the modal and the backend read it.
      if (attribute.type === ATTRIBUTE_TYPES.CHECKBOX) {
        return value == null;
      }

      // For other attribute types, only consider null, undefined, empty string, or whitespace-only as missing
      // Allow falsy values like 0, false as they are valid filled values
      return value == null || String(value).trim() === '';
    });

    return {
      hasMissing: missing.length > 0,
      missing,
      all: requiredAttributes.value,
    };
  };

  return {
    requiredAttributeKeys,
    requiredAttributes,
    requiredAttributeConditions,
    getVisibleAttributes,
    checkMissingAttributes,
  };
}
