# Learning loop

Issue: https://github.com/SysKata-project/app/issues/2

The Learn tab opens the server's versioned journey. Lesson availability and
unmet prerequisites come from its lesson nodes; the client does not unlock lessons
from XP or locally evaluate answers. The bounded pilot contains seven lessons.
Two checkpoint entries identify the planned mobile terminal integration in app #4;
they cannot be launched or claimed completed through a simulated terminal.
Curriculum beyond the pilot is explicitly unavailable.

A lesson shows its explanation and HTTPS documentation links. Starting it enrolls
in the journey using the displayed/entered IANA timezone, then starts or resumes
the server's active session. Existing accounts must use their saved timezone;
this screen does not implement timezone changes. The service may resume a different
lesson, which is labeled in the UI. Lesson selection and prerequisite eligibility
remain server-authoritative. Authentication/onboarding remains app #3.

Choice answers send option IDs. Ordering exposes labeled move controls usable
without drag gestures. Command practice accepts one line, up to 4096 characters,
without control characters, and never executes locally. Starting an attempt precedes
submission or hint delivery; hint responses advance the revision. Resumed open
attempts retain their assistance. Feedback displays criteria, documentation,
independent/assisted evidence, confirmed XP and completion separately. The next
step follows `continue`, `remediate` or `session_complete`; it never derives completion
from a successful-looking answer or a nonzero XP balance.

Historical `progress.status: partial` results preserve absent daily-goal/streak
values as null/unavailable. They retain confirmed lesson/checkpoint IDs and skill
counters, without manufacturing review schedules or daily activity.

## Requests and recovery

Each mutation gets a random UUID idempotency key. The controller disables concurrent
submissions and retains the exact request payload, revision and key for an explicit
retry after a timeout or retryable service failure. It does not count infrastructure
failures as incorrect answers or add XP locally. Stale-state errors offer a server
refresh. Hints also retain their exact request on retry. The controller state is
in-memory only: process-death recovery, account binding, persistent request replay,
refresh tokens and sign-out cleanup are explicitly app #3, not claimed by this issue.
Live modes still require credentials from the credential store; no build-time token
or unauthenticated grading fallback is introduced.

## Preview and provenance

Development uses the upstream **public draft** 0.3.0 learner projection, with seven
lessons. The two checkpoint entries are informational mobile placeholders; this
text-only draft contains no lab tasks and cannot establish checkpoint eligibility. `contracts/preview-provenance.json` pins its source and
SHA-256. This is not a released bundle or actual learner availability. Preview
locks are fixed sample data; scripted feedback deliberately does not grade the
entered answer, award XP, persist progress or unlock lessons. Every preview learning
screen labels this limitation. Tests separately exercise correct/incorrect and
partial-progress API fixtures; the public response fixture provenance is pinned
in `contracts/fixture-provenance.json`. No assessment projection ships in the app.

Documentation opens in the external browser through pinned `url_launcher` 6.3.2.
Only HTTPS URLs without embedded credentials are launchable. Failure shows a safe
message. Source Markdown is displayed as selectable text, never executed as HTML.
Scrollable layouts, labeled ordering controls, selected choice semantics and live
feedback announcements support keyboard insets, large text and screen readers.
No exercise animation is required, including with reduced motion enabled.

## Validation

See [validation evidence](validation.md). Automated widgets exercise the full
journey-to-lesson flow, hints, mistakes, remediation and completion; controller
checks cover duplicate prevention and exact retry replay. Adapter tests check the
session/attempt/hint wire requests. Device integration checks use contract fixtures,
not real authenticated learner data. Live end-to-end pilot validation remains the
cross-repository release gate.
