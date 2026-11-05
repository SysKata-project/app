# Product specification

Status: proposed product design. Flutter, iOS, and Android are confirmed requirements; the capabilities below are planned.

## Learner promise

A clear path, a little practice each day, and measurable progress toward technical mastery. The application supports certification preparation and practical skills; completing a path does not guarantee exam readiness or a passing result.

## Daily learning loop

1. Open Today to see a suggested lesson or review and progress toward a chosen daily goal.
2. Continue along the selected certification path.
3. Learn one focused concept through a short explanation and example.
4. Apply it in interactive exercises or a remote lab.
5. Receive an explanation of the result, request a hint, and retry as needed.
6. Finish with a summary of skills practiced, progress earned, and the next step.
7. Return for targeted review when skills need reinforcement.

Use roughly 3–7 minutes as an initial target for ordinary lessons. Label longer labs with realistic duration estimates and do not force complex administration tasks into a short timer.

## Main screens

| Screen | Purpose and primary action |
| --- | --- |
| Welcome | Meet Kata, choose a target path and daily goal, and configure an account when needed to save progress |
| Today | Continue the next useful activity; see daily progress and optional reminders |
| Learn | Browse a path of units, lesson nodes, and practical checkpoints with visible prerequisites |
| Lesson | Read a concise explanation, answer or practice, see feedback, and continue |
| Lab | Read objectives, connect to an isolated environment, submit for assessment, inspect feedback, and reset or exit |
| Review | Revisit weak or due skills with a focused practice session |
| Progress | Inspect completed skills, experience points, streak history, and achievements |
| Settings | Manage account, daily goal, reminder preferences, accessibility options, and data controls |

Use four primary destinations: Today, Learn, Review, and Profile (containing Progress and Settings). Keep the active exercise focused, with clear exit and resume behavior.

## Exercise design

Start with single-answer questions, command ordering, and short command entry. Distinguish knowledge checks and simulated command exercises from actual system execution. Later activities combine multiple skills in realistic administrative scenarios.

Every exercise needs a measurable objective, explicit success criteria, explanatory feedback, and a useful next action after an incorrect attempt. Content versions must remain associated with attempts so feedback and scoring stay reproducible.

For hands-on labs, provide a remote terminal with readable monospace text, selectable output, an accessory row for common shell keys, landscape support, and external keyboard support. Mobile keyboards must not obscure the command line or submit controls. Show connection, provisioning, assessment, expiry, and reset states clearly. A simulated terminal must never be presented as a real lab.

## Motivation and mastery

- Experience points recognize completed practice; skill evidence and assessment results represent mastery separately.
- A streak counts qualifying practice on consecutive learner-local days. The server defines qualifying activity and day boundaries; duplicate submissions cannot increase rewards twice.
- Daily goals are adjustable. Reminders are optional, respect local time, and are requested after the learner understands their purpose.
- Achievements celebrate meaningful milestones such as completing a unit or improving a weak skill.
- Hints and retries remain available. Incorrect answers should not lock a learner out of practice.
- Returning after a missed day earns a warm welcome. Avoid shame, public ranking pressure, or punitive messaging.

Exact reward values, review intervals, timezone-change rules, and streak recovery behavior must be agreed before implementation. They are not fixed by this specification.

## Kata and visual identity

Use Kata's rust-orange, cream, charcoal, and teal identity with readable type, generous spacing, clear controls, and restrained celebration. Kata offers encouragement and useful feedback without distracting from technical work. Suggested copy: “Let's check what changed” and “One more rep?”

Use original layouts, artwork, and interactions. Keep technical explanations precise and suited to adult learners. Support dark and light themes, large text, screen readers, reduced motion, and optional sound/haptics. Never rely on color or animation alone to indicate success.

## MVP and later scope

The MVP includes the OpenShift journey aligned to DO180 and DO280 public objectives: seven pilot lessons and two real remote lab scenarios, onboarding, saved progress, basic review, daily goals, streaks, and Kata feedback. This is a bounded slice, not complete coverage of either course. Original content and the scope are defined in the [shared MVP plan](https://github.com/SysKata-project/docs/blob/main/plans/openshift-mvp.md). Authentication and cross-device progress are required before a public pilot.

Downloaded lessons, offline attempt synchronization, richer achievements, adaptive placement, multiple paths, and reminders can follow the first reliable learning loop. Lives and life gifting, social competitions, payments, and additional client platforms are outside the initial scope. Mistakes do not gate MVP learning or review; lab compute quotas are managed separately.

## Failure and interruption behavior

Preserve lesson position when the app backgrounds or connectivity drops. Explain what was saved locally and what is awaiting server confirmation. Labs require a connection and can expire while the app is closed; resume or reconnect when possible, otherwise offer a clear restart. Never award confirmed lab completion solely from client state.
