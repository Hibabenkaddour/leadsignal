# LeadSignal — KAINO

Sources récupérées depuis la sauvegarde du VPS du 18 octobre 2026.
Cette copie est destinée au versionnement. Elle ne contient ni données Supabase,
ni sessions Hermes, ni clés privées, ni mots de passe, ni historiques de recherches.

## État de préparation

- Plateforme, backend, runner, politiques métier, skills LeadSignal et Monitoring : inclus.
- Docker et scripts de lancement : inclus.
- Tâches Hermes : horaires documentés, sans importer l'historique d'exécution.
- Schéma public Supabase : inclus dans supabase/schema.sql (30 tables, 34 fonctions).
  Les données initiales, comptes et réglages externes restent à configurer.
- Hermes lui-même est une dépendance externe, référencée par l'image Docker épinglée.
- Modèles, connexions MCP et fournisseurs doivent être configurés dans Hermes.
- La sauvegarde a été réalisée à chaud : aucune cohérence des bases runtime n'est revendiquée;
  ces bases ne sont pas incluses ici.

## Arborescence

| Chemin | Rôle |
|---|---|
| platform-v1/ | Interface HTML/CSS/JS et serveur Node |
| hermes-data/leadsignal_runner/ | Contrôleur Python, fournisseurs, qualification, coûts |
| hermes-data/leadsignal_runner/previous-version/project/ | Projet métier ACTIF malgré son nom historique : règles et skills |
| hermes-data/scripts/ | Lanceurs des tâches Hermes |
| monitoring/ | Collecteur des états Hermes vers Supabase |
| config/*.env.example | Noms des variables nécessaires, sans valeurs |
| compose.yaml | Service Hermes |
| platform-local.yaml | Service plateforme |
| supabase/ | Export du schéma public actuel et notes de restauration |
| docs/ | Exploitation, planification et limites de l'export |

## Fonctionnement

L'utilisateur définit l'ICP et les signaux actifs. Le runner recherche les événements,
vérifie les preuves et l'éligibilité de l'entreprise, déduplique les événements métier,
publie les opportunités et enrichit les contacts. Les résultats sont stockés dans Supabase.

Les 15 signaux sont : cluster d'offres tech; poste tech non pourvu/reposté;
embauche de recruteur tech interne; levée de fonds Série A+; nomination tech/data;
grand contrat/partenariat éditeur; programme tech/data majeur; financement public R&D;
conformité DORA/NIS2; lancement produit; fusion/acquisition; appel d'offres IT-Data;
création de filiale; déménagement/nouveaux locaux; croissance d'effectifs.

Les règles exécutables et les politiques du projet font foi. Les fichiers historiques
peuvent conserver des noms v1 ou «4h»; ces noms ne constituent pas un paramétrage.

## Installation et exploitation

Consulter docs/DEPLOIEMENT.md. Ne pas lancer ces fichiers sur un nouveau serveur
avant d'avoir installé le schéma Supabase et configuré les fournisseurs.

## Avant GitHub

Utiliser un dépôt privé. Ne jamais y déposer l'archive privée téléchargée, les exports
de données SQL, .env, config.yaml, auth.json, les clés ou les bases de sessions.
Les contrôles effectués sont décrits dans docs/EXPORT.md.
