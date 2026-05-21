# Trigowiki Search Tuning

## Aktueller Befund

CirrusSearch und Elasticsearch laufen technisch sauber, aber der Standardindex sucht wortbasiert. Eine Suche nach `postgres` findet Treffer, eine Suche nach `gres` oder `*gres*` findet in der aktuellen CirrusSearch-Version keine Treffer. `insource:/gres/` wird ebenfalls nicht als Query verstanden.

## Relevanz-Tuning

Die Datei `CirrusSearchTuning.php` enthaelt ein konservatives Ranking-Profil fuer Trigowiki:

- Titel bleiben wichtig, dominieren aber weniger stark.
- Abschnittsueberschriften und Einleitungstext werden staerker beruecksichtigt.
- Volltext wird hoeher gewichtet als im bisherigen Profil.
- Kategorien werden nuetzlich, aber nicht uebermaessig stark gewichtet.
- Fuzzy Completion und Phrase Suggest bleiben aktiv.

Einbindung in der aktiven `LocalSettings.php` nach dem Laden von Elastica/CirrusSearch. Im Docker-Setup wird `config/CirrusSearchTuning.php` nach `/var/www/mediawiki/CirrusSearchTuning.php` gemountet:

```php
require_once "$IP/CirrusSearchTuning.php";
```

Danach die Suchkonfiguration und Suggest-Indizes aktualisieren:

```bash
docker exec mediawiki_wiki php /var/www/mediawiki/extensions/CirrusSearch/maintenance/updateSearchIndexConfig.php
docker exec mediawiki_wiki php /var/www/mediawiki/extensions/CirrusSearch/maintenance/updateSuggesterIndex.php
docker exec mediawiki_wiki php /var/www/mediawiki/extensions/CirrusSearch/maintenance/forceSearchIndex.php --skipLinks --indexOnSkip
docker exec mediawiki_wiki php /var/www/mediawiki/extensions/CirrusSearch/maintenance/forceSearchIndex.php --skipParse
```

## Teilwortsuche innerhalb von Woertern

Best Practice: Teilwortsuche nicht ueber fuehrende Wildcards wie `*gres*` auf dem normalen Volltextindex erzwingen. Das ist teuer, schlecht zu ranken und bei aelteren Elasticsearch/CirrusSearch-Versionen oft gar nicht sauber verfuegbar.

Sinnvolle Varianten:

1. Prefix-Suche fuer normale Benutzer: gut fuer `post` -> `postgres`, bereits ueber Completion/Prefix-Tuning abgedeckt.
2. Synonyme fuer Fachbegriffe: `postgres`, `postgresql`, `pg`, `datenbank`; das verbessert echte Suchabsichten besser als reine Substrings.
3. Separater Infix-Index fuer Titel und Weiterleitungen: N-Gramme fuer Seitentitel, Redirects und Kategorien, nicht fuer den gesamten Volltext.
4. Power-User-Suche ueber eine Spezialseite oder ein kleines Tool: explizite Contains-Suche in Titeln/Inhalten, getrennt vom normalen Ranking.

Fuer Trigowiki ist Variante 3 am besten: ein kleiner separater Title/Infix-Index fuer Suchvorschlaege plus der normale CirrusSearch-Volltext fuer die Trefferliste. So findet `gres` einen Vorschlag `Postgres`, ohne den Hauptindex mit Substrings aufzublaehen.

Umgesetzt ist zunaechst die konservative Variante als Spezialseite `Special:InfixSearch`. Sie sucht Teilwoerter nur in Seitentiteln ausgewaehlter Namensraeume und ist damit deutlich billiger als Infix-Volltext im Elasticsearch-Hauptindex. Auf Staging wurde `gres` gegen MediaWiki 1.43 verifiziert und liefert unter anderem:

- `Backup_und_Restore_(Postgres)`
- `Postgres_Aufbau`
- `Kategorie:Postgres`

Die normale Suche bleibt unveraendert CirrusSearch-basiert. Fuer Benutzer kann die Spezialseite spaeter als Suchhilfe verlinkt oder bei Bedarf in die Suchoberflaeche integriert werden.

Zusatz: Ueber den Hook `SearchAfterNoDirectMatch` nutzt die normale Such-Navigation den Titel-Infix-Fallback bereits als "Go"-Naehertreffer. Damit fuehren Anfragen wie `gres` direkt auf die beste passende Seite, ohne den Volltextindex umzustellen.

## Aehnlichkeitssuche

Fuer "aehnliche Seiten" eignet sich ein separates Feature besser als die normale Suchbox:

- Basis: Titel, Einleitung, Kategorien, Abschnittsueberschriften.
- Ausgabe: Top 5 aehnliche Seiten in einer Sidebar oder unter dem Artikel.
- Umsetzung: Elasticsearch `more_like_this` gegen den bestehenden CirrusSearch-Index oder ein eigener kompakter Similarity-Index.

Das sollte nicht die normale Suche ersetzen, sondern ergaenzen.

## Testset

Vor produktivem Tuning ein kleines Testset pflegen:

```text
postgres -> Postgres Aufbau, Backup und Restore (Postgres)
postgres replika -> PostgreSQL-/Backup-/Cluster-Seiten
gis -> relevante GIS-Seiten
geodaten -> relevante Geodaten-Seiten
sql backup -> Backup- und Restore-Seiten
```

Nach jeder Aenderung die Top-5 vergleichen:

```bash
echo "postgres" | docker exec -i mediawiki_wiki php /var/www/mediawiki/extensions/CirrusSearch/maintenance/runSearch.php --limit 5
```