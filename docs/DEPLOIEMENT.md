# Déploiement et exploitation

## Configuration spécifique au déploiement source

- Emplacement sur le VPS : /docker/leadsignal.
- Données Hermes : montage de ./hermes-data vers /opt/data.
- Projet métier actif : /opt/data/leadsignal_runner/previous-version/project.
- Python Hermes : /opt/hermes/.venv/bin/python3.
- Plateforme : 127.0.0.1:8781 vers port 3000 du conteneur.
- Interface Hermes : 127.0.0.1:4860.
- Les deux fichiers Compose utilisent le réseau externe n8n_default.
  Adapter le réseau sur un autre serveur. Ne pas modifier les services
  nginx/Traefik d'un serveur partagé pour ce déploiement.
- Le collecteur Monitoring contient les identifiants des deux tâches du déploiement source.
  Mettre à jour ces identifiants après leur recréation dans une autre instance Hermes.

## Configuration à compléter

1. Copier les fichiers config/*.env.example vers les mêmes noms sans .example,
   puis renseigner les valeurs directement sur la machine cible.
2. Configurer Supabase dans platform-v1/supabase-client.js :
   URL du projet et clé publique publishable/anon seulement.
   Ne jamais utiliser une clé service_role dans le navigateur.
3. Configurer Hermes (modèle, fournisseurs, MCP) avec ses outils de configuration.
   hermes-data/config.yaml.example décrit uniquement les paramètres de planification.
4. Installer le schéma SQL actuel et examiner ses rôles, extensions et politiques RLS.
   Les comptes Auth, données et paramètres du projet Supabase ne sont pas dans ce dépôt.
5. Donner à l'utilisateur du gateway Hermes les accès nécessaires aux scripts,
   au runner et au dossier des logs. Git ne reproduit pas les UID Linux.
6. Initialiser les dossiers runtime/logs attendus et exécuter les contrôles du runner.

## Démarrage

Depuis le dossier de déploiement configuré :

    docker compose -f compose.yaml up -d hermes
    docker compose -f platform-local.yaml up -d --build platform

Contrôle sans lancement de recherche :

    docker compose -f compose.yaml exec -T hermes /opt/hermes/.venv/bin/python3 /opt/data/leadsignal_runner/test_runner.py --workdir /opt/data/leadsignal_runner/previous-version/project --check

## Planification Hermes

- Fuseau : Europe/Paris.
- Recherche : 0 0 * * 6,0,1 — samedi, dimanche, lundi à minuit.
- Runner : 300 minutes maximum; Hermes : cron.script_timeout_seconds=19800.
- Nettoyage : 0 6 1 * * — premier jour du mois à 06 h.
- Rétention : plus de 11 mois, date d'événement puis date de source.
- Scripts : leadsignal-nightly.sh et leadsignal-cleanup.sh, mode --no-agent.
- Créer d'abord les tâches avec --paused, vérifier les droits et les prochaines
  échéances, puis activer. Ne pas cumuler avec des timers systemd recherche/nettoyage.

Le timer distinct de synchronisation Monitoring fonctionne toutes les minutes.
Il lit Hermes et transmet uniquement les champs de suivi à Supabase.
Il ne déclenche pas les recherches ni les nettoyages.

## Limites

Ce dépôt n'inclut pas les dépendances tierces installées dans le conteneur,
les sessions, les données commerciales ni les credentials.
Une installation propre n'a pas été testée à partir de ce dépôt.
