# Périmètre et contrôles de l'export

Archive source privée : leadsignal-export-prive.tar.gz du 18 octobre 2026.
Sélection explicite des sources actives; aucun extractall ni lien symbolique repris.
Inclus : plateforme, Docker, Monitoring, scripts, runner et son projet métier actif.
Exclus : sauvegardes, staging, dépendances, secrets/configuration privée, logs,
bases SQLite, historiques de sessions et imports de données clients.
La clé PUBLIQUE Supabase du frontend a été remplacée par un paramètre fictif,
ainsi que l'URL du projet; cela exige une configuration avant exécution.
Les noms de variables sont conservés dans des exemples à valeurs vides.
Le code du runner et ses politiques n'ont pas été reformattés pour préserver les empreintes.

Contrôles locaux : recherche des valeurs sensibles issues des fichiers env dans
les sources sélectionnées; détection de formats de tokens connus; analyse syntaxique
Python et JavaScript. Ce contrôle n'est pas une certification d'absence de secrets.
Aucun accès fournisseur, aucune publication et aucun nettoyage de données exécutés.

Schéma public actuel intégré : 30 tables et 34 fonctions, sans données métier.
Reste à compléter pour une reconstruction autonome : données initiales non sensibles,
configuration Hermes/MCP reproductible et validation de déploiement propre.
