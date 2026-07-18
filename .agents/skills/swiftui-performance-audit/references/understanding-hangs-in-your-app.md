# Understanding Hangs in Your App (Summary)

Context: Apple guidance on identifying hangs caused by long-running main-thread work and understanding the main run loop.

## Key concepts

- A hang is a noticeable delay in a discrete interaction, almost always caused by long-running work on the main thread.
- Discrete interaction delays start becoming noticeable at roughly 50-100 ms; that is a perceptual onset, not a hard measured cutoff.
- The main run loop processes UI events, timers, and main-queue work sequentially.

## Main-thread work stages

- Event delivery to the correct view/handler.
- Your code: state updates, data fetch, UI changes.
- Core Animation commit to the render server.

## Why the main run loop matters

- Only the main thread can update UI safely.
- The run loop is the foundation that executes main-queue work.
- If the run loop is busy, it can’t handle new events; this causes hangs.

## Responsiveness targets vs. tooling thresholds

These are three distinct numbers for three distinct purposes; do not treat them as interchangeable:

- **~100 ms — development target.** Apple's guidance for main-thread work is to keep it under roughly 100 ms so a discrete interaction feels instant. This is a target to design and code toward, not a measured reporting threshold.
- **~250 ms — default tooling threshold.** The Hangs instrument, MetricKit, and Xcode Organizer's hang rate default to flagging main-run-loop busy periods once they exceed about 250 ms. Apple calls hangs in this range "micro hangs": easy to ignore, but often still worth fixing. The Hangs instrument lets you configure a lower threshold.
- **>500 ms — proper/severe hang.** Apple considers unresponsiveness beyond roughly 500 ms a "proper" hang that should be investigated. Main-thread stalls of 1 s or longer additionally trigger backtrace sampling for diagnostic hang reports.

## Diagnosing hangs

- Observe the main run loop’s busy periods: healthy loops sleep most of the time.
- Use the ~250 ms default as a starting point for spotting hangs, but judge severity against the ~100 ms target and the ~500 ms "proper hang" framing above, not the tooling default alone.
- The Hangs instrument can be configured to lower thresholds.

## Practical takeaways

- Design and code toward the ~100 ms responsiveness target; treat the ~250 ms tooling default and ~500 ms severity framing as reporting/triage thresholds, not the goal itself.
- Keep main-thread work short; offload heavy work from event handlers.
- Avoid long-running tasks on the main dispatch queue or main actor.
- Use run loop behavior as a proxy for user-perceived responsiveness.
