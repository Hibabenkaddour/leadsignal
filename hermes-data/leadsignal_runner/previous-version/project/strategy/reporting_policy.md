

# LeadSignal Reporting Policy

## Purpose

Report what Hermes actually searched, verified, saved, and could
not complete.

Preserve the distinction between:

- a worker session ending
- an overnight batch ending
- all result targets being reached

This policy defines reporting only. It does not authorize additional
research, database changes, scheduling changes, or contact outreach.

## Evidence For Reports

Build reports from durable progress records and verified database
read-back, not from memory or intended actions.

Use the batch and worker identifiers defined in run_state.md.

Never count an attempted write as a successful insert.

If a write outcome is uncertain:

- reconcile it against saved records
- keep the outcome unresolved until verified
- do not repeat the insert blindly
- do not count it twice after recovery

If reporting data is unavailable, mark it unknown.
Do not replace unknown counts or costs with zero.

## Reporting Scope

Every report must identify:

- report_scope: worker or batch
- batch_id
- worker_session_id, when applicable
- parent agent_run_id
- icp_id
- selected signal keys from the batch snapshot
- actual start time
- report generation time
- authorized research and final deadlines
- whether the batch is continuing or finished

Use Europe/Paris for human-readable times.
Include the date and timezone, especially across midnight.

Store execution instants as UTC timestamps according to
supabase_schema_policy.md.

Do not describe a scheduled start as an actual start.

## Required Reporting Fields

Preserve these original reporting fields:

- status
- active_signals_processed
- results_per_signal
- new_opportunities
- total_opportunities_created
- search_effort_per_signal
- duplicates_skipped
- skipped_duplicates
- date_rejections
- icp_rejections
- contacts_inserted_this_run
- contacts_inserted
- incomplete_contacts
- broken_linkedin_urls_removed
- failed_signals
- shortfall_reasons
- blocked_reasons
- errors

Also report when relevant:

- rejected_weak_evidence
- rejected_missing_date
- pending_candidates
- existing_opportunities_updated
- published opportunity IDs
- inserted contact IDs
- monitoring synchronization outcome
- research coverage and remaining work
- observed usage and costs
- recovery or interruption details

These are logical report fields.

Store them only in supported logs_json or verified execution
storage fields. Do not assume matching database columns exist.

## Counter Definitions

For the declared report scope:

- new_opportunities and total_opportunities_created represent
  the same verified new-publication count.
- duplicates_skipped and skipped_duplicates represent
  the same confirmed duplicate count.
- contacts_inserted_this_run and contacts_inserted represent
  the same verified new contact-row count.

Aliases must agree. Never add aliases together.

For worker reports, explicitly separate:

- worker_delta: records newly created during this worker
- batch_total: cumulative verified records for the batch

For final batch reports, use batch totals.

Do not add cumulative worker totals together.

Derive counts from unique records and durable decisions.

Count a rejected or duplicate candidate once per batch, even
when several workers revisit it.

If rejection categories overlap, say so. Do not present their
sum as a count of unique candidates.

## What Counts As An Opportunity

Count a result only when it is:

- new for this batch
- qualified under the selected ICP and signal
- within the required freshness window
- not a duplicate
- published through the approved process
- linked to at least three accepted contacts
- verified through database read-back

Each accepted contact must satisfy contact_policy.md, including
a verified direct LinkedIn person URL.

Do not count:

- company records alone
- signal records alone
- private candidates
- historical opportunities
- updates to existing opportunities
- duplicate events
- incomplete contact research
- unverified or failed writes

Count the same event only once across selected signals, according
to deduplication.md.

The per-signal batch target and cap are five.

## Per-Signal Report

Include every selected signal from the batch snapshot, even if
it received no research or no results.

For each signal, report:

- signal key
- target: 5
- verified new opportunities published
- remaining target
- published opportunity IDs
- discovery searches completed
- source and query variants used
- verification work completed
- contact research completed
- unique candidates reviewed
- duplicates skipped
- rejections by reason
- pending candidates
- unresolved contact verification
- errors and blockers
- actual coverage
- remaining useful research directions

Calculate remaining target as:

max(0, 5 - verified new opportunities published)

Do not hide an over-cap result by clamping the published count.
Report it as a publication-control error.

Distinguish signals that are:

- searched
- pending research
- blocked
- unsupported by the available approved tools
- at target

These are descriptive report labels, not assumed database enums.

A signal that received searches must not be labelled unprocessed
merely because it produced no opportunity.

Do not claim all selected signals were processed when some
were deferred or blocked before research began.

## Search Effort

Describe actual effort using the ledger defined in source_budget.md.

Distinguish:

- discovery searches
- source verification
- feed fetches
- company qualification
- contact discovery
- LinkedIn verification
- retries after failures

If a tool call contains several queries, count the actual queries
separately from the tool call count.

Record useful changes between research passes, such as:

- different keywords
- alternative source domains
- another approved provider
- different company or event terminology
- revisiting promising incomplete candidates

Do not claim comprehensive coverage based on a few empty queries.

Do not claim to have searched throughout the whole night merely
because the batch remained open.

Distinguish productive work, retry waiting, interruption, and
scheduler downtime.

## Contact Reporting

Separate:

- accepted contacts associated with published opportunities
- newly inserted contact rows
- identified people awaiting verification
- candidates with fewer than three accepted contacts

A fallback LinkedIn search URL is not a verified person profile.

For incomplete candidates, report:

- accepted-contact count
- remaining contacts needed
- unresolved verification reasons
- research already attempted
- next useful verification steps

Use the logical contact statuses from contact_policy.md.

Do not write unsupported status strings into database fields.

Report broken_linkedin_urls_removed only for actual authorized,
persisted corrections.

If no correction was performed, report zero.
If the outcome cannot be verified, report unknown.

Do not treat this reporting field as authorization to modify
historical contacts.

## Worker Completion And Continuation

A worker may finish while the batch remains active.

Its report must state:

- why the worker stopped
- whether progress was saved
- which work remains
- whether controller continuation is confirmed
- any unresolved write or lease issue

A context or tool limit is a worker interruption, not proof that
the overnight research target is impossible.

Do not report final batch failure solely because one worker ended.

Do not claim that another worker will resume unless the controller
has actually recorded or confirmed continuation.

If infrastructure is missing, report setup_required as the
blocker and identify the missing component.

## Final Batch Status

Use completed only when:

- every selected signal reached five verified new opportunities
- every counted opportunity passed the contact requirements
- database reconciliation is complete
- required final tracking succeeded

Otherwise use blocked_not_complete in the final report and
explain the precise outcome.

This label preserves the original reporting contract.
It does not necessarily mean a technical failure.

Distinguish:

- fewer qualifying events found despite repeated research
- unresolved contact verification
- deadline reached
- spending limit reached
- unavailable provider
- missing infrastructure
- interrupted execution
- publication failure
- monitoring synchronization failure

If result targets were reached but monitoring synchronization
failed, state both facts. Do not imply the research target failed.

Do not treat an empty selected-signal set as successful delivery
of the overnight target. Report that there was no selected work.

## Database Run Status

Follow run_state.md and supabase_schema_policy.md.

Use only supported agent_runs.status values:

- running
- success
- partial
- failed

Do not write completed, blocked_not_complete, setup_required,
or descriptive signal labels into agent_runs.status.

Store detailed reporting labels in supported structured logs.

While continuation is active, keep the parent batch running.
A worker yield must not finalize the parent run.

At batch finalization:

- use success only when the full completion contract is satisfied
- use partial for a batch with incomplete outcomes or shortfalls,
  including a completed search window with no qualifying results
- use failed when execution was blocked or failed with no
  verified new opportunities

Record exact reasons so zero valid results after real research
can be distinguished from a scan that could not execute.

## Shortfall Reporting

For every signal below five, explain:

- the number published
- the remaining number
- the research passes and approved sources actually used
- the main rejection reasons
- candidates still awaiting verification
- why further work stopped

Do not use unsupported statements such as:

- no opportunities exist
- all sources were exhausted
- the entire date window was fully covered
- the signal is too rare to search further

Describe the observed coverage and limitations instead.

Never invent opportunities, people, profile URLs, search attempts,
or source evidence to make the report appear complete.

## Errors And Monitoring

Report errors by stage:

- source access
- company qualification
- contact research
- database publication
- checkpointing
- controller recovery
- monitoring synchronization

Distinguish recovered errors from unresolved errors.

Include affected signals or records when known.

Never report errors: none when synchronization or another
required operation failed.

A failed monitoring update does not prove the research failed.
A successful update does not prove the scheduler is online.

Report the actual synchronization outcome and timestamp.

Never invent the next execution time or substitute a worker retry
time for the next parent batch start.

## Costs And Limits

Report actual usage and costs when available.

Separate model costs from external provider costs.

Label estimates as estimates and identify unavailable components.

Do not claim a precise total when some costs are unknown.

Record resource-limit interruptions and whether recovery occurred.

Do not claim an increased tool limit or spending allowance unless
it was verified.

## Human-Readable Summary

Write the user-facing summary in French.

Keep it concise:

1. Overall result and whether the batch has ended.
2. Per-signal results, shown as published / 5.
3. Confirmation or shortfall of verified contact requirements.
4. Main unresolved issues.
5. Actual next scheduled run, only when confirmed.

Keep detailed queries, evidence, counters, and record IDs in
the structured report rather than overwhelming the summary.

Do not place execution reports inside opportunities.reason.

Never expose secrets in reports or logs.


