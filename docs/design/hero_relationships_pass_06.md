# Relations persistantes entre héros — Pass 06

## Intention

Un héros de *Light in the Dark* ne doit plus être défini uniquement par sa classe, son équipement et ses traces psychologiques. Ce qu'il a vécu avec les autres membres de la compagnie doit laisser une mémoire sociale persistante.

Le système reste volontairement discret : aucune nouvelle batterie de jauges n'apparaît dans le HUD. Les relations sont directionnelles et se révèlent par des comportements, des conséquences tactiques limitées, des phrases de journal et quelques scènes au Sanctuaire.

## Tendances internes

Chaque héros peut développer envers un autre :

- **Confiance** — née du soutien répété, des soins critiques et des actes de protection ;
- **Admiration** — née des actes remarquables, notamment face aux boss ;
- **Méfiance** — réserve durable qui peut gêner la coordination ;
- **Ressentiment** — tension plus profonde, surtout destinée aux futurs choix narratifs et politiques.

Ces valeurs sont stockées dans le héros et sauvegardées avec la compagnie, mais elles ne sont pas montrées comme quatre nombres au joueur.

## Événements qui créent un lien

Le pass 06 privilégie les événements significatifs plutôt qu'une simulation sociale permanente :

- soigner un allié crée de la confiance ;
- le relever lorsqu'il est sous 25 % de ses PV crée davantage de confiance et d'admiration ;
- s'interposer pour un allié Terrifié ou grièvement blessé renforce fortement le lien ;
- porter le coup final à un boss provoque de l'admiration chez les témoins ;
- un repas partagé peut créer une petite mémoire commune une fois par chapitre ;
- une conversation à la Taverne peut ouvrir un lien encore faible ou réduire une relation réellement tendue.

## Conséquences en combat

Les effets restent modestes pour ne jamais remplacer les compétences :

- combattre aux côtés d'un allié en qui le héros a une forte confiance améliore légèrement la résistance à la Peur ;
- une admiration forte peut améliorer légèrement la précision ;
- une relation très tendue peut au contraire réduire légèrement la précision ;
- un allié bénéficiant d'une confiance mutuelle suffisante peut s'interposer une fois par round lorsqu'un compagnon est Terrifié ou proche de la mort.

Le système complète donc Peur/Folie/Espoir au lieu de former une couche de statistiques indépendante.

## Mort et perte

La mort d'un héros n'a plus le même impact pour tout le monde. Un survivant qui faisait profondément confiance au personnage tombé reçoit davantage de Peur ; l'admiration renforce encore ce choc.

Le Mémorial peut ensuite faire ressortir le lien le plus marqué avec un disparu. Cela permet à une mort de devenir une partie de l'histoire de la compagnie plutôt qu'un simple changement de roster.

## Sanctuaire

La Taverne expose des **liens marquants** sous forme de descriptions : « confiance solide », « admiration marquée », « relation tendue », etc. Elle ne montre pas les quatre valeurs internes.

Une seule conversation relationnelle est possible par chapitre. Elle cible le lien qui en a le plus besoin : soit une tension importante à apaiser, soit une relation encore distante susceptible de s'ouvrir.

## Persistance

Les relations sont enregistrées directement dans `GameState.party`, sous `hero.relationships`. Le système de sauvegarde existant sérialise déjà toute la compagnie : les liens survivent donc aux sauvegardes sans créer une seconde source d'état.

## Validation

Le pass 06 est couvert par :

- `relationship_smoke.tscn` ;
- `tools.qa.hero_relationships_audit` ;
- `tests/python/test_hero_relationships.py` ;
- les parcours Godot et audits existants, avec `main_v18.gd` comme nouvelle couche principale.
