<?php

if ( !defined( 'MEDIAWIKI' ) ) {
    exit;
}

if ( getenv( 'MEDIAWIKI_SEARCH_ENABLED' ) !== '1' ) {
    return;
}

$elasticaExtension = "$IP/extensions/Elastica/extension.json";
$cirrusExtension = "$IP/extensions/CirrusSearch/extension.json";
if ( !file_exists( $elasticaExtension ) || !file_exists( $cirrusExtension ) ) {
    return;
}

// Elastica vendor autoload must be explicitly required when the extension is
// mounted as a volume; Apache/PHP-FPM does not auto-require it.
//
// Problem: Elastica vendor ships PSR-3 v2 (setLogger(): void), while
// MediaWiki's own BagOStuff implements PSR-3 v1 (no :void return type).
// If Elastica's autoloader loads PSR-3 v2 before BagOStuff is instantiated,
// PHP 8 raises a fatal interface-compatibility error.
//
// Fix: explicitly require MediaWiki's PSR-3 v1 class files BEFORE registering
// Elastica's autoloader, so they are already in the class table and Elastica's
// PSR-3 v2 autoloader will never fire for those classes.
$mwPsr3Dir = "$IP/vendor/psr/log/Psr/Log";
if ( is_dir( $mwPsr3Dir ) ) {
    foreach ( glob( "$mwPsr3Dir/*.php" ) as $mwPsr3File ) {
        require_once $mwPsr3File;
    }
}

$elasticaAutoload = "$IP/extensions/Elastica/vendor/autoload.php";
if ( file_exists( $elasticaAutoload ) ) {
    require_once $elasticaAutoload;
}

wfLoadExtension( 'Elastica' );
wfLoadExtension( 'CirrusSearch' );
if ( file_exists( "$IP/extensions/AdvancedSearch/extension.json" ) ) {
    wfLoadExtension( 'AdvancedSearch' );
}

$wgSearchType = 'CirrusSearch';
$cirrusSearchHost = getenv( 'MEDIAWIKI_SEARCH_HOST' ) ?: 'elasticsearch_staging_lts';
$wgCirrusSearchDefaultCluster = 'default';
$wgCirrusSearchClusters = [
    'default' => [ $cirrusSearchHost ],
];
$wgCirrusSearchWriteClusters = [ 'default' ];
$wgCirrusSearchServers = [ $cirrusSearchHost ];
$wgCirrusSearchUseCompletionSuggester = 'yes';
$wgCirrusSearchPrefixSearchStartsWithAnyWord = true;
$wgCirrusSearchCompletionSettings = 'fuzzy';
$wgCirrusSearchCompletionDefaultScore = 'quality';
$wgCirrusSearchCompletionSuggesterSubphrases = [
    'build' => true,
    'use' => true,
    'type' => 'anywords',
    'limit' => 10,
];
