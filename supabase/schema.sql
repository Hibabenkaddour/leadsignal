--
-- PostgreSQL database dump
--

\restrict JItcVs7YH0ZUIchCbViOlwkhmGmSzaWnOAO5n7E1U4yeUfUNmB5Lwq4SYDXP3Ba

-- Dumped from database version 17.11
-- Dumped by pg_dump version 18.6 (Debian 18.6-1.pgdg13+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: is_platform_ceo(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_platform_ceo() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$ select exists(select 1 from public.platform_members
  where user_id=(select auth.uid()) and active and role='ceo'); $$;


--
-- Name: is_platform_member(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_platform_member() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select exists (select 1 from public.platform_members
    where user_id = (select auth.uid()) and active = true);
$$;


--
-- Name: latest_scan_opportunity_ids(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.latest_scan_opportunity_ids(target_icp_id uuid) RETURNS TABLE(opportunity_id uuid)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  with latest_batch as (
    select r.id, r.started_at
    from public.agent_runs r
    where public.is_platform_member()
      and r.icp_id = target_icp_id
      and exists (
        select 1 from public.signals s
        join public.opportunities o on o.primary_signal_id=s.id
        where s.agent_run_id=r.id
          and o.created_at >= r.started_at
          and o.status not in ('rejected','archived')
      )
    order by r.started_at desc, r.id desc limit 1
  )
  select o.id
  from latest_batch r
  join public.signals s on s.agent_run_id=r.id
  join public.opportunities o on o.primary_signal_id=s.id
  where o.created_at >= r.started_at
    and o.status not in ('rejected','archived');
$$;


--
-- Name: leadsignal_apify_policy_version(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_apify_policy_version() RETURNS text
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'pg_catalog'
    AS $$ SELECT 'apify_boamp_v2'::text $$;


--
-- Name: leadsignal_assert_event_v2(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_assert_event_v2(p_candidate_id uuid) RETURNS void
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE c public.leadsignal_candidates; d jsonb; conflict uuid; old public.leadsignal_events_v2;
BEGIN
 SELECT * INTO STRICT c FROM public.leadsignal_candidates WHERE id=p_candidate_id;
 d:=c.evidence->'deduplication_v2';
 IF c.company_id IS NULL OR d->>'verdict' IS DISTINCT FROM 'distinct_event'
 OR coalesce(length(btrim(d->>'rationale')),0)<20
 OR coalesce(length(d->>'event_key'),0) NOT BETWEEN 8 AND 300
 OR jsonb_typeof(d->'facts') IS DISTINCT FROM 'object' OR d->'facts'='{}'::jsonb
 OR jsonb_typeof(d->'compared_signal_ids') IS DISTINCT FROM 'array' THEN
   RAISE EXCEPTION 'Document semantic comparison: company, signal, event facts, stable event_key, compared_signal_ids, rationale';
 END IF;
 -- Serializes same-company/signal qualifications even if URLs or keys differ.
 PERFORM pg_advisory_xact_lock(hashtextextended(c.company_id::text||':'||c.signal_key,0));
 IF EXISTS(SELECT 1 FROM public.signals s WHERE s.company_id=c.company_id AND s.signal_key=c.signal_key
    AND NOT coalesce((d->'compared_signal_ids') @> jsonb_build_array(s.id::text),false)) THEN
   RAISE EXCEPTION 'Historical/concurrent event missing from semantic comparison; re-read history';
 END IF;
 SELECT * INTO old FROM public.leadsignal_events_v2 WHERE candidate_id=c.id;
 IF FOUND AND (old.company_id<>c.company_id OR old.signal_key<>c.signal_key OR old.event_key<>d->>'event_key') THEN
   RAISE EXCEPTION 'Qualified event identity cannot be rotated';
 END IF;
 SELECT candidate_id INTO conflict FROM public.leadsignal_events_v2
 WHERE company_id=c.company_id AND signal_key=c.signal_key AND event_key=d->>'event_key';
 IF FOUND AND conflict<>c.id THEN RAISE EXCEPTION 'Duplicate business event (URL independent)'; END IF;
 INSERT INTO public.leadsignal_events_v2(company_id,signal_key,event_key,candidate_id,facts)
 VALUES(c.company_id,c.signal_key,d->>'event_key',c.id,d->'facts') ON CONFLICT(candidate_id) DO NOTHING;
END;
$$;


--
-- Name: leadsignal_assert_perplexity_contact(uuid, uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_assert_perplexity_contact(p_batch uuid, p_candidate uuid, p_person jsonb) RETURNS void
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE a public.leadsignal_research_attempts%ROWTYPE;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.leadsignal_batches WHERE id=p_batch
    AND execution_config->>'contact_provider'='perplexity_only') THEN RETURN; END IF;
 SELECT * INTO a FROM public.leadsignal_research_attempts
 WHERE id=(p_person->>'verification_attempt_id')::uuid AND batch_id=p_batch
 AND candidate_id=p_candidate AND provider='perplexity'
 AND purpose='linkedin_verification' AND state='succeeded';
 IF NOT FOUND OR a.finished_at IS NULL
 OR (p_person->>'verified_at')::timestamptz IS DISTINCT FROM a.finished_at THEN
  RAISE EXCEPTION 'Accepted contact requires a successful Perplexity verification attempt and its timestamp'; END IF;
 IF jsonb_typeof(a.result_summary->'sources') IS DISTINCT FROM 'array' THEN
  RAISE EXCEPTION 'Perplexity cited evidence missing'; END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(a.result_summary->'sources') s
    WHERE s->>'url'=p_person->>'verification_source_url') THEN
  RAISE EXCEPTION 'Contact evidence URL must match a returned Perplexity source'; END IF;
END;
$$;


--
-- Name: leadsignal_assert_worker(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_assert_worker(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid) RETURNS void
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE
    b public.leadsignal_batches%ROWTYPE;
    v_now timestamptz;
BEGIN
    IF p_worker_id IS NULL OR p_lease_token IS NULL THEN
        RAISE EXCEPTION 'Worker identity and lease token required';
    END IF;
    SELECT * INTO b FROM public.leadsignal_batches
        WHERE id = p_batch_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Batch not found'; END IF;
    v_now := clock_timestamp();
    IF b.state <> 'running' OR b.final_deadline IS NULL OR v_now >= b.final_deadline
       OR b.lease_worker_id IS DISTINCT FROM p_worker_id
       OR b.lease_token IS DISTINCT FROM p_lease_token
       OR b.lease_expires_at IS NULL OR v_now >= b.lease_expires_at THEN
        RAISE EXCEPTION 'Worker lease is invalid, expired, or superseded';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.leadsignal_workers
        WHERE id = p_worker_id AND batch_id = p_batch_id AND state = 'started') THEN
        RAISE EXCEPTION 'Worker is not active';
    END IF;
END;
$$;


--
-- Name: leadsignal_claim_contact_recovery(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_claim_contact_recovery(p_opportunity_id uuid) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE t public.leadsignal_contact_recovery_targets%ROWTYPE;
BEGIN
 SELECT * INTO t FROM public.leadsignal_contact_recovery_targets WHERE opportunity_id=p_opportunity_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Opportunity outside approved recovery list'; END IF;
 IF t.state IN ('done','blocked','skipped') THEN RETURN jsonb_build_object('state',t.state); END IF;
 IF t.state='running' AND t.lease_expires_at>clock_timestamp() THEN
   RAISE EXCEPTION 'Recovery already active for this opportunity';
 END IF;
 IF EXISTS(SELECT 1 FROM public.leadsignal_batches WHERE state='running') THEN
   RAISE EXCEPTION 'Do not overlap recovery with a discovery batch';
 END IF;
 PERFORM 1 FROM public.opportunities WHERE id=t.opportunity_id AND company_id=t.company_id
   AND status IN ('new','review','qualified') FOR UPDATE;
 IF NOT FOUND OR (t.started_at IS NULL AND EXISTS(SELECT 1 FROM public.opportunity_contacts WHERE opportunity_id=t.opportunity_id)) THEN
   UPDATE public.leadsignal_contact_recovery_targets SET state='skipped',updated_at=clock_timestamp()
     WHERE opportunity_id=p_opportunity_id;
   RETURN jsonb_build_object('state','skipped');
 END IF;
 UPDATE public.leadsignal_contact_recovery_targets SET state='running',started_at=coalesce(started_at,clock_timestamp()),
   lease_token=gen_random_uuid(),lease_expires_at=clock_timestamp()+interval '120 seconds',attempts=attempts+1,
   updated_at=clock_timestamp() WHERE opportunity_id=p_opportunity_id RETURNING * INTO t;
 RETURN to_jsonb(t);
END;
$$;


--
-- Name: leadsignal_claim_worker(uuid, uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_claim_worker(p_batch_id uuid, p_worker_id uuid, p_lease_seconds integer DEFAULT 120) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE
    b public.leadsignal_batches%ROWTYPE;
    v_now timestamptz;
    v_token uuid;
    v_until timestamptz;
    v_attempt integer;
BEGIN
    IF p_worker_id IS NULL OR p_lease_seconds IS NULL
       OR p_lease_seconds < 30 OR p_lease_seconds > 300 THEN
        RAISE EXCEPTION 'Invalid worker identity or lease duration (30..300 seconds required)';
    END IF;

    SELECT * INTO b FROM public.leadsignal_batches
        WHERE id = p_batch_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Batch not found'; END IF;
    v_now := clock_timestamp();

    IF b.state <> 'running' OR b.final_deadline IS NULL
       OR v_now >= b.final_deadline THEN
        RAISE EXCEPTION 'Batch is not running or its deadline has passed';
    END IF;

    IF b.lease_worker_id IS NOT NULL AND b.lease_expires_at > v_now THEN
        IF b.lease_worker_id <> p_worker_id THEN
            RAISE EXCEPTION 'Batch already has an active worker';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM public.leadsignal_workers
            WHERE id = p_worker_id AND batch_id = p_batch_id AND state = 'started') THEN
            RAISE EXCEPTION 'Lease and worker state disagree';
        END IF;
        RETURN jsonb_build_object('worker_id', p_worker_id,
            'lease_token', b.lease_token, 'lease_expires_at', b.lease_expires_at,
            'research_deadline', b.research_deadline, 'final_deadline', b.final_deadline,
            'reused', true);
    END IF;

    IF EXISTS (SELECT 1 FROM public.leadsignal_workers WHERE id = p_worker_id) THEN
        RAISE EXCEPTION 'Worker identity already used; create a new attempt UUID';
    END IF;

    IF b.lease_worker_id IS NOT NULL THEN
        UPDATE public.leadsignal_workers
            SET state = 'timed_out', finished_at = v_now,
                error_message = 'Lease expired; process termination must be checked by controller'
            WHERE id = b.lease_worker_id AND batch_id = p_batch_id AND state = 'started';
    END IF;

    IF EXISTS (SELECT 1 FROM public.leadsignal_workers
        WHERE batch_id = p_batch_id AND state = 'started') THEN
        RAISE EXCEPTION 'Unreconciled started worker; manual diagnosis required';
    END IF;

    SELECT coalesce(max(attempt_number), 0) + 1 INTO v_attempt
        FROM public.leadsignal_workers WHERE batch_id = p_batch_id;
    INSERT INTO public.leadsignal_workers
        (id, batch_id, attempt_number, state, started_at, heartbeat_at)
        VALUES (p_worker_id, p_batch_id, v_attempt, 'started', v_now, v_now);

    v_token := gen_random_uuid();
    v_until := least(v_now + make_interval(secs => p_lease_seconds), b.final_deadline);
    UPDATE public.leadsignal_batches
        SET lease_worker_id = p_worker_id, lease_token = v_token,
            lease_expires_at = v_until
        WHERE id = p_batch_id;

    RETURN jsonb_build_object('worker_id', p_worker_id, 'attempt_number', v_attempt,
        'lease_token', v_token, 'lease_expires_at', v_until,
        'research_deadline', b.research_deadline, 'final_deadline', b.final_deadline,
        'reused', false);
END;
$$;


--
-- Name: leadsignal_cleanup_opportunities_11m(boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_cleanup_opportunities_11m(p_dry_run boolean DEFAULT true) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    SET lock_timeout TO '5s'
    SET statement_timeout TO '60s'
    AS $$
DECLARE
  cutoff date := ((CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Paris')::date - interval '11 months')::date;
  ids uuid[];
  eligible bigint;
  removed integer := 0;
BEGIN
  IF p_dry_run IS NULL THEN RAISE EXCEPTION 'p_dry_run obligatoire'; END IF;
  SELECT count(*) INTO eligible FROM public.opportunities o
    LEFT JOIN public.signals s ON s.id=o.primary_signal_id
    WHERE COALESCE(o.event_date, s.source_published_at) < cutoff;
  IF p_dry_run THEN
    RETURN jsonb_build_object('version','retention_11m_v1','dry_run',true,
      'date_basis','event_date_then_source_published_at','cutoff',cutoff,'eligible',eligible,'deleted',0);
  END IF;
  IF NOT pg_try_advisory_xact_lock(518907, 1101) THEN
    RETURN jsonb_build_object('skipped','cleanup_already_running','deleted',0);
  END IF;
  -- Ne pas nettoyer pendant un traitement. Le verrou bloque une création
  -- concurrente de batch jusqu'à la fin de cette transaction courte.
  LOCK TABLE public.leadsignal_batches IN SHARE ROW EXCLUSIVE MODE;
  IF EXISTS(SELECT 1 FROM public.leadsignal_batches WHERE state='running') THEN
    RETURN jsonb_build_object('skipped','batch_running','deleted',0);
  END IF;
  SELECT array_agg(id) INTO ids FROM (
    SELECT o.id FROM public.opportunities o
      LEFT JOIN public.signals s ON s.id=o.primary_signal_id
      WHERE COALESCE(o.event_date, s.source_published_at) < cutoff
    ORDER BY COALESCE(o.event_date, s.source_published_at), o.id
    LIMIT 500 FOR UPDATE OF o
  ) picked;
  IF ids IS NOT NULL THEN
    DELETE FROM public.leadsignal_contact_recovery_attempts WHERE opportunity_id=ANY(ids);
    DELETE FROM public.leadsignal_contact_recovery_targets WHERE opportunity_id=ANY(ids);
    UPDATE public.leadsignal_candidates
      SET opportunity_purged_at=CURRENT_TIMESTAMP, opportunity_id=NULL, next_action=NULL
      WHERE opportunity_id=ANY(ids);
    -- Ce champ n'a pas de FK, mais ne doit pas garder un lien vers une fiche absente.
    UPDATE public.leadsignal_apify_decisions SET opportunity_id=NULL
      WHERE opportunity_id=ANY(ids);
    -- Les liens opportunity_contacts sont supprimés par leur FK CASCADE.
    DELETE FROM public.opportunities WHERE id=ANY(ids);
    GET DIAGNOSTICS removed = ROW_COUNT;
  END IF;
  RETURN jsonb_build_object('version','retention_11m_v1','dry_run',false,
    'date_basis','event_date_then_source_published_at','cutoff',cutoff,'eligible',eligible,'deleted',removed);
END;
$$;


--
-- Name: leadsignal_client_rules_version(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_client_rules_version() RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
SELECT jsonb_build_object('version','client_rules_v2','duplicate_key','company_signal_business_event',
 'max_contacts',5,'contact_search_below',2,'open_min_days',60,
 'discovery_without_qualification',20,'apify_primary_limit',4);
$$;


--
-- Name: leadsignal_contact_recovery_step(uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_contact_recovery_step(p_opportunity_id uuid, p_lease_token uuid, p_action text, p_details jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
DECLARE
 t public.leadsignal_contact_recovery_targets%ROWTYPE;
 a public.leadsignal_contact_recovery_attempts%ROWTYPE;
 proof public.leadsignal_contact_recovery_attempts%ROWTYPE;
 existing public.opportunity_contacts%ROWTYPE;
 contacts jsonb;
 person jsonb;
 verified jsonb := '[]';
 v_url text; v_name text;
 v_urls text[] := ARRAY[]::text[];
 v_names text[] := ARRAY[]::text[];
 v_id uuid;
 ids jsonb := '[]';
 inserted integer := 0;
 n integer;
BEGIN
 SELECT * INTO t FROM public.leadsignal_contact_recovery_targets WHERE opportunity_id=p_opportunity_id FOR UPDATE;
 IF NOT FOUND OR t.state<>'running' OR p_lease_token IS NULL OR t.lease_token IS DISTINCT FROM p_lease_token
    OR t.lease_expires_at<=clock_timestamp() THEN RAISE EXCEPTION 'Recovery lease invalid or expired'; END IF;
 IF p_details IS NULL OR jsonb_typeof(p_details)<>'object' THEN RAISE EXCEPTION 'Details object required'; END IF;
 IF p_action='heartbeat' THEN
   UPDATE public.leadsignal_contact_recovery_targets SET lease_expires_at=clock_timestamp()+interval '120 seconds',
    updated_at=clock_timestamp() WHERE opportunity_id=t.opportunity_id;
   RETURN jsonb_build_object('renewed',true);
 ELSIF p_action='checkpoint' THEN
   IF jsonb_typeof(p_details->'notes') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Notes object required'; END IF;
   UPDATE public.leadsignal_contact_recovery_targets SET notes=notes||(p_details->'notes'),updated_at=clock_timestamp()
    WHERE opportunity_id=t.opportunity_id;
   RETURN jsonb_build_object('saved',true);
 ELSIF p_action IN ('attempt_start','attempt_succeeded','attempt_failed','attempt_interrupted') THEN
   IF nullif(btrim(p_details->>'request_key'),'') IS NULL THEN RAISE EXCEPTION 'Request key required'; END IF;
   SELECT * INTO a FROM public.leadsignal_contact_recovery_attempts
    WHERE opportunity_id=t.opportunity_id AND request_key=p_details->>'request_key';
   IF FOUND THEN
     IF a.lease_token<>p_lease_token THEN RAISE EXCEPTION 'Attempt belongs to another worker'; END IF;
     IF p_action='attempt_start' OR a.state=substring(p_action from 9) THEN RETURN to_jsonb(a)-'lease_token'; END IF;
     IF a.state<>'started' THEN RAISE EXCEPTION 'Attempt already completed'; END IF;
     UPDATE public.leadsignal_contact_recovery_attempts SET state=substring(p_action from 9),finished_at=clock_timestamp(),
       result_summary=coalesce(p_details->'result_summary','{}'::jsonb),error_message=p_details->>'error_message'
       WHERE id=a.id RETURNING * INTO a;
   ELSE
     IF p_action<>'attempt_start' THEN RAISE EXCEPTION 'Record start before provider request'; END IF;
     IF nullif(btrim(p_details->>'provider'),'') IS NULL THEN RAISE EXCEPTION 'Provider required'; END IF;
     INSERT INTO public.leadsignal_contact_recovery_attempts(opportunity_id,lease_token,request_key,purpose,provider,query_text)
       VALUES(t.opportunity_id,p_lease_token,p_details->>'request_key',p_details->>'purpose',
         p_details->>'provider',p_details->>'query_text') RETURNING * INTO a;
   END IF;
   RETURN to_jsonb(a)-'lease_token';
 ELSIF p_action='release' THEN
   IF coalesce(p_details->>'state','pending') NOT IN ('pending','done','blocked') THEN RAISE EXCEPTION 'Invalid completion state'; END IF;
   IF p_details->>'state'='done' AND NOT EXISTS(SELECT 1 FROM public.leadsignal_contact_recovery_attempts
     WHERE opportunity_id=t.opportunity_id AND state='succeeded') THEN RAISE EXCEPTION 'No recorded successful research'; END IF;
   UPDATE public.leadsignal_contact_recovery_targets SET state=coalesce(p_details->>'state','pending'),
     finished_at=CASE WHEN p_details->>'state' IN ('done','blocked') THEN clock_timestamp() ELSE NULL END,
     lease_token=NULL,lease_expires_at=NULL,updated_at=clock_timestamp()
    WHERE opportunity_id=t.opportunity_id;
   RETURN jsonb_build_object('released',true);
 ELSIF p_action<>'apply' OR p_action IS NULL THEN
   RAISE EXCEPTION 'Unknown recovery action';
 END IF;
 PERFORM 1 FROM public.opportunities WHERE id=t.opportunity_id AND company_id=t.company_id
   AND status IN ('new','review','qualified') FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Opportunity changed or is no longer active'; END IF;
 contacts := p_details->'contacts';
    -- CONTACT_COUNT_OPTIONAL_V1
    IF jsonb_typeof(contacts) IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION 'contact_research must be an array; use [] when empty';
    END IF;
    -- contact_research can also include pending people; publish accepted entries only.
    FOR person IN SELECT value FROM jsonb_array_elements(contacts)
        WHERE value->>'accepted' = 'true'
    LOOP
        v_url := person->>'linkedin_url';
        v_name := lower(regexp_replace(btrim(person->>'full_name'), '[[:space:]]+', ' ', 'g'));
        IF v_url IS NULL OR v_url !~ '^https://(www\.)?linkedin\.com/in/[^/?#[:space:]]+/?$'
           OR person->>'linkedin_url_verified' IS DISTINCT FROM 'true'
           OR person->>'company_association_verified' IS DISTINCT FROM 'true'
           OR person->>'company_id' IS DISTINCT FROM t.company_id::text
           OR v_name IS NULL OR v_name !~ '^[^[:space:]]+ [^[:space:]].*$'
           OR v_name ~ '(https?://|"|[[:cntrl:]])'
           OR nullif(btrim(person->>'title'), '') IS NULL
           OR coalesce(person->>'title', '') ~* 'https?://'
           OR nullif(btrim(person->>'relevance_reason'), '') IS NULL
           OR coalesce(person->>'priority', '') NOT IN ('Low', 'Medium', 'High')
           OR nullif(btrim(person->>'source_type'), '') IS NULL
           OR nullif(btrim(person->>'verification_method'), '') IS NULL
           OR coalesce(person->>'verification_source_url', '') !~ '^https?://[^[:space:]]+$'
           OR nullif(btrim(person->>'verification_notes'), '') IS NULL THEN
            RAISE EXCEPTION 'An accepted contact has incomplete identity/profile/evidence fields';
        END IF;
        SELECT * INTO proof FROM public.leadsignal_contact_recovery_attempts
        WHERE id=(person->>'verification_attempt_id')::uuid
          AND opportunity_id=t.opportunity_id AND state='succeeded'
          AND purpose='linkedin_verification';
        IF NOT FOUND OR proof.finished_at IS NULL OR proof.finished_at < t.started_at
           OR proof.finished_at > clock_timestamp()
           OR NOT coalesce((proof.result_summary->'verified_linkedin_urls') @> jsonb_build_array(v_url), false) THEN
          RAISE EXCEPTION 'Completed exact-profile verification for this opportunity required';
        END IF;
        v_url := 'https://www.linkedin.com/in/' ||
            regexp_replace(v_url, '^https://(www\.)?linkedin\.com/in/([^/]+)/?$', '\2') || '/';
        IF lower(v_url) = ANY(v_urls) OR v_name = ANY(v_names) THEN
            RAISE EXCEPTION 'Accepted contacts must be distinct people and profiles';
        END IF;
        v_urls := array_append(v_urls, lower(v_url));
        v_names := array_append(v_names, v_name);
        verified := verified || jsonb_build_array(person || jsonb_build_object(
          'verified_at',proof.finished_at,'linkedin_url',v_url,
          'recovery_opportunity_id',t.opportunity_id));
    END LOOP;

 FOR person IN SELECT value FROM jsonb_array_elements(verified) LOOP
   v_url:=person->>'linkedin_url';
   v_name:=lower(regexp_replace(btrim(person->>'full_name'),'[[:space:]]+',' ','g'));
   SELECT * INTO existing FROM public.opportunity_contacts WHERE opportunity_id=t.opportunity_id AND
     (lower(rtrim(linkedin_url,'/'))=lower(rtrim(v_url,'/')) OR
      lower(regexp_replace(btrim(full_name),'[[:space:]]+',' ','g'))=v_name) ORDER BY id LIMIT 1;
   IF FOUND THEN
     IF existing.company_id<>t.company_id OR existing.linkedin_url_verified IS DISTINCT FROM true
        OR existing.contact_status IS DISTINCT FROM 'valid'
        OR lower(rtrim(existing.linkedin_url,'/')) IS DISTINCT FROM lower(rtrim(v_url,'/'))
        OR lower(regexp_replace(btrim(existing.full_name),'[[:space:]]+',' ','g')) IS DISTINCT FROM v_name THEN
       RAISE EXCEPTION 'Existing contact needs identity reconciliation; no overwrite';
     END IF;
     ids:=ids||jsonb_build_array(existing.id);
     CONTINUE;
   END IF;
   INSERT INTO public.opportunity_contacts(opportunity_id,company_id,full_name,title,linkedin_url,
     linkedin_url_verified,relevance_reason,priority,source_type,raw_result)
   VALUES(t.opportunity_id,t.company_id,btrim(person->>'full_name'),btrim(person->>'title'),v_url,true,
     person->>'relevance_reason',person->>'priority',person->>'source_type',person)
   RETURNING id INTO v_id;
   inserted:=inserted+1;
   ids:=ids||jsonb_build_array(v_id);
 END LOOP;
 SELECT count(*) INTO n FROM public.opportunity_contacts WHERE opportunity_id=t.opportunity_id
   AND company_id=t.company_id AND linkedin_url_verified=true AND contact_status='valid';
 IF n>0 THEN UPDATE public.opportunities SET contact_status=CASE WHEN n>=3 THEN 'complete'
   ELSE 'incomplete_contacts_needed' END WHERE id=t.opportunity_id; END IF;
 IF t.lease_expires_at<=clock_timestamp() THEN RAISE EXCEPTION 'Lease expired during contact apply'; END IF;
 RETURN jsonb_build_object('inserted_contacts',inserted,'verified_contact_count',n,'contact_ids',ids);
END;
$_$;


--
-- Name: leadsignal_discovery_budget(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_discovery_budget(p_batch_id uuid, p_signal_key text) RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
WITH last_q AS (
 SELECT max(q.qualified_at) AS at FROM public.leadsignal_qualifications_v1 q
 JOIN public.leadsignal_candidates c ON c.id=q.candidate_id
 LEFT JOIN public.opportunities o ON o.id=c.opportunity_id
 WHERE q.batch_id=p_batch_id AND q.signal_key=p_signal_key
   AND (c.state='ready_for_validation' OR (c.state='published' AND o.status IN ('new','review','qualified')))
), used AS (
 SELECT count(*) AS n FROM public.leadsignal_dispatches_v1 d
 JOIN public.leadsignal_research_attempts a ON a.id=d.attempt_id CROSS JOIN last_q
 WHERE d.batch_id=p_batch_id AND d.signal_key=p_signal_key
   AND coalesce(a.result_summary->>'no_provider_call','false')<>'true'
   AND (last_q.at IS NULL OR d.dispatched_at>last_q.at)
)
SELECT jsonb_build_object('attempts_since_qualification',used.n,'last_qualified_at',last_q.at,'limit',20)
FROM used,last_q;
$$;


--
-- Name: leadsignal_dispatch_discovery(uuid, uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_dispatch_discovery(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_attempt_key text) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE b public.leadsignal_batches; a public.leadsignal_research_attempts; n integer; s jsonb;
BEGIN
 PERFORM public.leadsignal_assert_worker(p_batch_id,p_worker_id,p_lease_token);
 SELECT * INTO STRICT b FROM public.leadsignal_batches WHERE id=p_batch_id FOR UPDATE;
 IF b.execution_config->>'client_rules' IS DISTINCT FROM 'client_rules_v2'
    OR clock_timestamp()>=b.research_deadline THEN RAISE EXCEPTION 'Discovery contract/window invalid'; END IF;
 SELECT * INTO STRICT a FROM public.leadsignal_research_attempts
  WHERE batch_id=b.id AND worker_id=p_worker_id AND attempt_key=p_attempt_key;
 IF a.state<>'started' OR a.purpose<>'discovery' OR a.provider='apify'
    OR a.signal_key IN ('tech_job_velocity_cluster','tech_role_repost','internal_tech_recruiter_hiring') THEN
  RAISE EXCEPTION 'Only a new non-Apify discovery request can be dispatched here'; END IF;
 IF EXISTS(SELECT 1 FROM public.leadsignal_dispatches_v1 WHERE attempt_id=a.id) THEN
  RAISE EXCEPTION 'Already dispatched or uncertain; do not send again'; END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(b.signal_snapshot) x
   WHERE x->>'signal_key'=a.signal_key AND x->>'active'='true') THEN
  RAISE EXCEPTION 'Signal not active in snapshot'; END IF;
 -- Hard discovery priority; qualification/source checks are not discovery.
 IF NOT EXISTS(SELECT 1 FROM public.leadsignal_research_attempts f WHERE f.batch_id=b.id
   AND f.provider='apify' AND f.state='failed' AND f.error_message ~* '(HTTP (401|402|403|429)|exceeds your plan|insufficient credits|credits exhausted|quota exceeded|usage limit|credit limit|monthly usage hard limit|platform-feature-disabled|not-enough-usage)') THEN
  FOR s IN SELECT value FROM jsonb_array_elements(b.signal_snapshot)
   WHERE value->>'active'='true' AND value->>'signal_key' IN
    ('tech_job_velocity_cluster','tech_role_repost','internal_tech_recruiter_hiring') LOOP
   SELECT count(*) INTO n FROM public.leadsignal_apify_lots l
     WHERE l.batch_id=b.id AND l.signal_key=s->>'signal_key';
   IF n<4 AND (SELECT count(DISTINCT o.id) FROM public.leadsignal_candidates c
      JOIN public.opportunities o ON o.id=c.opportunity_id
      WHERE c.batch_id=b.id AND c.signal_key=s->>'signal_key' AND c.state='published'
        AND o.status IN ('new','review','qualified'))<5 THEN
     RAISE EXCEPTION 'Apify primary discovery has priority: %',s->>'signal_key';
   END IF;
  END LOOP;
 END IF;
 IF (SELECT count(DISTINCT o.id) FROM public.leadsignal_candidates c
     JOIN public.opportunities o ON o.id=c.opportunity_id
     WHERE c.batch_id=b.id AND c.signal_key=a.signal_key AND c.state='published'
       AND o.status IN ('new','review','qualified'))>=5 THEN
  RAISE EXCEPTION 'Five retained opportunities reached'; END IF;
 IF (public.leadsignal_discovery_budget(b.id,a.signal_key)->>'attempts_since_qualification')::int>=20 THEN
  RAISE EXCEPTION 'Twenty discovery requests without a new qualification'; END IF;
 INSERT INTO public.leadsignal_dispatches_v1(attempt_id,batch_id,signal_key)
 VALUES(a.id,b.id,a.signal_key);
 RETURN jsonb_build_object('dispatch_authorized',true,'attempt_id',a.id);
END;
$$;


--
-- Name: leadsignal_enrich_candidate_contacts(uuid, uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_enrich_candidate_contacts(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
DECLARE
    b public.leadsignal_batches%ROWTYPE;
    c public.leadsignal_candidates%ROWTYPE;
    existing public.opportunity_contacts%ROWTYPE;
    person jsonb;
    v_url text;
    v_name text;
    v_checked timestamptz;
    v_urls text[] := ARRAY[]::text[];
    v_names text[] := ARRAY[]::text[];
    v_contact_id uuid;
    v_contact_ids jsonb := '[]'::jsonb;
    v_opportunity_id uuid;
    v_inserted integer := 0;
    v_count integer;
BEGIN
    PERFORM public.leadsignal_assert_worker(p_batch_id,p_worker_id,p_lease_token);
    SELECT * INTO b FROM public.leadsignal_batches WHERE id=p_batch_id;
    SELECT * INTO c FROM public.leadsignal_candidates
      WHERE id=p_candidate_id AND batch_id=p_batch_id FOR UPDATE;
    IF NOT FOUND OR c.state <> 'published' OR c.opportunity_id IS NULL THEN
        RAISE EXCEPTION 'Published candidate in current batch required';
    END IF;
    v_opportunity_id := c.opportunity_id;
    PERFORM 1 FROM public.opportunities
      WHERE id=v_opportunity_id AND company_id=c.company_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Opportunity company mismatch'; END IF;
    -- CONTACT_COUNT_OPTIONAL_V1
    IF jsonb_typeof(c.contact_research) IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION 'contact_research must be an array; use [] when empty';
    END IF;
    -- contact_research can also include pending people; publish accepted entries only.
    FOR person IN SELECT value FROM jsonb_array_elements(c.contact_research)
        WHERE value->>'accepted' = 'true'
    LOOP
        v_url := person->>'linkedin_url';
        v_name := lower(regexp_replace(btrim(person->>'full_name'), '[[:space:]]+', ' ', 'g'));
        IF v_url IS NULL OR v_url !~ '^https://(www\.)?linkedin\.com/in/[^/?#[:space:]]+/?$'
           OR person->>'linkedin_url_verified' IS DISTINCT FROM 'true'
           OR person->>'company_association_verified' IS DISTINCT FROM 'true'
           OR person->>'company_id' IS DISTINCT FROM c.company_id::text
           OR v_name IS NULL OR v_name !~ '^[^[:space:]]+ [^[:space:]].*$'
           OR v_name ~ '(https?://|"|[[:cntrl:]])'
           OR nullif(btrim(person->>'title'), '') IS NULL
           OR coalesce(person->>'title', '') ~* 'https?://'
           OR nullif(btrim(person->>'relevance_reason'), '') IS NULL
           OR coalesce(person->>'priority', '') NOT IN ('Low', 'Medium', 'High')
           OR nullif(btrim(person->>'source_type'), '') IS NULL
           OR nullif(btrim(person->>'verification_method'), '') IS NULL
           OR coalesce(person->>'verification_source_url', '') !~ '^https?://[^[:space:]]+$'
           OR nullif(btrim(person->>'verification_notes'), '') IS NULL THEN
            RAISE EXCEPTION 'An accepted contact has incomplete identity/profile/evidence fields';
        END IF;
        -- CONTACT_TIMESTAMP_V2: a calendar date is not a verification timestamp.
        IF coalesce(person->>'verified_at', '') !~
           '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$' THEN
            RAISE EXCEPTION 'verified_at requires full ISO timestamp with timezone from actual verification; date-only is invalid';
        END IF;
        PERFORM public.leadsignal_assert_perplexity_contact(b.id,c.id,person);
        v_checked := nullif(person->>'verified_at', '')::timestamptz;
        IF v_checked IS NULL OR v_checked < b.started_at OR v_checked > clock_timestamp() THEN
            RAISE EXCEPTION 'Accepted contact must be verified or revalidated during this batch';
        END IF;
        v_url := 'https://www.linkedin.com/in/' ||
            regexp_replace(v_url, '^https://(www\.)?linkedin\.com/in/([^/]+)/?$', '\2') || '/';
        IF lower(v_url) = ANY(v_urls) OR v_name = ANY(v_names) THEN
            RAISE EXCEPTION 'Accepted contacts must be distinct people and profiles';
        END IF;
        v_urls := array_append(v_urls, lower(v_url));
        v_names := array_append(v_names, v_name);
    END LOOP;
    -- No minimum contact count; individual verification remains required.


    FOR person IN SELECT value FROM jsonb_array_elements(c.contact_research)
        WHERE value->>'accepted' = 'true'
    LOOP
        v_url := 'https://www.linkedin.com/in/' || regexp_replace(
            person->>'linkedin_url', '^https://(www\.)?linkedin\.com/in/([^/]+)/?$', '\2') || '/';
        SELECT * INTO existing FROM public.opportunity_contacts
        WHERE opportunity_id = v_opportunity_id AND (
            lower(rtrim(linkedin_url, '/')) = lower(rtrim(v_url, '/'))
            OR lower(regexp_replace(btrim(full_name), '[[:space:]]+', ' ', 'g')) =
               lower(regexp_replace(btrim(person->>'full_name'), '[[:space:]]+', ' ', 'g')))
        ORDER BY id LIMIT 1;
        IF FOUND THEN
            IF existing.company_id IS DISTINCT FROM c.company_id
               OR lower(rtrim(existing.linkedin_url, '/')) IS DISTINCT FROM lower(rtrim(v_url, '/'))
               OR lower(regexp_replace(btrim(existing.full_name), '[[:space:]]+', ' ', 'g')) IS DISTINCT FROM
                  lower(regexp_replace(btrim(person->>'full_name'), '[[:space:]]+', ' ', 'g'))
               OR existing.linkedin_url_verified IS DISTINCT FROM true
               OR existing.contact_status IS DISTINCT FROM 'valid' THEN
                RAISE EXCEPTION 'Existing contact requires identity reconciliation; no overwrite performed';
            END IF;
            v_contact_ids := v_contact_ids || jsonb_build_array(existing.id);
            CONTINUE;
        END IF;
        INSERT INTO public.opportunity_contacts(opportunity_id, company_id,
            full_name, title, linkedin_url, linkedin_url_verified, relevance_reason,
            priority, source_type, raw_result)
        VALUES (v_opportunity_id, c.company_id, btrim(person->>'full_name'),
            btrim(person->>'title'), v_url, true, person->>'relevance_reason',
            person->>'priority', person->>'source_type', person)
        RETURNING id INTO v_contact_id;
        v_inserted := v_inserted + 1;
        v_contact_ids := v_contact_ids || jsonb_build_array(v_contact_id);
    END LOOP;


    SELECT count(*) INTO v_count FROM public.opportunity_contacts
      WHERE opportunity_id=v_opportunity_id AND company_id=c.company_id
        AND linkedin_url_verified=true AND contact_status='valid';
    -- Zero is not proof of an exhausted search. Preserve status until actual research is recorded.
    IF v_count > 0 THEN
      UPDATE public.opportunities SET contact_status=CASE WHEN v_count>=3 THEN 'complete'
        ELSE 'incomplete_contacts_needed' END WHERE id=v_opportunity_id;
    END IF;
    PERFORM public.leadsignal_assert_worker(p_batch_id,p_worker_id,p_lease_token);
    RETURN jsonb_build_object('opportunity_id',v_opportunity_id,'inserted_contacts',v_inserted,
                             'contact_ids',v_contact_ids,'verified_contact_count',v_count);
END;
$_$;


--
-- Name: leadsignal_exact_url_guard_v1(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_exact_url_guard_v1() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF TG_OP='UPDATE' AND NEW.source_url IS NOT DISTINCT FROM OLD.source_url
    AND NEW.signal_key IS NOT DISTINCT FROM OLD.signal_key THEN RETURN NEW; END IF;
 IF NEW.source_url IS NULL OR NEW.source_url='' THEN RETURN NEW; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(jsonb_build_array(NEW.signal_key,NEW.source_url)::text,0));
 IF EXISTS(SELECT 1 FROM public.signals s WHERE s.signal_key=NEW.signal_key
    AND s.source_url=NEW.source_url AND s.id<>NEW.id) THEN
   RAISE EXCEPTION 'Duplicate: same source URL and signal'; END IF;
 RETURN NEW;
END;
$$;


--
-- Name: leadsignal_five_contacts_guard_v1(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_five_contacts_guard_v1() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF TG_OP='UPDATE' AND NEW.opportunity_id=OLD.opportunity_id THEN RETURN NEW; END IF;
 PERFORM id FROM public.opportunities WHERE id=NEW.opportunity_id FOR UPDATE;
 IF (SELECT count(*) FROM public.opportunity_contacts WHERE opportunity_id=NEW.opportunity_id)>=5 THEN
   RAISE EXCEPTION 'Maximum five linked contacts per opportunity'; END IF;
 RETURN NEW;
END;
$$;


--
-- Name: leadsignal_heartbeat_worker(uuid, uuid, uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_heartbeat_worker(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_lease_seconds integer DEFAULT 120) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE
    v_now timestamptz;
    v_until timestamptz;
BEGIN
    IF p_lease_seconds IS NULL OR p_lease_seconds < 30 OR p_lease_seconds > 300 THEN
        RAISE EXCEPTION 'Lease duration must be 30..300 seconds';
    END IF;
    PERFORM public.leadsignal_assert_worker(p_batch_id, p_worker_id, p_lease_token);
    v_now := clock_timestamp();
    UPDATE public.leadsignal_batches
        SET lease_expires_at = least(final_deadline,
            v_now + make_interval(secs => p_lease_seconds))
        WHERE id = p_batch_id RETURNING lease_expires_at INTO v_until;
    UPDATE public.leadsignal_workers SET heartbeat_at = v_now
        WHERE id = p_worker_id AND batch_id = p_batch_id;
    RETURN jsonb_build_object('worker_id', p_worker_id, 'lease_expires_at', v_until);
END;
$$;


--
-- Name: leadsignal_long_open_evidence_ok(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_long_open_evidence_ok(p_batch uuid, p_candidate uuid) RETURNS boolean
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
DECLARE
 b public.leadsignal_batches%ROWTYPE;
 c public.leadsignal_candidates%ROWTYPE;
 a public.leadsignal_research_attempts%ROWTYPE;
 proof jsonb; observation jsonb; original_date date; checked_date date; age integer;
BEGIN
 SELECT * INTO b FROM public.leadsignal_batches WHERE id=p_batch;
 IF NOT FOUND OR b.state<>'running' THEN RETURN false; END IF;
 SELECT * INTO c FROM public.leadsignal_candidates WHERE id=p_candidate AND batch_id=p_batch;
 IF NOT FOUND OR c.signal_key<>'tech_role_repost' OR c.company_id IS NULL THEN RETURN false; END IF;
 proof:=c.evidence->'long_open_proof';
 IF jsonb_typeof(proof) IS DISTINCT FROM 'object'
  OR proof->>'original_publication_verified' IS DISTINCT FROM 'true'
  OR proof->>'currently_open_verified' IS DISTINCT FROM 'true'
  OR proof->>'same_vacancy_verified' IS DISTINCT FROM 'true'
  OR proof->>'employer_company_id' IS DISTINCT FROM c.company_id::text
  OR nullif(btrim(proof->>'job_id'),'') IS NULL
  OR nullif(btrim(proof->>'verification_excerpt'),'') IS NULL
  OR proof->>'source_url' IS DISTINCT FROM c.event_data->>'source_url'
  OR coalesce(proof->>'source_url','') !~ '^https://[^[:space:]]+$'
  OR coalesce(proof->>'original_published_at','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  OR proof->>'original_published_at' IS DISTINCT FROM c.event_data->>'source_published_at'
 THEN RETURN false; END IF;
 original_date:=(proof->>'original_published_at')::date;
 IF nullif(c.event_data->>'event_date','') IS NOT NULL
   AND (c.event_data->>'event_date')::date<>original_date THEN RETURN false; END IF;
 SELECT * INTO a FROM public.leadsignal_research_attempts
 WHERE id=(proof->>'verification_attempt_id')::uuid AND batch_id=p_batch
 AND candidate_id=p_candidate AND signal_key='tech_role_repost'
 AND purpose='source_verification' AND state='succeeded';
 IF NOT FOUND OR a.finished_at IS NULL OR a.finished_at<b.started_at
 OR a.finished_at>clock_timestamp() OR a.source_url IS DISTINCT FROM proof->>'source_url'
 THEN RETURN false; END IF;
 age:=(b.icp_snapshot->>'max_source_age_days')::integer;
 checked_date:=(a.finished_at AT TIME ZONE 'Europe/Paris')::date;
 IF age IS NULL OR age<1 OR checked_date<(clock_timestamp() AT TIME ZONE 'Europe/Paris')::date-age
 OR checked_date-original_date<60 THEN RETURN false; END IF;
 observation:=a.result_summary->'job_observation';
 IF jsonb_typeof(observation) IS DISTINCT FROM 'object'
 OR observation->>'job_id' IS DISTINCT FROM proof->>'job_id'
 OR observation->>'employer_company_id' IS DISTINCT FROM c.company_id::text
 OR observation->>'original_published_at' IS DISTINCT FROM proof->>'original_published_at'
 OR observation->>'source_url' IS DISTINCT FROM proof->>'source_url'
 OR observation->>'original_publication_verified' IS DISTINCT FROM 'true'
 OR observation->>'currently_open_verified' IS DISTINCT FROM 'true'
 OR observation->>'same_vacancy_verified' IS DISTINCT FROM 'true'
 OR nullif(btrim(observation->>'excerpt'),'') IS NULL THEN RETURN false; END IF;
 RETURN true;
END;
$_$;


--
-- Name: leadsignal_monitoring_overview(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_monitoring_overview(p_icp_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    SET statement_timeout TO '10s'
    AS $$
DECLARE schedules jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_platform_member() THEN
    RAISE EXCEPTION 'Accès réservé aux membres actifs' USING ERRCODE='42501';
  END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'task_key',task_key,'observed_at',observed_at,'details',payload)
    ORDER BY task_key),'[]'::jsonb) INTO schedules
  FROM public.leadsignal_scheduler_status;
  RETURN jsonb_build_object('server_time',CURRENT_TIMESTAMP,
    'schedules',schedules);
END;
$$;


--
-- Name: leadsignal_primary_query_v2(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_primary_query_v2(p_signal text) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'pg_catalog'
    AS $_$
SELECT $json${"internal_tech_recruiter_hiring": {"keywords": "(\"technical recruiter\" OR \"tech recruiter\" OR \"IT recruiter\" OR \"technical sourcer\" OR \"recruteur IT\" OR \"recruteur tech\" OR \"recrutement IT\" OR \"recrutement informatique\" OR \"talent acquisition specialist\" OR \"talent acquisition manager\" OR \"talent acquisition partner\")", "location": "France", "page_number": 1, "sort": "recent", "limit": 25}, "tech_job_velocity_cluster": {"keywords": "(\"développeur\" OR \"développeuse\" OR \"developer\" OR \"software engineer\" OR \"ingénieur logiciel\" OR \"software architect\" OR \"architecte logiciel\" OR \"tech lead\" OR \"engineering manager\" OR \"CTO\" OR \"frontend\" OR \"backend\" OR \"fullstack\" OR \"full stack\" OR \"QA engineer\" OR \"test automation\" OR \"ingénieur test\" OR \"data engineer\" OR \"data scientist\" OR \"data analyst\" OR \"analytics engineer\" OR \"data architect\" OR \"architecte data\" OR \"business intelligence\" OR \"consultant BI\" OR \"machine learning engineer\" OR \"AI engineer\" OR \"ingénieur IA\" OR \"MLOps\" OR \"DevOps\" OR \"DevSecOps\" OR \"SRE\" OR \"cloud engineer\" OR \"cloud architect\" OR \"platform engineer\" OR \"ingénieur systèmes\" OR \"ingénieur réseaux\" OR \"administrateur systèmes\" OR \"cybersécurité\" OR \"cybersecurity\" OR \"security engineer\" OR \"analyste SOC\" OR \"RSSI\" OR \"technical product manager\" OR \"product owner\")", "location": "France", "page_number": 1, "sort": "relevant", "limit": 25}, "tech_role_repost": {"keywords": "(\"développeur\" OR \"développeuse\" OR \"developer\" OR \"software engineer\" OR \"ingénieur logiciel\" OR \"software architect\" OR \"architecte logiciel\" OR \"tech lead\" OR \"engineering manager\" OR \"CTO\" OR \"frontend\" OR \"backend\" OR \"fullstack\" OR \"full stack\" OR \"QA engineer\" OR \"test automation\" OR \"ingénieur test\" OR \"data engineer\" OR \"data scientist\" OR \"data analyst\" OR \"analytics engineer\" OR \"data architect\" OR \"architecte data\" OR \"business intelligence\" OR \"consultant BI\" OR \"machine learning engineer\" OR \"AI engineer\" OR \"ingénieur IA\" OR \"MLOps\" OR \"DevOps\" OR \"DevSecOps\" OR \"SRE\" OR \"cloud engineer\" OR \"cloud architect\" OR \"platform engineer\" OR \"ingénieur systèmes\" OR \"ingénieur réseaux\" OR \"administrateur systèmes\" OR \"cybersécurité\" OR \"cybersecurity\" OR \"security engineer\" OR \"analyste SOC\" OR \"RSSI\" OR \"technical product manager\" OR \"product owner\")", "location": "France", "page_number": 1, "sort": "recent", "limit": 25}}$json$::jsonb -> p_signal;
$_$;


--
-- Name: leadsignal_publish_candidate(uuid, uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_publish_candidate(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
DECLARE
    b public.leadsignal_batches%ROWTYPE;
    c public.leadsignal_candidates%ROWTYPE;
    e jsonb;
    person jsonb;
    v_signal_id uuid;
    v_opportunity_id uuid;
    v_contact_id uuid;
    v_contact_ids jsonb := '[]'::jsonb;
    v_urls text[] := ARRAY[]::text[];
    v_names text[] := ARRAY[]::text[];
    v_url text;
    v_name text;
    v_count integer;
    v_age integer;
    v_today date;
    v_published date;
    v_event date;
    v_checked timestamptz;
    v_reason text;
    v_diagnostic boolean := false;
BEGIN
    -- Serializes publications within the batch and rejects superseded workers.
    PERFORM public.leadsignal_assert_worker(p_batch_id, p_worker_id, p_lease_token);
    SELECT * INTO b FROM public.leadsignal_batches WHERE id = p_batch_id;
    SELECT * INTO c FROM public.leadsignal_candidates
        WHERE id = p_candidate_id AND batch_id = p_batch_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Candidate not found in this batch'; END IF;

    IF b.execution_config->>'client_rules' IS DISTINCT FROM 'client_rules_v2'
       OR b.execution_config->>'diagnostic_ignore_history'='true' THEN
        RAISE EXCEPTION 'Client rules require a new normal-mode batch';
    END IF;
    IF b.target_per_signal<>5 THEN RAISE EXCEPTION 'Client target must be five'; END IF;
    v_diagnostic := false;
    IF v_diagnostic AND (b.target_per_signal NOT IN (1,2)
       OR (b.icp_snapshot->>'max_source_age_days') IS DISTINCT FROM '90'
       OR c.candidate_key NOT LIKE ('mini-test:' || b.id::text || ':%')) THEN
        RAISE EXCEPTION 'Invalid isolated mini-test configuration or candidate key';
    END IF;
    -- Idempotent retry after a committed publication, while caller lease is valid.
    IF c.state = 'published' THEN
        RETURN jsonb_build_object('opportunity_id', c.opportunity_id,
            'created', false, 'candidate_id', c.id);
    END IF;
    IF c.state <> 'ready_for_validation' OR c.company_id IS NULL THEN
        RAISE EXCEPTION 'Candidate requires ready_for_validation and an existing company_id';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.companies WHERE id = c.company_id) THEN
        RAISE EXCEPTION 'Company not found';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(b.signal_snapshot) s
        WHERE s->>'signal_key' = c.signal_key AND s->>'active' = 'true') THEN
        RAISE EXCEPTION 'Signal is not selected in batch snapshot';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.agent_runs
        WHERE id = b.agent_run_id AND icp_id = b.icp_id AND status = 'running') THEN
        RAISE EXCEPTION 'Parent agent run is missing, mismatched, or not running';
    END IF;

    SELECT count(DISTINCT o.id) INTO v_count
    FROM public.leadsignal_candidates pc JOIN public.opportunities o ON o.id=pc.opportunity_id
    WHERE pc.batch_id=b.id AND pc.signal_key=c.signal_key
      AND pc.state='published' AND o.status IN ('new','review','qualified');
    IF c.signal_key NOT IN ('internal_tech_recruiter_hiring', 'tech_job_velocity_cluster', 'tech_role_repost') AND v_count >= b.target_per_signal THEN RAISE EXCEPTION 'Signal publication cap reached'; END IF;

    -- Recorded reviewer attestations, not independent proof of their truth.
    IF (c.evidence->>'icp_fit_verified' IS DISTINCT FROM 'true' AND NOT public.leadsignal_unknown_size_allowed(p_batch_id,p_candidate_id))
       OR c.evidence->>'signal_verified' IS DISTINCT FROM 'true'
       OR (NOT v_diagnostic AND c.evidence->>'deduplication_checked' IS DISTINCT FROM 'true')
       OR nullif(btrim(c.evidence->>'recruitment_rationale'), '') IS NULL
       OR nullif(btrim(c.evidence->>'deduplication_notes'), '') IS NULL THEN
        RAISE EXCEPTION 'Qualification and duplicate-check evidence required';
    END IF;

    e := c.event_data;
    IF nullif(btrim(e->>'title'), '') IS NULL
       OR nullif(btrim(e->>'signal_name'), '') IS NULL
       OR nullif(btrim(e->>'source_type'), '') IS NULL
       OR nullif(btrim(e->>'source_title'), '') IS NULL
       OR nullif(btrim(e->>'raw_excerpt'), '') IS NULL
       OR coalesce(e->>'source_url', '') !~ '^https?://[^[:space:]]+$' THEN
        RAISE EXCEPTION 'Required event/source fields are missing or invalid';
    END IF;
    IF coalesce(b.icp_snapshot->>'max_source_age_days', '') !~ '^[0-9]+$' THEN
        RAISE EXCEPTION 'Snapshot requires numeric max_source_age_days';
    END IF;
    v_age := (b.icp_snapshot->>'max_source_age_days')::integer;
    v_today := (clock_timestamp() AT TIME ZONE 'Europe/Paris')::date;
    IF coalesce(e->>'source_published_at', '') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
        RAISE EXCEPTION 'Source publication date is required';
    END IF;
    v_published := (e->>'source_published_at')::date;
    v_event := nullif(e->>'event_date', '')::date;
    IF v_published > v_today OR v_published < v_today - v_age
       OR (v_event IS NOT NULL AND (v_event > v_today OR v_event < v_today - v_age)) THEN
        IF NOT public.leadsignal_long_open_evidence_ok(b.id,c.id) THEN
            RAISE EXCEPTION 'Source or event date fails freshness checks';
        END IF;
    END IF; -- LONG_OPEN_EVIDENCE_V1
    -- A future project milestone belongs in evidence, not the triggering event date.

    v_reason := e->>'reason';
    IF v_reason IS NULL OR v_reason ~ '(\*\*|<[^>]*>|…|\.\.\.)'
       OR position(chr(92) || 'n' IN v_reason) > 0
       OR cardinality(string_to_array(v_reason, chr(10))) NOT BETWEEN 3 AND 5
       OR EXISTS (SELECT 1 FROM unnest(string_to_array(v_reason, chr(10))) line
                  WHERE line !~ '^- [^[:space:]]') THEN
        RAISE EXCEPTION 'Reason must contain 3..5 plain bullet lines beginning with dash-space';
    END IF;
    -- Publication without a numeric score; priority remains independently validated.
    IF coalesce(e->>'priority', '') NOT IN ('Low', 'Medium', 'High') THEN
        RAISE EXCEPTION 'Invalid priority';
    END IF;

    -- Mandatory qualification and duplicate preflight before publication.
    PERFORM public.leadsignal_qualify_candidate(p_batch_id,p_worker_id,p_lease_token,p_candidate_id);
    -- CONTACT_COUNT_OPTIONAL_V1
    IF jsonb_typeof(c.contact_research) IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION 'contact_research must be an array; use [] when empty';
    END IF;
    -- contact_research can also include pending people; publish accepted entries only.
    FOR person IN SELECT value FROM jsonb_array_elements(c.contact_research)
        WHERE value->>'accepted' = 'true'
    LOOP
        v_url := person->>'linkedin_url';
        v_name := lower(regexp_replace(btrim(person->>'full_name'), '[[:space:]]+', ' ', 'g'));
        IF v_url IS NULL OR v_url !~ '^https://(www\.)?linkedin\.com/in/[^/?#[:space:]]+/?$'
           OR person->>'linkedin_url_verified' IS DISTINCT FROM 'true'
           OR person->>'company_association_verified' IS DISTINCT FROM 'true'
           OR person->>'company_id' IS DISTINCT FROM c.company_id::text
           OR v_name IS NULL OR v_name !~ '^[^[:space:]]+ [^[:space:]].*$'
           OR v_name ~ '(https?://|"|[[:cntrl:]])'
           OR nullif(btrim(person->>'title'), '') IS NULL
           OR coalesce(person->>'title', '') ~* 'https?://'
           OR nullif(btrim(person->>'relevance_reason'), '') IS NULL
           OR coalesce(person->>'priority', '') NOT IN ('Low', 'Medium', 'High')
           OR nullif(btrim(person->>'source_type'), '') IS NULL
           OR nullif(btrim(person->>'verification_method'), '') IS NULL
           OR coalesce(person->>'verification_source_url', '') !~ '^https?://[^[:space:]]+$'
           OR nullif(btrim(person->>'verification_notes'), '') IS NULL THEN
            RAISE EXCEPTION 'An accepted contact has incomplete identity/profile/evidence fields';
        END IF;
        -- CONTACT_TIMESTAMP_V2: a calendar date is not a verification timestamp.
        IF coalesce(person->>'verified_at', '') !~
           '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$' THEN
            RAISE EXCEPTION 'verified_at requires full ISO timestamp with timezone from actual verification; date-only is invalid';
        END IF;
        PERFORM public.leadsignal_assert_perplexity_contact(b.id,c.id,person);
        v_checked := nullif(person->>'verified_at', '')::timestamptz;
        IF v_checked IS NULL OR v_checked < b.started_at OR v_checked > clock_timestamp() THEN
            RAISE EXCEPTION 'Accepted contact must be verified or revalidated during this batch';
        END IF;
        v_url := 'https://www.linkedin.com/in/' ||
            regexp_replace(v_url, '^https://(www\.)?linkedin\.com/in/([^/]+)/?$', '\2') || '/';
        IF lower(v_url) = ANY(v_urls) OR v_name = ANY(v_names) THEN
            RAISE EXCEPTION 'Accepted contacts must be distinct people and profiles';
        END IF;
        v_urls := array_append(v_urls, lower(v_url));
        v_names := array_append(v_names, v_name);
    END LOOP;
    -- No minimum contact count; individual verification remains required.


    PERFORM public.leadsignal_assert_event_v2(c.id);

    -- Recheck after potentially waiting for the cross-batch event lock.
    PERFORM public.leadsignal_assert_worker(p_batch_id, p_worker_id, p_lease_token);
    INSERT INTO public.signals(company_id, agent_run_id, signal_key, signal_name,
        source_type, source_url, source_title, source_published_at, event_date,
        raw_excerpt, metadata_json, dedupe_key)
    VALUES (c.company_id, b.agent_run_id, c.signal_key, e->>'signal_name',
        e->>'source_type', e->>'source_url', e->>'source_title', v_published,
        v_event, e->>'raw_excerpt', c.evidence || jsonb_build_object(
            'batch_id', b.id, 'candidate_id', c.id,
            'diagnostic_ignore_history',v_diagnostic), c.candidate_key)
    RETURNING id INTO v_signal_id;

    INSERT INTO public.opportunities(company_id, primary_signal_id, title, score,
        priority, reason, status, source_urls, contact_status, dedupe_key, event_date)
    VALUES (c.company_id, v_signal_id, CASE WHEN v_diagnostic THEN '[MINI-TEST] ' ELSE '' END || (e->>'title'), NULL,
        e->>'priority', v_reason, 'new', ARRAY[e->>'source_url'],
        CASE
            WHEN cardinality(v_urls) = 0
                THEN 'no_verified_people_found'
            WHEN cardinality(v_urls) < 3
                THEN 'incomplete_contacts_needed'
            ELSE 'complete'
        END, c.candidate_key, v_event)
    RETURNING id INTO v_opportunity_id;

    FOR person IN SELECT value FROM jsonb_array_elements(c.contact_research)
        WHERE value->>'accepted' = 'true'
    LOOP
        v_url := 'https://www.linkedin.com/in/' || regexp_replace(
            person->>'linkedin_url', '^https://(www\.)?linkedin\.com/in/([^/]+)/?$', '\2') || '/';
        INSERT INTO public.opportunity_contacts(opportunity_id, company_id,
            full_name, title, linkedin_url, linkedin_url_verified, relevance_reason,
            priority, source_type, raw_result)
        VALUES (v_opportunity_id, c.company_id, btrim(person->>'full_name'),
            btrim(person->>'title'), v_url, true, person->>'relevance_reason',
            person->>'priority', person->>'source_type', person)
        RETURNING id INTO v_contact_id;
        v_contact_ids := v_contact_ids || jsonb_build_array(v_contact_id);
    END LOOP;

    UPDATE public.leadsignal_candidates SET state = 'published',
        opportunity_id = v_opportunity_id, next_action = NULL WHERE id = c.id;
    UPDATE public.agent_runs SET new_opportunities_count = (
        SELECT count(DISTINCT o.id) FROM public.leadsignal_candidates pc
        JOIN public.opportunities o ON o.id=pc.opportunity_id
        WHERE pc.batch_id=b.id AND pc.state='published' AND o.status IN ('new','review','qualified')),
        logs_json = logs_json || jsonb_build_object('batch_id', b.id,
            'last_published_candidate_id', c.id, 'last_published_opportunity_id', v_opportunity_id)
        WHERE id = b.agent_run_id;

    -- Failure here rolls back the entire publication, including all contacts.
    PERFORM public.leadsignal_assert_worker(p_batch_id, p_worker_id, p_lease_token);
    RETURN jsonb_build_object('created', true, 'candidate_id', c.id,
        'opportunity_id', v_opportunity_id, 'signal_id', v_signal_id,
        'contact_ids', v_contact_ids);
END;
$_$;


--
-- Name: leadsignal_qualify_candidate(uuid, uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_qualify_candidate(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
DECLARE
    b public.leadsignal_batches%ROWTYPE;
    c public.leadsignal_candidates%ROWTYPE;
    e jsonb;
    person jsonb;
    v_signal_id uuid;
    v_opportunity_id uuid;
    v_contact_id uuid;
    v_contact_ids jsonb := '[]'::jsonb;
    v_urls text[] := ARRAY[]::text[];
    v_names text[] := ARRAY[]::text[];
    v_url text;
    v_name text;
    v_count integer;
    v_age integer;
    v_today date;
    v_published date;
    v_event date;
    v_checked timestamptz;
    v_reason text;
    v_diagnostic boolean := false;
BEGIN
    -- Serializes publications within the batch and rejects superseded workers.
    PERFORM public.leadsignal_assert_worker(p_batch_id, p_worker_id, p_lease_token);
    SELECT * INTO b FROM public.leadsignal_batches WHERE id = p_batch_id;
    SELECT * INTO c FROM public.leadsignal_candidates
        WHERE id = p_candidate_id AND batch_id = p_batch_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Candidate not found in this batch'; END IF;

    IF b.execution_config->>'client_rules' IS DISTINCT FROM 'client_rules_v2'
       OR b.execution_config->>'diagnostic_ignore_history'='true' THEN
        RAISE EXCEPTION 'Client rules require a new normal-mode batch';
    END IF;
    IF b.target_per_signal<>5 THEN RAISE EXCEPTION 'Client target must be five'; END IF;
    v_diagnostic := false;
    IF v_diagnostic AND (b.target_per_signal NOT IN (1,2)
       OR (b.icp_snapshot->>'max_source_age_days') IS DISTINCT FROM '90'
       OR c.candidate_key NOT LIKE ('mini-test:' || b.id::text || ':%')) THEN
        RAISE EXCEPTION 'Invalid isolated mini-test configuration or candidate key';
    END IF;
    -- Idempotent retry after a committed publication, while caller lease is valid.
    IF c.state='published' THEN
        RETURN jsonb_build_object('qualified',true,'new_qualification',false,'opportunity_id',c.opportunity_id);
    END IF;
    IF c.state <> 'ready_for_validation' OR c.company_id IS NULL THEN
        RAISE EXCEPTION 'Candidate requires ready_for_validation and an existing company_id';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.companies WHERE id = c.company_id) THEN
        RAISE EXCEPTION 'Company not found';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(b.signal_snapshot) s
        WHERE s->>'signal_key' = c.signal_key AND s->>'active' = 'true') THEN
        RAISE EXCEPTION 'Signal is not selected in batch snapshot';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.agent_runs
        WHERE id = b.agent_run_id AND icp_id = b.icp_id AND status = 'running') THEN
        RAISE EXCEPTION 'Parent agent run is missing, mismatched, or not running';
    END IF;

    SELECT count(DISTINCT o.id) INTO v_count
    FROM public.leadsignal_candidates pc JOIN public.opportunities o ON o.id=pc.opportunity_id
    WHERE pc.batch_id=b.id AND pc.signal_key=c.signal_key
      AND pc.state='published' AND o.status IN ('new','review','qualified');
    IF c.signal_key NOT IN ('internal_tech_recruiter_hiring', 'tech_job_velocity_cluster', 'tech_role_repost') AND v_count >= b.target_per_signal THEN RAISE EXCEPTION 'Signal publication cap reached'; END IF;

    -- Recorded reviewer attestations, not independent proof of their truth.
    IF (c.evidence->>'icp_fit_verified' IS DISTINCT FROM 'true' AND NOT public.leadsignal_unknown_size_allowed(p_batch_id,p_candidate_id))
       OR c.evidence->>'signal_verified' IS DISTINCT FROM 'true'
       OR (NOT v_diagnostic AND c.evidence->>'deduplication_checked' IS DISTINCT FROM 'true')
       OR nullif(btrim(c.evidence->>'recruitment_rationale'), '') IS NULL
       OR nullif(btrim(c.evidence->>'deduplication_notes'), '') IS NULL THEN
        RAISE EXCEPTION 'Qualification and duplicate-check evidence required';
    END IF;

    e := c.event_data;
    IF nullif(btrim(e->>'title'), '') IS NULL
       OR nullif(btrim(e->>'signal_name'), '') IS NULL
       OR nullif(btrim(e->>'source_type'), '') IS NULL
       OR nullif(btrim(e->>'source_title'), '') IS NULL
       OR nullif(btrim(e->>'raw_excerpt'), '') IS NULL
       OR coalesce(e->>'source_url', '') !~ '^https?://[^[:space:]]+$' THEN
        RAISE EXCEPTION 'Required event/source fields are missing or invalid';
    END IF;
    IF coalesce(b.icp_snapshot->>'max_source_age_days', '') !~ '^[0-9]+$' THEN
        RAISE EXCEPTION 'Snapshot requires numeric max_source_age_days';
    END IF;
    v_age := (b.icp_snapshot->>'max_source_age_days')::integer;
    v_today := (clock_timestamp() AT TIME ZONE 'Europe/Paris')::date;
    IF coalesce(e->>'source_published_at', '') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
        RAISE EXCEPTION 'Source publication date is required';
    END IF;
    v_published := (e->>'source_published_at')::date;
    v_event := nullif(e->>'event_date', '')::date;
    IF v_published > v_today OR v_published < v_today - v_age
       OR (v_event IS NOT NULL AND (v_event > v_today OR v_event < v_today - v_age)) THEN
        IF NOT public.leadsignal_long_open_evidence_ok(b.id,c.id) THEN
            RAISE EXCEPTION 'Source or event date fails freshness checks';
        END IF;
    END IF; -- LONG_OPEN_EVIDENCE_V1
    -- A future project milestone belongs in evidence, not the triggering event date.

    v_reason := e->>'reason';
    IF v_reason IS NULL OR v_reason ~ '(\*\*|<[^>]*>|…|\.\.\.)'
       OR position(chr(92) || 'n' IN v_reason) > 0
       OR cardinality(string_to_array(v_reason, chr(10))) NOT BETWEEN 3 AND 5
       OR EXISTS (SELECT 1 FROM unnest(string_to_array(v_reason, chr(10))) line
                  WHERE line !~ '^- [^[:space:]]') THEN
        RAISE EXCEPTION 'Reason must contain 3..5 plain bullet lines beginning with dash-space';
    END IF;
    -- Publication without a numeric score; priority remains independently validated.
    IF coalesce(e->>'priority', '') NOT IN ('Low', 'Medium', 'High') THEN
        RAISE EXCEPTION 'Invalid priority';
    END IF;

    PERFORM public.leadsignal_assert_event_v2(c.id);

    -- Only one milestone per candidate and URL+signal in a batch. No replay reset.
    IF EXISTS (SELECT 1 FROM public.leadsignal_qualifications_v1 q
        WHERE q.candidate_id=c.id AND (q.source_url IS DISTINCT FROM e->>'source_url'
          OR q.signal_key IS DISTINCT FROM c.signal_key)) THEN
        RAISE EXCEPTION 'Qualification identity changed: create a distinct candidate';
    END IF;
    IF EXISTS (SELECT 1 FROM public.leadsignal_qualifications_v1 q
        WHERE q.candidate_id=c.id) THEN
        RETURN jsonb_build_object('qualified',true,'new_qualification',false,'candidate_id',c.id);
    END IF;
    INSERT INTO public.leadsignal_qualifications_v1(candidate_id,batch_id,signal_key,source_url)
        VALUES(c.id,b.id,c.signal_key,e->>'source_url');
    RETURN jsonb_build_object('qualified',true,'new_qualification',true,'candidate_id',c.id);
END;
$_$;


--
-- Name: leadsignal_record_attempt(uuid, uuid, text, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_record_attempt(p_batch_id uuid, p_lease_token uuid, p_attempt_key text, p_action text, p_details jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE
    b public.leadsignal_batches%ROWTYPE;
    a public.leadsignal_research_attempts%ROWTYPE;
BEGIN
    SELECT * INTO b FROM public.leadsignal_batches WHERE id = p_batch_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Batch not found'; END IF;
    PERFORM public.leadsignal_assert_worker(p_batch_id, b.lease_worker_id, p_lease_token);
    IF p_action='start' AND b.execution_config->>'contact_provider'='perplexity_only'
       AND p_details->>'purpose' IN ('contact_discovery','linkedin_verification')
       AND p_details->>'provider' IS DISTINCT FROM 'perplexity' THEN
        RAISE EXCEPTION 'Contacts must use Perplexity only in this batch';
    END IF; -- PERPLEXITY_ONLY_V1
    IF p_attempt_key IS NULL OR btrim(p_attempt_key) = ''
       OR p_action IS NULL OR p_action NOT IN ('start','succeeded','failed','interrupted')
       OR p_details IS NULL OR jsonb_typeof(p_details) <> 'object' THEN
        RAISE EXCEPTION 'Invalid attempt request';
    END IF;
    IF p_details ?| ARRAY['worker_id','started_at','finished_at','batch_id','id','state'] THEN
        RAISE EXCEPTION 'Identity, state and timestamps are supplied by the database';
    END IF;
    SELECT * INTO a FROM public.leadsignal_research_attempts
        WHERE batch_id = p_batch_id AND attempt_key = p_attempt_key;
    IF FOUND THEN
        IF a.worker_id IS DISTINCT FROM b.lease_worker_id THEN
            RAISE EXCEPTION 'Attempt belongs to a different worker';
        END IF;
        IF p_action = 'start' THEN RETURN to_jsonb(a); END IF;
        IF a.state <> 'started' THEN
            IF a.state = p_action THEN RETURN to_jsonb(a); END IF;
            RAISE EXCEPTION 'Attempt already finished with another outcome';
        END IF;
        UPDATE public.leadsignal_research_attempts SET
            state = p_action, finished_at = clock_timestamp(),
            result_summary = coalesce(p_details->'result_summary','{}'::jsonb),
            error_message = p_details->>'error_message',
            cost_usd = (p_details->>'cost_usd')::numeric,
            cost_is_estimate = coalesce((p_details->>'cost_is_estimate')::boolean, true)
        WHERE id = a.id RETURNING * INTO a;
    ELSE
        IF p_action <> 'start' THEN RAISE EXCEPTION 'Start attempt before making the request'; END IF;
        IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(b.signal_snapshot) AS s
                       WHERE s->>'signal_key' = p_details->>'signal_key') THEN
            RAISE EXCEPTION 'Signal is not selected in this batch';
        END IF;
        INSERT INTO public.leadsignal_research_attempts
            (batch_id,worker_id,attempt_key,candidate_id,signal_key,purpose,
             provider,query_text,source_url,state,started_at)
        VALUES (p_batch_id,b.lease_worker_id,p_attempt_key,(p_details->>'candidate_id')::uuid,
            p_details->>'signal_key',p_details->>'purpose',p_details->>'provider',
            p_details->>'query_text',p_details->>'source_url','started',clock_timestamp())
        RETURNING * INTO a;
    END IF;
    RETURN to_jsonb(a);
END;
$$;


--
-- Name: leadsignal_release_worker(uuid, uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_release_worker(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_outcome text, p_checkpoint jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
    IF p_outcome IS NULL OR p_outcome NOT IN ('yielded', 'completed', 'failed') THEN
        RAISE EXCEPTION 'Invalid worker outcome';
    END IF;
    IF p_checkpoint IS NULL OR jsonb_typeof(p_checkpoint) <> 'object' THEN
        RAISE EXCEPTION 'Checkpoint must be a JSON object';
    END IF;
    PERFORM public.leadsignal_assert_worker(p_batch_id, p_worker_id, p_lease_token);
    UPDATE public.leadsignal_workers
        SET state = p_outcome, finished_at = clock_timestamp(),
            checkpoint = checkpoint || p_checkpoint
        WHERE id = p_worker_id AND batch_id = p_batch_id;
    UPDATE public.leadsignal_batches
        SET lease_worker_id = NULL, lease_token = NULL, lease_expires_at = NULL
        WHERE id = p_batch_id;
    RETURN jsonb_build_object('worker_id', p_worker_id, 'state', p_outcome,
        'batch_finalized', false);
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: leadsignal_apify_lots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leadsignal_apify_lots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    batch_id uuid NOT NULL,
    signal_key text NOT NULL,
    page_number integer NOT NULL,
    request_input jsonb NOT NULL,
    state text DEFAULT 'reserved'::text NOT NULL,
    run_id text,
    dataset_id text,
    raw_results jsonb DEFAULT '[]'::jsonb NOT NULL,
    metrics jsonb DEFAULT '{}'::jsonb NOT NULL,
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    qualification_completed_at timestamp with time zone,
    qualification_report jsonb,
    CONSTRAINT leadsignal_apify_lots_page_number_check CHECK (((page_number >= 1) AND (page_number <= 5))),
    CONSTRAINT leadsignal_apify_lots_raw_results_check CHECK (((jsonb_typeof(raw_results) = 'array'::text) AND (jsonb_array_length(raw_results) <= 25))),
    CONSTRAINT leadsignal_apify_lots_request_input_check CHECK (((request_input ->> 'limit'::text) = '25'::text)),
    CONSTRAINT leadsignal_apify_lots_signal_key_check CHECK ((signal_key = ANY (ARRAY['internal_tech_recruiter_hiring'::text, 'tech_job_velocity_cluster'::text, 'tech_role_repost'::text]))),
    CONSTRAINT leadsignal_apify_lots_state_check CHECK ((state = ANY (ARRAY['reserved'::text, 'running'::text, 'succeeded'::text, 'failed'::text, 'unknown'::text])))
);


--
-- Name: leadsignal_reserve_apify_lot(uuid, uuid, uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_reserve_apify_lot(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_signal_key text, p_input jsonb) RETURNS public.leadsignal_apify_lots
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE b public.leadsignal_batches; r public.leadsignal_apify_lots; n integer; matches integer;
BEGIN
  PERFORM public.leadsignal_assert_worker(p_batch_id,p_worker_id,p_lease_token);
  SELECT * INTO STRICT b FROM public.leadsignal_batches WHERE id=p_batch_id FOR UPDATE;
  IF b.execution_config->>'controller' NOT IN ('apify_manual_v1','leadsignal_runner_4h_v1') OR b.execution_config->>'controller' IS NULL THEN
    RAISE EXCEPTION 'Manual Apify batch required';
  END IF;
  IF b.research_deadline IS NULL OR clock_timestamp() >= b.research_deadline THEN
    RAISE EXCEPTION 'Research deadline reached; finish existing work only';
  END IF;
  IF p_signal_key IS NULL OR p_signal_key NOT IN ('internal_tech_recruiter_hiring','tech_job_velocity_cluster','tech_role_repost') THEN
    RAISE EXCEPTION 'Unsupported signal';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(b.signal_snapshot) s
    WHERE s->>'signal_key'=p_signal_key AND s->>'active'='true') THEN
    RAISE EXCEPTION 'Signal not active in snapshot';
  END IF;
  SELECT count(*) INTO n FROM public.leadsignal_apify_lots WHERE batch_id=p_batch_id AND signal_key=p_signal_key;
  IF n>=4 THEN RAISE EXCEPTION 'Four primary calls already reserved'; END IF;
  IF EXISTS (SELECT 1 FROM public.leadsignal_apify_lots WHERE batch_id=p_batch_id AND signal_key=p_signal_key AND state IN ('reserved','running','unknown')) THEN
    RAISE EXCEPTION 'Resolve the previous call before reserving another';
  END IF;
  SELECT count(DISTINCT o.id) INTO matches FROM public.leadsignal_candidates c
    JOIN public.opportunities o ON o.id=c.opportunity_id
    WHERE c.batch_id=p_batch_id AND c.signal_key=p_signal_key AND c.state='published'
      AND o.status IN ('new','review','qualified');
  IF matches>=5 THEN RAISE EXCEPTION 'Five published: finish existing lots and company follow-ups'; END IF;
  IF p_input IS DISTINCT FROM (public.leadsignal_primary_query_v2(p_signal_key) || jsonb_build_object('page_number',n+1)) THEN
    RAISE EXCEPTION 'Primary query must match the approved catalog exactly';
  END IF;
  IF p_input IS NULL OR p_input->>'limit' IS DISTINCT FROM '25'
    OR p_input->>'page_number' IS DISTINCT FROM (n+1)::text
    OR p_input->>'location' IS DISTINCT FROM 'France'
    OR p_input->>'sort' IS DISTINCT FROM (CASE WHEN p_signal_key='tech_job_velocity_cluster' THEN 'relevant' ELSE 'recent' END)
    OR nullif(trim(p_input->>'keywords'),'') IS NULL THEN
    RAISE EXCEPTION 'Expected France, limit 25, next page and configured sort';
  END IF;
  INSERT INTO public.leadsignal_apify_lots(batch_id,signal_key,page_number,request_input)
    VALUES(p_batch_id,p_signal_key,n+1,p_input) RETURNING * INTO r;
  RETURN r;
END $$;


--
-- Name: leadsignal_cluster_company_calls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leadsignal_cluster_company_calls (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    batch_id uuid NOT NULL,
    worker_id uuid NOT NULL,
    linkedin_company_id text NOT NULL,
    search_scope text NOT NULL,
    page_number integer NOT NULL,
    request_input jsonb NOT NULL,
    state text DEFAULT 'reserved'::text NOT NULL,
    run_id text,
    dataset_id text,
    raw_results jsonb DEFAULT '[]'::jsonb NOT NULL,
    qualification_report jsonb,
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    CONSTRAINT leadsignal_cluster_company_calls_linkedin_company_id_check CHECK ((linkedin_company_id ~ '^[0-9]+$'::text)),
    CONSTRAINT leadsignal_cluster_company_calls_page_number_check CHECK (((page_number >= 1) AND (page_number <= 3))),
    CONSTRAINT leadsignal_cluster_company_calls_raw_results_check CHECK (((jsonb_typeof(raw_results) = 'array'::text) AND (jsonb_array_length(raw_results) <= 10))),
    CONSTRAINT leadsignal_cluster_company_calls_search_scope_check CHECK ((search_scope = ANY (ARRAY['month'::text, 'full_window'::text]))),
    CONSTRAINT leadsignal_cluster_company_calls_state_check CHECK ((state = ANY (ARRAY['reserved'::text, 'running'::text, 'succeeded'::text, 'failed'::text, 'unknown'::text])))
);


--
-- Name: leadsignal_reserve_cluster_company_call(uuid, uuid, uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_reserve_cluster_company_call(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_input jsonb) RETURNS public.leadsignal_cluster_company_calls
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
DECLARE
  b public.leadsignal_batches;
  r public.leadsignal_cluster_company_calls;
  v_company text := p_input->>'company_id';
  v_scope text := CASE WHEN p_input ? 'date_posted' THEN 'month' ELSE 'full_window' END;
  v_page integer;
  v_max_page integer;
BEGIN
  PERFORM public.leadsignal_assert_worker(p_batch_id,p_worker_id,p_lease_token);
  SELECT * INTO STRICT b FROM public.leadsignal_batches WHERE id=p_batch_id FOR UPDATE;
  IF b.research_deadline IS NULL OR clock_timestamp()>=b.research_deadline THEN
    RAISE EXCEPTION 'Research deadline reached';
  END IF;
  IF p_input IS NULL OR v_company IS NULL OR v_company !~ '^[0-9]+$'
    OR p_input->>'keywords' IS DISTINCT FROM ''
    OR p_input->>'location' IS DISTINCT FROM 'France'
    OR p_input->>'sort' IS DISTINCT FROM 'recent'
    OR p_input->>'limit' IS DISTINCT FROM '10'
    OR (p_input ? 'date_posted' AND p_input->>'date_posted' IS DISTINCT FROM 'month')
    OR coalesce(p_input->>'page_number','') !~ '^[1-3]$'
    OR EXISTS (SELECT 1 FROM jsonb_object_keys(p_input) AS k(key)
               WHERE k.key NOT IN ('company_id','keywords','location','sort','date_posted','page_number','limit'))
  THEN RAISE EXCEPTION 'Invalid cluster company input'; END IF;
  v_page := (p_input->>'page_number')::integer;
  -- Discovery must have found this exact LinkedIn employer, and its job must
  -- have an ICP-pass decision. No client-advertiser substitution is allowed.
  IF NOT EXISTS (
    SELECT 1 FROM public.leadsignal_apify_decisions d
    JOIN public.leadsignal_apify_lots l ON l.id=d.source_lot_id
    JOIN public.leadsignal_batches source_batch ON source_batch.id=l.batch_id
    CROSS JOIN LATERAL jsonb_array_elements(l.raw_results) AS j(job)
    WHERE d.batch_id=p_batch_id
      AND d.signal_key='tech_job_velocity_cluster'
      AND d.icp_decision='pass'
      AND l.signal_key='tech_job_velocity_cluster'
      AND source_batch.icp_id=b.icp_id
      AND (d.canonical_job_key = (j.job->>'job_id')
      OR d.canonical_job_key = ('li:' || (j.job->>'job_id')))
      AND j.job->>'company_urn'=v_company
  ) THEN RAISE EXCEPTION 'No ICP-pass discovery row for this LinkedIn company ID'; END IF;
  IF EXISTS (SELECT 1 FROM public.leadsignal_cluster_company_calls
             WHERE batch_id=p_batch_id AND linkedin_company_id=v_company
               AND state IN ('reserved','running','unknown'))
  THEN RAISE EXCEPTION 'Reconcile the prior company call before reserving another'; END IF;
  SELECT coalesce(max(page_number),0) INTO v_max_page
    FROM public.leadsignal_cluster_company_calls
   WHERE batch_id=p_batch_id AND linkedin_company_id=v_company AND search_scope=v_scope;
  IF v_page<>v_max_page+1 OR v_page>3 THEN
    RAISE EXCEPTION 'Expected next page within company scope (maximum 3)'; END IF;
  IF v_scope='full_window' AND NOT EXISTS (
    SELECT 1 FROM public.leadsignal_cluster_company_calls
     WHERE batch_id=p_batch_id AND linkedin_company_id=v_company
       AND search_scope='month' AND qualification_report IS NOT NULL
  ) THEN RAISE EXCEPTION 'Qualify month results before full-window fallback'; END IF;
  INSERT INTO public.leadsignal_cluster_company_calls
    (batch_id,worker_id,linkedin_company_id,search_scope,page_number,request_input)
    VALUES (p_batch_id,p_worker_id,v_company,v_scope,v_page,p_input)
    RETURNING * INTO r;
  RETURN r;
END $_$;


--
-- Name: leadsignal_reuse_company_contacts_v2(uuid, uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_reuse_company_contacts_v2(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
DECLARE c public.leadsignal_candidates; b public.leadsignal_batches;
 s public.opportunity_contacts; n int; total_links int; added int:=0; age_days int;
BEGIN
 PERFORM public.leadsignal_assert_worker(p_batch_id,p_worker_id,p_lease_token);
 SELECT * INTO STRICT c FROM public.leadsignal_candidates WHERE id=p_candidate_id AND batch_id=p_batch_id FOR UPDATE;
 SELECT * INTO STRICT b FROM public.leadsignal_batches WHERE id=p_batch_id;
 IF c.state<>'published' OR c.opportunity_id IS NULL THEN RAISE EXCEPTION 'Published candidate required'; END IF;
 PERFORM 1 FROM public.opportunities WHERE id=c.opportunity_id AND company_id=c.company_id
 AND status IN ('new','review','qualified') FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Retained same-company opportunity required'; END IF;
 age_days:=coalesce((b.icp_snapshot->>'max_source_age_days')::int,60);
 SELECT count(*) INTO total_links FROM public.opportunity_contacts WHERE opportunity_id=c.opportunity_id;
 SELECT count(DISTINCT lower(rtrim(linkedin_url,'/'))) INTO n FROM public.opportunity_contacts
 WHERE opportunity_id=c.opportunity_id AND linkedin_url_verified IS TRUE AND contact_status='valid';
 FOR s IN SELECT * FROM public.opportunity_contacts
 WHERE company_id=c.company_id AND opportunity_id<>c.opportunity_id
 AND linkedin_url_verified IS TRUE AND contact_status='valid'
 AND raw_result->>'company_association_verified'='true'
 AND raw_result->>'company_id'=c.company_id::text
 AND nullif(raw_result->>'verification_source_url','') IS NOT NULL
 AND nullif(raw_result->>'verification_notes','') IS NOT NULL
 ORDER BY updated_at DESC,id LOOP
   EXIT WHEN n>=2 OR total_links>=5;
   -- Reuse actual recent evidence, never manufacture a new verification timestamp.
   BEGIN
     IF (s.raw_result->>'verified_at')::timestamptz IS NULL
       OR (s.raw_result->>'verified_at')::timestamptz < now()-make_interval(days=>age_days)
       OR (s.raw_result->>'verified_at')::timestamptz > now() THEN CONTINUE; END IF;
   EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN CONTINUE;
   END;
   IF s.linkedin_url !~ '^https://(www\.)?linkedin\.com/in/[^/?#[:space:]]+/?$' THEN CONTINUE; END IF;
   IF EXISTS(SELECT 1 FROM public.opportunity_contacts t WHERE t.opportunity_id=c.opportunity_id
     AND (lower(rtrim(t.linkedin_url,'/'))=lower(rtrim(s.linkedin_url,'/'))
       OR lower(btrim(t.full_name))=lower(btrim(s.full_name)))) THEN CONTINUE; END IF;
   INSERT INTO public.opportunity_contacts(opportunity_id,company_id,full_name,title,linkedin_url,
    linkedin_url_verified,relevance_reason,priority,source_type,raw_result,contact_status,phone,enrichment_status)
   VALUES(c.opportunity_id,c.company_id,s.full_name,s.title,s.linkedin_url,true,s.relevance_reason,
    s.priority,s.source_type,s.raw_result||jsonb_build_object('reused_from_contact_id',s.id,'reused_at',now()),
    s.contact_status,s.phone,s.enrichment_status);
   n:=n+1;added:=added+1;total_links:=total_links+1;
 END LOOP;
 UPDATE public.leadsignal_candidates SET evidence=jsonb_set(coalesce(evidence,'{}'),'{contact_reuse_v2}',
   jsonb_build_object('checked_at',now(),'linked_count',n,'inserted',added,'company_id',c.company_id)),updated_at=now()
 WHERE id=c.id;
 RETURN jsonb_build_object('inserted',added,'linked_count',n,'perplexity_needed',n<2,
  'nomination_exception',c.signal_key='leader_tech_data_nomination');
END;
$_$;


--
-- Name: leadsignal_runner_4h_policy_version(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_runner_4h_policy_version() RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT jsonb_build_object('version','runner_4h_v1', 'unknown_size_installed',
    position('leadsignal_unknown_size_allowed' IN pg_get_functiondef(
        'public.leadsignal_publish_candidate(uuid,uuid,uuid,uuid)'::regprocedure)) > 0)
$$;


--
-- Name: leadsignal_unknown_size_allowed(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_unknown_size_allowed(p_batch uuid, p_candidate uuid) RETURNS boolean
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
    SELECT coalesce(bool_or(
        b.execution_config->>'allow_unknown_company_size' = 'true'
        AND c.evidence->>'other_icp_criteria_verified' = 'true'
        AND c.evidence->>'size_status' = 'unknown'
        AND c.evidence->>'known_size_outside_icp' = 'false'
        AND c.company_data->>'employee_count' IS NULL
        AND co.employee_count IS NULL
        AND nullif(btrim(c.evidence->>'size_unknown_reason'), '') IS NOT NULL
        AND c.event_data->>'reason' LIKE '%Taille inconnue%'
    ), false)
    FROM public.leadsignal_candidates c
    JOIN public.leadsignal_batches b ON b.id = c.batch_id
    JOIN public.companies co ON co.id = c.company_id
    WHERE c.id = p_candidate AND c.batch_id = p_batch
$$;


--
-- Name: leadsignal_v3_finish_apify_lot(uuid, uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_v3_finish_apify_lot(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_lot_id uuid) RETURNS public.leadsignal_apify_lots
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE r public.leadsignal_apify_lots; report jsonb;
BEGIN
 PERFORM public.leadsignal_assert_worker(p_batch_id,p_worker_id,p_lease_token);
 SELECT * INTO STRICT r FROM public.leadsignal_apify_lots WHERE id=p_lot_id AND batch_id=p_batch_id FOR UPDATE;
 IF r.qualification_completed_at IS NOT NULL THEN RETURN r; END IF;
 IF r.state NOT IN ('succeeded','failed') THEN RAISE EXCEPTION 'Resolve run outcome first'; END IF;
 IF r.state='failed' AND nullif(trim(r.error_message),'') IS NULL THEN RAISE EXCEPTION 'Failure reason required'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(r.raw_results) j WHERE
   coalesce(nullif(j->>'job_id',''),nullif(j->>'job_url','')) IS NULL OR NOT EXISTS(
    SELECT 1 FROM public.leadsignal_apify_decisions d WHERE d.batch_id=p_batch_id AND d.signal_key=r.signal_key
      AND d.canonical_job_key=coalesce(nullif(j->>'job_id',''),nullif(j->>'job_url',''))
      AND nullif(trim(d.reason),'') IS NOT NULL
      AND (d.icp_decision<>'pending' AND d.signal_decision<>'pending'
           OR nullif(trim(d.evidence->>'qualification_blocker'),'') IS NOT NULL)))
 THEN RAISE EXCEPTION 'Every job needs a persisted decision or documented qualification blocker'; END IF;
 SELECT jsonb_build_object(
   'raw_rows',jsonb_array_length(r.raw_results),'snapshot_at',clock_timestamp(),
   'distinct_jobs',count(*),'icp_pass',count(*) FILTER(WHERE d.icp_decision='pass'),
   'icp_reject',count(*) FILTER(WHERE d.icp_decision='reject'),'icp_pending',count(*) FILTER(WHERE d.icp_decision='pending'),
   'signal_pass',count(*) FILTER(WHERE d.signal_decision='pass'),
   'both_pass',count(*) FILTER(WHERE d.icp_decision='pass' AND d.signal_decision='pass'),
   'decisions',coalesce(jsonb_agg(to_jsonb(d)),'[]'::jsonb),
   'cumulative_distinct_icp_companies',(SELECT count(DISTINCT company_key) FROM public.leadsignal_apify_decisions
     WHERE batch_id=p_batch_id AND signal_key=r.signal_key AND icp_decision='pass'),
   'relaunch_rule','below five distinct ICP companies, at most five reserved calls') INTO report
 FROM public.leadsignal_apify_decisions d WHERE d.batch_id=p_batch_id AND d.signal_key=r.signal_key
 AND d.canonical_job_key IN (SELECT coalesce(nullif(j->>'job_id',''),nullif(j->>'job_url','')) FROM jsonb_array_elements(r.raw_results) j);
 UPDATE public.leadsignal_apify_lots SET qualification_completed_at=clock_timestamp(),qualification_report=report
 WHERE id=r.id RETURNING * INTO r;
 RETURN r;
END $$;


--
-- Name: leadsignal_discovery_calls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leadsignal_discovery_calls (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    batch_id uuid NOT NULL,
    signal_key text NOT NULL,
    call_number integer NOT NULL,
    provider text NOT NULL,
    request_input jsonb NOT NULL,
    state text DEFAULT 'reserved'::text NOT NULL,
    raw_results jsonb DEFAULT '[]'::jsonb NOT NULL,
    qualification_completed_at timestamp with time zone,
    qualification_report jsonb,
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    CONSTRAINT leadsignal_discovery_calls_call_number_check CHECK (((call_number >= 1) AND (call_number <= 2))),
    CONSTRAINT leadsignal_discovery_calls_provider_check CHECK ((provider = ANY (ARRAY['tavily'::text, 'boamp'::text, 'ted'::text]))),
    CONSTRAINT leadsignal_discovery_calls_raw_results_check CHECK ((jsonb_typeof(raw_results) = 'array'::text)),
    CONSTRAINT leadsignal_discovery_calls_request_input_check CHECK ((jsonb_typeof(request_input) = 'object'::text)),
    CONSTRAINT leadsignal_discovery_calls_state_check CHECK ((state = ANY (ARRAY['reserved'::text, 'running'::text, 'succeeded'::text, 'failed'::text, 'unknown'::text])))
);


--
-- Name: leadsignal_v3_finish_discovery(uuid, uuid, uuid, uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_v3_finish_discovery(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_call_id uuid, p_report jsonb) RETURNS public.leadsignal_discovery_calls
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE r public.leadsignal_discovery_calls; n integer;
BEGIN
 PERFORM public.leadsignal_assert_worker(p_batch_id,p_worker_id,p_lease_token);
 SELECT * INTO STRICT r FROM public.leadsignal_discovery_calls WHERE id=p_call_id AND batch_id=p_batch_id FOR UPDATE;
 IF r.qualification_completed_at IS NOT NULL THEN RETURN r; END IF;
 IF r.state NOT IN ('succeeded','failed') THEN RAISE EXCEPTION 'Resolve request outcome first'; END IF;
 IF r.state='failed' AND nullif(trim(r.error_message),'') IS NULL THEN RAISE EXCEPTION 'Failure reason required'; END IF;
 n:=jsonb_array_length(r.raw_results);
 IF jsonb_typeof(p_report->'items') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Per-row decisions required'; END IF;
 IF jsonb_array_length(p_report->'items')<>n OR EXISTS(
   SELECT 1 FROM generate_series(0,n-1) pos WHERE
     (SELECT count(*) FROM jsonb_array_elements(p_report->'items') x WHERE x->>'position'=pos::text)<>1
 ) OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_report->'items') x
   WHERE coalesce(x->>'decision','') NOT IN ('pass','reject','pending','duplicate') OR nullif(trim(x->>'reason'),'') IS NULL)
 THEN RAISE EXCEPTION 'Every raw position needs exactly one reasoned decision'; END IF;
 UPDATE public.leadsignal_discovery_calls SET qualification_completed_at=clock_timestamp(),
   qualification_report=p_report || jsonb_build_object('raw_rows',n,'snapshot_at',clock_timestamp())
 WHERE id=r.id RETURNING * INTO r;
 RETURN r;
END $$;


--
-- Name: leadsignal_v3_reserve_discovery(uuid, uuid, uuid, text, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.leadsignal_v3_reserve_discovery(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_signal_key text, p_provider text, p_input jsonb) RETURNS public.leadsignal_discovery_calls
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE b public.leadsignal_batches; r public.leadsignal_discovery_calls; n integer;
BEGIN
 PERFORM public.leadsignal_assert_worker(p_batch_id,p_worker_id,p_lease_token);
 SELECT * INTO STRICT b FROM public.leadsignal_batches WHERE id=p_batch_id FOR UPDATE;
 IF b.execution_config->>'controller' IS DISTINCT FROM 'all_signals_v3' THEN RAISE EXCEPTION 'V3 batch required'; END IF;
 IF coalesce((b.icp_snapshot->>'max_source_age_days')::integer,0)<=0 THEN RAISE EXCEPTION 'Positive date window required'; END IF;
 IF b.research_deadline IS NULL OR clock_timestamp()>=b.research_deadline THEN RAISE EXCEPTION 'Discovery deadline reached'; END IF;
 IF p_signal_key IS NULL OR p_signal_key NOT IN ('headcount_growth','fundraising','leader_tech_data_nomination',
 'major_contract_partnership','major_tech_data_program','public_rd_funding','compliance_pressure','new_product',
 'ma_activity','office_move_expansion','subsidiary_creation','tech_team_attrition','it_data_rfp')
 OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(b.signal_snapshot) s WHERE s->>'signal_key'=p_signal_key)
 THEN RAISE EXCEPTION 'Signal not selected'; END IF;
 IF p_input IS NULL OR jsonb_typeof(p_input)<>'object' THEN RAISE EXCEPTION 'Full request input required'; END IF;
 IF p_signal_key='it_data_rfp' THEN
   IF p_provider IS NULL OR p_provider NOT IN ('boamp','ted') THEN RAISE EXCEPTION 'Procurement route required'; END IF;
 ELSE
   IF p_provider IS DISTINCT FROM 'tavily' OR nullif(trim(p_input->>'query'),'') IS NULL
     OR p_input->>'include_published_date' IS DISTINCT FROM 'true'
     OR p_input->>'filter_by_published_date' IS DISTINCT FROM 'true'
     OR p_input->>'search_depth' IS DISTINCT FROM 'basic'
     OR p_input->>'max_results' IS DISTINCT FROM '10'
     OR p_input->>'auto_parameters' IS DISTINCT FROM 'false'
     OR p_input->>'start_date' IS DISTINCT FROM
       ((b.started_at AT TIME ZONE 'UTC')::date - (b.icp_snapshot->>'max_source_age_days')::integer)::text
     OR p_input->>'end_date' IS DISTINCT FROM ((b.started_at AT TIME ZONE 'UTC')::date)::text
   THEN RAISE EXCEPTION 'Expected Tavily exact bounded dates and reviewed options'; END IF;
 END IF;
 SELECT count(*) INTO n FROM public.leadsignal_discovery_calls WHERE batch_id=p_batch_id AND signal_key=p_signal_key;
 IF n>=2 THEN RAISE EXCEPTION 'Two discovery calls already reserved'; END IF;
 IF EXISTS(SELECT 1 FROM public.leadsignal_discovery_calls WHERE batch_id=p_batch_id AND signal_key=p_signal_key
     AND qualification_completed_at IS NULL) THEN RAISE EXCEPTION 'Finish previous collection first'; END IF;
 INSERT INTO public.leadsignal_discovery_calls(batch_id,signal_key,call_number,provider,request_input)
 VALUES(p_batch_id,p_signal_key,n+1,p_provider,p_input) RETURNING * INTO r;
 RETURN r;
END $$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


--
-- Name: agent_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    monitoring_job_id uuid,
    icp_id uuid,
    agent_name text DEFAULT 'HermesProactiveAgent'::text NOT NULL,
    run_type text DEFAULT 'proactive'::text NOT NULL,
    status text DEFAULT 'running'::text NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    signals_checked text[] DEFAULT '{}'::text[] NOT NULL,
    companies_checked integer DEFAULT 0 NOT NULL,
    new_opportunities_count integer DEFAULT 0 NOT NULL,
    cost_estimate numeric(10,4),
    error_message text,
    logs_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT agent_runs_status_check CHECK ((status = ANY (ARRAY['running'::text, 'success'::text, 'failed'::text, 'partial'::text])))
);


--
-- Name: companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.companies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    siren text,
    siret text,
    domain text,
    sector text,
    employee_count integer,
    city text,
    country text DEFAULT 'France'::text,
    pappers_data_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contacts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid,
    full_name text,
    role_title text NOT NULL,
    seniority text,
    linkedin_url text,
    email text,
    phone text,
    enrichment_status text DEFAULT 'not_requested'::text NOT NULL,
    source text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT contacts_enrichment_status_check CHECK ((enrichment_status = ANY (ARRAY['not_requested'::text, 'requested'::text, 'found'::text, 'not_found'::text, 'failed'::text])))
);


--
-- Name: hidden_signal_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hidden_signal_preferences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    icp_id uuid NOT NULL,
    signal_key text NOT NULL,
    signal_name text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    weight integer DEFAULT 10 NOT NULL,
    custom_description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: icp_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.icp_profiles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text DEFAULT 'Default ICP'::text NOT NULL,
    sectors text[] DEFAULT '{}'::text[] NOT NULL,
    locations text[] DEFAULT '{}'::text[] NOT NULL,
    company_size_min integer,
    company_size_max integer,
    target_roles text[] DEFAULT '{}'::text[] NOT NULL,
    seniority text,
    minimum_score integer DEFAULT 70 NOT NULL,
    qualification_instruction text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    max_source_age_days integer DEFAULT 60,
    CONSTRAINT icp_profiles_minimum_score_check CHECK (((minimum_score >= 0) AND (minimum_score <= 100)))
);


--
-- Name: leadsignal_apify_decisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leadsignal_apify_decisions (
    batch_id uuid NOT NULL,
    canonical_job_key text NOT NULL,
    signal_key text NOT NULL,
    source_lot_id uuid NOT NULL,
    source_signal_key text NOT NULL,
    company_key text,
    icp_decision text NOT NULL,
    signal_decision text NOT NULL,
    reason text NOT NULL,
    evidence jsonb DEFAULT '{}'::jsonb NOT NULL,
    candidate_id uuid,
    publication_status text DEFAULT 'not_ready'::text NOT NULL,
    opportunity_id uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT leadsignal_apify_decisions_icp_decision_check CHECK ((icp_decision = ANY (ARRAY['pass'::text, 'reject'::text, 'pending'::text]))),
    CONSTRAINT leadsignal_apify_decisions_publication_status_check CHECK ((publication_status = ANY (ARRAY['not_ready'::text, 'ready'::text, 'published'::text, 'duplicate'::text, 'failed'::text]))),
    CONSTRAINT leadsignal_apify_decisions_signal_decision_check CHECK ((signal_decision = ANY (ARRAY['pass'::text, 'reject'::text, 'pending'::text, 'not_evaluated'::text]))),
    CONSTRAINT leadsignal_apify_decisions_signal_key_check CHECK ((signal_key = ANY (ARRAY['internal_tech_recruiter_hiring'::text, 'tech_job_velocity_cluster'::text, 'tech_role_repost'::text])))
);


--
-- Name: leadsignal_batches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leadsignal_batches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    icp_id uuid NOT NULL,
    agent_run_id uuid,
    state text DEFAULT 'prepared'::text NOT NULL,
    display_timezone text DEFAULT 'Africa/Casablanca'::text NOT NULL,
    target_per_signal integer DEFAULT 5 NOT NULL,
    icp_snapshot jsonb NOT NULL,
    signal_snapshot jsonb NOT NULL,
    started_at timestamp with time zone,
    research_deadline timestamp with time zone,
    final_deadline timestamp with time zone,
    finished_at timestamp with time zone,
    budget_usd numeric,
    observed_cost_usd numeric,
    cost_accounting_complete boolean DEFAULT false NOT NULL,
    execution_config jsonb DEFAULT '{}'::jsonb NOT NULL,
    progress jsonb DEFAULT '{}'::jsonb NOT NULL,
    report jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    lease_worker_id uuid,
    lease_token uuid,
    lease_expires_at timestamp with time zone,
    CONSTRAINT leadsignal_batch_lease_complete CHECK ((((lease_worker_id IS NULL) AND (lease_token IS NULL) AND (lease_expires_at IS NULL)) OR ((lease_worker_id IS NOT NULL) AND (lease_token IS NOT NULL) AND (lease_expires_at IS NOT NULL)))),
    CONSTRAINT leadsignal_batches_budget_usd_check CHECK ((budget_usd > (0)::numeric)),
    CONSTRAINT leadsignal_batches_check CHECK ((((started_at IS NULL) AND (research_deadline IS NULL) AND (final_deadline IS NULL)) OR ((started_at IS NOT NULL) AND (research_deadline IS NOT NULL) AND (final_deadline IS NOT NULL) AND (started_at < research_deadline) AND (research_deadline < final_deadline)))),
    CONSTRAINT leadsignal_batches_check2 CHECK (((finished_at IS NULL) OR ((started_at IS NOT NULL) AND (finished_at >= started_at)))),
    CONSTRAINT leadsignal_batches_display_timezone_check CHECK ((display_timezone = ANY (ARRAY['Africa/Casablanca'::text, 'Europe/Paris'::text]))),
    CONSTRAINT leadsignal_batches_execution_config_check CHECK ((jsonb_typeof(execution_config) = 'object'::text)),
    CONSTRAINT leadsignal_batches_icp_snapshot_check CHECK ((jsonb_typeof(icp_snapshot) = 'object'::text)),
    CONSTRAINT leadsignal_batches_observed_cost_usd_check CHECK ((observed_cost_usd >= (0)::numeric)),
    CONSTRAINT leadsignal_batches_progress_check CHECK ((jsonb_typeof(progress) = 'object'::text)),
    CONSTRAINT leadsignal_batches_report_check CHECK ((jsonb_typeof(report) = 'object'::text)),
    CONSTRAINT leadsignal_batches_signal_snapshot_check CHECK (((jsonb_typeof(signal_snapshot) = 'array'::text) AND (jsonb_array_length(signal_snapshot) > 0))),
    CONSTRAINT leadsignal_batches_state_check CHECK ((state = ANY (ARRAY['prepared'::text, 'running'::text, 'completed'::text, 'partial'::text, 'failed'::text, 'cancelled'::text]))),
    CONSTRAINT leadsignal_batches_target_per_signal_check CHECK ((target_per_signal = ANY (ARRAY[1, 2, 5]))),
    CONSTRAINT leadsignal_running_context_required CHECK (((state <> 'running'::text) OR ((agent_run_id IS NOT NULL) AND (started_at IS NOT NULL))))
);


--
-- Name: TABLE leadsignal_batches; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.leadsignal_batches IS 'Private execution storage. Budget values record configuration; they do not enforce provider spending.';


--
-- Name: leadsignal_candidates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leadsignal_candidates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    batch_id uuid NOT NULL,
    signal_key text NOT NULL,
    candidate_key text NOT NULL,
    company_id uuid,
    company_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    event_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    evidence jsonb DEFAULT '{}'::jsonb NOT NULL,
    contact_research jsonb DEFAULT '[]'::jsonb NOT NULL,
    state text DEFAULT 'researching'::text NOT NULL,
    next_action text,
    rejection_reason text,
    opportunity_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    opportunity_purged_at timestamp with time zone,
    CONSTRAINT leadsignal_candidates_candidate_key_check CHECK ((length(btrim(candidate_key)) > 0)),
    CONSTRAINT leadsignal_candidates_check CHECK ((((opportunity_purged_at IS NULL) AND ((state = 'published'::text) = (opportunity_id IS NOT NULL))) OR ((opportunity_purged_at IS NOT NULL) AND (state = 'published'::text) AND (opportunity_id IS NULL)))),
    CONSTRAINT leadsignal_candidates_company_data_check CHECK ((jsonb_typeof(company_data) = 'object'::text)),
    CONSTRAINT leadsignal_candidates_contact_research_check CHECK ((jsonb_typeof(contact_research) = 'array'::text)),
    CONSTRAINT leadsignal_candidates_event_data_check CHECK ((jsonb_typeof(event_data) = 'object'::text)),
    CONSTRAINT leadsignal_candidates_evidence_check CHECK ((jsonb_typeof(evidence) = 'object'::text)),
    CONSTRAINT leadsignal_candidates_signal_key_check CHECK ((length(btrim(signal_key)) > 0)),
    CONSTRAINT leadsignal_candidates_state_check CHECK ((state = ANY (ARRAY['researching'::text, 'pending_contacts'::text, 'ready_for_validation'::text, 'rejected'::text, 'duplicate'::text, 'published'::text])))
);


--
-- Name: TABLE leadsignal_candidates; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.leadsignal_candidates IS 'Private research, not published opportunities. Ready state is not proof of qualification or contact verification.';


--
-- Name: COLUMN leadsignal_candidates.opportunity_purged_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.leadsignal_candidates.opportunity_purged_at IS 'Date de suppression de la fiche par la rétention ; publication historique conservée.';


--
-- Name: leadsignal_contact_recovery_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leadsignal_contact_recovery_attempts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    opportunity_id uuid NOT NULL,
    lease_token uuid NOT NULL,
    request_key text NOT NULL,
    purpose text NOT NULL,
    provider text NOT NULL,
    query_text text,
    state text DEFAULT 'started'::text NOT NULL,
    started_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    finished_at timestamp with time zone,
    result_summary jsonb DEFAULT '{}'::jsonb NOT NULL,
    error_message text,
    CONSTRAINT leadsignal_contact_recovery_attempts_purpose_check CHECK ((purpose = ANY (ARRAY['contact_discovery'::text, 'linkedin_verification'::text, 'company_identity'::text]))),
    CONSTRAINT leadsignal_contact_recovery_attempts_result_summary_check CHECK ((jsonb_typeof(result_summary) = 'object'::text)),
    CONSTRAINT leadsignal_contact_recovery_attempts_state_check CHECK ((state = ANY (ARRAY['started'::text, 'succeeded'::text, 'failed'::text, 'interrupted'::text])))
);


--
-- Name: leadsignal_contact_recovery_targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leadsignal_contact_recovery_targets (
    opportunity_id uuid NOT NULL,
    company_id uuid NOT NULL,
    snapshot jsonb NOT NULL,
    state text DEFAULT 'pending'::text NOT NULL,
    notes jsonb DEFAULT '{}'::jsonb NOT NULL,
    started_at timestamp with time zone,
    finished_at timestamp with time zone,
    lease_token uuid,
    lease_expires_at timestamp with time zone,
    attempts integer DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT leadsignal_contact_recovery_targets_notes_check CHECK ((jsonb_typeof(notes) = 'object'::text)),
    CONSTRAINT leadsignal_contact_recovery_targets_state_check CHECK ((state = ANY (ARRAY['pending'::text, 'running'::text, 'done'::text, 'blocked'::text, 'skipped'::text])))
);


--
-- Name: leadsignal_dispatches_v1; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leadsignal_dispatches_v1 (
    attempt_id uuid NOT NULL,
    batch_id uuid NOT NULL,
    signal_key text NOT NULL,
    dispatched_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);


--
-- Name: leadsignal_events_v2; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leadsignal_events_v2 (
    company_id uuid NOT NULL,
    signal_key text NOT NULL,
    event_key text NOT NULL,
    candidate_id uuid NOT NULL,
    facts jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: leadsignal_function_backups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leadsignal_function_backups (
    backup_key text NOT NULL,
    definition text NOT NULL,
    saved_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: leadsignal_qualifications_v1; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leadsignal_qualifications_v1 (
    candidate_id uuid NOT NULL,
    batch_id uuid NOT NULL,
    signal_key text NOT NULL,
    source_url text NOT NULL,
    qualified_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);


--
-- Name: leadsignal_research_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leadsignal_research_attempts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    batch_id uuid NOT NULL,
    worker_id uuid,
    candidate_id uuid,
    attempt_key text NOT NULL,
    signal_key text NOT NULL,
    purpose text NOT NULL,
    provider text NOT NULL,
    query_text text,
    source_url text,
    state text DEFAULT 'started'::text NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    result_summary jsonb DEFAULT '{}'::jsonb NOT NULL,
    cost_usd numeric,
    cost_is_estimate boolean DEFAULT true NOT NULL,
    error_message text,
    CONSTRAINT leadsignal_research_attempts_attempt_key_check CHECK ((length(btrim(attempt_key)) > 0)),
    CONSTRAINT leadsignal_research_attempts_check CHECK (((finished_at IS NULL) OR (finished_at >= started_at))),
    CONSTRAINT leadsignal_research_attempts_cost_usd_check CHECK ((cost_usd >= (0)::numeric)),
    CONSTRAINT leadsignal_research_attempts_provider_check CHECK ((length(btrim(provider)) > 0)),
    CONSTRAINT leadsignal_research_attempts_purpose_check CHECK ((purpose = ANY (ARRAY['discovery'::text, 'source_verification'::text, 'company_qualification'::text, 'contact_discovery'::text, 'linkedin_verification'::text, 'feed_fetch'::text]))),
    CONSTRAINT leadsignal_research_attempts_result_summary_check CHECK ((jsonb_typeof(result_summary) = 'object'::text)),
    CONSTRAINT leadsignal_research_attempts_signal_key_check CHECK ((length(btrim(signal_key)) > 0)),
    CONSTRAINT leadsignal_research_attempts_state_check CHECK ((state = ANY (ARRAY['started'::text, 'succeeded'::text, 'failed'::text, 'interrupted'::text])))
);


--
-- Name: leadsignal_rules_backup_v1; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leadsignal_rules_backup_v1 (
    signature text NOT NULL,
    definition text NOT NULL,
    saved_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);


--
-- Name: leadsignal_scheduler_status; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leadsignal_scheduler_status (
    task_key text NOT NULL,
    observed_at timestamp with time zone NOT NULL,
    payload jsonb NOT NULL,
    CONSTRAINT leadsignal_scheduler_status_payload_check CHECK ((jsonb_typeof(payload) = 'object'::text)),
    CONSTRAINT leadsignal_scheduler_status_task_key_check CHECK ((task_key = ANY (ARRAY['research'::text, 'cleanup'::text])))
);


--
-- Name: leadsignal_v2_function_backup; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leadsignal_v2_function_backup (
    signature text NOT NULL,
    definition text NOT NULL
);


--
-- Name: leadsignal_workers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leadsignal_workers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    batch_id uuid NOT NULL,
    attempt_number integer NOT NULL,
    state text DEFAULT 'started'::text NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    heartbeat_at timestamp with time zone,
    finished_at timestamp with time zone,
    session_reference text,
    usage jsonb DEFAULT '{}'::jsonb NOT NULL,
    checkpoint jsonb DEFAULT '{}'::jsonb NOT NULL,
    error_message text,
    CONSTRAINT leadsignal_workers_attempt_number_check CHECK ((attempt_number > 0)),
    CONSTRAINT leadsignal_workers_check CHECK (((finished_at IS NULL) OR (finished_at >= started_at))),
    CONSTRAINT leadsignal_workers_checkpoint_check CHECK ((jsonb_typeof(checkpoint) = 'object'::text)),
    CONSTRAINT leadsignal_workers_state_check CHECK ((state = ANY (ARRAY['started'::text, 'yielded'::text, 'completed'::text, 'failed'::text, 'timed_out'::text]))),
    CONSTRAINT leadsignal_workers_usage_check CHECK ((jsonb_typeof(usage) = 'object'::text))
);


--
-- Name: TABLE leadsignal_workers; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.leadsignal_workers IS 'Worker history only. A heartbeat field does not implement leases, fencing, or automatic recovery.';


--
-- Name: monitoring_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.monitoring_jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    icp_id uuid NOT NULL,
    job_type text DEFAULT 'proactive'::text NOT NULL,
    frequency text DEFAULT 'daily'::text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    last_run_at timestamp with time zone,
    next_run_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT monitoring_jobs_frequency_check CHECK ((frequency = ANY (ARRAY['hourly'::text, 'every_2h'::text, 'daily'::text, 'weekly'::text]))),
    CONSTRAINT monitoring_jobs_job_type_check CHECK ((job_type = ANY (ARRAY['proactive'::text, 'reactive'::text, 'watchlist'::text]))),
    CONSTRAINT monitoring_jobs_status_check CHECK ((status = ANY (ARRAY['active'::text, 'paused'::text, 'disabled'::text])))
);


--
-- Name: opportunities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.opportunities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    primary_signal_id uuid,
    title text NOT NULL,
    score integer,
    priority text DEFAULT 'Medium'::text NOT NULL,
    reason text NOT NULL,
    status text DEFAULT 'new'::text NOT NULL,
    recommended_contacts text[] DEFAULT '{}'::text[] NOT NULL,
    source_urls text[] DEFAULT '{}'::text[] NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    assigned_to text,
    rejection_reason text,
    rejected_at timestamp with time zone,
    contact_status text DEFAULT 'not_checked'::text,
    dedupe_key text,
    event_date date,
    assigned_user_id uuid,
    assigned_at timestamp with time zone,
    assigned_by_user_id uuid,
    work_done boolean DEFAULT false NOT NULL,
    work_done_at timestamp with time zone,
    work_done_by_user_id uuid,
    CONSTRAINT opportunities_priority_check CHECK ((priority = ANY (ARRAY['Low'::text, 'Medium'::text, 'High'::text]))),
    CONSTRAINT opportunities_score_check CHECK (((score >= 0) AND (score <= 100))),
    CONSTRAINT opportunities_status_check CHECK ((status = ANY (ARRAY['new'::text, 'review'::text, 'qualified'::text, 'rejected'::text, 'archived'::text])))
);


--
-- Name: opportunity_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.opportunity_contacts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    opportunity_id uuid NOT NULL,
    company_id uuid NOT NULL,
    full_name text NOT NULL,
    title text NOT NULL,
    linkedin_url text,
    relevance_reason text NOT NULL,
    priority text NOT NULL,
    source_type text DEFAULT 'apify_linkedin_company_employees'::text NOT NULL,
    raw_result jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    linkedin_url_verified boolean,
    linkedin_search_url text,
    contact_status text DEFAULT 'valid'::text,
    validation_notes text,
    phone text,
    enrichment_status text DEFAULT 'not_requested'::text,
    CONSTRAINT opportunity_contacts_enrichment_status_check CHECK ((enrichment_status = ANY (ARRAY['not_requested'::text, 'found'::text, 'not_found'::text, 'failed'::text]))),
    CONSTRAINT opportunity_contacts_priority_check CHECK ((priority = ANY (ARRAY['High'::text, 'Medium'::text, 'Low'::text])))
);


--
-- Name: platform_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.platform_members (
    user_id uuid NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    role text DEFAULT 'employee'::text NOT NULL,
    last_seen_at timestamp with time zone,
    CONSTRAINT platform_members_role_check CHECK ((role = ANY (ARRAY['ceo'::text, 'employee'::text])))
);


--
-- Name: qualified_opportunities; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.qualified_opportunities AS
 SELECT id,
    company_id,
    primary_signal_id,
    title,
    score,
    priority,
    reason,
    status,
    recommended_contacts,
    source_urls,
    created_at,
    updated_at,
    assigned_to,
    rejection_reason,
    rejected_at,
    contact_status,
    dedupe_key,
    event_date
   FROM public.opportunities
  WHERE (status = ANY (ARRAY['new'::text, 'review'::text, 'qualified'::text]));


--
-- Name: rejected_opportunities; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.rejected_opportunities AS
 SELECT id,
    company_id,
    primary_signal_id,
    title,
    score,
    priority,
    reason,
    status,
    recommended_contacts,
    source_urls,
    created_at,
    updated_at,
    assigned_to,
    rejection_reason,
    rejected_at,
    contact_status,
    dedupe_key,
    event_date
   FROM public.opportunities
  WHERE (status = 'rejected'::text);


--
-- Name: signal_test_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.signal_test_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    icp_id uuid,
    signal_key text NOT NULL,
    signal_name text,
    expected_source text,
    request_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    company_name text,
    source_used text,
    source_type text,
    source_url text,
    source_title text,
    publication_date text,
    matched_signal boolean,
    match_quality text,
    company_id uuid,
    signal_id uuid,
    opportunity_id uuid,
    score integer,
    reason text,
    errors jsonb DEFAULT '[]'::jsonb NOT NULL,
    raw_result jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    started_at timestamp with time zone,
    finished_at timestamp with time zone,
    CONSTRAINT signal_test_runs_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'running'::text, 'inserted'::text, 'updated'::text, 'rejected'::text, 'failed'::text])))
);


--
-- Name: signals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.signals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid,
    agent_run_id uuid,
    signal_key text NOT NULL,
    signal_name text NOT NULL,
    signal_category text,
    source_type text NOT NULL,
    source_url text NOT NULL,
    source_title text,
    source_published_at date,
    detected_at timestamp with time zone DEFAULT now() NOT NULL,
    raw_excerpt text,
    raw_content_hash text,
    reliability text DEFAULT 'medium'::text NOT NULL,
    confidence_score integer DEFAULT 50 NOT NULL,
    metadata_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    event_date date,
    dedupe_key text,
    CONSTRAINT signals_confidence_score_check CHECK (((confidence_score >= 0) AND (confidence_score <= 100))),
    CONSTRAINT signals_reliability_check CHECK ((reliability = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text])))
);


--
-- Name: source_cursors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.source_cursors (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    icp_id uuid,
    source_name text NOT NULL,
    signal_key text,
    last_checked_at timestamp with time zone,
    last_seen_url text,
    last_seen_publication_date date,
    cursor_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: watchlist_companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.watchlist_companies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid,
    company_name text NOT NULL,
    domain text,
    priority text DEFAULT 'Strategic'::text NOT NULL,
    owner_name text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: agent_runs agent_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_runs
    ADD CONSTRAINT agent_runs_pkey PRIMARY KEY (id);


--
-- Name: companies companies_domain_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_domain_key UNIQUE (domain);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


--
-- Name: companies companies_siren_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_siren_key UNIQUE (siren);


--
-- Name: contacts contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_pkey PRIMARY KEY (id);


--
-- Name: hidden_signal_preferences hidden_signal_preferences_icp_id_signal_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_signal_preferences
    ADD CONSTRAINT hidden_signal_preferences_icp_id_signal_key_key UNIQUE (icp_id, signal_key);


--
-- Name: hidden_signal_preferences hidden_signal_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_signal_preferences
    ADD CONSTRAINT hidden_signal_preferences_pkey PRIMARY KEY (id);


--
-- Name: icp_profiles icp_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.icp_profiles
    ADD CONSTRAINT icp_profiles_pkey PRIMARY KEY (id);


--
-- Name: leadsignal_apify_decisions leadsignal_apify_decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_apify_decisions
    ADD CONSTRAINT leadsignal_apify_decisions_pkey PRIMARY KEY (batch_id, canonical_job_key, signal_key);


--
-- Name: leadsignal_apify_lots leadsignal_apify_lots_batch_id_signal_key_page_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_apify_lots
    ADD CONSTRAINT leadsignal_apify_lots_batch_id_signal_key_page_number_key UNIQUE (batch_id, signal_key, page_number);


--
-- Name: leadsignal_apify_lots leadsignal_apify_lots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_apify_lots
    ADD CONSTRAINT leadsignal_apify_lots_pkey PRIMARY KEY (id);


--
-- Name: leadsignal_batches leadsignal_batches_agent_run_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_batches
    ADD CONSTRAINT leadsignal_batches_agent_run_id_key UNIQUE (agent_run_id);


--
-- Name: leadsignal_batches leadsignal_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_batches
    ADD CONSTRAINT leadsignal_batches_pkey PRIMARY KEY (id);


--
-- Name: leadsignal_candidates leadsignal_candidates_batch_id_candidate_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_candidates
    ADD CONSTRAINT leadsignal_candidates_batch_id_candidate_key_key UNIQUE (batch_id, candidate_key);


--
-- Name: leadsignal_candidates leadsignal_candidates_batch_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_candidates
    ADD CONSTRAINT leadsignal_candidates_batch_id_id_key UNIQUE (batch_id, id);


--
-- Name: leadsignal_candidates leadsignal_candidates_opportunity_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_candidates
    ADD CONSTRAINT leadsignal_candidates_opportunity_id_key UNIQUE (opportunity_id);


--
-- Name: leadsignal_candidates leadsignal_candidates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_candidates
    ADD CONSTRAINT leadsignal_candidates_pkey PRIMARY KEY (id);


--
-- Name: leadsignal_cluster_company_calls leadsignal_cluster_company_ca_batch_id_linkedin_company_id__key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_cluster_company_calls
    ADD CONSTRAINT leadsignal_cluster_company_ca_batch_id_linkedin_company_id__key UNIQUE (batch_id, linkedin_company_id, search_scope, page_number);


--
-- Name: leadsignal_cluster_company_calls leadsignal_cluster_company_calls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_cluster_company_calls
    ADD CONSTRAINT leadsignal_cluster_company_calls_pkey PRIMARY KEY (id);


--
-- Name: leadsignal_contact_recovery_attempts leadsignal_contact_recovery_atte_opportunity_id_request_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_contact_recovery_attempts
    ADD CONSTRAINT leadsignal_contact_recovery_atte_opportunity_id_request_key_key UNIQUE (opportunity_id, request_key);


--
-- Name: leadsignal_contact_recovery_attempts leadsignal_contact_recovery_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_contact_recovery_attempts
    ADD CONSTRAINT leadsignal_contact_recovery_attempts_pkey PRIMARY KEY (id);


--
-- Name: leadsignal_contact_recovery_targets leadsignal_contact_recovery_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_contact_recovery_targets
    ADD CONSTRAINT leadsignal_contact_recovery_targets_pkey PRIMARY KEY (opportunity_id);


--
-- Name: leadsignal_discovery_calls leadsignal_discovery_calls_batch_id_signal_key_call_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_discovery_calls
    ADD CONSTRAINT leadsignal_discovery_calls_batch_id_signal_key_call_number_key UNIQUE (batch_id, signal_key, call_number);


--
-- Name: leadsignal_discovery_calls leadsignal_discovery_calls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_discovery_calls
    ADD CONSTRAINT leadsignal_discovery_calls_pkey PRIMARY KEY (id);


--
-- Name: leadsignal_dispatches_v1 leadsignal_dispatches_v1_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_dispatches_v1
    ADD CONSTRAINT leadsignal_dispatches_v1_pkey PRIMARY KEY (attempt_id);


--
-- Name: leadsignal_events_v2 leadsignal_events_v2_candidate_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_events_v2
    ADD CONSTRAINT leadsignal_events_v2_candidate_id_key UNIQUE (candidate_id);


--
-- Name: leadsignal_events_v2 leadsignal_events_v2_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_events_v2
    ADD CONSTRAINT leadsignal_events_v2_pkey PRIMARY KEY (company_id, signal_key, event_key);


--
-- Name: leadsignal_function_backups leadsignal_function_backups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_function_backups
    ADD CONSTRAINT leadsignal_function_backups_pkey PRIMARY KEY (backup_key);


--
-- Name: leadsignal_qualifications_v1 leadsignal_qualifications_v1_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_qualifications_v1
    ADD CONSTRAINT leadsignal_qualifications_v1_pkey PRIMARY KEY (candidate_id);


--
-- Name: leadsignal_research_attempts leadsignal_research_attempts_batch_id_attempt_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_research_attempts
    ADD CONSTRAINT leadsignal_research_attempts_batch_id_attempt_key_key UNIQUE (batch_id, attempt_key);


--
-- Name: leadsignal_research_attempts leadsignal_research_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_research_attempts
    ADD CONSTRAINT leadsignal_research_attempts_pkey PRIMARY KEY (id);


--
-- Name: leadsignal_rules_backup_v1 leadsignal_rules_backup_v1_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_rules_backup_v1
    ADD CONSTRAINT leadsignal_rules_backup_v1_pkey PRIMARY KEY (signature);


--
-- Name: leadsignal_scheduler_status leadsignal_scheduler_status_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_scheduler_status
    ADD CONSTRAINT leadsignal_scheduler_status_pkey PRIMARY KEY (task_key);


--
-- Name: leadsignal_v2_function_backup leadsignal_v2_function_backup_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_v2_function_backup
    ADD CONSTRAINT leadsignal_v2_function_backup_pkey PRIMARY KEY (signature);


--
-- Name: leadsignal_workers leadsignal_workers_batch_id_attempt_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_workers
    ADD CONSTRAINT leadsignal_workers_batch_id_attempt_number_key UNIQUE (batch_id, attempt_number);


--
-- Name: leadsignal_workers leadsignal_workers_batch_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_workers
    ADD CONSTRAINT leadsignal_workers_batch_id_id_key UNIQUE (batch_id, id);


--
-- Name: leadsignal_workers leadsignal_workers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_workers
    ADD CONSTRAINT leadsignal_workers_pkey PRIMARY KEY (id);


--
-- Name: monitoring_jobs monitoring_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monitoring_jobs
    ADD CONSTRAINT monitoring_jobs_pkey PRIMARY KEY (id);


--
-- Name: opportunities opportunities_company_id_primary_signal_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.opportunities
    ADD CONSTRAINT opportunities_company_id_primary_signal_id_key UNIQUE (company_id, primary_signal_id);


--
-- Name: opportunities opportunities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.opportunities
    ADD CONSTRAINT opportunities_pkey PRIMARY KEY (id);


--
-- Name: opportunity_contacts opportunity_contacts_opportunity_id_linkedin_url_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.opportunity_contacts
    ADD CONSTRAINT opportunity_contacts_opportunity_id_linkedin_url_key UNIQUE (opportunity_id, linkedin_url);


--
-- Name: opportunity_contacts opportunity_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.opportunity_contacts
    ADD CONSTRAINT opportunity_contacts_pkey PRIMARY KEY (id);


--
-- Name: platform_members platform_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_members
    ADD CONSTRAINT platform_members_pkey PRIMARY KEY (user_id);


--
-- Name: signal_test_runs signal_test_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signal_test_runs
    ADD CONSTRAINT signal_test_runs_pkey PRIMARY KEY (id);


--
-- Name: signals signals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signals
    ADD CONSTRAINT signals_pkey PRIMARY KEY (id);


--
-- Name: source_cursors source_cursors_icp_id_source_name_signal_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_cursors
    ADD CONSTRAINT source_cursors_icp_id_source_name_signal_key_key UNIQUE (icp_id, source_name, signal_key);


--
-- Name: source_cursors source_cursors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_cursors
    ADD CONSTRAINT source_cursors_pkey PRIMARY KEY (id);


--
-- Name: watchlist_companies watchlist_companies_domain_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watchlist_companies
    ADD CONSTRAINT watchlist_companies_domain_key UNIQUE (domain);


--
-- Name: watchlist_companies watchlist_companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watchlist_companies
    ADD CONSTRAINT watchlist_companies_pkey PRIMARY KEY (id);


--
-- Name: idx_agent_runs_started; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agent_runs_started ON public.agent_runs USING btree (started_at DESC);


--
-- Name: idx_icp_profiles_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_icp_profiles_active ON public.icp_profiles USING btree (active);


--
-- Name: idx_monitoring_jobs_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_monitoring_jobs_due ON public.monitoring_jobs USING btree (status, next_run_at);


--
-- Name: idx_opportunities_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_opportunities_created ON public.opportunities USING btree (created_at DESC);


--
-- Name: idx_opportunities_status_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_opportunities_status_priority ON public.opportunities USING btree (status, priority);


--
-- Name: idx_opportunity_contacts_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_opportunity_contacts_company_id ON public.opportunity_contacts USING btree (company_id);


--
-- Name: idx_opportunity_contacts_opportunity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_opportunity_contacts_opportunity_id ON public.opportunity_contacts USING btree (opportunity_id);


--
-- Name: idx_signals_detected; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_signals_detected ON public.signals USING btree (detected_at DESC);


--
-- Name: idx_signals_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_signals_key ON public.signals USING btree (signal_key);


--
-- Name: leadsignal_attempts_batch_signal; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX leadsignal_attempts_batch_signal ON public.leadsignal_research_attempts USING btree (batch_id, signal_key, started_at);


--
-- Name: leadsignal_candidates_batch_signal_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX leadsignal_candidates_batch_signal_state ON public.leadsignal_candidates USING btree (batch_id, signal_key, state);


--
-- Name: leadsignal_dispatches_v1_batch_id_signal_key_dispatched_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX leadsignal_dispatches_v1_batch_id_signal_key_dispatched_at_idx ON public.leadsignal_dispatches_v1 USING btree (batch_id, signal_key, dispatched_at);


--
-- Name: leadsignal_one_running_batch_per_icp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX leadsignal_one_running_batch_per_icp ON public.leadsignal_batches USING btree (icp_id) WHERE (state = 'running'::text);


--
-- Name: leadsignal_one_started_worker_per_batch; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX leadsignal_one_started_worker_per_batch ON public.leadsignal_workers USING btree (batch_id) WHERE (state = 'started'::text);


--
-- Name: leadsignal_qualifications_v1_batch_id_signal_key_qualified__idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX leadsignal_qualifications_v1_batch_id_signal_key_qualified__idx ON public.leadsignal_qualifications_v1 USING btree (batch_id, signal_key, qualified_at);


--
-- Name: opportunities_assigned_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX opportunities_assigned_user_idx ON public.opportunities USING btree (assigned_user_id);


--
-- Name: opportunities_work_done_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX opportunities_work_done_idx ON public.opportunities USING btree (assigned_user_id, work_done);


--
-- Name: platform_members_last_seen_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX platform_members_last_seen_idx ON public.platform_members USING btree (last_seen_at);


--
-- Name: signal_test_runs_signal_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX signal_test_runs_signal_created_idx ON public.signal_test_runs USING btree (signal_key, created_at DESC);


--
-- Name: signal_test_runs_status_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX signal_test_runs_status_created_idx ON public.signal_test_runs USING btree (status, created_at DESC);


--
-- Name: leadsignal_batches leadsignal_batches_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER leadsignal_batches_updated_at BEFORE UPDATE ON public.leadsignal_batches FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: leadsignal_candidates leadsignal_candidates_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER leadsignal_candidates_updated_at BEFORE UPDATE ON public.leadsignal_candidates FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: opportunity_contacts leadsignal_five_contacts_guard_v1; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER leadsignal_five_contacts_guard_v1 BEFORE INSERT OR UPDATE OF opportunity_id ON public.opportunity_contacts FOR EACH ROW EXECUTE FUNCTION public.leadsignal_five_contacts_guard_v1();


--
-- Name: companies set_companies_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_companies_updated_at BEFORE UPDATE ON public.companies FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contacts set_contacts_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_contacts_updated_at BEFORE UPDATE ON public.contacts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: icp_profiles set_icp_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_icp_profiles_updated_at BEFORE UPDATE ON public.icp_profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: monitoring_jobs set_monitoring_jobs_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_monitoring_jobs_updated_at BEFORE UPDATE ON public.monitoring_jobs FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: opportunities set_opportunities_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_opportunities_updated_at BEFORE UPDATE ON public.opportunities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: agent_runs agent_runs_icp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_runs
    ADD CONSTRAINT agent_runs_icp_id_fkey FOREIGN KEY (icp_id) REFERENCES public.icp_profiles(id) ON DELETE SET NULL;


--
-- Name: agent_runs agent_runs_monitoring_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_runs
    ADD CONSTRAINT agent_runs_monitoring_job_id_fkey FOREIGN KEY (monitoring_job_id) REFERENCES public.monitoring_jobs(id) ON DELETE SET NULL;


--
-- Name: contacts contacts_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;


--
-- Name: hidden_signal_preferences hidden_signal_preferences_icp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_signal_preferences
    ADD CONSTRAINT hidden_signal_preferences_icp_id_fkey FOREIGN KEY (icp_id) REFERENCES public.icp_profiles(id) ON DELETE CASCADE;


--
-- Name: leadsignal_apify_decisions leadsignal_apify_decisions_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_apify_decisions
    ADD CONSTRAINT leadsignal_apify_decisions_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.leadsignal_batches(id);


--
-- Name: leadsignal_apify_decisions leadsignal_apify_decisions_candidate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_apify_decisions
    ADD CONSTRAINT leadsignal_apify_decisions_candidate_id_fkey FOREIGN KEY (candidate_id) REFERENCES public.leadsignal_candidates(id);


--
-- Name: leadsignal_apify_decisions leadsignal_apify_decisions_source_lot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_apify_decisions
    ADD CONSTRAINT leadsignal_apify_decisions_source_lot_id_fkey FOREIGN KEY (source_lot_id) REFERENCES public.leadsignal_apify_lots(id);


--
-- Name: leadsignal_apify_lots leadsignal_apify_lots_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_apify_lots
    ADD CONSTRAINT leadsignal_apify_lots_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.leadsignal_batches(id);


--
-- Name: leadsignal_batches leadsignal_batch_lease_worker_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_batches
    ADD CONSTRAINT leadsignal_batch_lease_worker_fk FOREIGN KEY (id, lease_worker_id) REFERENCES public.leadsignal_workers(batch_id, id) ON DELETE RESTRICT;


--
-- Name: leadsignal_batches leadsignal_batches_agent_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_batches
    ADD CONSTRAINT leadsignal_batches_agent_run_id_fkey FOREIGN KEY (agent_run_id) REFERENCES public.agent_runs(id) ON DELETE RESTRICT;


--
-- Name: leadsignal_batches leadsignal_batches_icp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_batches
    ADD CONSTRAINT leadsignal_batches_icp_id_fkey FOREIGN KEY (icp_id) REFERENCES public.icp_profiles(id) ON DELETE RESTRICT;


--
-- Name: leadsignal_candidates leadsignal_candidates_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_candidates
    ADD CONSTRAINT leadsignal_candidates_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.leadsignal_batches(id) ON DELETE RESTRICT;


--
-- Name: leadsignal_candidates leadsignal_candidates_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_candidates
    ADD CONSTRAINT leadsignal_candidates_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE RESTRICT;


--
-- Name: leadsignal_candidates leadsignal_candidates_opportunity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_candidates
    ADD CONSTRAINT leadsignal_candidates_opportunity_id_fkey FOREIGN KEY (opportunity_id) REFERENCES public.opportunities(id) ON DELETE RESTRICT;


--
-- Name: leadsignal_cluster_company_calls leadsignal_cluster_company_calls_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_cluster_company_calls
    ADD CONSTRAINT leadsignal_cluster_company_calls_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.leadsignal_batches(id);


--
-- Name: leadsignal_cluster_company_calls leadsignal_cluster_company_calls_worker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_cluster_company_calls
    ADD CONSTRAINT leadsignal_cluster_company_calls_worker_id_fkey FOREIGN KEY (worker_id) REFERENCES public.leadsignal_workers(id);


--
-- Name: leadsignal_contact_recovery_attempts leadsignal_contact_recovery_attempts_opportunity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_contact_recovery_attempts
    ADD CONSTRAINT leadsignal_contact_recovery_attempts_opportunity_id_fkey FOREIGN KEY (opportunity_id) REFERENCES public.leadsignal_contact_recovery_targets(opportunity_id);


--
-- Name: leadsignal_contact_recovery_targets leadsignal_contact_recovery_targets_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_contact_recovery_targets
    ADD CONSTRAINT leadsignal_contact_recovery_targets_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE RESTRICT;


--
-- Name: leadsignal_contact_recovery_targets leadsignal_contact_recovery_targets_opportunity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_contact_recovery_targets
    ADD CONSTRAINT leadsignal_contact_recovery_targets_opportunity_id_fkey FOREIGN KEY (opportunity_id) REFERENCES public.opportunities(id) ON DELETE RESTRICT;


--
-- Name: leadsignal_discovery_calls leadsignal_discovery_calls_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_discovery_calls
    ADD CONSTRAINT leadsignal_discovery_calls_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.leadsignal_batches(id);


--
-- Name: leadsignal_dispatches_v1 leadsignal_dispatches_v1_attempt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_dispatches_v1
    ADD CONSTRAINT leadsignal_dispatches_v1_attempt_id_fkey FOREIGN KEY (attempt_id) REFERENCES public.leadsignal_research_attempts(id);


--
-- Name: leadsignal_dispatches_v1 leadsignal_dispatches_v1_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_dispatches_v1
    ADD CONSTRAINT leadsignal_dispatches_v1_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.leadsignal_batches(id);


--
-- Name: leadsignal_events_v2 leadsignal_events_v2_candidate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_events_v2
    ADD CONSTRAINT leadsignal_events_v2_candidate_id_fkey FOREIGN KEY (candidate_id) REFERENCES public.leadsignal_candidates(id);


--
-- Name: leadsignal_events_v2 leadsignal_events_v2_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_events_v2
    ADD CONSTRAINT leadsignal_events_v2_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: leadsignal_qualifications_v1 leadsignal_qualifications_v1_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_qualifications_v1
    ADD CONSTRAINT leadsignal_qualifications_v1_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.leadsignal_batches(id);


--
-- Name: leadsignal_qualifications_v1 leadsignal_qualifications_v1_candidate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_qualifications_v1
    ADD CONSTRAINT leadsignal_qualifications_v1_candidate_id_fkey FOREIGN KEY (candidate_id) REFERENCES public.leadsignal_candidates(id);


--
-- Name: leadsignal_research_attempts leadsignal_research_attempts_batch_id_candidate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_research_attempts
    ADD CONSTRAINT leadsignal_research_attempts_batch_id_candidate_id_fkey FOREIGN KEY (batch_id, candidate_id) REFERENCES public.leadsignal_candidates(batch_id, id) ON DELETE RESTRICT;


--
-- Name: leadsignal_research_attempts leadsignal_research_attempts_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_research_attempts
    ADD CONSTRAINT leadsignal_research_attempts_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.leadsignal_batches(id) ON DELETE RESTRICT;


--
-- Name: leadsignal_research_attempts leadsignal_research_attempts_batch_id_worker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_research_attempts
    ADD CONSTRAINT leadsignal_research_attempts_batch_id_worker_id_fkey FOREIGN KEY (batch_id, worker_id) REFERENCES public.leadsignal_workers(batch_id, id) ON DELETE RESTRICT;


--
-- Name: leadsignal_workers leadsignal_workers_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leadsignal_workers
    ADD CONSTRAINT leadsignal_workers_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.leadsignal_batches(id) ON DELETE RESTRICT;


--
-- Name: monitoring_jobs monitoring_jobs_icp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monitoring_jobs
    ADD CONSTRAINT monitoring_jobs_icp_id_fkey FOREIGN KEY (icp_id) REFERENCES public.icp_profiles(id) ON DELETE CASCADE;


--
-- Name: opportunities opportunities_assigned_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.opportunities
    ADD CONSTRAINT opportunities_assigned_by_user_id_fkey FOREIGN KEY (assigned_by_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: opportunities opportunities_assigned_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.opportunities
    ADD CONSTRAINT opportunities_assigned_user_id_fkey FOREIGN KEY (assigned_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: opportunities opportunities_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.opportunities
    ADD CONSTRAINT opportunities_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;


--
-- Name: opportunities opportunities_primary_signal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.opportunities
    ADD CONSTRAINT opportunities_primary_signal_id_fkey FOREIGN KEY (primary_signal_id) REFERENCES public.signals(id) ON DELETE SET NULL;


--
-- Name: opportunities opportunities_work_done_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.opportunities
    ADD CONSTRAINT opportunities_work_done_by_user_id_fkey FOREIGN KEY (work_done_by_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: opportunity_contacts opportunity_contacts_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.opportunity_contacts
    ADD CONSTRAINT opportunity_contacts_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;


--
-- Name: opportunity_contacts opportunity_contacts_opportunity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.opportunity_contacts
    ADD CONSTRAINT opportunity_contacts_opportunity_id_fkey FOREIGN KEY (opportunity_id) REFERENCES public.opportunities(id) ON DELETE CASCADE;


--
-- Name: platform_members platform_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_members
    ADD CONSTRAINT platform_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: signals signals_agent_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signals
    ADD CONSTRAINT signals_agent_run_id_fkey FOREIGN KEY (agent_run_id) REFERENCES public.agent_runs(id) ON DELETE SET NULL;


--
-- Name: signals signals_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.signals
    ADD CONSTRAINT signals_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;


--
-- Name: source_cursors source_cursors_icp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_cursors
    ADD CONSTRAINT source_cursors_icp_id_fkey FOREIGN KEY (icp_id) REFERENCES public.icp_profiles(id) ON DELETE CASCADE;


--
-- Name: watchlist_companies watchlist_companies_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watchlist_companies
    ADD CONSTRAINT watchlist_companies_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE SET NULL;


--
-- Name: agent_runs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.agent_runs ENABLE ROW LEVEL SECURITY;

--
-- Name: agent_runs approved_member_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_access ON public.agent_runs TO authenticated USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: companies approved_member_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_access ON public.companies TO authenticated USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: contacts approved_member_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_access ON public.contacts TO authenticated USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: hidden_signal_preferences approved_member_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_access ON public.hidden_signal_preferences TO authenticated USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: icp_profiles approved_member_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_access ON public.icp_profiles TO authenticated USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: monitoring_jobs approved_member_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_access ON public.monitoring_jobs TO authenticated USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: opportunities approved_member_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_access ON public.opportunities TO authenticated USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: opportunity_contacts approved_member_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_access ON public.opportunity_contacts TO authenticated USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: signal_test_runs approved_member_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_access ON public.signal_test_runs TO authenticated USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: signals approved_member_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_access ON public.signals TO authenticated USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: source_cursors approved_member_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_access ON public.source_cursors TO authenticated USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: watchlist_companies approved_member_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_access ON public.watchlist_companies TO authenticated USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: agent_runs approved_member_guard; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_guard ON public.agent_runs AS RESTRICTIVE USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: companies approved_member_guard; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_guard ON public.companies AS RESTRICTIVE USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: contacts approved_member_guard; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_guard ON public.contacts AS RESTRICTIVE USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: hidden_signal_preferences approved_member_guard; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_guard ON public.hidden_signal_preferences AS RESTRICTIVE USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: icp_profiles approved_member_guard; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_guard ON public.icp_profiles AS RESTRICTIVE USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: monitoring_jobs approved_member_guard; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_guard ON public.monitoring_jobs AS RESTRICTIVE USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: opportunities approved_member_guard; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_guard ON public.opportunities AS RESTRICTIVE USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: opportunity_contacts approved_member_guard; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_guard ON public.opportunity_contacts AS RESTRICTIVE USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: signal_test_runs approved_member_guard; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_guard ON public.signal_test_runs AS RESTRICTIVE USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: signals approved_member_guard; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_guard ON public.signals AS RESTRICTIVE USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: source_cursors approved_member_guard; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_guard ON public.source_cursors AS RESTRICTIVE USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: watchlist_companies approved_member_guard; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approved_member_guard ON public.watchlist_companies AS RESTRICTIVE USING (( SELECT public.is_platform_member() AS is_platform_member)) WITH CHECK (( SELECT public.is_platform_member() AS is_platform_member));


--
-- Name: companies; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;

--
-- Name: contacts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contacts ENABLE ROW LEVEL SECURITY;

--
-- Name: hidden_signal_preferences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hidden_signal_preferences ENABLE ROW LEVEL SECURITY;

--
-- Name: icp_profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.icp_profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: leadsignal_apify_decisions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leadsignal_apify_decisions ENABLE ROW LEVEL SECURITY;

--
-- Name: leadsignal_apify_lots; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leadsignal_apify_lots ENABLE ROW LEVEL SECURITY;

--
-- Name: leadsignal_batches; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leadsignal_batches ENABLE ROW LEVEL SECURITY;

--
-- Name: leadsignal_candidates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leadsignal_candidates ENABLE ROW LEVEL SECURITY;

--
-- Name: leadsignal_cluster_company_calls; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leadsignal_cluster_company_calls ENABLE ROW LEVEL SECURITY;

--
-- Name: leadsignal_contact_recovery_attempts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leadsignal_contact_recovery_attempts ENABLE ROW LEVEL SECURITY;

--
-- Name: leadsignal_contact_recovery_targets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leadsignal_contact_recovery_targets ENABLE ROW LEVEL SECURITY;

--
-- Name: leadsignal_discovery_calls; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leadsignal_discovery_calls ENABLE ROW LEVEL SECURITY;

--
-- Name: leadsignal_dispatches_v1; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leadsignal_dispatches_v1 ENABLE ROW LEVEL SECURITY;

--
-- Name: leadsignal_events_v2; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leadsignal_events_v2 ENABLE ROW LEVEL SECURITY;

--
-- Name: leadsignal_function_backups; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leadsignal_function_backups ENABLE ROW LEVEL SECURITY;

--
-- Name: leadsignal_qualifications_v1; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leadsignal_qualifications_v1 ENABLE ROW LEVEL SECURITY;

--
-- Name: leadsignal_research_attempts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leadsignal_research_attempts ENABLE ROW LEVEL SECURITY;

--
-- Name: leadsignal_rules_backup_v1; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leadsignal_rules_backup_v1 ENABLE ROW LEVEL SECURITY;

--
-- Name: leadsignal_scheduler_status; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leadsignal_scheduler_status ENABLE ROW LEVEL SECURITY;

--
-- Name: leadsignal_batches leadsignal_server_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY leadsignal_server_access ON public.leadsignal_batches TO service_role USING (true) WITH CHECK (true);


--
-- Name: leadsignal_candidates leadsignal_server_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY leadsignal_server_access ON public.leadsignal_candidates TO service_role USING (true) WITH CHECK (true);


--
-- Name: leadsignal_research_attempts leadsignal_server_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY leadsignal_server_access ON public.leadsignal_research_attempts TO service_role USING (true) WITH CHECK (true);


--
-- Name: leadsignal_workers leadsignal_server_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY leadsignal_server_access ON public.leadsignal_workers TO service_role USING (true) WITH CHECK (true);


--
-- Name: leadsignal_workers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leadsignal_workers ENABLE ROW LEVEL SECURITY;

--
-- Name: platform_members member_self_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY member_self_read ON public.platform_members FOR SELECT TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: monitoring_jobs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.monitoring_jobs ENABLE ROW LEVEL SECURITY;

--
-- Name: opportunities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.opportunities ENABLE ROW LEVEL SECURITY;

--
-- Name: opportunity_contacts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.opportunity_contacts ENABLE ROW LEVEL SECURITY;

--
-- Name: platform_members; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.platform_members ENABLE ROW LEVEL SECURITY;

--
-- Name: signal_test_runs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.signal_test_runs ENABLE ROW LEVEL SECURITY;

--
-- Name: signals; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.signals ENABLE ROW LEVEL SECURITY;

--
-- Name: source_cursors; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.source_cursors ENABLE ROW LEVEL SECURITY;

--
-- Name: watchlist_companies; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.watchlist_companies ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION is_platform_ceo(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.is_platform_ceo() FROM PUBLIC;
GRANT ALL ON FUNCTION public.is_platform_ceo() TO anon;
GRANT ALL ON FUNCTION public.is_platform_ceo() TO authenticated;
GRANT ALL ON FUNCTION public.is_platform_ceo() TO service_role;


--
-- Name: FUNCTION is_platform_member(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.is_platform_member() FROM PUBLIC;
GRANT ALL ON FUNCTION public.is_platform_member() TO anon;
GRANT ALL ON FUNCTION public.is_platform_member() TO authenticated;
GRANT ALL ON FUNCTION public.is_platform_member() TO service_role;


--
-- Name: FUNCTION latest_scan_opportunity_ids(target_icp_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.latest_scan_opportunity_ids(target_icp_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.latest_scan_opportunity_ids(target_icp_id uuid) TO anon;
GRANT ALL ON FUNCTION public.latest_scan_opportunity_ids(target_icp_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.latest_scan_opportunity_ids(target_icp_id uuid) TO service_role;


--
-- Name: FUNCTION leadsignal_apify_policy_version(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_apify_policy_version() FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_apify_policy_version() TO service_role;


--
-- Name: FUNCTION leadsignal_assert_event_v2(p_candidate_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_assert_event_v2(p_candidate_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_assert_event_v2(p_candidate_id uuid) TO service_role;


--
-- Name: FUNCTION leadsignal_assert_perplexity_contact(p_batch uuid, p_candidate uuid, p_person jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_assert_perplexity_contact(p_batch uuid, p_candidate uuid, p_person jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_assert_perplexity_contact(p_batch uuid, p_candidate uuid, p_person jsonb) TO anon;
GRANT ALL ON FUNCTION public.leadsignal_assert_perplexity_contact(p_batch uuid, p_candidate uuid, p_person jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_assert_perplexity_contact(p_batch uuid, p_candidate uuid, p_person jsonb) TO service_role;


--
-- Name: FUNCTION leadsignal_assert_worker(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_assert_worker(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_assert_worker(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid) TO anon;
GRANT ALL ON FUNCTION public.leadsignal_assert_worker(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid) TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_assert_worker(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid) TO service_role;


--
-- Name: FUNCTION leadsignal_claim_contact_recovery(p_opportunity_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_claim_contact_recovery(p_opportunity_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_claim_contact_recovery(p_opportunity_id uuid) TO anon;
GRANT ALL ON FUNCTION public.leadsignal_claim_contact_recovery(p_opportunity_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_claim_contact_recovery(p_opportunity_id uuid) TO service_role;


--
-- Name: FUNCTION leadsignal_claim_worker(p_batch_id uuid, p_worker_id uuid, p_lease_seconds integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_claim_worker(p_batch_id uuid, p_worker_id uuid, p_lease_seconds integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_claim_worker(p_batch_id uuid, p_worker_id uuid, p_lease_seconds integer) TO anon;
GRANT ALL ON FUNCTION public.leadsignal_claim_worker(p_batch_id uuid, p_worker_id uuid, p_lease_seconds integer) TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_claim_worker(p_batch_id uuid, p_worker_id uuid, p_lease_seconds integer) TO service_role;


--
-- Name: FUNCTION leadsignal_cleanup_opportunities_11m(p_dry_run boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_cleanup_opportunities_11m(p_dry_run boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_cleanup_opportunities_11m(p_dry_run boolean) TO service_role;


--
-- Name: FUNCTION leadsignal_client_rules_version(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_client_rules_version() FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_client_rules_version() TO service_role;


--
-- Name: FUNCTION leadsignal_contact_recovery_step(p_opportunity_id uuid, p_lease_token uuid, p_action text, p_details jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_contact_recovery_step(p_opportunity_id uuid, p_lease_token uuid, p_action text, p_details jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_contact_recovery_step(p_opportunity_id uuid, p_lease_token uuid, p_action text, p_details jsonb) TO anon;
GRANT ALL ON FUNCTION public.leadsignal_contact_recovery_step(p_opportunity_id uuid, p_lease_token uuid, p_action text, p_details jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_contact_recovery_step(p_opportunity_id uuid, p_lease_token uuid, p_action text, p_details jsonb) TO service_role;


--
-- Name: FUNCTION leadsignal_discovery_budget(p_batch_id uuid, p_signal_key text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_discovery_budget(p_batch_id uuid, p_signal_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_discovery_budget(p_batch_id uuid, p_signal_key text) TO service_role;


--
-- Name: FUNCTION leadsignal_dispatch_discovery(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_attempt_key text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_dispatch_discovery(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_attempt_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_dispatch_discovery(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_attempt_key text) TO service_role;


--
-- Name: FUNCTION leadsignal_enrich_candidate_contacts(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_enrich_candidate_contacts(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_enrich_candidate_contacts(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid) TO anon;
GRANT ALL ON FUNCTION public.leadsignal_enrich_candidate_contacts(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_enrich_candidate_contacts(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid) TO service_role;


--
-- Name: FUNCTION leadsignal_exact_url_guard_v1(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.leadsignal_exact_url_guard_v1() TO anon;
GRANT ALL ON FUNCTION public.leadsignal_exact_url_guard_v1() TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_exact_url_guard_v1() TO service_role;


--
-- Name: FUNCTION leadsignal_five_contacts_guard_v1(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.leadsignal_five_contacts_guard_v1() TO anon;
GRANT ALL ON FUNCTION public.leadsignal_five_contacts_guard_v1() TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_five_contacts_guard_v1() TO service_role;


--
-- Name: FUNCTION leadsignal_heartbeat_worker(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_lease_seconds integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_heartbeat_worker(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_lease_seconds integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_heartbeat_worker(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_lease_seconds integer) TO anon;
GRANT ALL ON FUNCTION public.leadsignal_heartbeat_worker(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_lease_seconds integer) TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_heartbeat_worker(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_lease_seconds integer) TO service_role;


--
-- Name: FUNCTION leadsignal_long_open_evidence_ok(p_batch uuid, p_candidate uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_long_open_evidence_ok(p_batch uuid, p_candidate uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_long_open_evidence_ok(p_batch uuid, p_candidate uuid) TO anon;
GRANT ALL ON FUNCTION public.leadsignal_long_open_evidence_ok(p_batch uuid, p_candidate uuid) TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_long_open_evidence_ok(p_batch uuid, p_candidate uuid) TO service_role;


--
-- Name: FUNCTION leadsignal_monitoring_overview(p_icp_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_monitoring_overview(p_icp_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_monitoring_overview(p_icp_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_monitoring_overview(p_icp_id uuid) TO service_role;


--
-- Name: FUNCTION leadsignal_primary_query_v2(p_signal text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_primary_query_v2(p_signal text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_primary_query_v2(p_signal text) TO service_role;


--
-- Name: FUNCTION leadsignal_publish_candidate(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_publish_candidate(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_publish_candidate(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid) TO anon;
GRANT ALL ON FUNCTION public.leadsignal_publish_candidate(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_publish_candidate(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid) TO service_role;


--
-- Name: FUNCTION leadsignal_qualify_candidate(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_qualify_candidate(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_qualify_candidate(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid) TO service_role;


--
-- Name: FUNCTION leadsignal_record_attempt(p_batch_id uuid, p_lease_token uuid, p_attempt_key text, p_action text, p_details jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_record_attempt(p_batch_id uuid, p_lease_token uuid, p_attempt_key text, p_action text, p_details jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_record_attempt(p_batch_id uuid, p_lease_token uuid, p_attempt_key text, p_action text, p_details jsonb) TO anon;
GRANT ALL ON FUNCTION public.leadsignal_record_attempt(p_batch_id uuid, p_lease_token uuid, p_attempt_key text, p_action text, p_details jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_record_attempt(p_batch_id uuid, p_lease_token uuid, p_attempt_key text, p_action text, p_details jsonb) TO service_role;


--
-- Name: FUNCTION leadsignal_release_worker(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_outcome text, p_checkpoint jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_release_worker(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_outcome text, p_checkpoint jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_release_worker(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_outcome text, p_checkpoint jsonb) TO anon;
GRANT ALL ON FUNCTION public.leadsignal_release_worker(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_outcome text, p_checkpoint jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_release_worker(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_outcome text, p_checkpoint jsonb) TO service_role;


--
-- Name: TABLE leadsignal_apify_lots; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.leadsignal_apify_lots TO anon;
GRANT ALL ON TABLE public.leadsignal_apify_lots TO authenticated;
GRANT ALL ON TABLE public.leadsignal_apify_lots TO service_role;


--
-- Name: FUNCTION leadsignal_reserve_apify_lot(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_signal_key text, p_input jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_reserve_apify_lot(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_signal_key text, p_input jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_reserve_apify_lot(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_signal_key text, p_input jsonb) TO service_role;


--
-- Name: TABLE leadsignal_cluster_company_calls; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.leadsignal_cluster_company_calls TO anon;
GRANT ALL ON TABLE public.leadsignal_cluster_company_calls TO authenticated;
GRANT ALL ON TABLE public.leadsignal_cluster_company_calls TO service_role;


--
-- Name: FUNCTION leadsignal_reserve_cluster_company_call(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_input jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_reserve_cluster_company_call(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_input jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_reserve_cluster_company_call(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_input jsonb) TO anon;
GRANT ALL ON FUNCTION public.leadsignal_reserve_cluster_company_call(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_input jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_reserve_cluster_company_call(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_input jsonb) TO service_role;


--
-- Name: FUNCTION leadsignal_reuse_company_contacts_v2(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_reuse_company_contacts_v2(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_reuse_company_contacts_v2(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_candidate_id uuid) TO service_role;


--
-- Name: FUNCTION leadsignal_runner_4h_policy_version(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_runner_4h_policy_version() FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_runner_4h_policy_version() TO anon;
GRANT ALL ON FUNCTION public.leadsignal_runner_4h_policy_version() TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_runner_4h_policy_version() TO service_role;


--
-- Name: FUNCTION leadsignal_unknown_size_allowed(p_batch uuid, p_candidate uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_unknown_size_allowed(p_batch uuid, p_candidate uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_unknown_size_allowed(p_batch uuid, p_candidate uuid) TO anon;
GRANT ALL ON FUNCTION public.leadsignal_unknown_size_allowed(p_batch uuid, p_candidate uuid) TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_unknown_size_allowed(p_batch uuid, p_candidate uuid) TO service_role;


--
-- Name: FUNCTION leadsignal_v3_finish_apify_lot(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_lot_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_v3_finish_apify_lot(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_lot_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_v3_finish_apify_lot(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_lot_id uuid) TO anon;
GRANT ALL ON FUNCTION public.leadsignal_v3_finish_apify_lot(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_lot_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_v3_finish_apify_lot(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_lot_id uuid) TO service_role;


--
-- Name: TABLE leadsignal_discovery_calls; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.leadsignal_discovery_calls TO anon;
GRANT ALL ON TABLE public.leadsignal_discovery_calls TO authenticated;
GRANT ALL ON TABLE public.leadsignal_discovery_calls TO service_role;


--
-- Name: FUNCTION leadsignal_v3_finish_discovery(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_call_id uuid, p_report jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_v3_finish_discovery(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_call_id uuid, p_report jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_v3_finish_discovery(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_call_id uuid, p_report jsonb) TO anon;
GRANT ALL ON FUNCTION public.leadsignal_v3_finish_discovery(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_call_id uuid, p_report jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_v3_finish_discovery(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_call_id uuid, p_report jsonb) TO service_role;


--
-- Name: FUNCTION leadsignal_v3_reserve_discovery(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_signal_key text, p_provider text, p_input jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.leadsignal_v3_reserve_discovery(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_signal_key text, p_provider text, p_input jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.leadsignal_v3_reserve_discovery(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_signal_key text, p_provider text, p_input jsonb) TO anon;
GRANT ALL ON FUNCTION public.leadsignal_v3_reserve_discovery(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_signal_key text, p_provider text, p_input jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.leadsignal_v3_reserve_discovery(p_batch_id uuid, p_worker_id uuid, p_lease_token uuid, p_signal_key text, p_provider text, p_input jsonb) TO service_role;


--
-- Name: FUNCTION set_updated_at(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.set_updated_at() TO anon;
GRANT ALL ON FUNCTION public.set_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.set_updated_at() TO service_role;


--
-- Name: TABLE agent_runs; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.agent_runs TO anon;
GRANT ALL ON TABLE public.agent_runs TO authenticated;
GRANT ALL ON TABLE public.agent_runs TO service_role;


--
-- Name: TABLE companies; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.companies TO anon;
GRANT ALL ON TABLE public.companies TO authenticated;
GRANT ALL ON TABLE public.companies TO service_role;


--
-- Name: TABLE contacts; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.contacts TO anon;
GRANT ALL ON TABLE public.contacts TO authenticated;
GRANT ALL ON TABLE public.contacts TO service_role;


--
-- Name: TABLE hidden_signal_preferences; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.hidden_signal_preferences TO anon;
GRANT ALL ON TABLE public.hidden_signal_preferences TO authenticated;
GRANT ALL ON TABLE public.hidden_signal_preferences TO service_role;


--
-- Name: TABLE icp_profiles; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.icp_profiles TO anon;
GRANT ALL ON TABLE public.icp_profiles TO authenticated;
GRANT ALL ON TABLE public.icp_profiles TO service_role;


--
-- Name: TABLE leadsignal_apify_decisions; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.leadsignal_apify_decisions TO anon;
GRANT ALL ON TABLE public.leadsignal_apify_decisions TO authenticated;
GRANT ALL ON TABLE public.leadsignal_apify_decisions TO service_role;


--
-- Name: TABLE leadsignal_batches; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.leadsignal_batches TO anon;
GRANT ALL ON TABLE public.leadsignal_batches TO authenticated;
GRANT ALL ON TABLE public.leadsignal_batches TO service_role;


--
-- Name: TABLE leadsignal_candidates; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.leadsignal_candidates TO anon;
GRANT ALL ON TABLE public.leadsignal_candidates TO authenticated;
GRANT ALL ON TABLE public.leadsignal_candidates TO service_role;


--
-- Name: TABLE leadsignal_contact_recovery_attempts; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.leadsignal_contact_recovery_attempts TO anon;
GRANT ALL ON TABLE public.leadsignal_contact_recovery_attempts TO authenticated;
GRANT ALL ON TABLE public.leadsignal_contact_recovery_attempts TO service_role;


--
-- Name: TABLE leadsignal_contact_recovery_targets; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.leadsignal_contact_recovery_targets TO anon;
GRANT ALL ON TABLE public.leadsignal_contact_recovery_targets TO authenticated;
GRANT ALL ON TABLE public.leadsignal_contact_recovery_targets TO service_role;


--
-- Name: TABLE leadsignal_dispatches_v1; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.leadsignal_dispatches_v1 TO service_role;


--
-- Name: TABLE leadsignal_events_v2; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.leadsignal_events_v2 TO service_role;


--
-- Name: TABLE leadsignal_function_backups; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.leadsignal_function_backups TO service_role;


--
-- Name: TABLE leadsignal_qualifications_v1; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.leadsignal_qualifications_v1 TO service_role;


--
-- Name: TABLE leadsignal_research_attempts; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.leadsignal_research_attempts TO anon;
GRANT ALL ON TABLE public.leadsignal_research_attempts TO authenticated;
GRANT ALL ON TABLE public.leadsignal_research_attempts TO service_role;


--
-- Name: TABLE leadsignal_rules_backup_v1; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.leadsignal_rules_backup_v1 TO service_role;


--
-- Name: TABLE leadsignal_scheduler_status; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.leadsignal_scheduler_status TO service_role;


--
-- Name: TABLE leadsignal_v2_function_backup; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.leadsignal_v2_function_backup TO service_role;


--
-- Name: TABLE leadsignal_workers; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.leadsignal_workers TO anon;
GRANT ALL ON TABLE public.leadsignal_workers TO authenticated;
GRANT ALL ON TABLE public.leadsignal_workers TO service_role;


--
-- Name: TABLE monitoring_jobs; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.monitoring_jobs TO anon;
GRANT ALL ON TABLE public.monitoring_jobs TO authenticated;
GRANT ALL ON TABLE public.monitoring_jobs TO service_role;


--
-- Name: TABLE opportunities; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.opportunities TO anon;
GRANT ALL ON TABLE public.opportunities TO authenticated;
GRANT ALL ON TABLE public.opportunities TO service_role;


--
-- Name: COLUMN opportunities.assigned_to; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(assigned_to) ON TABLE public.opportunities TO authenticated;


--
-- Name: TABLE opportunity_contacts; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.opportunity_contacts TO anon;
GRANT ALL ON TABLE public.opportunity_contacts TO authenticated;
GRANT ALL ON TABLE public.opportunity_contacts TO service_role;


--
-- Name: COLUMN opportunity_contacts.phone; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(phone) ON TABLE public.opportunity_contacts TO authenticated;


--
-- Name: COLUMN opportunity_contacts.enrichment_status; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(enrichment_status) ON TABLE public.opportunity_contacts TO authenticated;


--
-- Name: TABLE platform_members; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.platform_members TO anon;
GRANT ALL ON TABLE public.platform_members TO authenticated;
GRANT ALL ON TABLE public.platform_members TO service_role;


--
-- Name: TABLE qualified_opportunities; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.qualified_opportunities TO anon;
GRANT ALL ON TABLE public.qualified_opportunities TO authenticated;
GRANT ALL ON TABLE public.qualified_opportunities TO service_role;


--
-- Name: TABLE rejected_opportunities; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.rejected_opportunities TO anon;
GRANT ALL ON TABLE public.rejected_opportunities TO authenticated;
GRANT ALL ON TABLE public.rejected_opportunities TO service_role;


--
-- Name: TABLE signal_test_runs; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.signal_test_runs TO anon;
GRANT ALL ON TABLE public.signal_test_runs TO authenticated;
GRANT ALL ON TABLE public.signal_test_runs TO service_role;


--
-- Name: TABLE signals; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.signals TO anon;
GRANT ALL ON TABLE public.signals TO authenticated;
GRANT ALL ON TABLE public.signals TO service_role;


--
-- Name: TABLE source_cursors; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.source_cursors TO anon;
GRANT ALL ON TABLE public.source_cursors TO authenticated;
GRANT ALL ON TABLE public.source_cursors TO service_role;


--
-- Name: TABLE watchlist_companies; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.watchlist_companies TO anon;
GRANT ALL ON TABLE public.watchlist_companies TO authenticated;
GRANT ALL ON TABLE public.watchlist_companies TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- PostgreSQL database dump complete
--

\unrestrict JItcVs7YH0ZUIchCbViOlwkhmGmSzaWnOAO5n7E1U4yeUfUNmB5Lwq4SYDXP3Ba

