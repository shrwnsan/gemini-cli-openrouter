/**
 * @license
 * Copyright 2025 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

import type {
  CountTokensResponse,
  GenerateContentParameters,
  CountTokensParameters,
  EmbedContentResponse,
  EmbedContentParameters,
} from '@google/genai';
import {
  GoogleGenAI,
  FinishReason,
  GenerateContentResponse,
} from '@google/genai';
import { createCodeAssistContentGenerator } from '../code_assist/codeAssist.js';
import type { Config } from '../config/config.js';

import type { UserTierId } from '../code_assist/types.js';
import { LoggingContentGenerator } from './loggingContentGenerator.js';
import { InstallationManager } from '../utils/installationManager.js';

// Simple OpenRouter client implementation
class OpenRouterContentGenerator {
  constructor(
    private apiKey: string,
    private baseUrl: string,
  ) {}

  async generateContent(
    request: GenerateContentParameters,
    userPromptId: string,
  ): Promise<GenerateContentResponse> {
    const model = this.mapModel(request.model);
    const messages = this.convertContentsToMessages(request.contents);

    const response = await fetch(`${this.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        messages,
        ...request.config,
      }),
    });

    if (!response.ok) {
      throw new Error(`OpenRouter API error: ${response.statusText}`);
    }

    const data = await response.json();
    return this.convertResponse(data);
  }

  async generateContentStream(
    request: GenerateContentParameters,
    userPromptId: string,
  ): Promise<AsyncGenerator<GenerateContentResponse>> {
    // For simplicity, implement non-streaming first
    const result = await this.generateContent(request, userPromptId);
    async function* generator() {
      yield result;
    }
    return generator();
  }

  async countTokens(
    request: CountTokensParameters,
  ): Promise<CountTokensResponse> {
    console.log('🔢 DEBUG: OpenRouterContentGenerator.countTokens called');
    console.log('🔢 DEBUG: Model:', request.model);
    // OpenRouter doesn't have a direct countTokens endpoint, so we'll estimate
    const text = JSON.stringify(request.contents);
    const estimatedTokens = Math.ceil(text.length / 4); // Rough estimate
    console.log('🔢 DEBUG: Estimated tokens:', estimatedTokens);
    return { totalTokens: estimatedTokens };
  }

  async embedContent(
    request: EmbedContentParameters,
  ): Promise<EmbedContentResponse> {
    throw new Error('Embeddings not supported for OpenRouter');
  }

  private mapModel(model: string): string {
    // If OPENROUTER_BASE_URL is set, strip "models/" prefix
    let mappedModel = model.replace('models/', '');

    // For Zhipu AI (api.z.ai), use model ID as-is (no "zhipu/" prefix needed)
    if (this.baseUrl.includes('api.z.ai')) {
      return mappedModel;
    }

    // For OpenRouter (openrouter.ai), use model as-is (already includes provider prefix)
    if (this.baseUrl.includes('openrouter.ai')) {
      return mappedModel;
    }

    // For other OpenRouter-compatible endpoints, use as-is
    return mappedModel;
  }

  private convertContentsToMessages(contents: any): any[] {
    // Convert Gemini format to OpenAI format
    return contents.map((content: any) => ({
      role: content.role || 'user',
      content: content.parts?.map((part: any) => part.text).join('') || '',
    }));
  }

  private convertResponse(data: any): GenerateContentResponse {
    // Convert OpenAI format back to Gemini format
    const finishReason =
      data.choices[0].finish_reason === 'stop'
        ? FinishReason.STOP
        : FinishReason.OTHER;
    const response = new GenerateContentResponse();
    response.candidates = [
      {
        content: {
          role: 'model',
          parts: [{ text: data.choices[0].message.content }],
        },
        finishReason,
        index: 0,
      },
    ];
    response.usageMetadata = {
      promptTokenCount: data.usage?.prompt_tokens || 0,
      candidatesTokenCount: data.usage?.completion_tokens || 0,
      totalTokenCount: data.usage?.total_tokens || 0,
    };
    return response;
  }
}

/**
 * Interface abstracting the core functionalities for generating content and counting tokens.
 */
export interface ContentGenerator {
  generateContent(
    request: GenerateContentParameters,
    userPromptId: string,
  ): Promise<GenerateContentResponse>;

  generateContentStream(
    request: GenerateContentParameters,
    userPromptId: string,
  ): Promise<AsyncGenerator<GenerateContentResponse>>;

  countTokens(request: CountTokensParameters): Promise<CountTokensResponse>;

  embedContent(request: EmbedContentParameters): Promise<EmbedContentResponse>;

  userTier?: UserTierId;
}

export enum AuthType {
  LOGIN_WITH_GOOGLE = 'oauth-personal',
  USE_GEMINI = 'gemini-api-key',
  USE_VERTEX_AI = 'vertex-ai',
  CLOUD_SHELL = 'cloud-shell',
  USE_OPENROUTER = 'openrouter',
}

export type ContentGeneratorConfig = {
  apiKey?: string;
  vertexai?: boolean;
  authType?: AuthType;
  proxy?: string;
  baseUrl?: string;
};

export function createContentGeneratorConfig(
  config: Config,
  authType: AuthType | undefined,
): ContentGeneratorConfig {
  const geminiApiKey = process.env['GEMINI_API_KEY'] || undefined;
  const googleApiKey = process.env['GOOGLE_API_KEY'] || undefined;
  const googleCloudProject = process.env['GOOGLE_CLOUD_PROJECT'] || undefined;
  const googleCloudLocation = process.env['GOOGLE_CLOUD_LOCATION'] || undefined;
  const openRouterApiKey = process.env['OPENROUTER_API_KEY'] || undefined;
  const openRouterBaseUrl =
    process.env['OPENROUTER_BASE_URL'] || 'https://openrouter.ai/api/v1';

  const contentGeneratorConfig: ContentGeneratorConfig = {
    authType,
    proxy: config?.getProxy(),
  };

  // If we are using Google auth or we are in Cloud Shell, there is nothing else to validate for now
  if (
    authType === AuthType.LOGIN_WITH_GOOGLE ||
    authType === AuthType.CLOUD_SHELL
  ) {
    return contentGeneratorConfig;
  }

  if (authType === AuthType.USE_GEMINI && geminiApiKey) {
    contentGeneratorConfig.apiKey = geminiApiKey;
    contentGeneratorConfig.vertexai = false;

    return contentGeneratorConfig;
  }

  if (
    authType === AuthType.USE_VERTEX_AI &&
    (googleApiKey || (googleCloudProject && googleCloudLocation))
  ) {
    contentGeneratorConfig.apiKey = googleApiKey;
    contentGeneratorConfig.vertexai = true;

    return contentGeneratorConfig;
  }

  if (authType === AuthType.USE_OPENROUTER && openRouterApiKey) {
    contentGeneratorConfig.apiKey = openRouterApiKey;
    contentGeneratorConfig.baseUrl = openRouterBaseUrl;

    return contentGeneratorConfig;
  }

  return contentGeneratorConfig;
}

export async function createContentGenerator(
  config: ContentGeneratorConfig,
  gcConfig: Config,
  sessionId?: string,
): Promise<ContentGenerator> {
  const version = process.env['CLI_VERSION'] || process.version;
  const userAgent = `GeminiCLI/${version} (${process.platform}; ${process.arch})`;
  const baseHeaders: Record<string, string> = {
    'User-Agent': userAgent,
  };

  if (
    config.authType === AuthType.LOGIN_WITH_GOOGLE ||
    config.authType === AuthType.CLOUD_SHELL
  ) {
    const httpOptions = { headers: baseHeaders };
    return new LoggingContentGenerator(
      await createCodeAssistContentGenerator(
        httpOptions,
        config.authType,
        gcConfig,
        sessionId,
      ),
      gcConfig,
    );
  }

  if (
    config.authType === AuthType.USE_GEMINI ||
    config.authType === AuthType.USE_VERTEX_AI
  ) {
    let headers: Record<string, string> = { ...baseHeaders };
    if (gcConfig?.getUsageStatisticsEnabled()) {
      const installationManager = new InstallationManager();
      const installationId = installationManager.getInstallationId();
      headers = {
        ...headers,
        'x-gemini-api-privileged-user-id': `${installationId}`,
      };
    }
    const httpOptions = { headers };

    const googleGenAI = new GoogleGenAI({
      apiKey: config.apiKey === '' ? undefined : config.apiKey,
      vertexai: config.vertexai,
      httpOptions,
    });
    return new LoggingContentGenerator(googleGenAI.models, gcConfig);
  }

  if (config.authType === AuthType.USE_OPENROUTER) {
    // For OpenRouter, we'll create a simple fetch-based client
    console.log('🔧 DEBUG: Using OpenRouter client');
    console.log('🔧 DEBUG: API Key set:', !!config.apiKey);
    console.log('🔧 DEBUG: Base URL:', config.baseUrl);
    return new LoggingContentGenerator(
      new OpenRouterContentGenerator(config.apiKey!, config.baseUrl!),
      gcConfig,
    );
  }

  throw new Error(
    `Error creating contentGenerator: Unsupported authType: ${config.authType}`,
  );
}
