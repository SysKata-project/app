# Implementation roadmap

All milestones are planned. No dates or completed implementation are implied.

| Milestone | Deliverable | Acceptance criteria |
| --- | --- | --- |
| 1. Foundation | Flutter project, design tokens, navigation, Kata assets, and fake services | App launches on an iOS simulator and Android emulator; SDK is pinned; theme and large text are checked; README contains verified run commands |
| 2. Learning loop | Onboarding, one path, short lessons, interactive exercises, and feedback | Learner completes a lesson, receives explanatory feedback, retries a mistake, and resumes an interrupted lesson on both platforms |
| 3. Connected progress | Authentication, versioned content, server attempts, and progress | Progress survives sign-in on another device; retries do not duplicate rewards; offline/error states explain recovery |
| 4. Real practice | One remote Linux lab with terminal and assessment | Session provisions, connects, assesses, reconnects where possible, and expires cleanly; mobile keyboard does not block essential controls |
| 5. Daily habit | Review queue, daily goals, streaks, and milestone feedback | Server applies agreed day boundaries; review targets weak skills; missed days receive supportive messaging; reminders remain optional if included |
| 6. Pilot readiness | Device validation, accessibility, delivery configuration, and learner testing | iOS and Android build checks pass; no secrets are committed; key flows are tested on real devices; pilot distribution is documented |

## Decisions needed first

1. Initial certification path, supported objective version, and first lesson sequence.
2. Flutter SDK, minimum OS versions, app identifiers, and core packages.
3. Authentication and API contracts, including content versions and idempotency.
4. Lab gateway/terminal protocol and mobile session limitations.
5. Review policy, rewards, qualifying practice, and learner-local day rules.

Keep shared product and service decisions in [SysKata docs](https://github.com/SysKata-project/docs); record app-specific technical decisions alongside this roadmap.
