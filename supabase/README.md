# Schéma Supabase

schema.sql est un export du schéma public fourni le 18 octobre 2026.
Source : PostgreSQL 17.11; outil : pg_dump 18.6.
Contient 30 tables, 34 fonctions, contraintes, index, triggers, politiques RLS
et les droits inclus par pg_dump. Aucun bloc de données INSERT/COPY au niveau
du dump. Les INSERT à l'intérieur des fonctions font partie du code SQL.

Les contrôles de secrets connus n'ont pas trouvé de JWT, token fournisseur,
clé privée ni URL contenant des identifiants. Ce contrôle n'est pas une
certification d'absence de toute information sensible.

## Restauration

Ce fichier est un instantané DDL, pas une migration incrémentale idempotente.
Ne pas l'exécuter sur une base existante de production sans plan de migration.
Il vise un environnement Supabase disposant déjà des schémas auth et extensions
et des rôles anon/authenticated/service_role utilisés par les politiques.

Le dump contient des directives psql produites par pg_dump 18 : utiliser un client
psql compatible, plutôt que coller intégralement le fichier dans un éditeur SQL Web.
La restauration sur un nouveau projet n'a pas été exécutée ni validée ici.
Les extensions requises et les dépendances externes doivent être vérifiées.

## Ce qui n'est pas inclus

- Les lignes métier (ICP, catalogue enregistré, entreprises, contacts, opportunités).
- Les utilisateurs Auth et adhésions platform_members.
- Les réglages du dashboard Supabase, clés, fichiers Storage ou Edge Functions.
- Une éventuelle configuration hors du schéma public.

Préparer séparément des données initiales non sensibles pour un nouvel environnement.
