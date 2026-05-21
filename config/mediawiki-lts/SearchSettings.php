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

wfLoadExtension( 'Elastica' );
wfLoadExtension( 'CirrusSearch' );

$wgSearchType = 'CirrusSearch';
$wgCirrusSearchServers = [ getenv( 'MEDIAWIKI_SEARCH_HOST' ) ?: 'elasticsearch_staging_lts' ];
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
