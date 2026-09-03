# Safe Path — working notes

School transport safety platform. Arabic-first, bilingual (ar/en), RTL.

## Commands

```bash
flutter test          # 175 tests — keep them green
dart analyze          # must stay clean; the repo has no warnings
dart format lib test
flutter run           # demo mode: no key, no backend, no hardware
```

## Layout

- `lib/domain/` — pure Dart, no Flutter import. The safety rules live here and
  are meant to move to a server unchanged. Test everything added here.
- `lib/data/` — seed data, the fleet simulator, app state and the controller.
- `lib/features/` — one folder per role, plus `map/`.
- `lib/core/` — theme, strings, config.

## Rules that must not be relaxed

These are not style preferences; each one exists because breaking it makes the
product unsafe or unauditable.

1. **`AttendanceEvent` is append-only.** Never edit or delete one. Supersede it
   with a new event. A safety log that can be rewritten has no evidential value.
2. **Attendance keys on `studentId`, never on card UID.** A reissued card must
   not sever a student's history.
3. **A skipped stop is marked, never removed** from the trip plan.
4. **Never present an extrapolated position as live.** Past the stale window the
   UI stops animating and says when it last heard from the bus.
5. **Manual records are labelled as manual everywhere** — timeline, notification
   body, event log — and always carry the guardian's dispute action.
6. **Every privileged access is audited.** Impersonation is time-boxed and never
   changes `currentUser`.
7. **`schoolId` on every record.** The pilot is one school; the schema is not.
8. **An emergency reaches only guardians whose child is aboard.** Alarming a
   parent whose child already got off is a cruelty, not a safety measure.

## Conventions

- Strings go in `lib/core/i18n/strings.dart` — both languages, never inline.
- Colours come from `AppColors`; state colours (onBus / atSchool / manual /
  critical) carry meaning and are never reused as decoration.
- Spacing from `Gap`, radii from `Radii`.
- New external service? Put it behind an interface, like `FleetEventSource`,
  `RoutingService` and `NavigationService`, so it can be swapped without
  touching callers.
- Charts are single-series by default. Before shipping any categorical palette,
  run the dataviz validator — the app's own state colours fail it, which is why
  the state breakdown is four tiles rather than one stacked bar.
- Chart colours are their own tokens (`chartAccent`), checked per mode against
  that mode's surface. Never derive the dark step by flipping the light one.

## Testing notes

- Widget tests use `FakeFleetSource`, which schedules with microtasks rather
  than `Future.delayed` — a delayed future never completes under the fake clock
  a widget test runs on.
- Avoid `pumpAndSettle` on screens with live tracking; use bounded `pump()`.
  The animation ticker stops when there is no motion, but a moving bus is by
  definition never settled.
- `bootstrap()` is safe to call twice; the app calls it on its first frame.
