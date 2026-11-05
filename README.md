# SysKata web

The learner-facing application for SysKata, a daily technical practice platform focused primarily on Red Hat certification paths.

## Intended scope

- Certification path selection and clear lesson progression.
- Short guided lessons and hands-on challenge instructions.
- Practice session controls, assessment results, and helpful feedback.
- Targeted review activities and progress summaries.
- Daily goals, streaks, and achievement milestones.
- An approachable, playful experience with accessible interactions.

## Component boundaries

The [API](https://github.com/SysKata-project/api) owns saved learner state and progression rules. The [labs component](https://github.com/SysKata-project/labs) owns practice environments and assessment execution. The [content repository](https://github.com/SysKata-project/content) owns lesson text and exercises. The web app presents these capabilities through agreed service contracts.

## Proposed first milestone

Deliver one complete lesson flow: select a lesson, read its instructions, launch a practice session, submit for assessment, understand feedback, and view saved progress.

## Development and contribution

No application code or framework has been selected yet, so there are no installation or run commands. Start proposals with the learner journey and acceptance criteria. Coordinate shared contracts in [docs](https://github.com/SysKata-project/docs).

## Status

Planning scaffold only; listed capabilities are planned. No license has been selected yet.
