# Gemini CLI OpenRouter

[![License](https://img.shields.io/github/license/shrwnsan/gemini-cli-openrouter)](https://github.com/shrwnsan/gemini-cli-openrouter/blob/main/LICENSE)

_🚀 Community fork with OpenRouter support for accessing Gemini models through multiple providers_

![Gemini CLI Screenshot](./docs/assets/gemini-screenshot.png)

This fork adds **OpenRouter integration** to Google's Gemini CLI, allowing you to access Gemini models through various AI providers with unified pricing and automatic failover.

## ✨ Key Features

- **🔄 OpenRouter Support**: Access Gemini models via multiple providers
- **🎯 Four Auth Methods**: Google OAuth, API Key, Vertex AI, or OpenRouter
- **🔄 Auto-Sync**: Weekly updates from upstream to stay current
- **🛡️ Backup Safety**: Automatic backups during sync operations

## 🚀 Quick Start

### Run Instantly (No Installation Required)

```bash
npx https://github.com/shrwnsan/gemini-cli-openrouter
```

**Requirements:**

- Node.js 20+
- macOS, Linux, or Windows

That's it! The fork includes all OpenRouter enhancements automatically.

## 🎯 What You Get

All features from the official Gemini CLI, plus:

- **OpenRouter Integration**: Access Gemini models through multiple AI providers
- **Unified Pricing**: Pay-per-token pricing across different providers
- **Automatic Failover**: Seamless switching between providers
- **Enhanced Authentication**: Four different auth methods to choose from

## 🔐 Authentication

This fork supports all upstream authentication methods plus OpenRouter:

### Quick Setup for OpenRouter

```bash
# 1. Get your API key from https://openrouter.ai
# 2. Set the environment variable
export OPENROUTER_API_KEY="your-openrouter-api-key"

# 3. Run the CLI
npx https://github.com/shrwnsan/gemini-cli-openrouter
```

### Other Options

- **Google OAuth**: Free tier with 60 requests/min (see upstream docs)
- **Gemini API Key**: Direct Google API access
- **Vertex AI**: Enterprise-grade deployment

See the [OpenRouter guide](./docs/openrouter.md) for detailed setup instructions.

## 🚀 Usage

### Basic Usage

```bash
# Start interactive mode
npx https://github.com/shrwnsan/gemini-cli-openrouter

# Non-interactive mode
npx https://github.com/shrwnsan/gemini-cli-openrouter -p "Explain this codebase"
```

### With OpenRouter

```bash
export OPENROUTER_API_KEY="your-key"
npx https://github.com/shrwnsan/gemini-cli-openrouter
```

All standard Gemini CLI commands work exactly the same!

## 📚 Documentation

### Fork-Specific Guides

- [**OpenRouter Setup**](./docs/openrouter.md) - Complete OpenRouter integration guide
- [**Sync Automation**](./docs/sync-automation.md) - How this fork stays updated
- [**Authentication**](./docs/cli/authentication.md) - All authentication methods

### General Gemini CLI Docs

Most upstream documentation applies to this fork. Key resources:

- [**Commands Reference**](./docs/cli/commands.md) - All CLI commands and features
- [**Configuration**](./docs/cli/configuration.md) - Settings and customization
- [**Troubleshooting**](./docs/troubleshooting.md) - Common issues and solutions

## 🤝 Contributing

This is primarily a **consumption fork** that stays in sync with upstream. For contributions:

- **OpenRouter Features**: Contribute to [heartyguy/gemini-cli](https://github.com/heartyguy/gemini-cli)
- **General Features**: Contribute to [google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli)
- **Bug Reports**: Report issues in this repository
- **Documentation**: Help improve fork-specific docs

See [CONTRIBUTING.md](./CONTRIBUTING.md) for general guidelines.

## 🔄 Maintenance

This fork automatically syncs with upstream weekly to stay current. See [Sync Automation](./docs/sync-automation.md) for technical details.

## 📖 Links

- **[Repository](https://github.com/shrwnsan/gemini-cli-openrouter)** - This fork
- **[Upstream](https://github.com/google-gemini/gemini-cli)** - Original Gemini CLI
- **[OpenRouter](https://openrouter.ai)** - API provider
- **[Issues](https://github.com/shrwnsan/gemini-cli-openrouter/issues)** - Report problems

## 🤝 About

Community-maintained fork of Google's Gemini CLI with OpenRouter support. Automatically stays in sync with upstream changes.

---

<p align="center">
  <strong>Gemini CLI OpenRouter</strong> - OpenRouter support for Gemini CLI<br>
  <a href="https://github.com/google-gemini/gemini-cli">Based on Google's Gemini CLI</a>
</p>
