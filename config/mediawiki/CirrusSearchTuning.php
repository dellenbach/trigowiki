<?php

if ( !defined( 'MEDIAWIKI' ) ) {
    exit;
}

$wgSearchType = 'CirrusSearch';

$wgCirrusSearchWeights = [
    'title' => 16,
    'redirect' => 10,
    'category' => 4,
    'heading' => 8,
    'opening_text' => 6,
    'text' => 2,
    'auxiliary_text' => 1,
    'file_text' => 0.5,
];

$wgCirrusSearchStemmedWeight = 0.85;
$wgCirrusSearchPhraseRescoreBoost = 6.0;

$wgCirrusSearchPhraseSuggestUseOpeningText = true;
$wgCirrusSearchPhraseSuggestUseText = true;
$wgCirrusSearchEnablePhraseSuggest = true;
$wgCirrusSearchPhraseSuggestMaxErrorsHardLimit = 2;
$wgCirrusSearchPhraseSuggestPrefixLengthHardLimit = 2;

$wgCirrusSearchPrefixSearchStartsWithAnyWord = true;
$wgCirrusSearchUseCompletionSuggester = 'yes';
$wgCirrusSearchUseIcuFolding = true;
$wgCirrusSearchRecycleCompletionSuggesterIndex = true;
$wgCirrusSearchCompletionSettings = 'fuzzy';
$wgCirrusSearchCompletionDefaultScore = 'quality';
$wgCirrusSearchCompletionSuggesterSubphrases = [
    'build' => true,
    'use' => true,
    'type' => 'anywords',
    'limit' => 10,
];

$wgEnableOpenSearchSuggest = true;