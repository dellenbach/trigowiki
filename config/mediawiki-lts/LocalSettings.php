<?php

if ( !defined( 'MEDIAWIKI' ) ) {
    exit;
}

$wgSitename = getenv( 'MEDIAWIKI_SITENAME' ) ?: 'Trigowiki Staging LTS';
$wgMetaNamespace = 'Trigowiki';

$wgScriptPath = '';
$wgArticlePath = '/$1';
$wgUsePathInfo = true;
$wgScriptExtension = '.php';

if ( getenv( 'MEDIAWIKI_SERVER' ) === false || getenv( 'MEDIAWIKI_SERVER' ) === '' ) {
    throw new Exception( 'Missing environment variable MEDIAWIKI_SERVER' );
}
$wgServer = getenv( 'MEDIAWIKI_SERVER' );
$wgResourceBasePath = $wgScriptPath;

$wgEmergencyContact = getenv( 'MEDIAWIKI_EMERGENCY_CONTACT' ) ?: 'wiki@example.invalid';
$wgPasswordSender = getenv( 'MEDIAWIKI_PASSWORD_SENDER' ) ?: $wgEmergencyContact;

$wgDBtype = getenv( 'MEDIAWIKI_DB_TYPE' ) ?: 'mysql';
$dbHost = getenv( 'MEDIAWIKI_DB_HOST' ) ?: 'mediawiki_mysql_staging';
$dbPort = getenv( 'MEDIAWIKI_DB_PORT' ) ?: '3306';
$wgDBserver = $dbHost . ':' . $dbPort;
$wgDBname = getenv( 'MEDIAWIKI_DB_NAME' ) ?: 'wikidb';
$wgDBuser = getenv( 'MEDIAWIKI_DB_USER' ) ?: 'root';
$wgDBpassword = getenv( 'MEDIAWIKI_DB_PASSWORD' ) ?: '';
$wgDBTableOptions = getenv( 'MEDIAWIKI_DB_TABLE_OPTIONS' ) ?: 'ENGINE=InnoDB, DEFAULT CHARSET=binary';

$wgSecretKey = getenv( 'MEDIAWIKI_SECRET_KEY' ) ?: 'staging-secret-change-me';
$wgUpgradeKey = getenv( 'MEDIAWIKI_UPGRADE_KEY' ) ?: 'staging-upgrade-change-me';

$wgMainCacheType = CACHE_NONE;
$wgSessionCacheType = CACHE_DB;
$wgMemCachedServers = [];

$wgEnableUploads = getenv( 'MEDIAWIKI_ENABLE_UPLOADS' ) === '1';
$wgUploadPath = '/images';
$wgUploadDirectory = '/images';
$wgUploadSizeWarning = false;
$wgUseImageMagick = true;
$wgImageMagickConvertCommand = '/usr/bin/convert';
$wgShellLocale = 'C.UTF-8';
$wgDiff3 = '/usr/bin/diff3';

if ( getenv( 'MEDIAWIKI_MAX_UPLOAD_SIZE' ) !== false && getenv( 'MEDIAWIKI_MAX_UPLOAD_SIZE' ) !== '' ) {
    $wgMaxUploadSize = 500 * 1024 * 1024;
}

$wgLanguageCode = getenv( 'MEDIAWIKI_LANGUAGE_CODE' ) ?: 'de';
$wgDefaultSkin = getenv( 'MEDIAWIKI_DEFAULT_SKIN' ) ?: 'vector';

wfLoadSkin( 'Vector' );
wfLoadSkin( 'MonoBook' );

$wgLogo = "$wgResourceBasePath/resources/trigowiki/trigonet_Logo_pos_ohneClaim_RGB.svg";
$wgHooks['BeforePageDisplay'][] = static function ( OutputPage $out, Skin $skin ) use ( $wgLogo ) {
    $out->addInlineStyle( <<<CSS
.mw-wiki-logo { background-image: url('{$wgLogo}') !important; background-size: 135px auto; }
html,
body,
input,
textarea,
select,
button,
.mw-body,
.mw-parser-output,
.vector-body,
.mw-page-title-main,
h1,
h2,
h3,
h4,
h5,
h6,
.mw-editsection,
#mw-panel,
.mw-portlet,
#p-personal,
#p-views,
#p-cactions,
#footer,
.oo-ui-widget {
    font-family: Arial, Helvetica, sans-serif;
}
CSS
    );
    return true;
};

$wgGroupPermissions['*']['createaccount'] = false;
$wgGroupPermissions['*']['edit'] = false;
$wgGroupPermissions['*']['read'] = false;

wfLoadExtension( 'Cite' );
wfLoadExtension( 'ConfirmEdit' );
wfLoadExtension( 'Gadgets' );
wfLoadExtension( 'Interwiki' );
wfLoadExtension( 'ParserFunctions' );
wfLoadExtension( 'PdfHandler' );
wfLoadExtension( 'Scribunto' );
wfLoadExtension( 'SyntaxHighlight_GeSHi' );
wfLoadExtension( 'TemplateData' );
wfLoadExtension( 'VisualEditor' );
wfLoadExtension( 'WikiEditor' );

$wgPasswordPolicy = [
    'policies' => [
        'default' => [],
    ],
    'checks' => $wgPasswordPolicy['checks'],
];

$wgScribuntoDefaultEngine = 'luastandalone';
$wgDefaultUserOptions['usebetatoolbar'] = 1;

if ( getenv( 'MEDIAWIKI_DEBUG' ) === '1' ) {
    $wgShowExceptionDetails = true;
    $wgShowSQLErrors = true;
    $wgDebugDumpSql = true;
    $wgDebugLogFile = '/tmp/wiki-debug.log';
}

$trigowikiInfixSearch = "$IP/InfixTitleSearch.php";
if ( file_exists( $trigowikiInfixSearch ) ) {
    require_once $trigowikiInfixSearch;
}

$trigowikiSearchSettings = "$IP/SearchSettings.php";
if ( file_exists( $trigowikiSearchSettings ) ) {
    require_once $trigowikiSearchSettings;
}
