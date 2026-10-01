# Bopomofo Complete Question Flows Design

## Goal

Replace the current one-prompt review placeholder with a complete, offline-capable practice session that exercises all five question types already defined by the learning engine and resumes at the exact question after an app restart.

## Current state

- `packages/learning_engine/lib/src/quiz_generator.dart` defines recognition, recall, composition, listening, and keyboard prompt types, but selection currently returns minimal prompts and marks listening prompts as requiring audio without supplying a usable audio source.
- `app/bopomofo/lib/features/review/review_page.dart` renders one hard-coded recognition item. Its “next” action only hides the saved indicator.
- `packages/content/lib/src/curriculum.dart` declares curriculum units, but those units have no lesson items.
- `packages/phonology` contains the symbol inventory and phonetic mapping data used by the existing keyboard UI.
- `packages/persistence/lib/src/tables.dart` already provides a SQLite `settings` table; `LocalLearningRepository.recordReview` currently records a learning event independently from any session cursor.
- The Flutter app has no audio playback dependency or packaged pronunciation clips today.

## Scope and learner flow

1. Opening the practice/review surface resumes an unfinished session if one exists; otherwise it creates a new session from the available beginner question bank.
2. A new session targets 10 questions and aims for two questions of each of the five existing types. If a type lacks enough valid content, the generator uses the eligible questions available, does not fabricate prompts, and reports the resulting session length accurately.
3. The generator first reserves up to two eligible questions per type, selecting each type's due reviews before its confusion targets and new items. It then fills remaining slots (up to 10) by global due-review, confusion-target, and new-item priority. A question may not be duplicated by `(itemId, skill, type)` within the same session.
4. Every question presents its own response control and feedback. The learner can submit only once for the current question; after feedback, an explicit continue action moves to the next question. If the app closes between answer submission and continue, it restores that same question and its saved feedback.
5. Finishing the final question shows a completion summary (answered count and correct count) and an explicit action to start another session or leave. A completed session is not resumed as active work.
6. Session state is local to the current installation and user profile. This change does not synchronize a live queue across devices.

## Question behavior

- **Recognition:** show a Bopomofo symbol and select its corresponding phonetic/keyboard identity from plausible alternatives.
- **Recall:** show a supported pinyin or phonetic cue and enter the corresponding Bopomofo answer using the in-app answer controls.
- **Composition:** assemble a valid Bopomofo syllable from selectable symbol tiles; correctness is based on the canonical ordered syllable mapping, not the order in which distractors were displayed.
- **Listening:** play a packaged, prerecorded Mandarin pronunciation and choose the corresponding Bopomofo transcription. Playback works without network access. Only clips whose source, license, file format, and mapping to an eligible prompt have been verified are included.
- **Keyboard:** enter the requested symbol through the existing virtual keyboard control, with physical-key input supported where the existing keyboard implementation supports it.

The starter question bank is constrained to the existing Bopomofo symbol inventory and valid syllable mappings in `packages/phonology`; this feature does not claim to provide a full Mandarin vocabulary course. Distractors must be unique, valid answers from the same relevant answer domain, and the correct answer must always be present.

## Audio provenance and packaging

Use only the official CNS11643 “Voice” resource exposed by Taiwan’s [Government Open Data Platform](https://data.gov.tw/dataset/5961/), subject to validating the actual archive contents before selecting clips. Select the [Government Open Data License, Version 1.0](https://data.gov.tw/license) for these audio files and retain an attribution notice identifying the Ministry of Digital Affairs, CNS11643 Full Character Library, and the source URL. The dataset offers a choice between the Government Open Data License and OFL 1.1; OFL is not the license for audio assets.

Audio processing is limited to what is necessary for app packaging and playback. Preserve a source-to-derived-file manifest containing the original archive entry, source character/phonetic mapping, derived asset path, and attribution/license. If archive contents cannot provide a verified clip for a prompt, that prompt is ineligible for listening practice; do not substitute synthesized speech, an unverified third-party recording, or a clip with ambiguous mapping.

## Architecture and persistence

- Add a serializable `QuizSession` model and pure session coordinator in `packages/learning_engine`; define its persistence contract there without importing the persistence package. Implement that contract in `packages/persistence` and forward the operations through the app repository facade. The coordinator creates/resumes a queue, exposes the current prompt, evaluates a submitted response, records feedback state, advances, and marks completion.
- Persist a versioned JSON session record under a namespaced key in the existing SQLite `settings` table. The record contains a stable session ID, content version, immutable ordered prompt snapshots, current zero-based question index, current-question answer/feedback state, correct/answered counts, and lifecycle status. Prompt snapshots include all data required to render/evaluate the queued question and its optional audio asset ID; they do not depend on regenerating random choices after restart.
- Add repository operations to load/save/start/complete a session, commit an answer, and continue to the next question. Answer submission compares the submitted session ID and expected index with persisted state, appends exactly one `LearningEvent`, and records the answer/feedback in the same SQLite transaction. The cursor advances only when the learner explicitly chooses Continue, in a separate atomic session-state write. A stale or repeated submission must not create a second learning event or alter another question.
- Migrate persisted session JSON through an explicit version field. If the schema/version is unsupported or referenced content is unavailable, preserve learning events, discard only the incompatible active session, and start a valid session with a clear recoverable message.
- Keep session queues out of learning-data export/import and cloud synchronization. Clearing local learning data also clears the active session.
- The app review flow renders by `QuizType` using localized labels and controls. Audio playback is behind a small player interface so UI tests can verify offline playback requests without depending on device audio hardware.

## Errors and recovery

- Database write failure leaves both the review event and question cursor unchanged and displays a retryable error.
- If an audio file is missing or playback fails, keep the current question available, display localized playback failure, and allow retry; do not silently mark the response wrong or advance.
- An empty eligible question bank produces an understandable empty state with a path back to learning content instead of a stuck progress screen.
- Backgrounding or process termination does not require a separate save gesture; the queue, index, and submitted feedback are persisted before the UI reports success or advances.

## Localization and accessibility

All new visible text, answer feedback, progress, recovery messages, and completion summary use the existing Simplified Chinese, Traditional Chinese, and English localization system. Controls have semantic labels, can be reached by keyboard/focus navigation where applicable, and expose progress and answer result to assistive technologies.

## Acceptance criteria

1. A newly started session contains eligible questions from each of the five supported question types when the validated question bank has enough content, and each type can be answered through its intended control.
2. Each submitted response records the correct item, skill, response, correctness, and elapsed time exactly once; due-review state updates through the existing learning-event projection path.
3. The continue action advances to a different queued prompt and eventually displays completion; it never merely hides feedback while leaving the same question in place.
4. Closing/reopening the app restores the same ordered queue and exact interaction state: unanswered current question, or submitted answer feedback awaiting Continue.
5. Repeated/stale answer submissions do not duplicate events or change another question; storage failure does not split event persistence from saved answer/feedback state. Continue advances only after its session-state write succeeds.
6. Listening clips play from packaged assets in airplane mode, have a verified mapping to their expected answer, and ship with a source manifest and required attribution.
7. Unsupported session data or missing audio is recoverable without losing previously recorded learning history.
8. Automated tests cover generator eligibility and uniqueness, each answer interaction, persistence/restart, exactly-once transaction semantics, completion, localization coverage, and offline audio asset lookup.

## Out of scope

- Accounts, server persistence, or cross-device live-session synchronization.
- A general-purpose Mandarin word/sentence curriculum beyond the repository’s existing symbol and syllable data.
- Runtime text-to-speech, microphone recording, speech recognition, or user-uploaded audio.
- Replacing the existing spaced-repetition scheduler or changing the learning-data export schema.
