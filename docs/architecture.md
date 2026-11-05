# Flutter application architecture

Status: proposed architecture; no application code or service contracts exist yet.

## Confirmed decisions

Use Flutter and Dart for a shared iOS and Android application. The mobile client presents learning content and interacts with SysKata services. OpenShift hands-on exercises run in isolated remote labs; the phone does not host the cluster. The initial journey is aligned to DO180 and DO280 public objectives.

## Suggested organization

Organize code around onboarding, daily practice, learning paths, lessons, labs, review, progress, and settings. Within each feature, separate widgets and presentation state from data access. Repositories manage client data and caching; services encapsulate API and platform calls. This follows the separation described in the [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide), adapted to SysKata's needs.

```text
lib/
  app/                  # Startup, navigation, theme, dependency wiring
  core/                 # Shared models, errors, networking, accessibility
  features/
    onboarding/
    today/
    learning_paths/
    lessons/
    labs/
    review/
    progress/
    settings/
test/
integration_test/
assets/
```

This is a proposed layout, not an existing directory tree. Select state management, routing, networking, local storage, and secure credential storage packages through a recorded decision before scaffolding. Avoid committing to package versions until the Flutter SDK is selected and validated.

## Ownership and integration

| Component | Owns |
| --- | --- |
| Flutter app | Presentation, navigation, accessibility, transient exercise state, local cache, and pending submissions |
| API | Identity integration, enrollment, progress, attempt records, review scheduling, daily goals, streaks, and rewards |
| Labs | Environment lifecycle, terminal connections, resource limits, and execution of assessments |
| Content | Versioned paths, lessons, exercises, hints, setup requirements, and assessment criteria |

The API mediates session authorization. A terminal transport may connect directly to an authorized lab gateway using a short-lived, scoped session credential if the agreed contract requires it. Infrastructure credentials must never be embedded in the mobile app.

## Contracts to define before integration

- Identity: sign-in, refresh, sign-out, expired sessions, and account removal behavior.
- Learning: path and lesson identifiers, content versions, prerequisites, supported exercise types, and schema compatibility.
- Attempts: client-generated idempotency key, lesson/exercise ID, content version, submitted answer, and server-confirmed outcome.
- Progress: skill evidence, daily goal state, streak day policy, reward events, and due review items.
- Labs: session ID, readiness, expiry, terminal transport, reconnect behavior, reset semantics, assessment request, and structured result.
- Errors: retryability, expired session/content, unavailable environment, unsupported client, and user-facing recovery.

Proposed endpoint paths and transaction semantics are recorded in the [API learning engine design](https://github.com/SysKata-project/api/blob/main/docs/learning-engine.md). Formal payload schemas, authentication provider and terminal protocol remain implementation work. Record the agreed contract in the owning service repository rather than inventing client-only behavior.

## Learning state and synchronization

Model lesson states explicitly: loading, ready, answering, submitting, feedback, completed, and recoverable error. Model lab states separately: provisioning, ready, connected, disconnected, assessing, completed, expired, and failed.

The server is authoritative for progress and rewards. Preserve pending attempts across interruption and use idempotency keys for retries. Display pending versus confirmed completion distinctly. Reconcile server-confirmed progress after reconnecting or returning from the background; do not add rewards for an already accepted attempt.

The MVP requires connectivity for content retrieval and submission. Keep enough local state to recover an interrupted lesson. Downloaded lessons and offline practice are a later capability requiring cache versioning, a durable submission queue, and an explicit conflict policy. Live labs always require connectivity.

## Mobile requirements

- Test foreground/background transitions, interrupted submissions, expired credentials, and interrupted terminal connections.
- Adapt to safe areas, keyboard insets, portrait/landscape layouts, text scaling, and platform back behavior.
- Expose meaningful screen-reader labels, focus order, and textual feedback; respect reduced motion.
- Store session credentials with appropriate platform secure storage and exclude them from logs.
- Treat reminder permission as optional and keep the learning experience usable when denied.
- Pin supported OS versions and SDK/toolchain versions during implementation; do not claim device compatibility before verification.

## OpenShift learning integration

The server derives learner identity, eligibility and progression from authenticated saved state. Submit only the issued exercise-instance reference and answer, with a durable idempotency key; never authoritatively submit a level, score or balance. Render choice, ordering, constrained command entry and lab-task payloads through typed adapters. Keep answer keys out of client bundles.

Pin local recovery data to account, session, content version and instance. Preserve pending payload/key through interruption, distinguish pending from confirmed outcomes, and reconcile before advancing. The server returns feedback, documentation links, confirmed progress and next action. Conflicting/expired sessions must offer a clear refresh or restart.

Cache immutable assets by hash and clear/isolate account-specific recovery data on sign-out. MVP supports interruption recovery, not offline completion. Terminal access uses scoped short-lived lab credentials; provisioning, expiry, reconnect and assessment failures have separate UI states.

See the [shared architecture](https://github.com/SysKata-project/docs/blob/main/architecture/learning-platform.md) and [OpenShift MVP plan](https://github.com/SysKata-project/docs/blob/main/plans/openshift-mvp.md).
