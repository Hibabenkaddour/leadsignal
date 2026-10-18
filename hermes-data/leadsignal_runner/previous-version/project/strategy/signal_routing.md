

# Signal Routing

## Purpose and Ownership

This file defines approved provider assignments and source roles.

Follow:

- source_budget.md for research effort and limits
- icp_policy.md for qualification and freshness
- contact_policy.md for contact and LinkedIn verification
- deduplication.md for duplicate checks
- run_state.md for progress and recovery

A search result is a discovery lead, not automatic proof
that an opportunity qualifies.

## Selected Signals

Use the selected signal keys from the batch configuration snapshot.

A provider route does not activate a signal.
Do not research an unselected signal merely because a tool supports it.

Keep evidence and search accounting associated with the
correct selected signal.

## Tavily: Primary Discovery

Use Tavily as the primary discovery provider for:

- fundraising
- leader_tech_data_nomination
- major_contract_partnership
- major_tech_data_program
- public_rd_funding
- compliance_pressure
- new_product
- ma_activity
- office_move_expansion
- subsidiary_creation
- headcount_growth
- executive_recruiting_pain
- tech_team_attrition

Vary relevant queries using the selected signal, ICP sector,
company terminology and appropriate date constraints.

Prioritize identifiable company events and direct source evidence.

Do not treat a generic programme page, industry article
or search summary as a confirmed company event.

## Google News RSS: Confirmation and Explicit Discovery Fallbacks

Use Google News RSS as a confirmation source for:

- fundraising
- leader_tech_data_nomination
- ma_activity
- office_move_expansion
- new_product

For fundraising, ma_activity and office_move_expansion, RSS remains
confirmation only. The discovery extensions below apply only to the
explicitly listed keys; all qualification checks remain required.

For these five keys only, Google News RSS is also an approved
discovery fallback when Tavily is unavailable or documented
Tavily searches repeatedly return weak or irrelevant leads:

- major_tech_data_program
- subsidiary_creation
- headcount_growth
- leader_tech_data_nomination
- new_product

Locate the original publisher or company source where possible.
Do not assume an RSS item's timestamp is the underlying event date.
Verify dates under icp_policy.md. A headline or snippet alone
cannot establish qualification.

Other signal keys are not assigned to Google News RSS by this policy.
Report further proposed extensions for maintenance.

## Headcount Growth Qualification

For headcount_growth, Tavily is primary discovery and Google News RSS
is an approved discovery fallback. Apply the configured signal definition.
Verify a real workforce increase using comparable dated counts or a
source explicitly documenting that increase. Preserve entity scope and
the period compared. Hiring intentions, open vacancies, revenue growth,
mergers or incomparable group/entity counts alone do not establish
organic headcount growth. Never invent a percentage or time window.
Keep planned hiring distinct from achieved workforce growth.

## Direct Announcement Discovery: Four Explicit Assignments

For major_tech_data_program, subsidiary_creation,
leader_tech_data_nomination and new_product, existing
approved read/extraction tools may also inspect a bounded set of
relevant company newsrooms, original publisher announcement pages,
and public announcement indexes to discover events.

These are discovery routes, so an already-qualified candidate is
not required to start reviewing those pages. Record the actual
page URL, discovery purpose, results and provider/tool used.
Read a small relevant set, evaluate it, then choose the next useful
sources; this does not authorize unrestricted crawling, installation,
new paid integrations or circumvention of access restrictions.

A generic tool named web_search is not automatically approved:
identify its actual underlying provider before use. A Tavily-backed
tool is still Tavily and is not a fallback for a Tavily account limit.
If the provider cannot be identified, do not claim it is an approved
alternative. Existing approved page-reading tools may read the
explicit source pages above without adding a search provider.

For subsidiary_creation, look for an identified company's creation
of a distinct subsidiary or legal entity, supported by dated sources.
Use the configured signal description to determine the exact scope.
An office opening, product launch, acquisition, generic startup
portrait or publisher category label alone does not prove subsidiary
creation. Verify the parent/subsidiary relationship and apply ICP
rules to the actual target entity without mixing group and entity facts.

For major_tech_data_program, verify a concrete company programme
against the configured signal definition. A product mention, generic
national scheme or marketing use of AI/data alone is insufficient.

These assignments do not activate any signal or relax any
source-date, company-fit, deduplication or contact acceptance gate.

## Targeted Discovery for Three Signals

This section applies only to leader_tech_data_nomination, new_product
and subsidiary_creation. It changes discovery methods, not contact
acceptance, ICP, exclusions, freshness, publication or duplicate rules.
Use the batch snapshot's actual signal definitions and ICP values.

For leader_tech_data_nomination, combine relevant role names and
appointment terms (French and English) with identified eligible companies
or specialist announcement indexes. Follow promising leads to original
announcements. Job advertisements and generic job descriptions are not
appointments. Check the source date and company fit before contact work.

For new_product, search identified eligible publishers' newsrooms and
dated release announcements, using the product and company names rather
than repeating broad launch queries. Apply the configured signal definition
to distinguish a qualifying launch from an old product page or routine update.
Inspect actual announcement evidence; never infer launch dates from a footer.

For subsidiary_creation, combine identified parent companies and sector terms
with creation/establishment announcements. If a query returns legal guides,
change to a relevant company newsroom or announcement index instead of
repeating the same generic legal wording. Verify the distinct entity and
parent relationship under the existing rules above.

For these three signals, when documented discovery queries repeatedly yield
irrelevant leads, use an approved fallback with a different source or angle.
Record the examined source and what remains unexplored in the existing worker
checkpoint. Reuse recorded duplicate and rejected-event decisions; reopen
only when new evidence could change that decision. This does not change
contact-search rules or authorize restarting a blocked provider.

## Apify: LinkedIn Job Signals

Use the configured Apify actor for:

- internal_tech_recruiter_hiring
- tech_role_repost
- tech_job_velocity_cluster

Actor name:

apimaestro/linkedin-jobs-scraper-api

API actor identifier:

apimaestro~linkedin-jobs-scraper-api

Use its verified installed input contract.
Do not guess parameter names or silently substitute another actor.

Retain relevant job identifiers, employer identity,
job URLs, dates and supporting job information.

One observed posting does not by itself establish a repost
or a hiring-velocity pattern.

The evidence must support the specific selected signal.

## BOAMP / TED: Procurement Signals

Use BOAMP / TED for:

- it_data_rfp

Verify the notice identity, relevant dates, buyer,
scope and applicable company role.

Distinguish a call for tenders from a contract award.

Do not describe an invitation to bid as a contract
already won by a company.

Apply the ICP, freshness and signal-fit policies
before accepting a candidate.

## Perplexity: Verification and People Discovery

Use Perplexity for:

- company size verification
- headquarters and location verification
- key people discovery after business qualification
- targeted LinkedIn profile research for identified people

The LinkedIn research use extends the existing key-people route
to support the current verified-contact requirement.

Treat generated answers as research assistance.

Inspect the cited evidence supporting:

- company identity
- employee count and entity scope
- location
- professional role
- exact LinkedIn person profile URL

Do not mark a claim verified solely because it appears
in a provider-generated answer.

Follow contact_policy.md for the complete LinkedIn
acceptance requirements.

## Direct Source Verification

In addition to the four explicit direct-discovery assignments above,
for candidates discovered through the approved routes,
inspect relevant underlying sources using approved
available read or extraction tools.

Examples include:

- official company announcements
- leadership pages
- original publisher articles
- official programme award announcements
- procurement notices
- original job postings

This supports verification of discovered evidence.
It does not authorize unrelated provider integrations
or unrestricted crawling.

Record the actual source URL and relevant supporting evidence.

Do not copy a search-provider citation marker into a URL field.

## Provider Availability

Check a provider when it is needed for the selected work.

Do not spend the research budget probing unrelated providers.

If a required provider fails:

- record the actual failure
- distinguish temporary failure from missing configuration or an account quota limit
- retry transient failures within the execution policy
- continue other useful selected-signal work when possible
- preserve unfinished work for later resumption

Apply the shared provider-block rules in source_budget.md before retrying.
An alternative tool using the same blocked provider is not a new route.

Use another route only when this policy explicitly authorizes
it for that signal and purpose.

Do not claim a signal has no opportunities merely because
its provider was unavailable.

Never expose API keys or credentials.

## Route Coverage Before Research

Before paid research, check every selected signal against this file.
Record which discovery routes are approved and which are available.
An API credential alone does not establish route availability.
Do not probe unrelated providers. A read-only preflight must not claim
that paid-provider access has been tested when it has not.

A signal with no approved route must be reported as unsupported before
research begins. Preserve it in the batch target and shortfall report;
continue useful work on the other supported selected signals.
The execution layer should expose this coverage check explicitly.
Do not claim an automated preflight exists merely because this policy
requires it; the controller implementation must perform it.

## Unsupported Signals

Do not silently ignore an unsupported selected signal.

Record in the existing worker checkpoint or batch reporting structure,
not as a rejected company candidate:

- the exact signal key
- its configured description when available
- that no approved route is defined
- the resulting coverage limitation

Do not substitute a similar signal without authorization.

Report the missing route for maintenance.
Do not claim that the unsupported signal was fully processed
or that its result target was satisfied.

## Search and Evidence Accounting

For each source operation, record its purpose and outcome
according to source_budget.md.

Distinguish:

- primary discovery
- confirmation
- source extraction
- company verification
- contact discovery
- LinkedIn verification

Do not present provider summaries as independently verified
source evidence.

Do not mix evidence from different companies or events
to construct a qualifying opportunity.

## Runtime Changes

Research workers must not:

- edit this routing file
- install new providers or actors
- change credentials
- invent unsupported API parameters
- change signal selection
- modify database or scheduler configuration

Route changes belong to an explicit maintenance task.

## Per-signal search descriptions

Use the selected batch signal descriptions for search vocabulary and evidence
guidance. They do not change provider assignments, qualification, exclusions,
contact acceptance or the configured thresholds. Never treat suggested
recruitment implications as verified facts.

## Research Reliability V1 — 2026-10-06

Employment criteria: cluster = at least 3 distinct complementary IT/data/product jobs at the actual same hiring employer, verified original publication within 60 days AND the ICP freshness limit. Long-open = verified original publication at least 45 days before a fresh still-open check; repost = at least 2 separately evidenced publications of the same role/employer. Scrape observations and cross-site copies are not publications. See Research Reliability V1 in run_state.md. No discovery provider routes are added or removed.

## Perplexity-only contacts and long-open evidence â€” 2026-10-07

CONTACTS PERPLEXITY ONLY â€” operator decision, supersedes all earlier contact routes:
Use ONLY the installed perplexity_contacts.py helper for discovery of people,
verification of their professional role/company, and exact LinkedIn profile URLs.
No Tavily/web_search, Google/RSS, Apify, web_extract or terminal HTTP fallback for
CONTACT research or profile verification. These providers retain their existing
business-event discovery/qualification routes. Do not relabel a people search as
company_qualification or source_verification to evade the restriction.
If Perplexity is unavailable, preserve verified contacts and pending evidence,
record contact_workflow.state='blocked' and the exact reason; no substitute provider.
Contact count is still not a publication gate. Perplexity text alone is not proof:
inspect the returned citations and indexed snippets, match the exact person/profile
and current company. Use purpose=linkedin_verification for acceptance evidence.
verification_attempt_id must be the successful Perplexity attempt for THIS candidate
and batch; verification_source_url must be in its returned sources. Preserve its
finished_at as verified_at. If evidence conflicts about a title, ask Perplexity to
resolve the specific conflict using dated/official sources. If unresolved, keep the
person pending; never publish a guessed title or overwrite an existing verified contact.
Do not spend the contact helper on company sector/size qualification.

QUALIFICATION CONSISTENCY:
Check exclusions (including scale-ups), actual business activity and actual employer
before contacts/publication. NAF/APE alone is insufficient evidence of present business
activity. A staffing advertiser's client vacancies do not prove growth of its own team.
Record exact sources and entity scope; unresolved eligibility is pending, not invented.
Do not revise existing opportunities or delete orphan companies automatically.
For RFPs, retain the current ICP interpretation; if the buyer fails ICP record the
candidate-specific mismatch. Do not claim all BOAMP/TED buyers or every RFP is ineligible.

LONG-OPEN OFFER EXCEPTION (tech_role_repost only):
Keep the genuine original source_published_at. Never replace it with scrape date/today.
For an old original source, publication requires evidence.long_open_proof with:
job_id, employer_company_id, original_published_at (YYYY-MM-DD), source_url (same as
event_data.source_url), original_publication_verified=true, currently_open_verified=true,
same_vacancy_verified=true, verification_attempt_id, verification_excerpt.
The verification attempt must be a successful source_verification for THIS candidate,
batch and job URL, finished during this batch. result_summary.job_observation must
record matching job_id, employer_company_id, original_published_at, source_url,
original_publication_verified=true, currently_open_verified=true, same_vacancy_verified=true,
and a nonempty excerpt from the actual observed source. Observation must prove still open.
At least 45 days must separate original publication from the verification date.
event_date may be null or the original publication date; never invent a new event date.
Only use this exception after SQL migration has been installed. Other signal freshness
checks stay unchanged. Record job_evidence.py output as a consistency check, not final
publication approval. The server checks the supporting attempt; generic eligible=true
alone is insufficient. Company qualification and deduplication still apply.

REPORTING: Always report published signals / ALL snapshot-selected signals, including
suspended ones in the denominator. A suspended signal is not achieved or removed.
Use controller timestamps, not a guessed wall-clock report time. Report contact work
remaining/blocked separately; fewer than three contacts is not automatically pending.


