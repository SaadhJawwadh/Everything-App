
### 🌟 What's New
- **Android 16+ AppFunctions API Integration**: Everything App now serves as an official on-device MCP tool provider for Google Gemini and Android system AI agents.
- **Ambient AI Tool Execution**: Gemini can log expenses, add tasks, create notes, and summarize cash flow on-device with zero-friction low-priority notification receipts and 1-tap Undo.
- **Reactive Inbox Draining**: Pending AI actions automatically apply to encrypted SQLite storage on launch or resume with floating Undo feedback.

### 🚀 Improvements
- **Kotlin Symbol Processing (KSP)**: Upgraded native toolchain to KSP 2.2.20 for compile-time AppFunction XML schema generation.
- **Instant Widget State Synchronization**: AppFunctions immediately notify and refresh all Android Finance, Notes, Todo, and Unified home screen widgets.
- **CI/CD Build Environment Hardening**: Decoupled machine-local JVM properties to ensure seamless GitHub Actions release compilation.

### 🐛 Fixes
- **Native Metadata Task Compatibility**: Resolved AGP and compileSdk check tasks across Android 16 target environments.
- **Safe-Queue Deserialization**: Built-in corruption catching and atomic JSON queue flushing prevent stalled background intents.

