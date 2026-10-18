function safeExternalUrl(value) {
  try { const url = new URL(value); return ['https:', 'http:'].includes(url.protocol) ? escapeHtml(url.href) : '#'; }
  catch { return '#'; }
}
const hiddenSignals = [
  ["fundraising", "Levée de fonds Série A+", "Scale-up funded, hiring budget likely unlocked."],
  ["leader_tech_data_nomination", "Nomination leader tech/data", "New CTO/CDO/VP Eng may rebuild teams within 90 days."],
  ["tech_job_velocity_cluster", "Cluster / velocite d'offres tech", "Several recent tech job posts indicate active team scaling."],
  ["tech_role_repost", "Poste tech non pourvu / reposte", "Repeated tech postings suggest a hard-to-fill role and possible external recruitment need."],
  ["internal_tech_recruiter_hiring", "Embauche recruteur tech interne", "Company is preparing internal recruiting capacity."],
  ["growth_expansion", "Croissance / expansion", "New office, market, contract or strong growth signal."],
  ["registry_change", "Changement registre / BODACC", "Legal or leadership event that may trigger reorganization."],
  ["partnership_contract", "Gain de contrat / partenariat", "New commercial pressure can create hiring needs."],
  ["ma_activity", "Fusion / acquisition", "Integration or restructuring can create demand."],
  ["new_product", "Lancement produit", "Product launch often creates tech, sales and success hiring."]
];

hiddenSignals.splice(0, hiddenSignals.length,
  ["tech_job_velocity_cluster", "Cluster / vélocité d'offres tech", "Plusieurs offres récentes indiquent un développement actif de l'équipe."],
  ["fundraising", "Levée de fonds Série A+", "De nouveaux fonds peuvent débloquer le budget de recrutement IT, data et produit."],
  ["leader_tech_data_nomination", "Nomination leader tech/data", "Un nouveau CTO/CDO peut restructurer ses équipes dans les 90 jours."],
  ["tech_role_repost", "Poste tech non pourvu / reposté", "Des offres répétées suggèrent un poste difficile à pourvoir (besoin d'aide externe)."],
  ["internal_tech_recruiter_hiring", "Embauche recruteur tech interne", "L'entreprise prépare sa capacité de recrutement interne."],
  ["major_contract_partnership", "Grand contrat / partenariat éditeur", "Un nouveau grand contrat peut créer une pression de production/livraison."],
  ["major_tech_data_program", "Programme tech/data majeur", "Les programmes Cloud, ERP, data ou cyber peuvent déclencher des recrutements."],
  ["public_rd_funding", "Financement public R&D", "Le financement public de l'innovation révèle une capacité d'embauche R&D."],
  ["compliance_pressure", "Contrainte conformité DORA / NIS2", "La pression réglementaire peut créer des besoins urgents en tech/sécurité."],
  ["new_product", "Lancement produit", "Le lancement de produit crée souvent des recrutements tech, sales et CS."],
  ["ma_activity", "Fusion / acquisition", "L'intégration post-fusion peut créer des besoins en ERP, data et infrastructure."],
  ["it_data_rfp", "Appel d'offres / RFP services IT-Data", "Les appels d'offres publics révèlent des besoins IT/data externalisés."],
  ["subsidiary_creation", "Création de filiale", "Une nouvelle filiale peut signaler une expansion ou une nouvelle activité technique."],
  ["office_move_expansion", "Déménagement / nouveaux locaux", "De nouveaux bureaux confirment la croissance et une dynamique d'embauche."],
  ["headcount_growth", "Croissance d'effectifs", "La croissance des effectifs confirme la dynamique commerciale et l'embauche."]
);

const signalGuidance = {
  "tech_job_velocity_cluster": "Détecter : Plusieurs offres IT/data/produit complémentaires dans la même entreprise.\nRecherche : offres développeur, data engineer, recrutement équipe\nPreuves : Offres distinctes, dates et entreprise; appliquer les seuils configurés.\nÉcarter : Doublons multi-sites, annonces anciennes, remplacement isolé.\nIntérêt Kaino : besoin potentiel à étayer, jamais recrutement confirmé sans preuve. Respecter ICP, exclusions, dates, sources, doublons et contacts existants.",
  "fundraising": "Détecter : Levée de fonds annoncée pour une entreprise éligible.\nRecherche : levée de fonds, financement, funding round, raised\nPreuves : Annonce datée, entreprise, montant et usage déclaré lorsqu’ils sont disponibles.\nÉcarter : Rumeur, objectif de levée, événement déjà enregistré. Ne pas ajouter de seuil de série ou de montant.\nIntérêt Kaino : besoin potentiel à étayer, jamais recrutement confirmé sans preuve. Respecter ICP, exclusions, dates, sources, doublons et contacts existants.",
  "leader_tech_data_nomination": "Détecter : Arrivée ou promotion à un poste de direction tech, data ou produit.\nRecherche : nommé CTO, DSI, CDO, VP Engineering, Head of Data, Head of Product, appointed\nPreuves : Personne, entreprise, nouveau rôle et annonce datée.\nÉcarter : Offre d’emploi, biographie sans nomination, fonction commerciale ou conseil sans responsabilité tech/data.\nIntérêt Kaino : besoin potentiel à étayer, jamais recrutement confirmé sans preuve. Respecter ICP, exclusions, dates, sources, doublons et contacts existants.",
  "tech_role_repost": "Détecter : Poste IT/data durablement ouvert ou republié.\nRecherche : recrutement développeur, poste ouvert, reposted vacancy\nPreuves : Même poste et employeur, dates comparables; appliquer les seuils configurés.\nÉcarter : Copies sur plusieurs sites prises pour des republications.\nIntérêt Kaino : besoin potentiel à étayer, jamais recrutement confirmé sans preuve. Respecter ICP, exclusions, dates, sources, doublons et contacts existants.",
  "internal_tech_recruiter_hiring": "Détecter : Recherche ou arrivée d’un recruteur dédié aux profils techniques.\nRecherche : Tech Recruiter, Talent Acquisition Tech, Head of Talent\nPreuves : Offre ou annonce datée précisant le périmètre de recrutement technique.\nÉcarter : Annonce d’un cabinet pour un client non identifié; fonction RH sans périmètre pertinent.\nIntérêt Kaino : besoin potentiel à étayer, jamais recrutement confirmé sans preuve. Respecter ICP, exclusions, dates, sources, doublons et contacts existants.",
  "major_contract_partnership": "Détecter : Grand contrat ou partenariat éditeur ayant un périmètre concret.\nRecherche : contrat signé, client sélectionne, partenariat éditeur, selected provider\nPreuves : Entreprise bénéficiaire, annonce datée et portée du contrat ou partenariat.\nÉcarter : Simple logo partenaire ou référencement sans événement documenté.\nIntérêt Kaino : besoin potentiel à étayer, jamais recrutement confirmé sans preuve. Respecter ICP, exclusions, dates, sources, doublons et contacts existants.",
  "major_tech_data_program": "Détecter : Programme d’entreprise structurant en cloud, ERP, data, IA ou cybersécurité.\nRecherche : migration cloud, SAP S/4HANA, lakehouse, programme IA, plateforme data\nPreuves : Entreprise, projet identifié, date et périmètre technique.\nÉcarter : Article général, mention marketing IA, programme national sans bénéficiaire identifié.\nIntérêt Kaino : besoin potentiel à étayer, jamais recrutement confirmé sans preuve. Respecter ICP, exclusions, dates, sources, doublons et contacts existants.",
  "public_rd_funding": "Détecter : Attribution de financement public pour un projet R&D ou innovation.\nRecherche : lauréat France 2030, Bpifrance, subvention R&D, projet financé\nPreuves : Bénéficiaire et attribution datée; projet et montant si disponibles.\nÉcarter : Appel à candidatures, programme générique, simple éligibilité à une aide.\nIntérêt Kaino : besoin potentiel à étayer, jamais recrutement confirmé sans preuve. Respecter ICP, exclusions, dates, sources, doublons et contacts existants.",
  "compliance_pressure": "Détecter : Action concrète d’une entreprise liée à une exigence de conformité.\nRecherche : mise en conformité DORA, NIS2, AI Act, ISO 27001, recrutement conformité\nPreuves : Preuve datée concernant l’entreprise et exigence applicable vérifiée.\nÉcarter : Actualité réglementaire générale; supposer que toutes les entreprises sont concernées.\nIntérêt Kaino : besoin potentiel à étayer, jamais recrutement confirmé sans preuve. Respecter ICP, exclusions, dates, sources, doublons et contacts existants.",
  "new_product": "Détecter : Lancement documenté d’un produit ou d’une offre technique correspondant au signal configuré.\nRecherche : lance, dévoile, nouvelle plateforme, lancement logiciel, product launch\nPreuves : Entreprise, produit, annonce datée; distinguer lancement annoncé et disponibilité effective.\nÉcarter : Page produit ancienne, guide général, mise à jour mineure présentée comme lancement sans preuve.\nIntérêt Kaino : besoin potentiel à étayer, jamais recrutement confirmé sans preuve. Respecter ICP, exclusions, dates, sources, doublons et contacts existants.",
  "ma_activity": "Détecter : Fusion ou acquisition annoncée impliquant une entreprise éligible.\nRecherche : acquisition, rachat, fusion, acquires\nPreuves : Acquéreur, cible, date et statut annoncé ou finalisé du rapprochement.\nÉcarter : Rumeur ou partenariat présenté comme acquisition.\nIntérêt Kaino : besoin potentiel à étayer, jamais recrutement confirmé sans preuve. Respecter ICP, exclusions, dates, sources, doublons et contacts existants.",
  "it_data_rfp": "Détecter : Appel d’offres ou consultation pour des prestations IT/data.\nRecherche : appel d’offres informatique, marché data, AMOA, TMA, RFP\nPreuves : Avis identifié, acheteur, objet, dates et statut de la consultation.\nÉcarter : Attribution de marché présentée comme consultation encore ouverte.\nIntérêt Kaino : besoin potentiel à étayer, jamais recrutement confirmé sans preuve. Respecter ICP, exclusions, dates, sources, doublons et contacts existants.",
  "subsidiary_creation": "Détecter : Création d’une entité distincte liée à une entreprise mère identifiée.\nRecherche : crée une filiale, nouvelle entité, subsidiary, immatriculation\nPreuves : Entité créée, lien avec la société mère et date; recouper annonce et registre si nécessaire.\nÉcarter : Simple bureau, acquisition, guide juridique; un dirigeant commun ne prouve pas à lui seul une filiale.\nIntérêt Kaino : besoin potentiel à étayer, jamais recrutement confirmé sans preuve. Respecter ICP, exclusions, dates, sources, doublons et contacts existants.",
  "office_move_expansion": "Détecter : Nouveaux locaux, agrandissement ou nouveau site documenté.\nRecherche : nouveaux locaux, agrandit, nouveau siège, ouverture site\nPreuves : Entreprise, lieu, annonce datée et nature du changement; distinguer projet et réalisation.\nÉcarter : Annonce immobilière sans occupant identifié; présumer une croissance des effectifs.\nIntérêt Kaino : besoin potentiel à étayer, jamais recrutement confirmé sans preuve. Respecter ICP, exclusions, dates, sources, doublons et contacts existants.",
  "headcount_growth": "Détecter : Hausse documentée des effectifs d’une entreprise.\nRecherche : effectifs en hausse, collaborateurs, workforce growth\nPreuves : Comptages datés comparables ou source décrivant explicitement la hausse, même périmètre.\nÉcarter : Intentions d’embauche, chiffre d’affaires, postes ouverts ou périmètres incompatibles.\nIntérêt Kaino : besoin potentiel à étayer, jamais recrutement confirmé sans preuve. Respecter ICP, exclusions, dates, sources, doublons et contacts existants.",
  "tech_team_attrition": "Détecter : Départs ou instabilité documentés dans une équipe technique.\nRecherche : départ équipe technique, turnover, départ CTO\nPreuves : Faits datés et recoupés, rôles et entreprise identifiés.\nÉcarter : Avis isolé, rumeur ou incident cyber considéré automatiquement comme preuve de départs.\nIntérêt Kaino : besoin potentiel à étayer, jamais recrutement confirmé sans preuve. Respecter ICP, exclusions, dates, sources, doublons et contacts existants."
};

const seedOpportunities = [
  { id: crypto.randomUUID(), company: "Electra", sector: "Mobility", location: "Paris", signalKey: "fundraising", signal: "Levée de fonds Série A+", source: "Press release", priority: "High", score: 91, status: "new", date: "2026-06-20", reason: "Funding plus new charging hubs suggests near-term hiring in operations, tech and sales.", contacts: ["COO", "Head of Operations", "People Lead"] },
  { id: crypto.randomUUID(), company: "Qonto", sector: "FinTech", location: "Paris", signalKey: "leader_tech_data_nomination", signal: "Nomination leader tech/data", source: "Company news", priority: "High", score: 84, status: "new", date: "2026-06-19", reason: "A new engineering leader can indicate a team scaling or reorganization window.", contacts: ["CTO", "VP Engineering", "Talent Acquisition"] },
  { id: crypto.randomUUID(), company: "Yousign", sector: "LegalTech", location: "Caen / Paris", signalKey: "internal_tech_recruiter_hiring", signal: "Embauche recruteur tech interne", source: "Careers page", priority: "Medium", score: 76, status: "review", date: "2026-06-18", reason: "Hiring a tech recruiter is an upstream signal that recruitment volume may increase.", contacts: ["Head of Talent", "CTO", "People Manager"] }
];

const seedRejectedResults = [
  {
    id: crypto.randomUUID(),
    company: "Tessi",
    sector: "Business services / SaaS",
    location: "France",
    signalKey: "new_product",
    signal: "Lancement produit",
    sourceType: "tavily_web_search",
    sourceTitle: "Tessi lance une nouvelle solution SaaS de verification d'identite a distance - Le Journal des Entreprises",
    sourceUrl: "https://www.lejournaldesentreprises.com/breve/tessi-lance-une-nouvelle-solution-saas-de-verification-didentite-distance-2107629",
    publicationDate: "2024-11-18",
    matchedSignal: true,
    matchQuality: "weak",
    rejectionReason: "The article matches the product-launch signal, but it is older than the 6-month acceptance window and Tessi is far outside the ICP size range.",
    checkedAt: "2026-07-05",
    score: 0
  },
  {
    id: crypto.randomUUID(),
    company: "Gravity Capital",
    sector: "AI / Business transfer",
    location: "France",
    signalKey: "new_product",
    signal: "Lancement produit",
    sourceType: "tavily_web_search",
    sourceTitle: "Gravity Capital lance un agent IA pour faciliter et accelerer la transmission d'entreprises",
    sourceUrl: "https://www.lejournaldesentreprises.com/article/la-start-up-gravity-capital-lance-un-agent-ia-pour-faciliter-et-accelerer-la-transmission-2145898",
    publicationDate: "2026-07-01",
    matchedSignal: true,
    matchQuality: "medium",
    rejectionReason: "The launch signal is recent and real, but the ICP match is not verified because the source does not confirm the required 100-600 employee range.",
    checkedAt: "2026-07-05",
    score: 0
  }
];

const state = loadState();
state.signals = state.signals.filter(key => !['technographics_fit', 'executive_recruiting_pain', 'tech_team_attrition'].includes(key));
let selectedId = state.opportunities[0]?.id || null;
let selectedSignalId = state.detectedSignals?.[0]?.id || null;
let selectedPipelineItem = selectedId ? `opp:${selectedId}` : null;
let selectedRejectedId = state.rejectedResults?.[0]?.id || null;
let currentView = "feed";
let activeIcpId = localStorage.getItem("leadSignalActiveIcpId");
const content = document.getElementById("content");
const detail = document.getElementById("detail");
const filters = document.getElementById("filters");
const hasSupabase = typeof supabaseClient !== "undefined";
const HERMES_ENDPOINT_KEY = "leadSignalHermesSignalTestEndpoint";
const HERMES_SECRET_KEY = "leadSignalHermesSignalTestSecret";

function loadState() {
  const saved = null; // Workspace data is loaded from Supabase, never a shared browser cache.
  if (saved) return JSON.parse(saved);
  return {
    icp: {
      name: "ICP principal - IT/Data",
      sectors: "SaaS, FinTech, HealthTech",
      size: "50-500 employees",
      locations: "France",
      roles: "CTO, VP Engineering, Head of Data, Tech Recruiter",
      seniority: "Senior / Leadership",
      minimumScore: 70,
      maxSourceAgeDays: 60,
      instruction: "Detect companies likely to recruit IT, data or product profiles based on funding, leadership changes, internal recruiter hiring, growth and registry signals.",
      otherSignals: ""
    },
    signals: hiddenSignals.slice(0, 5).map(s => s[0]),
    watchlist: [
      { company: "Doctolib", domain: "doctolib.fr", priority: "Strategic", owner: "Aya" },
      { company: "Back Market", domain: "backmarket.fr", priority: "Strategic", owner: "Hiba" }
    ],
    monitoring: { job: null, error: null },
    detectedSignals: [],
    rejectedResults: seedRejectedResults,
    opportunities: seedOpportunities
  };
}

state.detectedSignals ||= [];
state.rejectedResults ||= seedRejectedResults;

function saveState() {
  updateKpis();
}

function csvList(value) {
  return String(value || "").split(",").map(x => x.trim()).filter(Boolean);
}

function parseCompanySize(value) {
  const nums = String(value || "").match(/\d+/g) || [];
  return { min: nums[0] ? Number(nums[0]) : null, max: nums[1] ? Number(nums[1]) : null };
}

function priorityFromScore(score) {
  if (score >= 80) return "High";
  if (score >= 60) return "Medium";
  return "Low";
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function truncateText(value, max = 140) {
  const text = String(value || "").trim();
  if (text.length <= max) return text;
  return `${text.slice(0, max - 1).trim()}…`;
}

function scoreTone(score) {
  if (score >= 80) return "high";
  if (score >= 60) return "medium";
  return "low";
}

function sourceLabel(type) {
  const labels = {
    linkedin_jobs_apify: "Apify LinkedIn Jobs",
    linkedin_jobs: "Apify LinkedIn Jobs",
    apify_linkedin_jobs: "Apify LinkedIn Jobs",
    tavily_web_search: "Recherche Tavily",
    tavily_discovery: "Recherche Tavily",
    groq_candidate_evaluation: "Evaluation IA",
    google_news_rss: "Google News RSS",
    google_news_rss_confirmation: "Confirmation Google News",
    boamp_api: "BOAMP API",
    ted_api: "TED API",
    pappers_api: "Pappers",
    web: "Recherche web",
    press: "Presse",
    company_site: "Site entreprise",
    careers_page: "Page carrieres"
  };
  return labels[type] || type || "Source inconnue";
}

function sourceClass(type) {
  const normalized = String(type || "").toLowerCase();
  if (normalized.includes("apify") || normalized.includes("linkedin_jobs")) return "source-apify";
  if (normalized.includes("tavily")) return "source-tavily";
  if (normalized.includes("google_news")) return "source-google";
  if (normalized.includes("firecrawl")) return "source-firecrawl";
  if (normalized.includes("boamp") || normalized.includes("ted_api")) return "source-public";
  if (normalized.includes("pappers")) return "source-pappers";
  if (normalized.includes("press")) return "source-press";
  return "source-web";
}

function formatDate(value) {
  return value ? String(value).slice(0, 10) : "Non fourni";
}

function sourcePublishedDate(item) {
  return firstMetadataValue(item?.metadata || {}, [
    "source_published_at",
    "published_at",
    "publication_date",
    "posted_at",
    "date_published"
  ]) || item?.sourcePublishedAt || "";
}

function comparableDate(value) {
  const date = String(value || "").slice(0, 10);
  return /^\d{4}-\d{2}-\d{2}$/.test(date) ? date : "";
}

function itemCityText(item) {
  const metadata = item?.metadata || {};
  return [
    item?.city,
    metadata.city,
    metadata.verified_city,
    metadata.company_city,
    item?.location
  ].filter(Boolean).join(" ").toLowerCase();
}

function passesSharedFilters(item, options = {}) {
  const signal = document.getElementById("signalFilter")?.value || "all";
  const city = (document.getElementById("cityFilter")?.value || "").trim().toLowerCase();

  if (signal !== "all" && item?.signalKey !== signal) return false;
  if (city && !itemCityText(item).includes(city)) return false;
  return true;
}

function getSortOrder() {
  return document.getElementById("sortOrder")?.value || "added";
}

function sortByDate(items) {
  const order = getSortOrder();
  return [...items].sort((a, b) => {
    if (order === "added") {
      const addedTime = item => {
        const value = Date.parse(item?.createdAt || item?.checkedAt || item?.detectedAt || item?.date || "");
        return Number.isFinite(value) ? value : 0;
      };
      return addedTime(b) - addedTime(a);
    }
    const dateA = comparableDate(sourcePublishedDate(a) || a?.sourcePublishedAt || a?.publicationDate || a?.detectedAt || a?.date) || "";
    const dateB = comparableDate(sourcePublishedDate(b) || b?.sourcePublishedAt || b?.publicationDate || b?.detectedAt || b?.date) || "";
    return order === "newest" ? dateB.localeCompare(dateA) : dateA.localeCompare(dateB);
  });
}

function detectedDate(item) {
  return item?.detectedAt || item?.date || "";
}

function linkedinPeopleSearchUrl(name, company) {
  const query = [name, company, "LinkedIn"].filter(Boolean).join(" ");
  return `https://www.linkedin.com/search/results/people/?keywords=${encodeURIComponent(query)}`;
}

function priorityLabel(value) {
  const labels = {
    High: "Haute",
    Medium: "Moyenne",
    Low: "Basse",
    Strategic: "Strategique"
  };
  return labels[value] || value || "Non defini";
}

function statusLabel(value) {
  const labels = {
    new: "Nouveau",
    review: "A revoir",
    candidate: "Candidat",
    inserted: "Insere",
    updated: "Mis a jour",
    rejected: "Rejete",
    failed: "Echec",
    active: "Actif",
    paused: "En pause"
  };
  return labels[String(value || "").toLowerCase()] || value || "Non defini";
}

function normalizeRecommendedContacts(value) {
  if (!value) return [];
  if (Array.isArray(value)) return value.filter(Boolean);
  if (typeof value === "object") return Object.values(value).filter(Boolean);
  const text = String(value).trim();
  if (!text) return [];
  try {
    const parsed = JSON.parse(text);
    if (Array.isArray(parsed)) return parsed.filter(Boolean);
    if (parsed && typeof parsed === "object") return Object.values(parsed).filter(Boolean);
  } catch {}
  return text.split(/\r?\n|;\s*/).map(item => item.replace(/^\s*[-*]\s*/, "").trim()).filter(Boolean);
}

function metadataLabel(key) {
  const labels = {
    employee_count: "Effectif",
    company_size: "Taille entreprise",
    company_size_estimate: "Effectif estime",
    employee_count_estimate: "Effectif estime",
    location: "Localisation",
    verified_location: "Localisation verifiee",
    location_match: "Localisation conforme",
    company_size_match: "Taille conforme",
    evidence_source_name: "Source de verification",
    evidence_source_url: "URL de verification",
    confidence: "Confiance",
    source_actor: "Acteur source",
    job_title: "Poste",
    posted_at: "Publie le",
    work_type: "Mode de travail",
    company_linkedin_url: "LinkedIn entreprise"
  };
  return labels[key] || String(key || "").replace(/_/g, " ");
}

function firstMetadataValue(metadata, keys) {
  for (const key of keys) {
    const value = metadata?.[key];
    if (value !== null && value !== undefined && value !== "") return value;
  }
  return "";
}

function evidenceValueFromText(text, key) {
  const escaped = String(key).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = String(text || "").match(new RegExp(`${escaped}:\\s*([^\\n\\r-]+(?:\\s(?!-\\s\\w+?:)[^\\n\\r-]+)*)`, "i"));
  return match ? match[1].trim() : "";
}

function importantMetadataRows(metadata, reason = "") {
  const rows = [];
  return rows
    .filter(([, value]) => value !== null && value !== undefined && value !== "")
    .map(([label, value]) => `<div class="fit-item"><span>${escapeHtml(label)}</span><strong>${escapeHtml(typeof value === "object" ? JSON.stringify(value) : value)}</strong></div>`)
    .join("");
}

function opportunityLocation(o) {
  return firstMetadataValue(o?.metadata || {}, ["verified_location", "location"]) ||
    evidenceValueFromText(o?.reason, "verified_location") ||
    o?.location ||
    "Localisation non fournie";
}

function formatOpportunityReason(o) {
  const raw = String(o.reason || "").replace(/[\t ]+/g, " ").trim();
  const clean = raw
    .split(/ICP evidence:|Key people evidence:|Evidence:/i)[0]
    .replace(/\s*-\s*$/g, "")
    .trim();
  if (clean && clean.length > 30) return clean;
  const sourcePart = o.sourceTitle ? ` La source indique : « ${truncateText(o.sourceTitle, 120)} ». ` : " ";
  return `${o.company} présente un signal commercial exploitable (${signalNameForKey(o.signalKey, o.signal)}).${sourcePart}Le contact est pertinent maintenant pour valider les besoins de recrutement IT/Data, confirmer le calendrier et identifier les décideurs impliqués.`;
}

function plainReasonText(text) {
  return escapeHtml(String(text).replace(/\*\*/g, '').replace(/__/g, ''));
}

function renderReasonBullets(reason) {
  const authored = String(reason || "").split(/\r?\n/).map(line => line.trim()).filter(Boolean);
  if (authored.length && authored.every(line => /^[-*•]\s+/.test(line))) {
    return `<ul class="reason-bullets">${authored.map(line => `<li>${plainReasonText(line.replace(/^[-*•]\s+/, ""))}</li>`).join("")}</ul>`;
  }
  const facts = summarizeOpportunityFacts(reason);
  if (facts.length) {
    return `<ul class="reason-bullets">${facts.map(fact => `<li>${plainReasonText(fact)}</li>`).join("")}</ul>`;
  }
  const sentences = new Intl.Segmenter("fr", { granularity: "sentence" });
  const points = String(reason || "").split(/\r?\n|\s*[•●]\s*/)
    .flatMap(line => Array.from(sentences.segment(line), part => part.segment))
    .map(text => text.replace(/^\s*(?:[-*]|\d+[.)])\s+/, "")
      .replace(/^(?:Il est pertinent de (?:les )?contacter (?:maintenant|cette entreprise) car|Il est opportun de (?:les )?contacter car|Cette opportunité est pertinente car|La source indique\s*:|En effet,|De plus,|Par ailleurs,)\s*/i, "")
      .replace(/\b(?:afin de|dans le but de)\b/gi, "pour")
      .replace(/\b(?:à la suite de|suite à)\b/gi, "après")
      .replace(/\b(?:est en train de|est actuellement en train de)\s+/gi, "")
      .replace(/\b(?:constitue|représente) une opportunité (?:pertinente|intéressante) pour\b/gi, "permet de")
      .replace(/\b(?:il est pertinent de|il serait pertinent de|il est recommandé de|il serait intéressant de)\s+/gi, "")
      .replace(/\b(?:dès maintenant|à l'heure actuelle|à ce jour)\b/gi, "maintenant")
      .trim())
    .filter(Boolean);
  // Separate independent clauses, while keeping lists such as "IT et Data" intact.
  const atomicPoints = points.flatMap(point => point
    .split(/\s*;\s*|\s+(?:ce qui|cela)\s+(?=permet|indique|suggère|implique|crée|nécessite|confirme)|,?\s+et\s+(?=(?:elle|il|l'entreprise|la société)\s)|,?\s+(?=avec des besoins de recrutement|avec un besoin de recrutement)/i)
    .map(part => part.trim().replace(/^[,\s]+|[,;\s]+$/g, ""))
    .filter(Boolean));
  const unique = [...new Set(atomicPoints)];
  const hiring = /recrut|embauch|talent|effectif|équipe|besoin|renforc/i;
  // Keep the triggering fact and a distinct hiring implication as complete thoughts.
  const selected = unique.length ? [unique[0]] : [];
  const implication = unique.slice(1).find(point => hiring.test(point));
  if (implication) selected.push(implication);
  for (const point of unique.slice(1)) {
    if (selected.length >= 3) break;
    if (!selected.includes(point)) selected.push(point);
  }
  return `<ul class="reason-bullets">${selected.map(point => {
    const standalone = /^(?:permet|indique|suggère|implique|crée|nécessite|confirme)\b/i.test(point)
      ? `Ce signal ${point}` : point.replace(/^avec (?:des|un) besoins? de recrutement/i, "Besoins de recrutement");
    const complete = standalone.charAt(0).toUpperCase() + standalone.slice(1);
    return `<li>${plainReasonText(complete)}</li>`;
  }).join("")}</ul>`;
}

function summarizeOpportunityFacts(reason) {
  const text = String(reason || "").replace(/\s+/g, " ").trim();
  const facts = [];
  const activity = text.match(/^([^,]+),\s*((?:éditeur|éditrice|spécialiste|entreprise spécialisée|société spécialisée|fabricant|fournisseur|acteur)[\s\S]+?)(?=\s+basé[e]?\s|\s+avec\s+\d|,\s+(?:a |qui |avec )|\.\s)/i);
  if (activity) facts.push(`${activity[1]} est un ${activity[2]}.`);
  const staff = text.match(/(?:avec|compte|emploie|de)\s+(\d[\d\s]*\s+(?:collaborateurs|salariés|employés))/i);
  const revenue = text.match(/(\d+(?:[,.]\d+)?)\s*(?:millions? d['’]euros|M€)\s+de chiffre d['’]affaires/i);
  if (staff && revenue) facts.push(`**${staff[1].trim()}** et **${revenue[1]} M€ de chiffre d’affaires**.`);
  else if (staff) facts.push(`**${staff[1].trim()}**.`);
  else if (revenue) facts.push(`**${revenue[1]} M€ de chiffre d’affaires**.`);
  const growth = text.match(/doublé (?:ses |les )?effectifs en (\d+ ans)/i);
  const target = text.match(/(?:vise|objectif)[^.]*?(\d+ collaborateurs)/i);
  if (growth) facts.push(`Effectifs **doublés en ${growth[1]}**${target ? ` ; objectif de **${target[1]}**${/vise le statut d['’]ETI/i.test(text) ? " et statut d’ETI" : ""}` : ""}.`);
  // Only emit recognition and strategic direction when both are explicitly stated.
  if (/(?:trophée|lauréat|sélectionné)[^.]*France 2030/i.test(text) && /qualification SecNumCloud/i.test(text)) {
    facts.push("Lauréat **France 2030** pour sa démarche de qualification **SecNumCloud**.");
  }
  if (/stratégie de croissance et de cybersécurité/i.test(text)) {
    facts.push("Dynamique de **croissance et de cybersécurité**.");
  }
  // An incomplete extraction must not hide the main source narrative.
  return facts.length >= 4 ? facts : [];
}

async function loadSupabaseData() {
  if (!hasSupabase) return;
  try {
    const { data: icps, error: icpError } = await supabaseClient
      .from("icp_profiles")
      .select("*")
      .eq("active", true)
      .order("created_at", { ascending: false })
      .limit(1);
    if (icpError) throw icpError;
    if (icps?.[0]) {
      const icp = icps[0];
      activeIcpId = icp.id;
      localStorage.setItem("leadSignalActiveIcpId", activeIcpId);
      state.icp = {
        name: icp.name || state.icp.name,
        sectors: (icp.sectors || []).join(", "),
        size: `${icp.company_size_min || ""}-${icp.company_size_max || ""} employees`,
        locations: (icp.locations || []).join(", "),
        roles: (icp.target_roles || []).join(", "),
        seniority: icp.seniority || "",
        maxSourceAgeDays: icp.max_source_age_days || state.icp.maxSourceAgeDays || 60,
        instruction: icp.qualification_instruction || "",
        otherSignals: state.icp.otherSignals || ""
      };
      const { data: prefs } = await supabaseClient
        .from("hidden_signal_preferences")
        .select("signal_key")
        .eq("icp_id", activeIcpId)
        .eq("active", true);
      state.signalDescriptions = Object.fromEntries((prefs || []).map(p => [p.signal_key, p.custom_description]));
      if (prefs?.length) state.signals = prefs.map(p => p.signal_key).filter(key => !['technographics_fit', 'executive_recruiting_pain', 'tech_team_attrition', 'custom_other'].includes(key));
    }

    const { data: watchlist } = await supabaseClient
      .from("watchlist_companies")
      .select("company_name, domain, priority, owner_name")
      .order("created_at", { ascending: false });
    if (watchlist?.length) {
      state.watchlist = watchlist.map(w => ({
        company: w.company_name,
        domain: w.domain || "",
        priority: w.priority || "Strategic",
        owner: w.owner_name || ""
      }));
    }

    await loadOpportunitiesFromSupabase();
    await loadDetectedSignalsFromSupabase();
    await loadMonitoringFromSupabase();
    saveState();
  } catch (error) {
    console.warn("Supabase load failed, using local data:", error.message);
    toast("Supabase load failed. Using local data.");
  }
}

async function loadDetectedSignalsFromSupabase() {
  if (!hasSupabase) return;
  const { data, error } = await supabaseClient
    .from("signals")
    .select(`
      id,
      signal_key,
      signal_name,
      signal_category,
      source_type,
      source_url,
      source_title,
      source_published_at,
      detected_at,
      raw_excerpt,
      reliability,
      confidence_score,
      metadata_json,
      companies (
        name,
        sector,
        employee_count,
        city,
        country,
        domain
      )
    `)
    .order("detected_at", { ascending: false })
    .limit(50);
  if (error) throw error;
  state.detectedSignals = (data || []).map(s => ({
    id: s.id,
    company: s.companies?.name || "Unknown company",
    sector: s.companies?.sector || "",
    location: [s.companies?.city, s.companies?.country].filter(Boolean).join(" / ") || "",
    domain: s.companies?.domain || "",
    signalKey: s.signal_key || "unknown",
    signal: signalNameForKey(s.signal_key, s.signal_name || "Signal non renseigné"),
    signalCategory: s.signal_category || "",
    sourceType: s.source_type || "",
    source: sourceLabel(s.source_type),
    sourceUrl: s.source_url || "",
    sourceTitle: s.source_title || "",
    sourcePublishedAt: s.source_published_at || "",
    detectedAt: s.detected_at || "",
    rawExcerpt: s.raw_excerpt || "",
    reliability: s.reliability || "",
    confidenceScore: s.confidence_score ?? null,
    metadata: s.metadata_json || {}
  }));
  selectedSignalId = state.detectedSignals[0]?.id || selectedSignalId;
}

async function loadOpportunitiesFromSupabase() {
  if (!hasSupabase) return;
  const opportunitySelect = `
      id,
      title,
      score,
      priority,
      reason,
      status,
      rejection_reason,
      rejected_at,
      assigned_to,
      recommended_contacts,
      source_urls,
      created_at,
      companies (
        name,
        sector,
        employee_count,
        city,
        country,
        domain
      ),
      signals (
        signal_key,
        signal_name,
        signal_category,
        source_type,
        source_url,
        source_title,
        source_published_at,
        detected_at,
        reliability,
        confidence_score,
        raw_excerpt,
        metadata_json
      )
    `;
  let { data, error } = await supabaseClient
    .from("opportunities")
    .select(opportunitySelect)
    .order("created_at", { ascending: false });

  if (error && /assigned_to|schema cache|column/i.test(error.message || "")) {
    const fallbackSelect = opportunitySelect.replace(/\s*assigned_to,\n/, "\n");
    const fallback = await supabaseClient
      .from("opportunities")
      .select(fallbackSelect)
      .order("created_at", { ascending: false });
    data = fallback.data;
    error = fallback.error;
  }

  if (error) throw error;
  if (!data?.length) return;
  const opportunityContacts = await loadOpportunityContactsFromSupabase(data.map(o => o.id));
  const latestIds = new Set();
  if (activeIcpId) {
    try {
      const batch = await supabaseClient.rpc('latest_scan_opportunity_ids', { target_icp_id: activeIcpId });
      if (batch.error) throw batch.error;
      for (const row of batch.data || []) latestIds.add(row.opportunity_id);
    } catch { console.warn('Latest scan badges unavailable: verify migration 09 and scan links.'); }
  }
  const mapOpportunity = o => ({
    id: o.id,
    isLatestScan: latestIds.has(o.id),
    company: o.companies?.name || o.title,
    employeeCount: o.companies?.employee_count ?? null,
    sector: o.companies?.sector || "",
    location: [o.companies?.city, o.companies?.country].filter(Boolean).join(" / ") || "France",
    signalKey: o.signals?.signal_key || "unknown",
    signal: signalNameForKey(o.signals?.signal_key, o.signals?.signal_name || "Signal non renseigné"),
    signalCategory: o.signals?.signal_category || "",
    source: sourceLabel(o.signals?.source_type) || (o.source_urls?.[0] || "Supabase"),
    sourceType: o.signals?.source_type || "",
    sourceUrl: o.signals?.source_url || o.source_urls?.[0] || "",
    sourceUrls: o.source_urls || [],
    sourceTitle: o.signals?.source_title || "",
    sourcePublishedAt: o.signals?.source_published_at || "",
    detectedAt: o.signals?.detected_at || "",
    reliability: o.signals?.reliability || "",
    confidenceScore: o.signals?.confidence_score ?? null,
    rawExcerpt: o.signals?.raw_excerpt || "",
    metadata: o.signals?.metadata_json || {},
    priority: o.priority || priorityFromScore(o.score || 0),
    score: o.score || 0,
    status: o.status || "new",
    assignedTo: o.assigned_to || "",
    createdAt: o.created_at || "",
    date: String(o.created_at || "").slice(0, 10),
    reason: o.reason || "",
    contacts: opportunityContacts[o.id] || [],
    suggestedRoles: o.recommended_contacts || [],
    rejectionReason: o.rejection_reason || "Rejeté par les règles de qualification",
    rejectedAt: o.rejected_at || ""
  });
  const rows = data.map(mapOpportunity);
  state.opportunities = rows.filter(o => ["new", "review", "qualified"].includes(o.status));
  state.rejectedResults = rows
    .filter(o => o.status === "rejected")
    .map(o => ({
      id: o.id,
      company: o.company,
      sector: o.sector,
      location: o.location,
      signalKey: o.signalKey,
      signal: o.signal,
      sourceType: o.sourceType,
      sourceTitle: o.sourceTitle,
      sourceUrl: o.sourceUrl,
      publicationDate: o.sourcePublishedAt,
      matchedSignal: true,
      matchQuality: "rejected",
      rejectionReason: o.rejectionReason,
      createdAt: o.createdAt,
      checkedAt: o.rejectedAt || o.detectedAt,
      score: o.score
    }));
  selectedId = state.opportunities.some(o => o.id === selectedId) ? selectedId : state.opportunities[0]?.id || null;
  selectedPipelineItem = selectedId ? `opp:${selectedId}` : null;
  selectedRejectedId = state.rejectedResults.some(r => r.id === selectedRejectedId) ? selectedRejectedId : state.rejectedResults[0]?.id || null;
}

async function loadOpportunityContactsFromSupabase(opportunityIds) {
  if (!hasSupabase || !opportunityIds?.length) return {};
  const { data, error } = await supabaseClient
    .from("opportunity_contacts")
    .select("id, opportunity_id, full_name, title, linkedin_url, linkedin_search_url, relevance_reason, priority, source_type, phone, enrichment_status")
    .in("opportunity_id", opportunityIds)
    .order("created_at", { ascending: true });

  if (error) {
    const missingTable = error.code === "42P01" || error.code === "PGRST205" || /opportunity_contacts/i.test(error.message || "");
    if (!missingTable) console.warn("Could not load opportunity contacts:", error.message);
    return {};
  }

  return (data || []).reduce((grouped, contact) => {
    grouped[contact.opportunity_id] ||= [];
    grouped[contact.opportunity_id].push({
      id: contact.id,
      name: contact.full_name,
      title: contact.title,
      linkedinUrl: contact.linkedin_url,
      linkedinSearchUrl: contact.linkedin_search_url,
      reason: contact.relevance_reason,
      priority: contact.priority,
      sourceType: contact.source_type,
      phone: contact.phone,
      enrichmentStatus: contact.enrichment_status
    });
    return grouped;
  }, {});
}

function subscribeToOpportunities() {
  if (!hasSupabase) return;
  supabaseClient
    .channel("opportunities-feed")
    .on("postgres_changes", { event: "*", schema: "public", table: "opportunities" }, async () => {
      try {
        await loadOpportunitiesFromSupabase();
        saveState();
        renderView(currentView);
        toast("Dashboard updated from Supabase.");
      } catch (error) {
        console.warn(error.message);
      }
    })
    .subscribe();

  supabaseClient
    .channel("opportunity-contacts-feed")
    .on("postgres_changes", { event: "*", schema: "public", table: "opportunity_contacts" }, async () => {
      try {
        await loadOpportunitiesFromSupabase();
        saveState();
        renderView(currentView);
        toast("Suggested contacts updated from Supabase.");
      } catch (error) {
        console.warn(error.message);
      }
    })
    .subscribe();

  supabaseClient
    .channel("signals-feed")
    .on("postgres_changes", { event: "*", schema: "public", table: "signals" }, async () => {
      try {
        await loadDetectedSignalsFromSupabase();
        saveState();
        if (document.querySelector('.nav-item[data-view="signals"]')?.classList.contains("active")) renderSignals();
        toast("Signals updated from Supabase.");
      } catch (error) {
        console.warn(error.message);
      }
    })
    .subscribe();
}

function updateKpis() {
  document.getElementById("kpiNew").textContent = state.opportunities.filter(o => o.status === "new").length;
  document.getElementById("kpiSignals").textContent = state.signals.length;
  document.getElementById("kpiWatchlist").textContent = state.watchlist.length;
}

function setPage(title, subtitle, showFilters = false) {
  document.getElementById("pageTitle").textContent = title;
  document.getElementById("pageSubtitle").textContent = subtitle;
  filters.style.display = showFilters ? "grid" : "none";
  const feedOnlyFilters = [
    document.getElementById("cityFilter"),
    document.getElementById("sortOrder")
  ].filter(Boolean);
  feedOnlyFilters.forEach(el => {
    el.style.display = showFilters && currentView === "feed" ? "" : "none";
  });
}

function populateSignalFilter() {
  const select = document.getElementById("signalFilter");
  const current = select.value || "all";
  const byKey = new Map(hiddenSignals.map(s => [s[0], s[1]]));
  // Le filtre propose uniquement les 15 signaux du catalogue actuel.
  select.innerHTML = `<option value="all">Tous les signaux</option>` + [...byKey.entries()]
    .sort((a, b) => String(a[1]).localeCompare(String(b[1]), "fr"))
    .map(([key, label]) => `<option value="${escapeHtml(key)}">${escapeHtml(label)}</option>`)
    .join("");
  select.value = byKey.has(current) ? current : "all";
}

function filteredOpportunities() {
  const q = document.getElementById("searchInput").value.toLowerCase();
  const filtered = state.opportunities.filter(o =>
    ["new", "review", "qualified"].includes(o.status) &&
    passesSharedFilters(o) &&
    JSON.stringify(o).toLowerCase().includes(q)
  );
  return sortByDate(filtered);
}

function filteredRejectedResults() {
  const q = document.getElementById("searchInput").value.toLowerCase();
  const signal = document.getElementById("signalFilter").value;
  return state.rejectedResults.filter(r =>
    (signal === "all" || r.signalKey === signal) &&
    JSON.stringify(r).toLowerCase().includes(q)
  );
}

function signalNameForKey(key, fallback = "Signal non renseigné") {
  const historicalLabels = {"executive_recruiting_pain": "Difficultés de recrutement exprimées par un dirigeant", "technographics_fit": "Stack technologique / technographics", "growth_expansion": "Croissance / expansion", "registry_change": "Changement registre / BODACC", "partnership_contract": "Gain de contrat / partenariat"};
  return hiddenSignals.find(s => s[0] === key)?.[1] || historicalLabels[key] || fallback;
}

function sourceForSignal(signalKey) {
  if (["tech_job_velocity_cluster", "tech_role_repost", "internal_tech_recruiter_hiring"].includes(signalKey)) return "apify_linkedin_jobs";
  if (signalKey === "it_data_rfp") return "boamp_api";
  if (["fundraising", "leader_tech_data_nomination", "ma_activity", "office_move_expansion", "new_product"].includes(signalKey)) return "tavily_web_search + google_news_rss_confirmation";
  return "tavily_web_search";
}

function buildSignalTestPayload(signalKey) {
  return {
    action: "signal_quality_test",
    signal_key: signalKey,
    signal_name: signalNameForKey(signalKey),
    expected_source: sourceForSignal(signalKey),
    active_icp_id: activeIcpId || null,
    icp: state.icp,
    search_behavior: {
      max_focused_attempts: 5,
      max_results_total: 10,
      continue_after_rejected_candidate: true,
      stop_after_strong_icp_match: true
    },
    rules: [
      "Test only this one signal.",
      "Use only the correct source for this signal according to soul.md.",
      "Do not insert anything unless the result clearly matches the signal definition and ICP.",
      "If rejected, return the best rejected candidate and exact rejection reason.",
      "Never invent company facts, dates, URLs, scores, or IDs."
    ],
    output_contract: {
      signal_key: signalKey,
      source_used: "",
      status: "inserted | updated | rejected | failed",
      company_name: "",
      source_type: "",
      source_url: "",
      source_title: "",
      publication_date: "",
      matched_signal: true,
      match_quality: "strong | medium | weak | none",
      company_id: "",
      signal_id: "",
      opportunity_id: "",
      score: 0,
      reason: "",
      errors: []
    }
  };
}

function normalizeSignalTestResult(result, signalKey) {
  const raw = Array.isArray(result?.source_tests)
    ? result.source_tests.find(item => item.signal_key === signalKey) || result.source_tests[0]
    : result;
  const status = raw?.status || "failed";
  return {
    id: crypto.randomUUID(),
    company: raw?.company_name || raw?.company || (status === "failed" ? "Hermes connection failed" : "Unknown company"),
    sector: raw?.sector || "",
    location: raw?.location || "",
    signalKey: raw?.signal_key || signalKey,
    signal: signalNameForKey(raw?.signal_key || signalKey),
    sourceType: raw?.source_type || raw?.source_used || sourceForSignal(signalKey),
    sourceTitle: raw?.source_title || "",
    sourceUrl: raw?.source_url || "",
    publicationDate: raw?.publication_date || "",
    matchedSignal: Boolean(raw?.matched_signal),
    matchQuality: raw?.match_quality || (status === "failed" ? "none" : "weak"),
    rejectionReason: raw?.reason || raw?.error || "Hermes did not return a qualification reason.",
    checkedAt: new Date().toISOString().slice(0, 10),
    score: raw?.score || 0,
    status,
    companyId: raw?.company_id || "",
    signalId: raw?.signal_id || "",
    opportunityId: raw?.opportunity_id || "",
    errors: raw?.errors || (raw?.error ? [raw.error] : []),
    rawExcerpt: raw?.raw_excerpt || raw?.reason || ""
  };
}

function isBrowserNetworkError(error) {
  return error instanceof TypeError || /Failed to fetch|NetworkError|Load failed|HTTP 400|HTTP 502|Hermes proxy failed/i.test(error?.message || "");
}

function renderHermesConnectionError(signalKey, endpoint, error) {
  const endpointText = endpoint || "Not configured";
  detail.innerHTML = `
    <h2>Hermes connection failed</h2>
    <p class="muted">The platform could not reach Hermes, so no signal-quality result was created.</p>
    <div class="note rejected-note"><span>Error</span>${escapeHtml(error.message || "Failed to fetch")}</div>
    <div class="metadata-grid">
      <div><span>Signal</span><strong>${escapeHtml(signalNameForKey(signalKey))}</strong></div>
      <div><span>Saved endpoint</span><strong>${escapeHtml(endpointText)}</strong></div>
    </div>
    <div class="note">
      <span>What to check</span>
      Le service de test Hermes doit être configuré sur le serveur de cette plateforme. Contactez votre administrateur.
    </div>
  `;
}

function renderHermesUnexpectedResponse(signalKey, endpoint, raw) {
  detail.innerHTML = `
    <h2>Hermes response received</h2>
    <p class="muted">Hermes accepted the webhook request, but it did not return the final signal-quality JSON contract.</p>
    <div class="note">
      <span>Meaning</span>
      The request reached Hermes. Now we need the webhook to return the agent's final JSON result, not only an acknowledgement.
    </div>
    <div class="metadata-grid">
      <div><span>Signal</span><strong>${escapeHtml(signalNameForKey(signalKey))}</strong></div>
      <div><span>Endpoint</span><strong>${escapeHtml(endpoint || "Not configured")}</strong></div>
    </div>
    <div class="evidence">
      <div class="section-head evidence-head">
        <div>
          <h3>Raw Hermes response</h3>
          <p class="muted">Use this to adjust the webhook delivery/response mode.</p>
        </div>
      </div>
      <pre class="raw-response">${escapeHtml(JSON.stringify(raw, null, 2))}</pre>
    </div>
  `;
}

function renderSignalTestQueued(run, signalKey) {
  detail.innerHTML = `
    <h2>Direct Hermes workflow</h2>
    <p class="muted">Automated browser-side signal queues are disabled. Run Hermes from chat; the UI will refresh from Supabase after Hermes writes results.</p>
    <div class="metadata-grid">
      <div><span>Signal</span><strong>${escapeHtml(signalNameForKey(signalKey))}</strong></div>
      <div><span>Status</span><strong>Manual Hermes chat</strong></div>
    </div>
    <div class="note">
      <span>Next step</span>
      Use the saved ICP and active signal configuration in your Hermes prompt.
    </div>
  `;
}

function configureHermesEndpoint() {
  const input = document.getElementById("hermesEndpointInput");
  const secretInput = document.getElementById("hermesSecretInput");
  if (!input) {
    toast("Open Rejected results to configure the endpoint.");
    return;
  }
  const next = input.value;
  if (next.trim()) {
    localStorage.setItem(HERMES_ENDPOINT_KEY, next.trim());
    toast("Hermes endpoint saved.");
  } else {
    localStorage.removeItem(HERMES_ENDPOINT_KEY);
    toast("Hermes endpoint cleared.");
  }
  if (secretInput && secretInput.value.trim()) {
    localStorage.setItem(HERMES_SECRET_KEY, secretInput.value.trim());
  }
  renderRejectedResults();
}

function clearHermesEndpoint() {
  localStorage.removeItem(HERMES_ENDPOINT_KEY);
  localStorage.removeItem(HERMES_SECRET_KEY);
  toast("Hermes endpoint cleared.");
  renderRejectedResults();
}

class HermesPollTimeoutError extends Error {
  constructor(runId, status) {
    super(`Legacy signal run ${runId} is still ${status || "unknown"}`);
    this.name = "HermesPollTimeoutError";
    this.runId = runId;
    this.status = status || "unknown";
  }
}

function renderHermesStillRunning(runId, signalKey, status) {
  detail.innerHTML = `
    <h2>Legacy run ignored</h2>
    <p class="muted">Queue-based signal runs are no longer used. Run Hermes from chat and refresh after it writes directly to Supabase.</p>
    <div class="note"><span>Signal</span>${escapeHtml(signalNameForKey(signalKey))}</div>
  `;
}

async function runSelectedSignalTest() {
  const select = document.getElementById("signalTestSelect");
  const signalKey = select?.value || document.getElementById("signalFilter").value || "new_product";
  detail.innerHTML = `
    <h2>Direct Hermes workflow</h2>
    <p class="muted">Queue-based signal tests are disabled. Run Hermes from the chat using the active ICP and signal configuration saved in Supabase.</p>
    <div class="note"><span>Selected signal</span>${escapeHtml(signalNameForKey(signalKey))}</div>
  `;
  toast("Queue-based signal tests are disabled.");
}

async function createSignalTestRun(signalKey) {
  throw new Error(`Queue-based signal tests are disabled. Run Hermes chat for ${signalNameForKey(signalKey)}.`);
}

async function pollSignalTestRun(runId, signalKey, timeoutMs = 420000) {
  throw new Error("Queue polling is disabled. Refresh opportunities after Hermes writes directly to Supabase.");
}

function normalizeSignalTestRunResult(row, signalKey) {
  return normalizeSignalTestResult({
    signal_key: row.signal_key || signalKey,
    source_used: row.source_used,
    status: row.status,
    company_name: row.company_name,
    source_type: row.source_type,
    source_url: row.source_url,
    source_title: row.source_title,
    publication_date: row.publication_date,
    matched_signal: row.matched_signal,
    match_quality: row.match_quality,
    company_id: row.company_id,
    signal_id: row.signal_id,
    opportunity_id: row.opportunity_id,
    score: row.score,
    reason: row.reason,
    errors: row.errors || []
  }, signalKey);
}

async function requestSignalTest(endpoint, signalKey) {
  const shouldUseProxy = endpoint.startsWith("http") && !endpoint.startsWith(window.location.origin);
  if (shouldUseProxy) {
    return postSignalTest(`${window.location.origin}/api/hermes-signal-test`, signalKey, endpoint);
  }
  return postSignalTest(endpoint, signalKey);
}

async function postSignalTest(endpoint, signalKey, targetEndpoint = "") {
  const headers = { "Content-Type": "application/json" };
  const response = await authorizedFetch('/api/hermes-signal-test', {
    method: "POST",
    headers,
    body: JSON.stringify(buildSignalTestPayload(signalKey))
  });
  const text = await response.text();
  if (!response.ok) throw new Error(`HTTP ${response.status}: ${text.slice(0, 500)}`);
  const parsed = JSON.parse(text);
  const raw = Array.isArray(parsed?.source_tests)
    ? parsed.source_tests.find(item => item.signal_key === signalKey) || parsed.source_tests[0]
    : parsed;
  if (!["inserted", "updated", "rejected", "failed"].includes(raw?.status)) {
    return { rawOnly: true, raw: parsed };
  }
  return normalizeSignalTestResult(parsed, signalKey);
}

function addRejectedResult(result) {
  state.rejectedResults = [result, ...state.rejectedResults.filter(r =>
    !(r.company === result.company && r.signalKey === result.signalKey && r.sourceUrl === result.sourceUrl)
  )];
  selectedRejectedId = result.id;
}

function signalResultMeetsIcpScore(result) {
  const minimumScore = Number(state.icp.minimumScore || 70);
  return Boolean(result.matchedSignal) && Number(result.score || 0) >= minimumScore;
}

function opportunityFromSignalResult(result) {
  const score = Number(result.score || 0);
  const sourceType = result.sourceType || sourceForSignal(result.signalKey);
  return {
    id: result.opportunityId || crypto.randomUUID(),
    date: result.checkedAt || new Date().toISOString().slice(0, 10),
    status: result.status === "inserted" || result.status === "updated" ? "new" : "candidate",
    company: result.company || "Unknown company",
    sector: result.sector || "",
    location: result.location || "",
    signalKey: result.signalKey,
    signal: signalNameForKey(result.signalKey, result.signal),
    source: sourceType,
    sourceType,
    sourceTitle: result.sourceTitle || "",
    sourceUrl: result.sourceUrl || "",
    sourcePublishedAt: result.publicationDate || "",
    detectedAt: result.checkedAt || new Date().toISOString().slice(0, 10),
    reliability: result.matchQuality === "strong" ? "high" : "medium",
    confidenceScore: score,
    priority: priorityFromScore(score),
    score,
    reason: result.rejectionReason || "Hermes found a candidate that satisfies the ICP score threshold.",
    contacts: ["CEO", "CTO", "Head of Talent"],
    rawExcerpt: result.rawExcerpt || result.rejectionReason || "",
    metadata: {
      source_status: result.status,
      match_quality: result.matchQuality,
      company_id: result.companyId,
      signal_id: result.signalId
    }
  };
}

function addOpportunityCandidate(result) {
  const opportunity = opportunityFromSignalResult(result);
  state.opportunities = [opportunity, ...state.opportunities.filter(o =>
    !(o.company === opportunity.company && o.signalKey === opportunity.signalKey && (o.sourceUrl || "") === (opportunity.sourceUrl || ""))
  )];
  state.rejectedResults = state.rejectedResults.filter(r =>
    !(r.company === result.company && r.signalKey === result.signalKey && (r.sourceUrl || "") === (result.sourceUrl || ""))
  );
  selectedId = opportunity.id;
  selectedPipelineItem = `opp:${opportunity.id}`;
  return opportunity;
}

async function applySignalTestResult(result) {
  if (["inserted", "updated"].includes(result.status)) {
    await loadOpportunitiesFromSupabase();
    await loadDetectedSignalsFromSupabase();
    return "qualified";
  }
  if (signalResultMeetsIcpScore(result)) {
    addOpportunityCandidate(result);
    return "qualified";
  }
  addRejectedResult(result);
  return result.status === "failed" ? "failed" : "rejected";
}

async function runIcpSignalTestsAfterSave() {
  detail.innerHTML = `
    <h2>Direct Hermes workflow</h2>
    <p class="muted">The browser no longer starts signal runs. Save the ICP here, then run Hermes from chat.</p>
  `;
  toast("Queue-based signal tests are disabled.");
}

function renderRejectedResults() {
  setPage("Résultats rejetés", "Résultats correspondant à un signal mais insuffisamment qualifiés pour être insérés.", true);
  populateSignalFilter();
  const rows = filteredRejectedResults().map(r => {
    const sourceMeta = r.sourceTitle || r.sourceUrl || formatDate(r.publicationDate);
    return `
    <tr class="row rejected-row ${selectedRejectedId === r.id ? "selected" : ""}" onclick="selectRejectedResult('${r.id}')">
      <td><div class="company">${escapeHtml(r.company)}</div><div class="muted">${escapeHtml(r.sector)} · ${escapeHtml(r.location)}</div></td>
      <td><div>${escapeHtml(signalNameForKey(r.signalKey, r.signal))}</div></td>
      <td><span class="source-badge ${sourceClass(r.sourceType)}">${sourceLabel(r.sourceType)}</span><div class="muted source-meta">${escapeHtml(sourceMeta)}</div></td>
      <td><span class="pill Low">${escapeHtml(r.matchQuality || "faible")}</span></td>
      <td><div class="rejection-reason">${escapeHtml(r.rejectionReason)}</div></td>
    </tr>`;
  }).join("");
  content.innerHTML = rows ? `<table class="table rejected-table"><thead><tr><th>Entreprise</th><th>Signal vérifié</th><th>Source</th><th>Qualité</th><th>Pourquoi rejeté</th></tr></thead><tbody>${rows}</tbody></table>` : `<div class="empty">Aucun résultat rejeté ne correspond à ces filtres.</div>`;
  renderRejectedDetail();
}

function selectRejectedResult(id) {
  selectedRejectedId = id;
  renderRejectedResults();
}

function renderRejectedDetail() {
  const r = state.rejectedResults.find(x => x.id === selectedRejectedId) || state.rejectedResults[0];
  if (!r) {
    detail.innerHTML = `<h2>Aucun résultat rejeté sélectionné</h2><p class="muted">Les tests de qualité de signal rejetés apparaîtront ici après que Hermes ait évalué les candidats.</p>`;
    return;
  }
  selectedRejectedId = r.id;
  detail.innerHTML = `
    <h2>${escapeHtml(r.company)}</h2>
    <p class="muted">${escapeHtml([r.sector, r.location].filter(Boolean).join(" · "))}</p>
    <div class="detail-grid">
      <div class="box"><span>Statut</span><strong>Rejeté</strong></div>
      <div class="box"><span>Signal correspond</span><strong>${r.matchedSignal ? "Oui" : "Non"}</strong></div>
      <div class="box"><span>Qualité</span><strong>${escapeHtml(r.matchQuality || "faible")}</strong></div>
    </div>
    <div class="note rejected-note"><span>Pourquoi rejeté ?</span>${escapeHtml(r.rejectionReason)}</div>
    <div class="evidence">
      <div class="section-head evidence-head">
        <div>
          <h3>Preuve vérifiée</h3>
          <p class="muted">Candidat trouvé par Hermes mais exclu des opportunités qualifiées.</p>
        </div>
        <span class="source-badge ${sourceClass(r.sourceType)}">${sourceLabel(r.sourceType)}</span>
      </div>
      <div class="detail-grid evidence-grid">
        <div class="box"><span>Publié le</span><strong>${formatDate(r.publicationDate)}</strong></div>
        <div class="box"><span>Vérifié le</span><strong>${formatDate(r.checkedAt)}</strong></div>
        <div class="box"><span>Type de source</span><strong>${escapeHtml(r.sourceType)}</strong></div>
      </div>
      <div class="note source-note">
        <span>Titre de la source</span>
        ${r.sourceUrl ? `<a href="${safeExternalUrl(r.sourceUrl)}" target="_blank" rel="noreferrer">${escapeHtml(r.sourceTitle || r.sourceUrl)}</a>` : escapeHtml(r.sourceTitle || "Aucune URL source")}
      </div>
    </div>
  `;
}

async function saveOpportunityAssignee(opportunityId) {
  const input = document.getElementById(`assignee-${opportunityId}`);
  const assignee = (input?.value || "").trim();
  const opportunity = state.opportunities.find(o => o.id === opportunityId);
  if (opportunity) opportunity.assignedTo = assignee;

  if (!hasSupabase) {
    toast("Assignation enregistrée localement. Supabase n'est pas chargé.");
    renderFeed();
    return;
  }

  const { error } = await supabaseClient
    .from("opportunities")
    .update({ assigned_to: assignee || null })
    .eq("id", opportunityId);

  if (error) {
    toast(`Assignation non enregistrée : ${error.message}`);
    return;
  }

  toast(assignee ? `Opportunité assignée à ${assignee}.` : "Assignation retirée.");
  renderFeed();
}

function formatOpportunityBullets(o) {
  const locationText = opportunityLocation(o) || "Non défini";
  const sectorText = o.sector || o.domain || "Non défini";
  const sourceType = o.sourceType || o.source || "unknown";
  const signalText = [signalNameForKey(o.signalKey, o.signal), sourceLabel(sourceType)].filter(Boolean).join(" • ");
  
  return `
    <ul class="opportunity-bullets">
      <li>${escapeHtml(locationText)}</li>
      <li>${escapeHtml(sectorText)}</li>
      <li>${escapeHtml(signalText)}</li>
    </ul>
  `;
}

function renderFeed() {
  setPage("Opportunités", "", true);
  populateSignalFilter();
  const visibleOpportunities = filteredOpportunities();
  const opportunityRows = visibleOpportunities.map(o => {
    const sourceType = o.sourceType || o.source || "unknown";
    const sourceMeta = o.sourceTitle || o.sourceUrl || formatDate(sourcePublishedDate(o));
    const locationText = opportunityLocation(o);
    return `
    <article class="opportunity-card ${selectedPipelineItem === `opp:${o.id}` ? "selected" : ""}" onclick="selectOpportunity('${o.id}')">
      <div class="candidate-body">
        <div class="candidate-title-row" style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px;">
          <div>
            <h3>${escapeHtml(o.company)} ${o.isLatestScan ? '<span class="new-scan-badge">Nouveau</span>' : ''}</h3>
            ${formatOpportunityBullets(o)}
          </div>
          <div class="assignee-row" style="margin: 0; min-width: 140px;" onclick="event.stopPropagation()">
            <label for="assignee-${escapeHtml(o.id)}">Suivi par</label>
            <input id="assignee-${escapeHtml(o.id)}" type="text" value="${escapeHtml(o.assignedTo || '')}" placeholder="Nom..." onkeypress="if(event.key === 'Enter') { saveOpportunityAssignee('${o.id}'); this.blur(); }">
          </div>
        </div>
        <div class="candidate-meta">
          <span>${escapeHtml(formatDate(sourcePublishedDate(o)))}</span>
        </div>
      </div>
    </article>`;
  });
  const opportunityCompanies = new Set([...state.opportunities, ...state.rejectedResults].map(o => String(o.company || "").toLowerCase()));
  const q = document.getElementById("searchInput").value.toLowerCase();
  const signalOnlyRows = state.detectedSignals
    .filter(s => !s.metadata?.opportunity_deleted && !opportunityCompanies.has(String(s.company || "").toLowerCase()))
    .filter(s => passesSharedFilters(s, { date: s.sourcePublishedAt || s.detectedAt }))
    .filter(s => JSON.stringify(s).toLowerCase().includes(q))
    .map(s => {
      const sourceMeta = s.sourceTitle || s.sourceUrl || formatDate(s.detectedAt);
      return `
      <article class="opportunity-card signal-only-row ${selectedPipelineItem === `sig:${s.id}` ? "selected" : ""}" onclick="selectSignalOnly('${s.id}')">
        <div class="candidate-body">
          <div class="candidate-title-row">
            <div>
              <h3>${escapeHtml(s.company)}</h3>
              ${formatOpportunityBullets(s)}
            </div>
            <span class="pill tag">A qualifier</span>
          </div>
          <div class="candidate-meta">
            <span class="source-badge ${sourceClass(s.sourceType)}">${sourceLabel(s.sourceType)}</span>
            <span>${escapeHtml(formatDate(s.sourcePublishedAt || s.detectedAt))}</span>
          </div>
          <p class="candidate-reason">${escapeHtml(truncateText(sourceMeta, 170))}</p>
        </div>
      </article>`;
    });
  const rows = [...opportunityRows, ...signalOnlyRows].join("");
  content.innerHTML = rows ? `
    <div class="opportunity-list">${rows}</div>
  ` : `<div class="empty">Aucune opportunité ou signal ne correspond à ces filtres.</div>`;
  renderDetail();
}

function selectOpportunity(id) {
  selectedId = id;
  selectedPipelineItem = `opp:${id}`;
  renderFeed();
}

function selectSignalOnly(id) {
  selectedSignalId = id;
  selectedPipelineItem = `sig:${id}`;
  renderFeed();
}

function filteredDetectedSignals() {
  const q = document.getElementById("searchInput").value.toLowerCase();
  const signal = document.getElementById("signalFilter").value;
  return state.detectedSignals.filter(s =>
    (signal === "all" || s.signalKey === signal) &&
    JSON.stringify(s).toLowerCase().includes(q)
  );
}

function renderSignals() {
  setPage("Signaux", "Preuves brutes capturées par Hermes, incluant les signaux de qualification seuls.", true);
  populateSignalFilter();
  const rows = filteredDetectedSignals().map(s => {
    const techs = s.metadata?.detected_technologies || [];
    const sourceMeta = s.sourceTitle || s.sourceUrl || formatDate(s.detectedAt);
    return `
      <tr class="row ${selectedSignalId === s.id ? "selected" : ""}" onclick="selectSignal('${s.id}')">
        <td><div class="company">${escapeHtml(s.company)}</div><div class="muted">${escapeHtml([s.domain, s.location].filter(Boolean).join(" · "))}</div></td>
        <td><div>${escapeHtml(signalNameForKey(s.signalKey, s.signal))}</div></td>
        <td><span class="source-badge ${sourceClass(s.sourceType)}">${sourceLabel(s.sourceType)}</span><div class="muted source-meta">${escapeHtml(sourceMeta)}</div></td>
        <td>${techs.length ? `<div class="tech-list">${techs.slice(0, 5).map(t => `<span>${escapeHtml(t)}</span>`).join("")}</div>` : `<span class="muted">Aucune métadonnée technique</span>`}</td>
        <td><span class="pill ${s.reliability === "high" ? "tag" : "Low"}">${escapeHtml(s.reliability || "inconnue")}</span></td>
      </tr>`;
  }).join("");
  content.innerHTML = rows ? `<table class="table"><thead><tr><th>Entreprise</th><th>Signal</th><th>Source</th><th>Preuve</th><th>Fiabilité</th></tr></thead><tbody>${rows}</tbody></table>` : `<div class="empty">Aucun signal brut trouvé pour le moment.</div>`;
  renderSignalDetail();
}

function selectSignal(id) {
  selectedSignalId = id;
  renderSignals();
}

function renderSignalDetail() {
  const s = state.detectedSignals.find(x => x.id === selectedSignalId) || state.detectedSignals[0];
  if (!s) {
    detail.innerHTML = `<h2>Aucun signal sélectionné</h2><p class="muted">Les signaux de qualification seuls apparaîtront ici après que Hermes ait écrit dans Supabase.</p>`;
    return;
  }
  selectedSignalId = s.id;
  const metadata = s.metadata || {};
  const techs = metadata.detected_technologies || [];
  const categories = metadata.technology_categories || [];
  const evidenceUrls = metadata.evidence_urls || [];
  const metadataRows = Object.entries(metadata)
    .filter(([key, value]) => !["detected_technologies", "technology_categories", "evidence_urls"].includes(key) && value !== null && value !== undefined && value !== "")
    .slice(0, 8)
    .map(([key, value]) => `<div><span>${escapeHtml(key)}</span><strong>${escapeHtml(typeof value === "object" ? JSON.stringify(value) : value)}</strong></div>`)
    .join("");
  detail.innerHTML = `
    <h2>${escapeHtml(s.company)}</h2>
    <p class="muted">${escapeHtml([s.sector, s.location, s.domain].filter(Boolean).join(" · "))}</p>
    <div class="detail-grid">
      <div class="box"><span>Signal</span><strong>${escapeHtml(signalNameForKey(s.signalKey, s.signal))}</strong></div>
      <div class="box"><span>Fiabilité</span><strong>${escapeHtml(s.reliability || "Non noté")}</strong></div>
    </div>
    <div class="evidence">
      <div class="section-head evidence-head">
        <div>
          <h3>Preuves de la source</h3>
          <p class="muted">Données brutes du signal de Hermes, même sans opportunité.</p>
        </div>
        <span class="source-badge ${sourceClass(s.sourceType)}">${sourceLabel(s.sourceType)}</span>
      </div>
      <div class="detail-grid evidence-grid">
        <div class="box"><span>Détecté le</span><strong>${formatDate(s.detectedAt)}</strong></div>
        <div class="box"><span>Publié le</span><strong>${formatDate(s.sourcePublishedAt)}</strong></div>
      </div>
      <div class="note source-note">
        <span>Titre de la source</span>
        ${s.sourceUrl ? `<a href="${safeExternalUrl(s.sourceUrl)}" target="_blank" rel="noreferrer">${escapeHtml(s.sourceTitle || s.sourceUrl)}</a>` : escapeHtml(s.sourceTitle || "Aucune URL source")}
      </div>
      ${s.rawExcerpt ? `<div class="note source-note"><span>Extrait brut</span>${escapeHtml(s.rawExcerpt)}</div>` : ""}
      ${techs.length ? `<div class="note source-note"><span>Technologies détectées</span><div class="tech-list detail-tech-list">${techs.map(t => `<span>${escapeHtml(t)}</span>`).join("")}</div></div>` : ""}
      ${categories.length ? `<div class="note source-note"><span>Catégories technologiques</span><div class="tech-list detail-tech-list">${categories.map(c => `<span>${escapeHtml(c)}</span>`).join("")}</div></div>` : ""}
      ${evidenceUrls.length ? `<div class="note source-note"><span>URLs de preuves</span>${evidenceUrls.map(url => `<a href="${safeExternalUrl(url)}" target="_blank" rel="noreferrer">${escapeHtml(url)}</a>`).join("<br>")}</div>` : ""}
      ${metadataRows ? `<div class="metadata-grid">${metadataRows}</div>` : ""}
    </div>
  `;
}

// ─── Lusha enrichment ────────────────────────────────────────────────────────
async function enrichLushaContact(btn, name, company, contactId) {
  const container = btn.closest(".lusha-enrich");
  const phoneEl = container.querySelector(".lusha-phone");
  if (btn.dataset.loading === 'true') return;
  btn.dataset.loading = 'true';
  const originalIcon = btn.innerHTML;
  phoneEl.style.display = 'none';
  btn.disabled = true;
  btn.textContent = "...";
  try {
    const res = await authorizedFetch("/api/lusha-enrich", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name, company })
    });
    const responseText = await res.text();
    const messages = {
      401: 'Session expirée ou accès refusé. Reconnectez-vous.',
      403: 'Accès au serveur refusé.',
      429: 'Trop de demandes. Réessayez dans une minute.',
      500: 'Configuration du service de contacts à vérifier.',
      502: 'Le service Lusha est indisponible ou a refusé la demande.',
      503: 'Vérification de connexion indisponible. Réessayez.'
    };
    if (!res.ok) {
      let detail; try { detail=JSON.parse(responseText); } catch {}
      const allowed=['provider_auth','provider_credits','provider_access','provider_quota','provider_timeout','invalid_response','provider_unavailable'];
      const message=allowed.includes(detail?.code) ? detail.error : messages[res.status];
      throw new Error((message || `Erreur serveur (${res.status}).`) + (detail?.requestId ? ' Référence : '+detail.requestId : ''));
    }
    let data;
    try { data = JSON.parse(responseText); }
    catch { throw new Error('Réponse du serveur invalide.'); }
    if (data.error || !Array.isArray(data.phones)) throw new Error('Réponse du service de contacts invalide.');
    if (data.phones && data.phones.length > 0) {
      phoneEl.style.color = '#25D366';
      phoneEl.textContent = data.phones[0].number;
      phoneEl.style.display = "inline";
      btn.style.display = "none";
      if (hasSupabase && contactId) {
        const saved = await supabaseClient.from("opportunity_contacts").update({ phone: data.phones[0].number, enrichment_status: "found" }).eq("id", contactId).select('id');
        if (saved.error || !saved.data?.length) {
          btn.style.display='inline';
          throw new Error('Résultat reçu mais non enregistré. Vérifiez la connexion avant de refaire une recherche payante.');
        }
      }
    } else {
      phoneEl.textContent = "Numéro non disponible";
      phoneEl.style.display = "inline";
      btn.style.display = "inline";
      btn.innerHTML = originalIcon;
      btn.title = "Relancer manuellement la recherche (crédits possibles)";
      if (hasSupabase && contactId) {
        const saved = await supabaseClient.from("opportunity_contacts").update({ enrichment_status: "not_found" }).eq("id", contactId).select('id');
        if (saved.error || !saved.data?.length) {
          btn.style.display='inline';
          throw new Error('Résultat reçu mais non enregistré. Vérifiez la connexion avant de refaire une recherche payante.');
        }
      }
    }
  } catch (e) {
    phoneEl.textContent = e instanceof TypeError ? 'Serveur inaccessible. Réessayez.' : e.message;
    phoneEl.style.color = '#b91c1c';
    phoneEl.style.display = "inline";
    btn.innerHTML = originalIcon;
    btn.title = 'Réessayer la recherche du numéro';
  } finally {
    btn.disabled = false;
    btn.dataset.loading = 'false';
  }
}

function renderContactCard(contact, company) {
  const linkedinIcon = '<svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M19 0h-14c-2.761 0-5 2.239-5 5v14c0 2.761 2.239 5 5 5h14c2.762 0 5-2.239 5-5v-14c0-2.761-2.238-5-5-5zm-11 19h-3v-11h3v11zm-1.5-12.268c-.966 0-1.75-.79-1.75-1.764s.784-1.764 1.75-1.764 1.75.79 1.75 1.764-.783 1.764-1.75 1.764zm13.5 12.268h-3v-5.604c0-3.368-4-3.113-4 0v5.604h-3v-11h3v1.765c1.396-2.586 7-2.777 7 2.476v6.759z"/></svg>';
  const phoneIcon = '<svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z"/></svg>';

  function lushaEnrichBtn(c, co) {
    if (!c || typeof c === "string") c = { name: c };
    const name = c.name || c.full_name || "Contact non nommé";

    if (c.phone) {
      return '<span class="lusha-enrich" style="display:inline-flex;align-items:center;gap:4px; transform:translateY(8px);">'
        + '<span class="lusha-phone" style="color:#25D366; font-size:13px; font-weight:600;">' + escapeHtml(c.phone) + '</span>'
        + '</span>';
    }

    if (false && c.enrichmentStatus === "not_found") { // Retry remains explicitly manual.
      return '<span class="lusha-enrich" style="display:inline-flex;align-items:center;gap:4px; transform:translateY(8px);">'
        + '<span class="lusha-phone" style="color:#25D366; font-size:13px; font-weight:600;">Introuvable</span>'
        + '</span>';
    }

    const contactId = c.id || "";
    const safeClick = "enrichLushaContact(this," + JSON.stringify(name) + "," + JSON.stringify(co || "") + "," + JSON.stringify(contactId) + ")";
    return '<span class="lusha-enrich" style="display:inline-flex;align-items:center;gap:4px; transform:translateY(8px);">'
      + '<span class="lusha-icon-btn" onclick="' + escapeHtml(safeClick) + '" title="Chercher le num\u00e9ro" style="color:#25D366; cursor:pointer; display:inline-flex; align-items:center;">' + phoneIcon + '</span>'
      + '<span class="lusha-phone" style="display:none; color:#25D366; font-size:13px; font-weight:600;"></span>'
      + '</span>';
  }

  if (typeof contact === "string") {
    const parts = contact.split(/\s+[—-]\s+/);
    const name = parts[0] || contact;
    return '<div class="contact person-contact"><div class="contact-main">'
      + '<div class="contact-heading" style="display:flex;align-items:center;gap:6px;">'
      + '<strong>' + escapeHtml(name) + '</strong>'
      + lushaEnrichBtn(contact, company)
      + '</div></div></div>';
  }

  const name = contact.name || contact.full_name || "Contact non nommé";
  const linkedinUrl = contact.linkedinUrl || contact.linkedin_url || "";
  const linkedinSearchUrl = contact.linkedinSearchUrl || contact.linkedin_search_url || "";
  const reason = contact.reason || contact.relevance_reason || "";

  return '<div class="contact person-contact"><div class="contact-main">'
    + '<div class="contact-heading" style="display:flex;align-items:center;gap:6px;">'
    + '<strong>' + escapeHtml(name) + '</strong>'
    + (linkedinUrl ? '<a href="' + safeExternalUrl(linkedinUrl) + '" target="_blank" rel="noreferrer" style="color:#0077b5;display:inline-flex;align-items:center;" title="Voir le profil LinkedIn">' + linkedinIcon + '</a>' : '')
    + (!linkedinUrl && linkedinSearchUrl ? '<a href="' + safeExternalUrl(linkedinSearchUrl) + '" target="_blank" rel="noreferrer" style="color:#0077b5;font-size:13px;" title="Recherche LinkedIn : profil non vérifié">Rechercher sur LinkedIn</a>' : '')
    + lushaEnrichBtn(contact, company)
    + '</div>'
    + (reason ? '<p>' + escapeHtml(reason) + '</p>' : '')
    + '</div></div>';
}


function clusterJobSources(opportunity) {
  if (opportunity.signalKey !== "tech_job_velocity_cluster") return [];
  const metadata = opportunity.metadata || {};
  const check = metadata.job_signal_check || {};
  const qualifyingIds = check.output?.qualifying_job_ids;
  const checkedJobs = Array.isArray(check.input?.jobs) ? check.input.jobs.filter(job =>
    !Array.isArray(qualifyingIds) || qualifyingIds.map(String).includes(String(job.job_id))) : [];
  const items = [
    ...(Array.isArray(metadata.cluster_job_sources) ? metadata.cluster_job_sources : []),
    ...checkedJobs
  ];
  const unique = new Map();
  for (const item of items) {
    if (!item) continue;
    const url = item.job_url || item.source_url;
    let parsed;
    try { parsed = new URL(url); } catch { continue; }
    if (!["https:", "http:"].includes(parsed.protocol)) continue;
    const linkedinId = /(^|\.)linkedin\.com$/i.test(parsed.hostname) && parsed.pathname.match(/\/jobs\/view\/(?:[^/]*-)?(\d+)\/?$/);
    const key = linkedinId ? `linkedin:${linkedinId[1]}` : parsed.origin + parsed.pathname.replace(/\/$/, "");
    const date = /^\d{4}-\d{2}-\d{2}(?:$|T)/.test(String(item.published_at || "")) && !Number.isNaN(Date.parse(item.published_at)) ? item.published_at : "";
    const previous = unique.get(key);
    if (!previous || (!previous.published_at && date)) unique.set(key, {job_url: parsed.href, title: item.title || previous?.title || parsed.href, published_at: date});
  }
  return [...unique.values()].slice(0, 5);
}

function renderDetail() {
  if (selectedPipelineItem?.startsWith("sig:")) {
    renderSignalDetail();
    return;
  }
  const o = state.opportunities.find(x => x.id === selectedId) || state.opportunities[0];
  if (!o) {
    detail.innerHTML = `<h2>Aucune opportunité sélectionnée</h2><p class="muted">Les nouveaux leads détectés apparaîtront ici.</p>`;
    return;
  }
  selectedId = o.id;
  const sourceType = o.sourceType || o.source || "inconnu";
  const sourceUrl = o.sourceUrl || "";
  const sourceTitle = o.sourceTitle || sourceUrl || "Aucun titre source capturé";
  const metadata = o.metadata || {};
  const clusterSources = clusterJobSources(o);
  const formalReason = formatOpportunityReason(o);
  const clusterReason = o.signalKey === "tech_job_velocity_cluster"
    ? `<ul class="reason-bullets"><li>${clusterSources.length >= 3 ? clusterSources.length : "Plusieurs"} offres tech, data ou produit publiées récemment par ${escapeHtml(o.company)}.</li><li>Des postes complémentaires sont à pourvoir.</li></ul>`
    : renderReasonBullets(formalReason);
  const contacts = o.contacts || [];
  const recommendedContacts = contacts.length ? contacts : normalizeRecommendedContacts(o.suggestedRoles);
  const fitRows = importantMetadataRows(metadata, o.reason);
  const locationText = opportunityLocation(o);
  const publishedAt = sourcePublishedDate(o);
  const detectedAt = detectedDate(o);
  detail.innerHTML = `
    <div class="detail-profile">
      <div>
        <h2>${escapeHtml(o.company)}</h2>
        ${formatOpportunityBullets(o)}
      </div>
    </div>
    ${fitRows ? `<div class="fit-summary">${fitRows}</div>` : ""}
    <div class="note main-reason"><span>Pourquoi les contacter maintenant ?</span>${clusterReason}</div>
    <div class="source-proof">
      <div class="section-head evidence-head">
        <div>
          <h3>SOURCE</h3>
        </div>
      </div>
      ${clusterSources.length > 0 ? `
        <div class="note source-note" style="margin-top: 8px;">
          ${clusterSources.map(item => `<div class="cluster-job-source"><a href="${safeExternalUrl(item.job_url)}" target="_blank" rel="noreferrer">${escapeHtml(item.title || item.job_url)}</a><small>${item.published_at ? `Publié le ${escapeHtml(formatDate(item.published_at))}` : "Date de publication non renseignée"}</small></div>`).join("")}
        </div>
        <div class="source-date-inline">Détecté le ${formatDate(detectedAt)}</div>
      ` : `
        <div class="note source-note" style="margin-top: 8px;">
          ${sourceUrl ? `<a href="${safeExternalUrl(sourceUrl)}" target="_blank" rel="noreferrer">${escapeHtml(sourceTitle)}</a>` : escapeHtml(sourceTitle)}
        </div>
        <div class="source-date-inline">Publié le ${formatDate(publishedAt)} &bull; Détecté le ${formatDate(detectedAt)}</div>
      `}
    </div>
    <h3>Contacts clés</h3>
    <div class="contacts">
      ${recommendedContacts.length
        ? recommendedContacts.slice(0, 4).map(c => renderContactCard(c, o.company)).join("")
        : `<div class="empty compact-empty">Aucune personne clé sauvegardée pour le moment.</div>`}
    </div>
  `;
}

function renderIcp() {
  setPage("ICP & Signaux", "Configurez ce que Hermes doit surveiller automatiquement.", false);
  const i = state.icp;
  content.innerHTML = `
    <div class="view-card">
      <div class="section-head"><div><h2>Profil Client Idéal (ICP)</h2><p class="muted">Sauvegardez l'ICP et les signaux sélectionnés pour le flux de travail direct Hermes chat.</p></div><button id="saveIcpRun" class="primary-btn" onclick="saveIcpForm()">Enregistrer l'ICP</button></div>
      <div class="settings-grid">
        ${field("Nom de l'ICP", "icpName", i.name)}
        ${field("Niche cible", "icpSectors", i.sectors)}
        ${field("Taille de l'entreprise", "icpSize", i.size)}
        ${field("Localisations", "icpLocations", i.locations)}
        ${field("Contacts cibles", "icpRoles", i.roles)}
        ${field("Séniorité", "icpSeniority", i.seniority)}
        ${field("Age maximum des sources (jours)", "icpMaxSourceAgeDays", i.maxSourceAgeDays || 60, "number")}
        <div class="hidden-signals">
          <div class="section-head"><div><h3>Signaux cachés à surveiller</h3><p class="muted">Hermes utilisera ces signaux pour la surveillance proactive.</p></div><span class="pill tag">${state.signals.length} actifs</span></div>
          <div class="signal-grid">${hiddenSignals.map(s => signalCard(s)).join("")}</div>
        </div>
      </div>
    </div>`;
  detail.innerHTML = `<h2>Flux Hermes direct</h2><p class="muted">Enregistrer cette page met uniquement à jour les paramètres ICP dans Supabase. Le chat Hermes lit ces paramètres et écrit les opportunités qualifiées directement dans Supabase.</p><div class="note"><span>Prêt pour Hermes</span>Cet écran ne sert qu'à sauvegarder la configuration. Les résultats apparaîtront ici après que Hermes ait écrit dans Supabase.</div>`;
}

function field(label, id, value, type = "text") {
  return `<div class="field"><label>${escapeHtml(label)}</label><input id="${escapeHtml(id)}" type="${escapeHtml(type)}" value="${escapeHtml(value)}"></div>`;
}

function signalCard(signal) {
  const checked = state.signals.includes(signal[0]) ? "checked" : "";
  return `<label class="signal-option"><input type="checkbox" value="${signal[0]}" ${checked}><span><strong>${escapeHtml(signal[1])}</strong></span></label>`;
}

async function saveIcpForm() {
  const button = document.getElementById("saveIcpRun");
  if (button) {
    button.disabled = true;
    button.textContent = "Enregistrement...";
  }
  state.icp = {
    name: document.getElementById("icpName").value,
    sectors: document.getElementById("icpSectors").value,
    size: document.getElementById("icpSize").value,
    locations: document.getElementById("icpLocations").value,
    roles: document.getElementById("icpRoles").value,
    seniority: document.getElementById("icpSeniority").value,
    maxSourceAgeDays: Number(document.getElementById("icpMaxSourceAgeDays").value || 60),
    instruction: state.icp.instruction,
    otherSignals: ""
  };
  state.signals = [...document.querySelectorAll(".signal-option input:checked")].map(x => x.value);
  saveState();
  if (hasSupabase) {
    try {
      const size = parseCompanySize(state.icp.size);
      const payload = {
        name: state.icp.name,
        sectors: csvList(state.icp.sectors),
        locations: csvList(state.icp.locations),
        company_size_min: size.min,
        company_size_max: size.max,
        target_roles: csvList(state.icp.roles),
        seniority: state.icp.seniority,
        max_source_age_days: state.icp.maxSourceAgeDays,
        qualification_instruction: state.icp.instruction,
        active: true
      };
      let query = activeIcpId
        ? supabaseClient.from("icp_profiles").update(payload).eq("id", activeIcpId).select().single()
        : supabaseClient.from("icp_profiles").insert(payload).select().single();
      let { data: icp, error: icpError } = await query;
      if (icpError && /max_source_age_days|schema cache|column/i.test(icpError.message || "")) {
        delete payload.max_source_age_days;
        query = activeIcpId
          ? supabaseClient.from("icp_profiles").update(payload).eq("id", activeIcpId).select().single()
          : supabaseClient.from("icp_profiles").insert(payload).select().single();
        ({ data: icp, error: icpError } = await query);
        if (!icpError) toast("ICP enregistré. Ajoutez max_source_age_days dans Supabase pour synchroniser l'âge maximum des sources.");
      }
      if (icpError) throw icpError;
      activeIcpId = icp.id;
      localStorage.setItem("leadSignalActiveIcpId", activeIcpId);

      await supabaseClient.from("hidden_signal_preferences").delete().eq("icp_id", activeIcpId);
      const signalRows = hiddenSignals
        .filter(s => state.signals.includes(s[0]))
        .map((s, idx) => ({
          icp_id: activeIcpId,
          signal_key: s[0],
          signal_name: s[1],
          active: true,
          weight: Math.max(10, 25 - idx * 2),
          custom_description: state.signalDescriptions?.[s[0]] || signalGuidance[s[0]]
        }));
      if (signalRows.length) {
        const { error: prefError } = await supabaseClient.from("hidden_signal_preferences").insert(signalRows);
        if (prefError) throw prefError;
      }

      toast("ICP enregistré dans Supabase.");
    } catch (error) {
      console.error(error);
      toast(`Echec de l'enregistrement Supabase : ${error.message}`);
    }
  } else {
    toast("ICP enregistré localement. Le client Supabase n'est pas chargé.");
  }
  detail.innerHTML = `
    <h2>ICP enregistré</h2>
    <p class="muted">Votre ICP et les signaux actifs sont prêts pour le chat Hermes.</p>
    <div class="note"><span>Prochaine étape</span>Lancez le prompt de test dans Hermes. Hermes écrira les opportunités et les contacts directement dans Supabase.</div>
  `;
  if (button) {
    button.disabled = false;
    button.textContent = "Enregistrer l'ICP";
  }
}

function renderWatchlist() {
  setPage("Watchlist", "Importez des comptes stratégiques pour une surveillance prioritaire.", false);
  content.innerHTML = `
    <div class="view-card">
      <div class="section-head"><div><h2>Importation de liste de suivi</h2><p class="muted">Téléversez un CSV ou ajoutez des comptes manuellement.</p></div><button class="primary-btn" onclick="addManualCompany()">Ajouter l'entreprise</button></div>
      <label class="upload-zone"><input id="watchFile" type="file" accept=".csv"><strong>Déposez votre CSV ici</strong><span>Colonnes : company, domain, priority, owner</span></label>
      <div class="settings-grid">
        ${field("Entreprise", "manualCompany", "")}
        ${field("Domaine", "manualDomain", "")}
        ${field("Priorité", "manualPriority", "Stratégique")}
        ${field("Propriétaire", "manualOwner", "")}
      </div>
      <div class="sample-table" style="margin-top:16px">${watchlistTable()}</div>
    </div>`;
  detail.innerHTML = `<h2>Règles de la liste de suivi</h2><p class="muted">Les entreprises importées sont surveillées en priorité et les alertes sont taguées comme stratégiques.</p><div class="note"><span>Comportement Frontend</span>L'import CSV fonctionne localement dans le navigateur à des fins de démonstration.</div>`;
  document.getElementById("watchFile").addEventListener("change", handleWatchlistFile);
}

function watchlistTable() {
  const rows = state.watchlist.map((w, idx) => `<tr><td><strong>${escapeHtml(w.company)}</strong></td><td>${escapeHtml(w.domain || "")}</td><td><span class="pill tag">${escapeHtml(w.priority || "Stratégique")}</span></td><td>${escapeHtml(w.owner || "")}</td><td><button class="ghost-btn" onclick="removeWatch(${idx})">Retirer</button></td></tr>`).join("");
  return `<table class="table"><thead><tr><th>Entreprise</th><th>Domaine</th><th>Priorité</th><th>Propriétaire</th><th></th></tr></thead><tbody>${rows}</tbody></table>`;
}

async function addManualCompany() {
  const company = document.getElementById("manualCompany").value.trim();
  if (!company) return toast("Company name is required.");
  const row = {
    company,
    domain: document.getElementById("manualDomain").value.trim(),
    priority: document.getElementById("manualPriority").value.trim() || "Strategic",
    owner: document.getElementById("manualOwner").value.trim()
  };
  state.watchlist.push(row);
  saveState();
  if (hasSupabase) {
    const { error } = await supabaseClient.from("watchlist_companies").upsert({
      company_name: row.company,
      domain: row.domain || null,
      priority: row.priority,
      owner_name: row.owner || null
    }, { onConflict: "domain" });
    if (error) toast(`Supabase watchlist save failed: ${error.message}`);
    else toast("Company added to Supabase watchlist.");
  } else {
    toast("Company added locally.");
  }
  renderWatchlist();
}

function removeWatch(index) {
  state.watchlist.splice(index, 1);
  saveState();
  renderWatchlist();
}

function handleWatchlistFile(e) {
  const file = e.target.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    const lines = String(reader.result).split(/\r?\n/).filter(Boolean);
    const rows = lines.slice(1).map(line => line.split(","));
    const imported = [];
    rows.forEach(r => {
      if (r[0]) imported.push({ company: r[0].trim(), domain: (r[1] || "").trim(), priority: (r[2] || "Strategic").trim(), owner: (r[3] || "").trim() });
    });
    state.watchlist.push(...imported);
    saveState();
    if (hasSupabase && imported.length) {
      supabaseClient.from("watchlist_companies").upsert(imported.map(row => ({
        company_name: row.company,
        domain: row.domain || null,
        priority: row.priority,
        owner_name: row.owner || null
      })), { onConflict: "domain" }).then(({ error }) => {
        if (error) toast(`Supabase import failed: ${error.message}`);
        else toast(`${imported.length} companies imported to Supabase.`);
      });
    } else {
      toast(`${imported.length} companies imported locally.`);
    }
    renderWatchlist();
  };
  reader.readAsText(file);
}

let monitoringRequestId = 0;
async function loadMonitoringFromSupabase() {
  const requestId = ++monitoringRequestId;
  const icp = activeIcpId;
  if (!hasSupabase || !icp) {
    state.monitoring = { data: null, error: null };
    return;
  }
  try {
    const { data, error } = await supabaseClient.rpc('leadsignal_monitoring_overview', {p_icp_id: icp});
    if (error) throw error;
    if (requestId !== monitoringRequestId || icp !== activeIcpId) return;
    state.monitoring = { data, error: null };
  } catch {
    if (requestId !== monitoringRequestId || icp !== activeIcpId) return;
    state.monitoring = { data: null, error: 'Le suivi est indisponible. Actualisez la page ou vérifiez la synchronisation du serveur.' };
  }
}
function monitoringDate(value) {
  if (!value) return 'Non disponible';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? 'Non disponible' :
    new Intl.DateTimeFormat('fr-FR', {dateStyle:'medium', timeStyle:'short', timeZone:'Europe/Paris'}).format(date);
}
function monitoringTaskStatus(task, now) {
  if (!task) return 'Non synchronisé';
  const time = Date.parse(task.observed_at);
  if (!Number.isFinite(time) || now - time > 180000 || time - now > 60000) return 'État à actualiser';
  const d = task.details || {};
  if (d.scheduler === 'hermes') {
    if (!d.installed) return 'Tâche Hermes absente';
    if (!d.enabled) return 'En pause';
    const age = d.heartbeat_age_seconds;
    if (age == null || !Number.isFinite(Number(age)) || Number(age) > 180) return 'Planificateur à vérifier';
    const execution = d.execution_state || d.last_status;
    if (['running','executing'].includes(d.job_state) || ['running','started','executing'].includes(d.execution_state)) return 'En cours';
    if (['failed','error','interrupted','cancelled','timed_out'].includes(execution)) return 'Dernière exécution en erreur';
    if (d.job_state === 'scheduled' && d.next_run_at) return 'Planifié';
    return 'État Hermes : ' + (d.job_state || 'inconnu');
  }
  if (d.load_state !== 'loaded') return 'Non installé';
  if (d.service_state === 'failed' || (d.result && d.result !== 'success')) return 'Dernière exécution en erreur';
  if (['active','activating','deactivating'].includes(d.service_state)) return 'En cours';
  if (d.timer_state === 'active' && ['enabled','enabled-runtime'].includes(d.enabled)) return 'Planifié';
  return 'Planification inactive';
}
function renderMonitoring() {
  setPage('Monitoring', 'Recherche nocturne et nettoyage automatique.', false);
  const m = state.monitoring || {};
  const data = m.data || {};
  const schedules = Array.isArray(data.schedules) ? data.schedules : [];
  const now = Date.parse(data.server_time) || Date.now();
  const esc = value => escapeHtml(String(value ?? 'Non disponible'));
  const row = (label,value) => '<div class="monitor-item"><strong>'+esc(label)+'</strong><span>'+esc(value)+'</span></div>';
  const taskCard = (key,title,schedule,description) => {
    const task = schedules.find(t => t.task_key === key);
    const d = task?.details || {};
    const stale = !task || monitoringTaskStatus(task,now) === 'État à actualiser';
    const cleanup = d.last_cleanup;
    if (d.scheduler === 'hermes') {
      const labels = {'0 0 * * 6,0,1':'Samedi, dimanche et lundi à 00 h — 5 heures maximum', '0 6 1 * *':'Le 1er de chaque mois à 06 h — rétention de 11 mois'};
      schedule = labels[d.calendar] || ('Horaire Hermes : ' + (d.calendar || 'non disponible'));
      if (d.timezone && d.timezone !== 'Europe/Paris') schedule += ' (fuseau de planification : ' + d.timezone + ')';
    }
    return '<section class="view-card" style="margin-bottom:16px"><h2>'+esc(title)+'</h2><p>'+esc(schedule)+'</p>'+
      '<div class="monitor-list">'+row('État',monitoringTaskStatus(task,now))+
      row('Prochain passage'+(stale?' (dernière information)':''),monitoringDate(d.next_run_at))+
      row('Dernier démarrage',d.scheduler === 'hermes' && !d.last_started_at ? 'Aucune exécution enregistrée' : monitoringDate(d.last_started_at))+
      row('Dernière fin',monitoringDate(d.last_finished_at))+
      (key==='cleanup' && cleanup ? row('Dernier nettoyage enregistré',cleanup.skipped ? 'Reporté : recherche ou nettoyage déjà en cours' : String(cleanup.deleted ?? 0)+' opportunité(s) supprimée(s)') : '')+
      row('Synchronisation serveur',monitoringDate(task?.observed_at))+'</div><p class="muted">'+esc(description)+'</p>'+
      (stale?'<p role="status">État actuel non confirmé : les informations serveur doivent être synchronisées.</p>':'')+'</section>';
  };
  content.innerHTML = '<div class="view-card"><div class="section-head"><h2>Planification Hermes</h2><button class="primary-btn" onclick="refreshMonitoring()">Actualiser</button></div>'+
    '<p class="muted">Tous les horaires sont affichés en heure de Paris. Synchronisation serveur chaque minute.</p>'+
    (m.error?'<p role="alert">'+esc(m.error)+'</p>':'')+'</div>'+
    taskCard('research','Recherche nocturne','Samedi, dimanche et lundi à 00 h — 5 heures maximum',
      'Utilise les signaux actifs au démarrage. L’exécution continue sur le VPS lorsque le navigateur est fermé.');
  detail.innerHTML = taskCard('cleanup','Nettoyage automatique','Le 1er de chaque mois à 06 h — rétention de 11 mois',
      'Ancienneté de l’événement, à défaut de la source. Les fiches sans date sont conservées. Le nettoyage est reporté si une recherche est en cours.');

}
async function refreshMonitoring() {
  await loadMonitoringFromSupabase();
  if (currentView === 'monitoring') renderMonitoring();
}

function renderSources() {
  setPage("Sources", "Sources de données utilisées par Hermes et les signaux alimentés par chaque source.", false);
  const sourceStack = [
    {
      name: "Apify LinkedIn Jobs",
      type: "linkedin_jobs_apify",
      status: "Actif",
      role: "Détection de signaux d'offres d'emploi pour la vélocité, les renouvellements et le recrutement de recruteurs tech.",
      cost: "Payé au résultat",
      signals: ["tech_job_velocity_cluster", "tech_role_repost", "internal_tech_recruiter_hiring"]
    },
    {
      name: "Tavily Web Search",
      type: "tavily_web_search",
      status: "Actif",
      role: "Recherche intelligente sur le web et les actualités pour une découverte et un contexte élargis.",
      cost: "Crédits API",
      signals: ["fundraising", "leader_tech_data_nomination", "major_contract_partnership", "major_tech_data_program", "public_rd_funding", "compliance_pressure", "new_product", "ma_activity", "office_move_expansion", "tech_team_attrition"]
    },
    {
      name: "Google News RSS",
      type: "google_news_rss",
      status: "Validation",
      role: "Couche de confirmation secondaire (dates, éditeurs) après une découverte initiale par Tavily.",
      cost: "Gratuit",
      signals: ["fundraising", "leader_tech_data_nomination", "ma_activity", "office_move_expansion", "new_product"]
    },
    {
      name: "BOAMP / TED",
      type: "boamp_api",
      status: "Actif",
      role: "Appels d'offres publics officiels pour les besoins informatiques et data externalisés.",
      cost: "Gratuit",
      signals: ["it_data_rfp"]
    },
    {
      name: "Firecrawl",
      type: "firecrawl_technographics",
      status: "Actif",
      role: "Extraction de pages d'entreprises pour détecter la stack technique et les preuves de qualification.",
      cost: "Crédits API",
    }
  ];
  const signalName = key => hiddenSignals.find(s => s[0] === key)?.[1] || key;
  const cards = sourceStack.map(source => `
    <article class="source-card">
      <div class="source-card-head">
        <div>
          <span class="source-badge ${sourceClass(source.type)}">${sourceLabel(source.type)}</span>
          <h3>${escapeHtml(source.name)}</h3>
        </div>
        <span class="pill ${source.status === "Actif" ? "tag" : source.status === "Testing" || source.status === "Validation" ? "Medium" : "Low"}">${source.status}</span>
      </div>
      <p>${escapeHtml(source.role)}</p>
      <div class="source-meta-row">
        <span>Coût</span>
        <strong>${escapeHtml(source.cost)}</strong>
      </div>
      <div class="source-signal-list">
        ${source.signals.map(key => `
          <div>
            <strong>${escapeHtml(signalName(key))}</strong>
            <span>${escapeHtml(key)}</span>
          </div>
        `).join("")}
      </div>
    </article>
  `).join("");
  content.innerHTML = `
    <div class="view-card">
      <div class="section-head">
        <div>
          <h2>Couverture des sources</h2>
          <p class="muted">Carte opérationnelle des sources vers les signaux, basée sur la stack Excel.</p>
        </div>
        <span class="pill tag">${sourceStack.filter(s => s.status === "Actif").length} sources actives</span>
      </div>
      <div class="source-stack-grid">${cards}</div>
    </div>`;
  detail.innerHTML = `
    <h2>Politique des sources</h2>
    <p class="muted">Chaque signal stocké doit inclure le type de source, l'URL de la source, la date de détection, la fiabilité et la preuve brute.</p>
    <div class="note"><span>Actif maintenant</span>Apify, Tavily, BOAMP/TED et Firecrawl sont opérationnels. Le flux RSS Google News est utilisé uniquement comme couche de confirmation secondaire pour des signaux d'actualité plus propres.</div>
    <div class="note"><span>Règle de qualification</span>La technographie Firecrawl peut enrichir une entreprise sans créer d'opportunité autonome.</div>`;
}

function renderView(view) {
  currentView = view;
  document.body.dataset.view = view;
  document.querySelectorAll(".nav-item").forEach(b => b.classList.toggle("active", b.dataset.view === view));
  if (view === "feed") renderFeed();
  if (view === "rejected") renderRejectedResults();
  if (view === "icp") renderIcp();
  if (view === "watchlist") renderWatchlist();
  if (view === "monitoring") renderMonitoring();
  if (view === "sources") renderSources();
}

async function simulateHermesRun() {
  const candidates = [
    { company: "Dust", sector: "AI SaaS", location: "Paris", signalKey: "fundraising", signal: "Levée de fonds Série A+", source: "Funding news", priority: "High", score: 89, reason: "Funding plus AI product expansion indicates likely hiring across engineering and GTM.", contacts: ["CEO", "CTO", "Head of Talent"] },
    { company: "Pennylane", sector: "FinTech", location: "Paris", signalKey: "growth_expansion", signal: "Croissance / expansion", source: "Press", priority: "Medium", score: 78, reason: "Growth and market expansion create likely finance, product and customer success hiring needs.", contacts: ["COO", "Head of People", "VP Product"] },
    { company: "Mistral AI", sector: "AI", location: "Paris", signalKey: "leader_tech_data_nomination", signal: "Nomination leader tech/data", source: "Company announcement", priority: "High", score: 86, reason: "Leadership movement in AI/data suggests team structuring and hiring opportunity.", contacts: ["CTO", "Head of Research", "Talent Lead"] }
  ];
  const next = candidates.find(c => !state.opportunities.some(o => o.company === c.company)) || candidates[Math.floor(Math.random() * candidates.length)];
  const localOpportunity = { id: crypto.randomUUID(), date: new Date().toISOString().slice(0,10), status: "new", ...next };
  if (hasSupabase) {
    try {
      const { data: run, error: runError } = await supabaseClient.from("agent_runs").insert({
        icp_id: activeIcpId || null,
        agent_name: "HermesProactiveAgent",
        run_type: "proactive",
        status: "success",
        started_at: new Date().toISOString(),
        finished_at: new Date().toISOString(),
        signals_checked: state.signals,
        companies_checked: 1,
        new_opportunities_count: 1,
        logs_json: { source: "frontend simulation" }
      }).select().single();
      if (runError) throw runError;

      const { data: company, error: companyError } = await supabaseClient.from("companies").upsert({
        name: next.company,
        domain: `${next.company.toLowerCase().replaceAll(" ", "")}.com`,
        sector: next.sector,
        city: next.location,
        country: "France"
      }, { onConflict: "domain" }).select().single();
      if (companyError) throw companyError;

      const { data: signal, error: signalError } = await supabaseClient.from("signals").upsert({
        company_id: company.id,
        agent_run_id: run.id,
        signal_key: next.signalKey,
        signal_name: next.signal,
        signal_category: "proactive",
        source_type: next.source,
        source_url: `https://example.com/${next.company.toLowerCase().replaceAll(" ", "-")}`,
        source_title: `${next.signal} - ${next.company}`,
        source_published_at: new Date().toISOString().slice(0, 10),
        raw_excerpt: next.reason,
        reliability: "medium",
        confidence_score: next.score,
        metadata_json: { simulated: true }
      }, { onConflict: "company_id,signal_key,source_url" }).select().single();
      if (signalError) throw signalError;

      const { data: opportunity, error: oppError } = await supabaseClient.from("opportunities").upsert({
        company_id: company.id,
        primary_signal_id: signal.id,
        title: `${next.company} - ${next.signal}`,
        score: next.score,
        priority: next.priority,
        reason: next.reason,
        status: "new",
        recommended_contacts: next.contacts,
        source_urls: [signal.source_url]
      }, { onConflict: "company_id,primary_signal_id" }).select().single();
      if (oppError) throw oppError;
      localOpportunity.id = opportunity.id;
      toast("Hermes simulation saved to Supabase.");
    } catch (error) {
      console.error(error);
      toast(`Supabase simulation failed: ${error.message}`);
    }
  }
  state.opportunities.unshift(localOpportunity);

  saveState();
  selectedId = state.opportunities[0].id;
  toast("Hermes run simulated: new opportunity added.");
  renderFeed();
}

function exportCsv() {
  const header = ["company","sector","location","signal","status","reason"];
  const lines = [header.join(",")].concat(state.opportunities.map(o => header.map(k => `"${String(o[k] || "").replaceAll('"','""')}"`).join(",")));
  const blob = new Blob([lines.join("\n")], { type: "text/csv" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "opportunities.csv";
  a.click();
  URL.revokeObjectURL(url);
}

function toast(message) {
  const t = document.createElement("div");
  t.className = "toast";
  t.textContent = message;
  document.body.appendChild(t);
  setTimeout(() => t.remove(), 2400);
}

document.querySelectorAll(".nav-item").forEach(btn => btn.addEventListener("click", () => renderView(btn.dataset.view)));
document.getElementById("searchInput").addEventListener("input", () => renderView(currentView));
document.getElementById("signalFilter").addEventListener("change", () => renderView(currentView));
document.getElementById("cityFilter").addEventListener("input", () => renderView(currentView));
document.getElementById("sortOrder").addEventListener("change", () => renderView(currentView));
window.selectOpportunity = selectOpportunity;
window.selectSignal = selectSignal;
window.selectSignalOnly = selectSignalOnly;
window.selectRejectedResult = selectRejectedResult;
window.runSelectedSignalTest = runSelectedSignalTest;
window.configureHermesEndpoint = configureHermesEndpoint;
window.clearHermesEndpoint = clearHermesEndpoint;
window.saveIcpForm = saveIcpForm;
window.addManualCompany = addManualCompany;
window.removeWatch = removeWatch;
window.refreshMonitoring = refreshMonitoring;
updateKpis();
loadSupabaseData().finally(() => {
  subscribeToOpportunities();
  renderView("feed");
});

let sharedRefreshRunning = false;
async function refreshSharedWorkspace() {
  if (sharedRefreshRunning || document.hidden) return;
  sharedRefreshRunning = true;
  try {
    const { data: allowed, error: accessError } = await supabaseClient.rpc('is_platform_member');
    if (accessError || !allowed) { document.body.classList.add('locked'); location.reload(); return; }
    const before = JSON.stringify([state.opportunities, state.detectedSignals, state.rejectedResults, (currentView==='monitoring' ? state.monitoring : null)]);
    await Promise.all([loadOpportunitiesFromSupabase(), loadDetectedSignalsFromSupabase(), loadMonitoringFromSupabase()]);
    const after = JSON.stringify([state.opportunities, state.detectedSignals, state.rejectedResults, (currentView==='monitoring' ? state.monitoring : null)]);
    if (before !== after) { saveState(); renderView(currentView); }
  } catch (error) { console.warn('Shared refresh failed'); }
  finally { sharedRefreshRunning = false; }
}
setInterval(refreshSharedWorkspace, 15000);
window.addEventListener('focus', refreshSharedWorkspace);
