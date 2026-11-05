# SysKata app

SysKata is a Flutter application for iOS and Android that turns technical training into a daily practice habit. Learners build practical Linux administration and automation skills through short lessons, guided challenges, immediate feedback, and targeted review, with a primary focus on Red Hat certification paths.

Kata, our curious red panda, accompanies learners as they progress from individual commands to realistic administrative tasks.

## The experience

- A clear path of units, lessons, and practical checkpoints toward a selected certification.
- Focused daily sessions with a suggested goal of 5, 10, or 15 minutes.
- Interactive questions, command-building exercises, and remote hands-on labs.
- Immediate explanations, useful hints, and opportunities to retry.
- Skill review, visible progress, experience points, streaks, and achievement milestones.
- Friendly encouragement that welcomes learners back after a break.

## Platforms and technology

One shared Flutter/Dart codebase will target iOS and Android. Phone layouts come first, with adaptive layouts for larger screens. Native platform conventions, accessibility, keyboard behavior, and lifecycle handling are part of the design.

## Documentation

| Document | Purpose |
| --- | --- |
| [Product specification](docs/product.md) | Learning loop, screens, motivation, and MVP scope |
| [Architecture](docs/architecture.md) | Flutter structure, service boundaries, sessions, and synchronization |
| [Development and delivery](docs/development.md) | Tooling, platform validation, testing, and release expectations |
| [Roadmap](docs/roadmap.md) | Milestones and acceptance criteria |

## Component boundaries

The [API](https://github.com/SysKata-project/api) owns learner progress, sessions, review, and reward rules. [Labs](https://github.com/SysKata-project/labs) provisions remote practice environments and assesses results. [Content](https://github.com/SysKata-project/content) owns original lessons, certification paths, and assessment criteria. Shared decisions belong in [docs](https://github.com/SysKata-project/docs).

Meet [Kata and browse the brand assets](https://github.com/SysKata-project/.github/tree/main/assets/branding).

## Project status

This repository currently contains planning documents, not a runnable Flutter application. Flutter and the iOS/Android targets are selected; package choices, minimum OS versions, and authentication remain open. The initial learning path is OpenShift aligned to DO180 and DO280 public objectives. No mobile builds have been produced or tested yet.

## Contributing

Open an issue with the learner problem and expected behavior. Changes affecting application contracts or content formats should be coordinated with their owning repositories. Include accessibility and both mobile platforms in implementation acceptance criteria.

## MVP implementation tracking

See the [OpenShift MVP tracker](https://github.com/SysKata-project/docs/issues/1) and [cross-repository backlog](https://github.com/SysKata-project/docs/blob/main/plans/mvp-backlog.md).

## License

Copyright 2026 SysKata contributors. Code, documentation, and learning content in this repository are licensed under the [Apache License 2.0](LICENSE).
