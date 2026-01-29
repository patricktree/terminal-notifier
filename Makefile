# pi-terminal-notifier Swift Makefile

# Build the Swift release version
build:
	swift build --configuration release

# Build debug version
debug:
	swift build

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build
	rm -rf pi-terminal-notifier.app
	rm -rf pi-terminal-notifier-*.app
	@echo "Build artifacts cleaned"

# Create app bundle with Terminal icon (automatically signed)
app: build
	mkdir -p pi-terminal-notifier.app/Contents/MacOS
	mkdir -p pi-terminal-notifier.app/Contents/Resources
	cp .build/release/pi-terminal-notifier pi-terminal-notifier.app/Contents/MacOS/
	cp Info.plist pi-terminal-notifier.app/Contents/
	@echo "App bundle created"
	@echo "Installing Terminal icon..."
	@if [ -f "/System/Applications/Utilities/Terminal.app/Contents/Resources/Terminal.icns" ]; then \
		cp "/System/Applications/Utilities/Terminal.app/Contents/Resources/Terminal.icns" pi-terminal-notifier.app/Contents/Resources/AppIcon.icns && \
		echo "✅ Terminal icon installed"; \
	else \
		echo "⚠️  Terminal icon not found, app bundle will use default icon"; \
	fi
	@echo "Signing app bundle..."
	@if command -v codesign >/dev/null 2>&1; then \
		codesign --force --deep --sign - pi-terminal-notifier.app && \
		echo "✅ App signed successfully" || \
		echo "❌ Code signing failed - continuing without signature"; \
	else \
		echo "⚠️  codesign not available - app will be unsigned"; \
		echo "   To enable signing, install Xcode Command Line Tools:"; \
		echo "   xcode-select --install"; \
	fi

# Install the binary to /usr/local/bin
install: build
	cp .build/release/pi-terminal-notifier /usr/local/bin/
	@echo "✅ Binary installed to /usr/local/bin/pi-terminal-notifier"

# Custom icon build targets
app-with-icon:
	@echo "Building app bundle with custom icon..."
	@echo "Usage: make app-with-icon ICON_PATH=/path/to/icon.icns [OUTPUT_NAME=custom-name]"
	@if [ -z "$(ICON_PATH)" ]; then \
		echo "❌ ICON_PATH is required"; \
		echo "Example: make app-with-icon ICON_PATH=/path/to/icon.icns"; \
		exit 1; \
	fi
	@./scripts/build_with_icon.sh "$(ICON_PATH)" "$(OUTPUT_NAME)"


# Build with custom icon from URL
app-icon-url:
	@echo "Building app bundle with custom icon from URL..."
	@echo "Usage: make app-icon-url ICON_URL=https://example.com/icon.png [OUTPUT_NAME=custom-name]"
	@if [ -z "$(ICON_URL)" ]; then \
		echo "❌ ICON_URL is required"; \
		echo "Example: make app-icon-url ICON_URL=https://example.com/icon.png"; \
		exit 1; \
	fi
	@TEMP_ICON=$$(mktemp /tmp/icon.XXXXXX.$$(echo "$(ICON_URL)" | sed 's/.*\.//')); \
	curl -s "$(ICON_URL)" -o "$$TEMP_ICON" && \
	./scripts/build_with_icon.sh "$$TEMP_ICON" "$(OUTPUT_NAME)" && \
	rm -f "$$TEMP_ICON"

# Kill any running pi-terminal-notifier processes
kill-processes:
	@echo "Killing any running pi-terminal-notifier processes..."
	@pkill -f "pi-terminal-notifier" 2>/dev/null && echo "✅ Processes killed" || echo "No processes found"
	@sleep 0.5

# Quick test
test: kill-processes
	@echo "Running quick test..."
	@if [ -d "pi-terminal-notifier.app" ]; then \
		./pi-terminal-notifier.app/Contents/MacOS/pi-terminal-notifier -message "Test notification" -title "Test" > /dev/null 2>&1 && \
		sleep 3 && \
		echo "✅ Test notification sent successfully"; \
	else \
		echo "❌ App bundle not found. Run 'make app' first."; \
		exit 1; \
	fi
	@$(MAKE) kill-processes

# Test action buttons
test-actions: kill-processes
	@echo "Running action button tests..."
	@if [ -d "pi-terminal-notifier.app" ]; then \
		swift tests/unit/test_action_buttons.swift && \
		./tests/integration/test_action_buttons.sh; \
	else \
		echo "❌ App bundle not found. Run 'make app' first."; \
		exit 1; \
	fi
	@$(MAKE) kill-processes

# Test Unix tool behavior
test-unix: kill-processes
	@echo "Running Unix tool behavior tests..."
	@if [ -d "pi-terminal-notifier.app" ]; then \
		./tests/integration/test_unix_tool_behavior.sh; \
	else \
		echo "❌ App bundle not found. Run 'make app' first."; \
		exit 1; \
	fi
	@$(MAKE) kill-processes

# Test prompt/reply functionality
test-prompt: kill-processes
	@echo "Running prompt/reply tests..."
	@if [ -d "pi-terminal-notifier.app" ]; then \
		./tests/integration/test_prompt_reply.sh; \
	else \
		echo "❌ App bundle not found. Run 'make app' first."; \
		exit 1; \
	fi
	@$(MAKE) kill-processes

# Show help
help:
	@echo "pi-terminal-notifier Makefile"
	@echo ""
	@echo "Essential targets:"
	@echo "  build          - Build release version"
	@echo "  debug          - Build debug version"
	@echo "  clean          - Clean build artifacts"
	@echo "  app            - Create signed app bundle with Terminal icon (default)"
	@echo "  install        - Install binary to /usr/local/bin"
	@echo ""
	@echo "Custom icon builds:"
	@echo "  app-with-icon  - Build with custom icon (requires ICON_PATH)"
	@echo "  app-icon-url   - Build with icon from URL (requires ICON_URL)"
	@echo ""
	@echo "Note: The default 'app' target uses the Terminal icon."
	@echo ""
	@echo "Other:"
	@echo "  test           - Send a test notification"
	@echo "  test-actions   - Run action button tests"
	@echo "  test-unix      - Test Unix tool behavior (stdin/stdout/stderr)"
	@echo "  test-prompt    - Test prompt/reply functionality"
	@echo "  kill-processes - Kill any running pi-terminal-notifier processes"
	@echo "  help           - Show this help"
	@echo ""
	@echo "Examples:"
	@echo "  make app                              # Build app bundle with Terminal icon"
	@echo "  make app-with-icon ICON_PATH=icon.icns # Build with custom icon"
	@echo "  make install                          # Install to /usr/local/bin"

.PHONY: build debug clean app install app-with-icon app-icon-url kill-processes test test-actions test-unix test-prompt help
