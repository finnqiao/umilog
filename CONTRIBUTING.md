# Contributing to UmiLog

Thank you for your interest in contributing to UmiLog! We're building the best dive logging app for iOS, and we'd love your help.

## 🤝 Code of Conduct

Be respectful, inclusive, and professional. We're all here to make diving safer and more enjoyable.

## 🚀 Getting Started

1. Fork the repository
2. Clone your fork locally
3. Create a feature branch (`git checkout -b feature/amazing-feature`)
4. Make your changes
5. Commit with conventional commits (see below)
6. Push to your fork
7. Open a Pull Request

## 📝 Conventional Commits

We use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation only
- `style:` Code style changes (formatting, etc)
- `refactor:` Code refactoring
- `perf:` Performance improvements
- `test:` Adding tests
- `chore:` Maintenance tasks

Examples:
```
feat(livelog): add voice command parsing
fix(sync): handle CloudKit conflicts properly
docs(readme): update installation instructions
```

## 🏗️ Development Process

### Prerequisites

- Xcode 15.0+
- iOS 17.0+ deployment target
- Apple Developer account (for device testing)
- Homebrew for build tools

### Setup

```bash
# Install dependencies
brew install xcodegen swiftlint

# Generate Xcode project
xcodegen generate

# Open workspace
open UmiLog.xcworkspace
```

### Code Style

- SwiftLint enforces our style guide
- Run `swiftlint` before committing
- Use SwiftUI and modern Swift patterns
- Follow MVVM architecture

### Testing

- Write unit tests for business logic
- UI tests for critical user flows
- Performance tests for sub-100ms operations
- Run tests: `cmd+U` in Xcode

## 🐛 Reporting Issues

### Bug Reports

Include:
- iOS version
- Device model
- Steps to reproduce
- Expected vs actual behavior
- Screenshots/videos if applicable
- Crash logs from TestFlight

### Feature Requests

- Check existing issues first
- Describe the problem it solves
- Explain your proposed solution
- Consider offline-first constraints

## 🔄 Pull Request Process

1. **Update Documentation**
   - Update README.md if needed
   - Update ARCHITECTURE.md for structural changes
   - Update TODO.md to reflect completed work
   - Update LEARNINGS.md with insights

2. **Test Your Changes**
   - All tests must pass
   - Add tests for new features
   - Test offline scenarios
   - Verify <100ms performance targets

3. **PR Description**
   - Link related issues
   - Describe what changed and why
   - Include screenshots for UI changes
   - Note any breaking changes

4. **Code Review**
   - Address feedback promptly
   - Keep PRs focused and small
   - Squash commits before merging

## 📊 Performance Guidelines

Critical metrics to maintain:
- Cold start: <2 seconds
- Database writes: <100ms
- Search response: <200ms
- Memory usage: <100MB baseline

## 🔐 Security

- Never commit API keys or secrets
- Use Keychain for sensitive data
- Follow E2E encryption patterns
- Report security issues privately

## 📱 UI/UX Guidelines

- Follow Apple Human Interface Guidelines
- Support Dynamic Type
- Ensure VoiceOver compatibility
- Test with wet fingers (seriously!)
- Design for one-handed use

## 🌐 Localization

When adding user-facing strings:
1. Use `LocalizedStringKey` in SwiftUI
2. Add to `Localizable.strings`
3. Keep keys descriptive: `dive.log.save.button`

## 📦 Dependencies

Before adding dependencies:
- Prefer Apple frameworks
- Check license compatibility (no GPL)
- Consider offline functionality
- Evaluate binary size impact

## 🎯 Focus Areas

Current priorities:
1. Offline-first reliability
2. Sub-100ms performance
3. Voice input accuracy
4. Import/export compatibility
5. Apple Watch Ultra integration

## 💡 Ideas Welcome!

We especially appreciate contributions for:
- Dive site data curation
- Species identification improvements
- Performance optimizations
- Accessibility enhancements
- TestFlight feedback

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## 🙏 Recognition

Contributors will be added to:
- ASSETS.md credits section
- App credits screen
- GitHub contributors page

## 📧 Contact

- GitHub Issues: Technical discussions
- Discord: Community chat
- Email: team@umilog.app

---

*Thank you for helping make UmiLog better for divers everywhere!* 🤿