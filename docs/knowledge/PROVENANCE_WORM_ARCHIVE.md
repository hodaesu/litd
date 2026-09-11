# Archivage externe des preuves de provenance LITD

## Statut

`READY_FOR_CONNECTION`

Le workflow `.github/workflows/provenance-worm-archive.yml` est volontairement inactif tant que les variables de sécurité ne sont pas explicitement activées. Il n'a aucune autorité sur le Core, les cibles de design ou le gameplay.

## Objectif

Après un `Provenance Checkpoint` valide et signé avec Sigstore, copier le checkpoint et son bundle Sigstore vers un stockage Cloudflare R2 privé protégé par une règle **Bucket Lock**. Le stockage externe sert uniquement de preuve indépendante et durable.

Chaîne visée :

`Measurement Provenance -> Provenance Checkpoint -> Sigstore/Rekor -> R2 privé + Bucket Lock -> reçu d'archivage`

## Invariants

- le workflow n'archive qu'un `Provenance Checkpoint` déjà signé ;
- la signature Sigstore est revérifiée avant toute copie externe ;
- les objets sont rangés sous une clé adressée par contenu : `litd/provenance/v1/<checkpoint_hash>/...` ;
- un objet existant n'est jamais remplacé silencieusement : il est relu et comparé octet pour octet ;
- un écart de hash provoque un échec ;
- les objets sont relus après l'envoi afin de vérifier le SHA-256 de bout en bout ;
- `core_write_allowed=false` ;
- `automatic_target_change_allowed=false` ;
- le workflow ne possède pas de permission permettant de modifier la configuration Bucket Lock.

## Configuration Cloudflare à faire manuellement une seule fois

1. Créer un bucket R2 privé, par exemple `litd-provenance`.
2. Dans `R2 -> bucket -> Settings -> Bucket lock rules`, ajouter une règle couvrant le préfixe `litd/provenance/`.
3. Choisir une durée de rétention adaptée. Pour démarrer, une durée fixe est préférable à un verrouillage indéfini afin d'éviter une conservation impossible à corriger en cas d'erreur de configuration.
4. Créer un token R2 limité au bucket concerné avec accès objet lecture/écriture. Ne pas lui donner la permission de modifier la configuration du bucket ou les règles de verrouillage.
5. Conserver l'Access Key ID et le Secret Access Key uniquement dans les secrets GitHub Actions.

Cloudflare documente que les Bucket Locks empêchent la suppression et l'écrasement des objets pendant la période de rétention. Les règles peuvent cibler un préfixe et s'appliquent aussi aux objets existants.

## Configuration GitHub requise

### Secrets Actions

- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`

### Variables Actions

- `R2_ACCOUNT_ID`
- `R2_BUCKET_NAME`
- `LITD_WORM_BUCKET_LOCK_CONFIRMED=true`
- `LITD_WORM_ARCHIVE_ENABLED=true`

Activer `LITD_WORM_ARCHIVE_ENABLED` en dernier, uniquement après création du bucket, activation du Bucket Lock et installation des identifiants.

## Vérification attendue

À chaque `Provenance Checkpoint` réussi sur `main`, le workflow doit :

1. télécharger l'artifact signé exact du run déclencheur ;
2. vérifier la signature et l'identité OIDC du workflow `provenance-checkpoint.yml` ;
3. calculer le `checkpoint_hash` ;
4. archiver le checkpoint et le bundle Sigstore sous un préfixe content-addressed ;
5. relire chaque objet depuis R2 et comparer son SHA-256 ;
6. produire `LITD_WORM_ARCHIVE_RECEIPT` comme artifact GitHub.

Le statut `DEPLOYED / VERIFIED` ne doit être utilisé qu'après un premier run réel ayant produit un reçu `ARCHIVED_AND_ROUNDTRIP_VERIFIED` et après vérification indépendante que la règle Bucket Lock est réellement active côté Cloudflare.

## Limite de confiance

`LITD_WORM_BUCKET_LOCK_CONFIRMED=true` est une déclaration de configuration, pas une preuve cryptographique du réglage Cloudflare. Le token utilisé par GitHub ne doit volontairement pas avoir le droit de modifier le Bucket Lock. Une vérification administrative séparée du réglage provider reste donc requise pour qualifier l'ensemble de `VERIFIED`.
