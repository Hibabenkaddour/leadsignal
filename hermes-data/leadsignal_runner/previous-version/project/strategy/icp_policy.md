

# ICP Policy

## Purpose and Ownership

This file defines business qualification:

- company identity
- sector fit
- geographic fit
- employee-size fit
- excluded company types
- selected-signal fit
- source and event freshness
- recruitment relevance

Follow:

- run_state.md for the batch configuration snapshot
- signal_routing.md for approved research sources
- deduplication.md for business-event duplicate checks
- contact_policy.md for contact acceptance
- supabase_schema_policy.md for storage and summary formatting

Passing business qualification does not alone make a candidate
ready for publication.

The candidate must also pass deduplication and the contact
acceptance gate.

## Configuration Source

For a new batch, read the intended active ICP from Supabase
and preserve its configuration under run_state.md.

For a resumed batch, use that saved configuration snapshot.
Do not silently replace it with settings edited after the batch began.

Read and apply the configured:

- sectors
- locations
- company-size boundaries
- excluded company types
- qualification instructions
- max_source_age_days
- selected signals

Do not invent missing constraints or infer settings from
previous conversations.

If a missing or ambiguous setting prevents qualification,
report the problem rather than guessing.

## Company Identity

Identify the actual company entity being evaluated.

Use supported evidence such as:

- official company name
- company website or domain
- legal identity when available
- location
- parent or subsidiary relationship

Do not confuse companies with similar names.

Do not combine one entity's employee count with another
entity's location or business event.

Record the relevant entity scope when group and subsidiary
information differ.

## Sector and Company-Type Fit

Verify the company's actual activity against the saved ICP.

Do not qualify a company solely because an article contains
an IT, AI, data or cybersecurity keyword.

Apply explicit exclusions.

A related activity or evidence-backed near-match may qualify
only when consistent with the saved ICP instructions.

Commercial judgment must not override an explicit exclusion.

## Mandatory Exclusions: Scale-ups and CAC 40

These explicit project exclusions apply to new research and publication,
in addition to the saved ICP settings, even when employee-size, sector,
location and signal criteria would otherwise pass. A broad ICP setting
or score cannot override them. Changing these exclusions requires an
explicit maintenance instruction; research workers must not remove them.

Always exclude these operator-named companies after resolving identity
and aliases (this is an exclusion list, not a claim about current status):

- Mistral AI (Mistral)
- Qonto
- Doctolib
- BlaBlaCar
- Back Market
- Spendesk
- L'Oréal
- LVMH
- Airbus
- BNP Paribas
- Schneider Electric

Also exclude other companies with evidence-backed scale-up status and
current CAC 40 constituents. The named examples are not exhaustive.
Verify CAC 40 membership using the official Euronext composition and
applicable effective dates at qualification; recheck before publication.
Do not assume every large or listed company belongs to the CAC 40.

For scale-ups outside the explicit list, require credible, dated evidence
explicitly identifying the correct company as a scale-up, supported by
its established business and sustained expansion context. Inspect the
underlying source rather than accepting a model answer or search snippet.
A funding round, AI activity, headcount, a growth adjective or membership
of a broad startup directory alone does not establish scale-up status.
Do not invent a turnover, valuation or growth threshold as the definition.
If there is material conflicting evidence about scale-up status, preserve
the candidate as pending and report the uncertainty before publication.

Check exclusions early, before contact research, and again at publication.
Record the decision, matched identity/alias, entity scope, checked date
and source URL in the candidate's existing evidence object. For an exact
operator-named exclusion, cite this policy instruction as the basis;
do not invent a supporting external URL.

A mere mention of an excluded customer or partner does not exclude an
otherwise eligible target company. Assess the actual prospect entity.
Do not use a different name or a subsidiary headcount to disguise an
excluded target. A legally distinct subsidiary must be evaluated on its
own evidence and disclosed group relationship, not automatically treated
as the parent or automatically allowed to bypass an exclusion.

Save exclusion decisions privately. Do not delete, relabel or rewrite
historical opportunities as part of this change or routine research.

## Location Fit

Verify the geographic criterion actually specified by the ICP.

Distinguish:

- headquarters
- registered office
- operating office
- subsidiary location
- customer location
- location of the reported event

A customer or contract in France does not by itself prove
that the supplier meets a France-based-company requirement.

Use Perplexity where available through the approved routing,
and inspect supporting evidence.

Evidence-backed location estimates may be used when consistent
with the ICP, with uncertainty recorded.

Do not treat an unsupported location guess as verified.

## Company Size

Use Perplexity to verify company size when possible,
following the approved source-routing policy.

Check the supporting evidence rather than accepting a generated
answer without corroboration.

Distinguish:

- legal-entity headcount
- subsidiary headcount
- consolidated group headcount
- employees in a particular country
- historical versus current headcount

Use the scope relevant to the candidate and saved ICP.
Do not select whichever number makes the candidate qualify.

An evidence-backed estimate is acceptable when consistent
with the ICP.

Do not reject solely because a supported figure is approximate.
Record medium confidence where appropriate.

Do not invent an exact count from an employee range.

If a range crosses an ICP boundary, seek further evidence.
Do not assume that the actual count falls inside the allowed range.

If uncertainty prevents establishing size fit, keep the candidate
pending rather than treating the match as confirmed.

## Company-Size Storage

When publishing a qualified candidate, store a supported
numeric employee count or estimate in:

- companies.employee_count

Also preserve the estimate or range evidence in:

- signals.metadata_json.icp_evidence.employee_count_estimate

Inside signals.metadata_json.icp_evidence, preserve:

- company_size_match
- company_size_source_name
- company_size_source_url
- company_size_confidence

Record entity scope, evidence date and unresolved uncertainty
in supported research or metadata fields.

These metadata details must reflect evidence actually obtained.

While the candidate is pending, preserve them in the supported
private research store.

Never store a range or explanatory sentence in the integer
companies.employee_count field.

A concise verified employee figure may appear in
opportunities.reason when useful.

Do not put raw verification notes, technical metadata or
company-size evidence dumps in the summary.

## Selected-Signal Fit

The evidence must support the exact selected signal.

Do not combine unrelated facts to manufacture a match.

Distinguish, for example:

- funding received from an open funding application
- a contract award from an invitation to tender
- an obtained certification from a qualification process
- a confirmed appointment from an unverified role listing
- actual expansion from an aspiration
- a hiring pattern from one isolated job posting

Do not treat broad regulatory or industry news as a company-specific
trigger without evidence connecting it to the candidate.

Keep the signal interpretation and supporting source together.

## Source Freshness

Read max_source_age_days from the batch's saved ICP configuration.

Never hardcode a 60-day, 90-day or other fixed window.

Use the actual current date at qualification and recheck
freshness before publication.

For consistent date-only comparisons, use the current
Europe/Paris calendar date.

The publication-date condition is:

source_published_at >= current_Paris_date - max_source_age_days

The source must not have a future publication date relative
to that current date.

Do not apply a bare database CURRENT_DATE without checking
whether its timezone matches the intended comparison.

## Publication, Event and Detection Dates

These dates have different meanings:

- signals.source_published_at:
  the actual publication date of the cited source

- signals.event_date:
  the underlying business-event date, when established
  and supported by the schema

- signals.detected_at:
  when Hermes discovered the signal

Do not substitute one for another.

Never use the scan date as the publication date unless
the source was actually published on that date.

Never use detected_at as evidence of source freshness.

Do not overwrite the publication date with an older event date
to make the fields appear consistent.

## Old Events in Recent Articles

A recent publication does not make an old event new.

When the underlying event date is established, verify that
it also falls inside the active age window.

Reject an old event even when:

- a recent article repeats it
- a roundup includes it
- a programme page was recently updated
- the event remains commercially relevant

Do not use a programme year, promotion year or general
event year as proof of an exact qualifying date.

For a dated announcement of a future launch or planned action,
distinguish the announcement date from the future milestone.
Qualify the actual evidenced signal without presenting
a future action as already completed.

## Date Verification

Confirm that the date belongs to the cited source and event.

Do not use:

- the date of another linked article
- a search crawl date
- a website footer year
- an unrelated page-update date
- an inferred date unsupported by evidence

If a dated original announcement clearly establishes a new event,
a separate event-date field may remain unknown when the
source does not supply one.

Do not fabricate a separate event date.

If the evidence could concern an older event and its timing
cannot be established, keep the candidate pending.
It must not be published as a fresh opportunity.

## Recruitment Relevance

Require a credible reason the event may create a need
for the recruitment services described by the ICP.

Separate:

- verified business facts
- confirmed recruitment information
- inferred recruitment potential

Label an inference as potential.

Do not claim announced hiring, vacancies or team expansion
without supporting evidence.

Avoid generic outreach reasons that could apply to any company.

## Qualification Decision

A candidate passes business qualification only when:

- company identity is sufficiently established
- sector and company-type criteria are satisfied
- location criteria are satisfied
- company-size criteria are satisfied
- mandatory scale-up, CAC 40 and named-company exclusions are checked and passed
- the exact selected signal is supported
- source and event freshness checks pass
- a credible recruitment angle exists

Then apply deduplication and contact acceptance before publication.

Do not insert weak, unrelated, stale or unverifiable candidates
as new ready opportunities.

## Pending and Rejected Research

Use pending research when additional evidence may resolve
a material uncertainty.

Record the exact missing evidence and next useful action.

Reject a research candidate when evidence establishes:

- an ICP mismatch
- an excluded company type
- a stale event or source
- an unrelated signal
- unsupported or misleading claims

Save the decision and evidence in the supported private
research store.

Do not create rejected public opportunities merely to record
routine discovery failures in the new overnight workflow.

Preserve existing historical rejected opportunities.
Do not delete or modify them automatically.

Report date and ICP rejection counts from recorded decisions,
not estimates or memory.


