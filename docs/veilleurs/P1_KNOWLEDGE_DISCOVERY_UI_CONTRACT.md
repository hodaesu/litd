# P1 — Contrat de connaissance et découverte pour l’UI

Ce lot implémente le socle du point P1 n°8 de la Bible UX/UI sans créer un nouveau propriétaire de données.

`KnowledgeDiscoveryUIContract` rapproche en lecture seule les preuves déjà produites par la mémoire de campagne, les archives des Veilleurs, le bestiaire roguelike, la capture et les découvertes du monde. Il fournit aux futures interfaces une échelle unique :

1. **Inconnu** — seulement ce qui est directement observable ;
2. **Observé** — identité et comportements effectivement rencontrés ;
3. **Étudié** — statistiques corroborées et compétences déjà vues ;
4. **Documenté** — dossier fiable, traits et informations de capture.

Les rencontres et traces simples ne peuvent pas produire seules un dossier complet. Les textes et sanctuaires corroborent une étude ; la recherche et la capture peuvent documenter le sujet. Les preuves inconnues sont rejetées et les doublons sont supprimés.

Le contrat ne sauvegarde rien, n’accorde aucune connaissance et ne modifie jamais ses sources lorsqu’une fiche, une inspection ou un codex est ouvert. Les runtimes existants restent propriétaires de l’observation, de la capture, des textes, des sanctuaires et de la progression persistante.

La tranche suivante branchera progressivement ce modèle sur l’inspection de combat et le bestiaire, avec conservation des comportements existants pour les héros.
