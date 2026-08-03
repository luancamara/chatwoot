import {
  processVariable,
  buildWhatsAppProcessedParams,
  findComponentByType,
  COMPONENT_TYPES,
} from '@chatwoot/utils';

// Constants and pure template helpers are shared with the mobile app via
// @chatwoot/utils so the logic lives in one place.
export {
  MEDIA_FORMATS,
  COMPONENT_TYPES,
  findComponentByType,
  processVariable,
} from '@chatwoot/utils';

export const DEFAULT_LANGUAGE = 'en';
export const DEFAULT_CATEGORY = 'UTILITY';

export const allKeysRequired = value => {
  const keys = Object.keys(value);
  return keys.every(key => value[key]);
};

export const replaceTemplateVariables = (templateText, processedParams) => {
  return templateText.replace(/{{([^}]+)}}/g, (match, variable) => {
    const variableKey = processVariable(variable);
    return processedParams.body?.[variableKey] || `{{${variable}}}`;
  });
};

// Text header variables (e.g. "Hello {{1}}") are not covered by the shared
// helper, which only builds header params for media headers.
export const buildTextHeaderParams = template => {
  const header = findComponentByType(template, COMPONENT_TYPES.HEADER);
  const matched = header?.text?.match(/{{([^}]+)}}/g);
  if (!matched) return null;

  return matched.reduce((params, variable) => {
    params[processVariable(variable)] = '';
    return params;
  }, {});
};

// The media-header flag is derived from the template inside the shared helper;
// the second argument is kept for backwards-compatible call sites.
export const buildTemplateParameters = template => {
  const params = buildWhatsAppProcessedParams(template);
  if (params.header) return params;

  const textHeaderParams = buildTextHeaderParams(template);
  if (textHeaderParams) params.header = textHeaderParams;

  return params;
};
