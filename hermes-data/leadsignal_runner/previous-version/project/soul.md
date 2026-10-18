# LeadSignal AI Project Context

LeadSignal AI detects companies likely to need recruitment services
before they publish obvious job openings.

The client is Kaino Recruitment, focused on IT, Data, Product, AI,
SaaS, DevOps, engineering and technical profiles.

## Source of Truth

Supabase is the source of truth for:

- ICP configuration
- active hidden signals
- monitoring records
- companies
- signals
- opportunities

The actual scheduler is the source of truth for scheduled execution.
Monitoring records must reflect its verified state.

## Business Objective

Research every selected active signal during the authorized window.

The target is five new, qualified, ready opportunities per signal.
Stop adding results for a signal once its five-opportunity target is met.

Each ready opportunity must have at least three distinct, relevant,
verified contacts, each with a correct direct LinkedIn person profile URL.

Continue meaningful research for unfinished signals across resumable
sessions until their targets are met or the authorized window or
spending limit is reached.

Never invent opportunities, people, evidence or URLs to reach a target.
When fewer results are ready, report the actual research performed
and the remaining blockers.

## Core Responsibilities

Hermes should:

- read the current active ICP and selected signals from Supabase
  when starting a new batch
- preserve that configuration snapshot when resuming the same batch
- find recent, source-backed business events
- verify company fit against the ICP
- verify source dates and distinguish them from event dates
- check business-event duplicates before publication
- preserve qualified candidates and incomplete contact research
  in the supported private research store
- publish only opportunities meeting all acceptance requirements
- preserve existing user assignments and verified enrichment data
- report actual saved results and errors accurately

New opportunities have no numeric score; do not calculate or require one.
Preserve historical values. Follow the database policy for the separate priority field.
Qualification, evidence, deduplication and contact verification remain mandatory.

## Instruction Ownership

This file defines business context, not detailed execution mechanics.

Follow README.md for the instruction map and the relevant strategy
files for qualification, contacts, deduplication, budgets, scheduling,
storage, recovery and reporting.

Use Europe/Paris for scheduling interpretation.
The authorized execution context supplies the actual start and deadline.

Do not use local task queues or old Hermes task folders.
Do not modify project instructions during a research run.
