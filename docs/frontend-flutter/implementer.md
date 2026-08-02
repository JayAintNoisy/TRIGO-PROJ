# Frontend Flutter Mobile App Implementer

**Role**: Implementation skill for the TriGo Native Mobile App (Android & iOS).
**Permission**: You **CAN** create, edit, and modify Dart files in `apps/trigo/lib/`. You **CAN** run `flutter analyze` and `flutter test`.
**Pre-requisite**: You **MUST** have a plan before implementing. If no plan is provided, request one from the user.

---

## Project Context

### Target Platform
- **Primary Targets**: **Native Mobile App (Android & iOS)** for Passengers and Drivers in the field.

### Tech Stack
- **Framework**: Flutter 3.x (Dart 3.x)
- **State**: Riverpod (`flutter_riverpod`)
- **Navigation**: `go_router` (`GoRouter`)
- **Theme**: `flex_color_scheme` (`FlexThemeData.light`)
- **Directory**: `apps/trigo/lib/`

---

## Implementation Patterns

### 1. ConsumerWidget Standard
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../providers/feature_provider.dart';

class FeatureScreen extends ConsumerWidget {
  const FeatureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(featureProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Feature Title')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              AppCard(
                child: Text(
                  'Feature Content',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              AppButton(
                label: 'Submit Action',
                onPressed: () {
                  ref.read(featureProvider.notifier).performAction();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## Strict Flutter Quality Rules

1. **Zero Deprecation Warnings**:
   - Do NOT use `withOpacity()`. Use `.withValues(alpha: 0.5)` instead.
   - Do NOT use `surfaceVariant`. Use `surfaceContainerHighest` instead.
2. **Font Weights**:
   - Use `FontWeight.w800` for extrabold weight.
3. **No Hardcoded Hex Colors**:
   - Always reference `Theme.of(context)` or `AppColors`.
4. **Icons & Styling**:
   - Do NOT use emojis for UI icons. Always use Material Icons (e.g., `Icons.home`).
   - Prefer soft `BoxShadow` (e.g. `Colors.black.withValues(alpha: 0.05)`, blur 10) for cards and floating elements instead of hard borders.
   - Use lighter colors like `Colors.grey.shade100` or `shade200` for dividers, never pure black.
5. **Verification**:
   - Run `flutter analyze` inside `apps/trigo/` before completing.
