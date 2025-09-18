/**
 * @license
 * Copyright 2025 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

import type { Config } from '@google/gemini-cli-core';
import { AuthType, OutputFormat } from '@google/gemini-cli-core';
import { USER_SETTINGS_PATH, SettingScope } from './config/settings.js';
import { validateAuthMethod } from './config/auth.js';
import { type LoadedSettings } from './config/settings.js';
import { handleError } from './utils/errors.js';

function getAuthTypeFromEnv(): AuthType | undefined {
  console.log('🔍 DEBUG: Checking auth type from environment');
  console.log(
    '🔍 DEBUG: OPENROUTER_API_KEY set:',
    !!process.env['OPENROUTER_API_KEY'],
  );
  console.log('🔍 DEBUG: GEMINI_API_KEY set:', !!process.env['GEMINI_API_KEY']);
  console.log(
    '🔍 DEBUG: GOOGLE_GENAI_USE_GCA:',
    process.env['GOOGLE_GENAI_USE_GCA'],
  );
  console.log(
    '🔍 DEBUG: GOOGLE_GENAI_USE_VERTEXAI:',
    process.env['GOOGLE_GENAI_USE_VERTEXAI'],
  );

  if (process.env['GOOGLE_GENAI_USE_GCA'] === 'true') {
    console.log('🔍 DEBUG: Using LOGIN_WITH_GOOGLE');
    return AuthType.LOGIN_WITH_GOOGLE;
  }
  if (process.env['GOOGLE_GENAI_USE_VERTEXAI'] === 'true') {
    console.log('🔍 DEBUG: Using USE_VERTEX_AI');
    return AuthType.USE_VERTEX_AI;
  }
  if (process.env['OPENROUTER_API_KEY']) {
    console.log('🔍 DEBUG: Using USE_OPENROUTER');
    return AuthType.USE_OPENROUTER;
  }
  if (process.env['GEMINI_API_KEY']) {
    console.log('🔍 DEBUG: Using USE_GEMINI (fallback)');
    return AuthType.USE_GEMINI;
  }
  console.log('🔍 DEBUG: No auth type detected');
  return undefined;
}

export async function validateNonInteractiveAuth(
  configuredAuthType: AuthType | undefined,
  useExternalAuth: boolean | undefined,
  nonInteractiveConfig: Config,
  settings: LoadedSettings,
) {
  try {
    const enforcedType = settings.merged.security?.auth?.enforcedType;
    if (enforcedType) {
      const currentAuthType = getAuthTypeFromEnv();
      if (currentAuthType !== enforcedType) {
        const message = `The configured auth type is ${enforcedType}, but the current auth type is ${currentAuthType}. Please re-authenticate with the correct type.`;
        throw new Error(message);
      }
    }

    const detectedAuthType = getAuthTypeFromEnv();
    const effectiveAuthType =
      enforcedType || detectedAuthType || configuredAuthType;

    if (!effectiveAuthType) {
      const message = `Please set an Auth method in your ${USER_SETTINGS_PATH} or specify one of the following environment variables before running: OPENROUTER_API_KEY, GEMINI_API_KEY, GOOGLE_GENAI_USE_VERTEXAI, GOOGLE_GENAI_USE_GCA`;
      throw new Error(message);
    }

    const authType: AuthType = effectiveAuthType as AuthType;

    // Update settings if we detected an auth type from environment variables
    // and it's different from what's currently saved
    if (
      detectedAuthType &&
      settings.merged.security?.auth?.selectedType !== detectedAuthType
    ) {
      console.log(`🔄 Updating selected auth type to ${detectedAuthType}`);
      settings.setValue(
        SettingScope.User,
        'security.auth.selectedType',
        detectedAuthType,
      );
    }

    if (!useExternalAuth) {
      const err = validateAuthMethod(String(authType));
      if (err != null) {
        throw new Error(err);
      }
    }

    await nonInteractiveConfig.refreshAuth(authType);
    return nonInteractiveConfig;
  } catch (error) {
    if (nonInteractiveConfig.getOutputFormat() === OutputFormat.JSON) {
      handleError(
        error instanceof Error ? error : new Error(String(error)),
        nonInteractiveConfig,
        1,
      );
    } else {
      console.error(error instanceof Error ? error.message : String(error));
      process.exit(1);
    }
  }
}
