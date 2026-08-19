# Pass 23 — Rencontres sociales persistantes

## Intention

Cette passe élargit les rencontres de terrain au-delà des groupes anonymes. Une personne blessée, une famille séparée, un ancien soldat, une caravane de réfugiés ou une créature consciente peut désormais conserver un destin après la première scène, réapparaître plus tard et modifier le Sanctuaire ou un réseau extérieur.

Aucune branche n'est traduite en score moral global. Une aide peut échouer ou créer de nouvelles contraintes ; un refus n'entraîne pas automatiquement la mort ; une personne laissée libre peut agir hors champ et revenir autrement.

## Blessé transportable — Edrin

Au Moulin Calciné, Edrin ne peut plus marcher correctement. La compagnie peut détacher deux porteurs et des ressources pour l'envoyer au Sanctuaire, le stabiliser sur place ou laisser un abri balisé.

L'évacuation coûte réellement nourriture, eau, bandages et médicament. Edrin devient alors une présence du Sanctuaire et peut ouvrir `q_edrin_last_waypoint`. Les branches où il reste sur la route peuvent aussi revenir au chapitre III : l'aide locale ou un simple balisage ne sont donc pas des états morts du scénario.

## Famille séparée — Sela et Nerin

Dans la Forêt Morte, Sela suit un jeu de fils rouges laissé par son enfant. La compagnie peut chercher, baliser une route ou poursuivre l'expédition.

Les deux premières branches conduisent à une vraie scène de retrouvailles à la Chapelle Effondrée. Plus tard, Sela et Nerin transforment cette expérience en tableau de personnes recherchées reliant le relais au Sanctuaire.

La branche de refus ne tue pas la famille par décret narratif : au chapitre III, des voyageurs peuvent apprendre qu'ils se sont retrouvés par un autre réseau. Cela conserve le poids du choix sans fabriquer une punition automatique.

## Ancien soldat et prisonnier — Tarek

Tarek porte un ancien uniforme retourné. Il peut être envoyé au Sanctuaire sous escorte civile, interrogé puis relâché, ou laissé sous la garde des voyageurs qui le retenaient déjà.

Les trois branches ont un retour au Poste Diplomatique Effondré. Son information peut voyager avec lui, sans lui ou par ceux qui l'ont retenu. S'il rejoint le Sanctuaire, il devient un témoin sous surveillance et peut ouvrir `q_tarek_order_without_uniform`.

La quête ne cherche pas à décider si « l'armée » est collectivement innocente ou coupable. Elle confronte ce qu'un soldat de rang pouvait lire dans les codes de marche avec une dépêche réellement présente dans le chapitre III.

## Réfugiés — caravane de la ligne basse

Nima conduit une caravane qui ne demande pas à être absorbée dans une communauté. Le joueur peut ouvrir la route du Sanctuaire, proposer un relais indépendant ou refuser de décider de leur destination.

Au chapitre III, les trois branches peuvent produire une communauté encore vivante : réseau distribué autour du Sanctuaire, halte indépendante ou route choisie sans la compagnie. Les conséquences portent sur les lieux, les rumeurs et les personnes, jamais sur une jauge « bon/mauvais ».

## Créature consciente — Sivra

Sivra parle et revendique sa propre identité. Elle n'est pas automatiquement traitée comme un monstre à capturer. Le joueur peut négocier un pacte territorial, la libérer sans dette ou la chasser de la route.

Le pacte ne la recrute pas. Elle reste indépendante et peut revenir près du Complexe du Seuil parce qu'elle choisit d'aider. Si elle est simplement libérée, elle peut aussi répondre plus tard sans qu'une dette lui soit imposée. Si elle est bannie, le retour prend la forme d'une trace de territoire éloigné : distance durable plutôt que vengeance obligatoire.

Cette règle ne remplace pas le système de créatures capturables. Elle ajoute un cas où la conscience et l'autonomie du personnage rendent la relation sociale plus appropriée que le recrutement.

## Mémoire du monde et Sanctuaire

`CommunityRuntime` reçoit les transitions de ces rencontres via son mécanisme existant `encounter_transitions`. Les états de personne, rumeurs, faits collectifs et quêtes restent donc dans le même payload de sauvegarde que Mara, Yoren et Iven.

Les nouveaux habitants éventuels alimentent automatiquement :

- `sanctuary_people()` ;
- les cues de population ;
- les cues visuels ;
- la présence dans l'écran Communauté ;
- les rumeurs et faits locaux ;
- les quêtes émergentes.

Les personnes qui choisissent ou obtiennent une vie indépendante restent persistantes sans être artificiellement déplacées vers le Sanctuaire.

## Boucle recherchée

Rencontre de terrain → choix avec coût réel ou renoncement → mémoire des héros → état persistant de la personne → rumeur/fait local → retour ultérieur → éventuelle présence au Sanctuaire ou réseau indépendant → quête émergente ou information nouvelle.

Le monde doit continuer à vivre lorsque le joueur ne regarde pas.
