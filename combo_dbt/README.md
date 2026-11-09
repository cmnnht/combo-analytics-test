## 🗄️ Entrepôt de données (Snowflake)

L'entrepôt de données de ce projet repose sur la plateforme **Snowflake**. Les données y sont structurées au sein de la base de données `COMBO_PROJECT` et organisées à travers différentes couches de schémas (à commencer par le schéma `RAW` pour les données sources).

### 1. Initialisation de l'environnement
L'infrastructure de la base de données (bases, schémas, entrepôt de calcul et rôles de sécurité) est configurée via le script d'initialisation :
📌 **Fichier :** `scripts/snowflake_init.sql`

*Note : Ce script doit être exécuté par un administrateur Snowflake (`ACCOUNTADMIN`) avant le premier chargement ou la première exécution de dbt.*

### 2. Chargement des données brutes (`RAW`)
Pour alimenter le schéma `RAW`, les tables peuvent être importées manuellement depuis l'interface Snowsight, ou de manière automatisée à l'aide d'un script d'ingestion.

Un script Python clé en main est mis à disposition pour automatiser le chargement local des fichiers volumineux (comme `shifts.csv`) :
📌 **Fichier :** `load_raw.py`

#### 🛠️ Pré-requis pour l'utilisation du script Python :
1. **Données sources :** Placez l'ensemble de vos fichiers d'extraction au format CSV dans le répertoire `data/raw/` (ex: `data/raw/shifts.csv`).
2. **Variables d'environnement :** 
   * Créez un fichier `.env` à la racine du projet en copiant le modèle fourni : `cp .env_example .env`
   * Complétez-le avec vos identifiants de connexion et paramètres Snowflake (`SNOWFLAKE_ACCOUNT`, `USER`, `PASSWORD`, etc.).


## 🏗️ Architecture du Projet dbt
 Ce projet est construit classiquement pour un projet DBT. Un schéma en étoile de Kimball est appliqué pour la couche mart.
L'architecture se décline en trois couches distinctes (architecture en médaillon) :
1. **Couche Staging (staging/)** : Nettoyage initial, alignement des types de données (Cast) et renommage et normalisation syntaxique des sources brutes (CSV).
2. **Couche Intermediate (intermediate/)** : centralisation des règles de gestion complexes. C'est ici que sont appliqués le dédoublonnement asymétrique des plannings (shifts vs repos) et l'algorithme de calcul des tranches tarifaires à l'usage par établissement, basé sur le fichier de référence (seed).
3. **Couche Marts (marts/)**: Modélisation en étoile (Star Schema) optimisée pour les outils de BI. Les tables de faits ne contiennent que des clés d'index et des métriques numériques exploitables. Les libellés textuels sont isolés dans des tables de dimensions dédiées.

## 🔍 Question 3 — Qualité des Données & Gestion des Anomalies

Au cours de la phase d'audit et de modélisation des données brutes, quatre anomalies majeures ayant un impact direct sur la justesse de la facturation ont été identifiées. Voici comment elles ont été interceptées à l'aide de tests dbt et corrigées de manière industrielle dans le code.

### 📜 Préambule : Des données booléennes et relatives à des dates multi-formes

• **Description :** Des données booléennes contiennent des données disparates (`True`, `true`, `1`, `Yes`, `False`, `false`, `0`, `No`). C'est le cas de la colonne `did_not_show` par exemple de la table `shifts`. De même, des données temporelles ont des formats changeant comme par exemple la colonne `contract_start` où deux formats co-existent (DD/MM/YYYY et DD-MM-YYYY).
• **Détection (Test) :** Les données temporelles de type date sont formattées à l'aide de la fonction `TRY_TO_DATE(TRIM(contract_start), <format>)` appliquée à l'aide d'un CASE pour unifier le format final et celles de type timestamp à l'aide de la macro `clean_snowflake_utc_date` afin de factoriser la transformation.


### 🐎 Anomalie 1 : Chevauchement de contrats sur une même semaine civile

• **Description :** Plusieurs lignes de contrats distinctes étaient actives simultanément pour un même employé (`membership_id`) sur les mêmes dates. Lier aveuglément les activités à ces contrats aurait provoqué une multiplication artificielle du nombre d'employés facturés ou des collisions d'ID d'établissements.
• **Détection (Test)** : Implémentation d’un test singulier d'alerte critique bloquante (`tests/assert_no_overlapping_contracts.sql`) vérifiant l'intersection des intervalles temporels par employé.
• **Résolution Métier :** Application d'une loi de priorité RH déterministe au travers d'une fonction de fenêtrage (`ROW_NUMBER()`). En cas de chevauchement, le pipeline classe et retient le contrat le plus engageant selon la distribution réelle observée : CDI > apprentissage > CDD > seasonal. En cas d'égalité de type, le contrat saisi le plus récemment (`start_date DESC`) prévaut.

### 🦹‍♂️ Anomalie 2 : Des contrats sans employé de référence

• **Description :** Présence de contrats dans la table user_contracts sans employé de référence au sein de la table membership.
• **Détection (Test) :** Utilisation du test générique relationship (`models/staging/_sgt_raw.yml`) qui fait remonter les lignes associées (au nombre de 4).
• **Résolution Métier :** Dans le modèle intermédiaire `int_billing_weekly_event`, une clause de filtrage existe lors de la jointure avec la table contrat. On exclut alors les contrats sans salariés.


### 📜 Anomalie 3 : Shifts ou repos orphelins de contrat

• **Description :** Des événements de planning ont été enregistrés pour des employés à des dates où aucun contrat n'était actif (avant la date de début ou après la date de fin). Par ailleurs, des événements de planning ont été enregistrés pour des employés qui ne sont pas référencés a priori (aucun matricule correspondant) dans la table membership. Nous avons donc deux raisons pour lesquelles ces contrats sont orphelins.
• **Détection (Test) :** Implémentation du test d'intégrité référentielle temporelle `tests/assert_shift_dates_within_contract_bounds.sql`. Application du test relationship pour la colonne user_contract_id avec la clé primaire de la table `user_contracts`.
• **Résolution Métier :** Une jointure interne (`INNER JOIN`) stricte entre les activités dédoublonnées et la table des contrats nettoyés élimine automatiquement ces lignes orphelines du calcul de la facturation d'une part. D'autre part, un filtre est appliqué pour ne garder que les événements dont les dates sont comprises dans un contrats.

### 📜 Anomalie 4 : Des contrats sans utilisateurs / employés connus
• **Description :** Il existe 4 contrats qui ne sont pas liés à un employé connu.
• **Détection (Test) :** Implémentation d'un test de relationship simple entre la clé `membership_id` de la table ``stg_raw__user_contract`` et la clé primaire de la table ``memberships``dans la table ``stg_raw__membership``.  Ce test sert à alerter dans un premier temps. On s'assure ensuite dans la couche intermédiaire de ne pas travailler avec des contrats d'ayant pas d'employé associé au travers d'un INNER JOIN scrict dans la table ``int_user_contracts_deduplicated``. Un test de la relation est alors réeffectué cette fois en mode erreur pour bloquer la génération de donnée erronée en amont.
• **Résolution Métier :** Il y a remontée d'alerte dans ces cas précis afin de pouvoir faire remonter le cas au métier et que potientielle correction il puisse avoir lieu en amont. On filtre ensuite les contrats sans employé défini. On fait par ailleurs de même concernant les établissements non définis.


## ☝️ Quelques remarques supplémentaires

### 😴 Remarque 1 : Périodes de repos multi-jours chevauchant deux semaines

• **Description :** À l'inverse des shifts, une période de repos ou de formation (rests.csv) peut légitimement durer plusieurs jours. Si elle commence en semaine \(N\) et s'achève en semaine \(N+1\), se baser uniquement sur la date de début priverait la semaine \(N+1\) de l'activité de l'employé, le rendant à tort non-facturable.
• **Résolution Métier :** Traitement asymétrique au sein du modèle éphémère. Les repos bénéficient d'une jointure d'intervalle sur la table dim_calendar afin d'éclater l'événement sur l'ensemble des semaines civiles réellement traversées. Un `SELECT DISTINCT` sécurise ensuite le flux pour éviter tout doublon intra-semaine.