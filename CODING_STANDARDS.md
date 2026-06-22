# Project Coding Standards: iOS Development

## 1. Architecture (MVVM)
- **Views:** Dedicated to UI layout and user interaction. No business logic.
- **ViewModels:** Must be marked with `@Observable` (iOS 17+) or `ObservableObject`. Use `@MainActor` for properties that drive UI updates.
- **Data Flow:** Pass dependencies via initializers. Avoid hard-coded singletons.

## 2. SwiftUI Best Practices
- **Modularity:** Views exceeding 200 lines must be decomposed into sub-views.
- **Performance:** Use `LazyVStack` or `LazyHStack` for large collections.
- **Modifiers:** Keep view modifiers organized by type (Layout, Style, Accessibility) for readability.

## 3. Memory & Concurrency
- **Retain Cycles:** Always capture `[weak self]` in escaping closures or tasks.
- **Concurrency:** Prefer `async/await` over completion handlers. Ensure all background work is properly scoped.
- **Main Thread:** UI-bound logic must be constrained to the `@MainActor`.

## 4. Xcode Readiness
- **Assets:** All images, colors, and assets must be managed via `Assets.xcassets`.
- **Dependencies:** Use standard Swift Package Manager (SPM). Avoid manual framework embedding where possible.
- **Naming:** Follow [Apple API Design Guidelines](https://swift.org/documentation/api-design-guidelines/). 
    - `camelCase` for properties/methods.
    - `PascalCase` for structs/classes/enums.

## 5. Documentation
- **Comments:** Public methods/types require `///` DocC formatted comments.
- **Intent:** If a piece of code implements a "workaround" or specific business logic, include a brief comment explaining the "why."

## 6. Review Workflow
- All new code must be checked against this file before being integrated into the main build.