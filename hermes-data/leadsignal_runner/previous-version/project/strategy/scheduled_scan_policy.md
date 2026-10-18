# Scheduled Scan Policy

## Purpose and Ownership

This file defines:

- scheduling timezone
- authorized research and finalization windows
- scheduled-job identity
- test versus recurring execution
- deadline enforcement
- Monitoring synchronization
- scheduler failure reporting

Follow:

- run_state.md for batch identity, leases, recovery and checkpoints
- source_budget.md for targets, spending and session allowances
- contact_policy.md for contact acceptance
- supabase_schema_policy.md for supported database mappings
- reporting_policy.md for completion and shortfall reports
- guardrails.md for prohibited runtime actions

This file does not redefine qualification, contact requirements
or numerical search budgets.

## Timezone

Use Europe/Paris for scheduling interpretation and
user-facing schedule labels.

Use the timezone identifier, not a permanently fixed UTC offset.

The execution layer must account for daylight-saving changes.

Persist actual execution timestamps and deadlines as UTC instants.
When displaying them, label the presentation timezone clearly.

Do not confuse:

- the server's local timezone
- UTC timestamps returned by the scheduler
- Europe/Paris display time
- the browser's local timezone

## Activation Is Explicit

Instruction files do not activate a schedule.

A schedule exists only after an authorized setup operation
creates it and verifies its actual state.

Do not assume that a historical cron job still exists.

Research workers must not create, edit, resume, pause
or delete scheduled jobs.

Those operations belong to the authorized scheduling controller
or an explicit operator action.

## Production Window

The proposed production schedule is:

- research: 22:00 to 06:00, Europe/Paris
- finalization: until 06:30, Europe/Paris

These are proposed defaults, not proof of an active schedule.

At activation, record the confirmed schedule and calculate
the actual UTC start, research deadline and final deadline.

The research window crosses midnight.
Associate it with one persistent batch, not two calendar-day batches.

On daylight-saving transition nights, the elapsed duration
may differ from eight hours.

Do not silently replace a local-clock schedule with a fixed
UTC offset or fixed elapsed duration.

## Eight-Hour Test

A test requested for eight hours starting now is a separate
execution mode from the recurring local-clock schedule.

At authorized activation:

- record the actual start instant
- set the research deadline eight elapsed hours later
- record whether any additional finalization time was authorized
- set the actual final deadline accordingly
- record the test's spending and session allowances

Do not add an extra thirty minutes to a test without authorization.

If no separate finalization period was authorized,
reserve finalization time within the eight-hour window.

Do not start a test while the user is only reviewing files.

A test must stop at its deadline.
It must not silently become an unlimited recurring job.

## Execution Context

The execution layer must provide:

- execution mode: test or recurring
- actual scheduled-job identity, when applicable
- persistent batch identity
- intended ICP or batch configuration reference
- actual start timestamp
- research deadline
- finalization deadline
- timezone
- remaining execution allowances

Use the current verified context.

Do not hardcode an old test-job ID in a policy or worker prompt.

Do not identify a job solely by a similar human-readable name
when several jobs may match.

If identity is ambiguous, report it before changing
any Monitoring record.

## Scheduler Preflight

Before an unattended batch begins, verify:

- the intended job exists, if scheduled
- the scheduler or controller is operational
- the job is enabled for the intended execution
- the required execution prerequisites in run_state.md exist
- the time window and allowances are valid
- another incompatible batch is not already active
- supported database mappings are available

A database monitoring row marked active is not proof
that the scheduler is running.

An old heartbeat is not proof of current scheduler health.

If a required preflight check fails, report the actual issue.
Do not begin an improvised unattended loop.

## Starting and Resuming Workers

The controller may start bounded worker sessions within
the authorized batch window.

Every resumed worker belongs to the same batch and loads
its durable progress under run_state.md.

A worker reaching its tool-call limit must not create
a new nightly batch or reset the result targets.

Only the controller decides whether another worker may start,
based on:

- remaining time
- remaining allowance
- unfinished targets
- actual worker ownership
- current errors and recovery state

A scheduling interval alone does not prevent overlapping workers.
Apply the lease and recovery controls in run_state.md.

## Early Completion

If every required signal reaches its accepted-result target:

- stop starting research workers
- finalize the batch
- save the actual completion time
- synchronize Monitoring
- prepare the final report

Do not consume the rest of the window simply because
time remains available.

Early completion of the current batch does not automatically
disable the next authorized nightly schedule.

## Research Deadline

At the research deadline:

- stop starting new discovery
- checkpoint unfinished research
- follow the authorized finalization policy

During an authorized finalization period, finish only
already pending verification, publication and reporting
that fits within the remaining allowance.

Do not use finalization as an unreported extension
of broad discovery.

Do not publish a candidate that still fails an acceptance gate.

## Final Deadline

The execution layer must enforce the final deadline.

Worker instructions alone are not a reliable stop mechanism
if a provider call hangs or a process stops responding.

At the final deadline:

- stop initiating paid work
- terminate or reconcile remaining worker activity
  through the controller
- prevent expired workers from publishing
- preserve committed results and durable checkpoints
- report unfinished work and interruptions

Late provider responses must not bypass expired worker ownership
or the publication gate.

Do not extend deadlines autonomously.

## Missed Starts and Server Restarts

Do not automatically launch several missed batches after
a server restart.

The operator or verified controller configuration must define
whether a missed schedule is skipped or resumed within
its remaining authorized window.

If that behaviour is not configured, report the missed start.

Recovery of an existing unfinished batch must preserve its identity
and must not duplicate previously published results.

Do not describe downtime as active research time.

## Pause, Cancellation and Exhausted Tests

Read the actual job and controller state.

A finite-repeat test may have exhausted its runs.
Do not report it as active merely because a historical row exists.

A paused recurring schedule prevents future scheduled starts,
but does not by itself prove an already running worker stopped.

Distinguish:

- pausing future starts
- cancelling an active batch
- a batch completing normally
- a finite test reaching its end
- a scheduler failure

Cancellation requires the execution layer to stop or reconcile
active work and preserve committed progress.

## Monitoring Source of Truth

The scheduler/controller is authoritative for scheduling.
Supabase stores the synchronized representation.

Synchronize the correct monitoring record only after verifying:

- the actual job or batch identity
- the intended ICP
- the current schedule
- the current enabled/paused/finished state
- the actual next execution time, if any

If several monitoring rows are ambiguous,
report the ambiguity instead of updating all of them.

If a row is absent, create it only through the authorized
supported mapping after verifying its identity.

## Existing Monitoring Field Meanings

For the existing monitoring_jobs mapping:

- frequency:
  the actual schedule represented by a supported value

- status:
  the supported representation of the verified schedule state

- last_run_at:
  the actual parent batch start, not each worker resumption

- next_run_at:
  the actual next parent batch execution from the scheduler,
  not an invented estimate or internal retry time

- updated_at:
  the actual successful synchronization time

Do not use a source publication date as a run timestamp.

Do not reset last_run_at merely because the page was refreshed.

If no future execution exists, use null where supported.

Keep worker retry timing separate from the next scheduled batch.
Do not confuse schedule status with research success.

## Frequency Mapping

For existing interval tests:

- every ten minutes maps to every_10m
- every two hours maps to every_2h

Use these values only when the database constraint supports them
and they match the actual schedule.

A daily frequency label alone does not fully describe:

- local start time
- timezone
- research cutoff
- finalization cutoff
- daylight-saving behaviour

The execution schema must support the actual schedule details
before the interface claims to display them.

Do not invent new columns or enum values during a scan.

If the schema cannot represent the actual schedule,
report the limitation instead of storing a different frequency.

## Synchronization Timing

Synchronize supported state:

- after authorized schedule activation or modification
- when the parent batch actually starts
- after a meaningful execution-state change
- when the batch completes or is interrupted
- after an authorized pause or cancellation

Use controller-driven synchronization where available.

A research worker's final response must not be the only mechanism:
it may never run after a hard session cutoff.

## Synchronization Failures

If synchronization fails:

- preserve the last confirmed values
- record the failure through supported execution tracking
- distinguish stale state from confirmed current state
- report the exact error
- retry recoverable failures within the execution policy

Do not fabricate timestamps to make Monitoring look current.

Do not report errors:none when synchronization failed.

A Monitoring failure does not by itself prove that
research or publication failed.

Likewise, successful synchronization does not prove
that research targets were met.

## Paris-Time Interface Requirement

The interface must display the schedule in Europe/Paris
or explicitly label another chosen timezone.

This policy does not change frontend code.

Verify the actual rendered timezone before declaring
the interface synchronized correctly.

Do not infer a timing error solely from a valid difference
between UTC and Paris representations of the same instant.

## Nouveau and Batch Identity

Follow run_state.md for parent-run linkage.

Worker resumptions must not each create a different
publication batch for Nouveau.

Only newly accepted, published opportunities belong
to the new batch's result set.

Do not change historical run links to refresh a badge.

The badge and Monitoring behaviour require implementation
and testing; reading this policy does not install them.

## Runtime Restrictions

Research workers must not:

- create recurring jobs
- change cron frequency
- extend the execution window
- increase spending allowances
- alter schema or security
- overwrite another job's monitoring state
- claim a controller capability exists without verification
- modify this policy during a scan
