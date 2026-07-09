<?php

if ( !defined( 'MEDIAWIKI' ) ) {
    exit;
}

$wgSitename = getenv( 'MEDIAWIKI_SITENAME' ) ?: 'Trigowiki';
$wgSitename = preg_replace( '/\s+(?:LTS|Staging)$/', '', $wgSitename );
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

$smtpHost = getenv( 'MEDIAWIKI_SMTP_HOST' );
if ( $smtpHost !== false && $smtpHost !== '' ) {
    $smtpPortRaw = getenv( 'MEDIAWIKI_SMTP_PORT' );
    $smtpPort = ( $smtpPortRaw !== false && $smtpPortRaw !== '' ) ? intval( $smtpPortRaw ) : 587;
    if ( $smtpPort <= 0 ) {
        $smtpPort = 587;
    }

    $smtpAuthEnv = getenv( 'MEDIAWIKI_SMTP_AUTH' );
    $smtpAuthRaw = strtolower( ( $smtpAuthEnv !== false && $smtpAuthEnv !== '' ) ? $smtpAuthEnv : '1' );
    $smtpAuth = !in_array( $smtpAuthRaw, [ '0', 'false', 'no', 'off' ], true );

    $smtpSecure = strtolower( getenv( 'MEDIAWIKI_SMTP_SECURE' ) ?: '' );
    if ( in_array( $smtpSecure, [ 'ssl', 'tls' ], true ) && strpos( $smtpHost, '://' ) === false ) {
        $smtpHost = $smtpSecure . '://' . $smtpHost;
    }

    $smtpIdHost = parse_url( $wgServer, PHP_URL_HOST );
    if ( !$smtpIdHost ) {
        $smtpIdHost = 'localhost';
    }

    $wgSMTP = [
        'host' => $smtpHost,
        'IDHost' => $smtpIdHost,
        'port' => $smtpPort,
        'auth' => $smtpAuth,
    ];

    $smtpUser = getenv( 'MEDIAWIKI_SMTP_USERNAME' );
    $smtpPassword = getenv( 'MEDIAWIKI_SMTP_PASSWORD' );
    if ( $smtpUser !== false && $smtpUser !== '' ) {
        $wgSMTP['username'] = $smtpUser;
    }
    if ( $smtpPassword !== false && $smtpPassword !== '' ) {
        $wgSMTP['password'] = $smtpPassword;
    }
}

$wgDBtype = getenv( 'MEDIAWIKI_DB_TYPE' ) ?: 'mysql';
$dbHost = getenv( 'MEDIAWIKI_DB_HOST' ) ?: 'mediawiki_mysql_production';
$dbPort = getenv( 'MEDIAWIKI_DB_PORT' ) ?: '3306';
$dbHostFallback = getenv( 'MEDIAWIKI_DB_HOST_FALLBACK' ) ?: 'mediawiki_mysql_production';
// Guard against stale container IPs after reboot; prefer stable Docker DNS name.
if ( preg_match( '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/', $dbHost ) ) {
    $dbHost = $dbHostFallback;
}
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
$wgUploadDirectory = "$IP/images";
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
$wgFavicon = "$wgResourceBasePath/resources/trigowiki/favicon.svg";
$wgHooks['BeforePageDisplay'][] = static function ( OutputPage $out, Skin $skin ) use ( $wgLogo ) {
    $out->addInlineStyle( <<<CSS
.mw-wiki-logo { background-image: url('{$wgLogo}') !important; background-size: 135px auto; }
html,
body,
body :not(pre):not(code):not(kbd):not(samp),
input,
textarea,
select,
button,
.mw-body,
.mw-parser-output,
.mw-parser-output *,
.vector-body,
.mw-page-title-main,
.mw-first-heading,
.firstHeading,
.mw-heading,
.mw-headline,
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
.oo-ui-widget,
.oo-ui-widget *,
.ve-ce-surface,
.ve-ce-documentNode,
.ve-ce-branchNode,
.ve-ce-contentBranchNode,
.ve-ce-attachedRootNode,
.ve-ce-paragraphNode,
.ve-ce-headingNode,
.ve-ce-headingNode * {
    font-family: Arial, Helvetica, sans-serif !important;
}
.mw-body h1,
.mw-body h2,
.mw-body h3,
.mw-body h4,
.mw-body h5,
.mw-body h6,
.mw-parser-output h1,
.mw-parser-output h2,
.mw-parser-output h3,
.mw-parser-output h4,
.mw-parser-output h5,
.mw-parser-output h6,
.mw-page-title-main,
.mw-first-heading,
.firstHeading,
.mw-heading .mw-headline {
    color: #990000;
    border-bottom: 0 !important;
}
.mw-heading {
    border-bottom: 0 !important;
}

.mw-page-title-main,
.mw-first-heading,
.firstHeading,
.mw-body h1,
.mw-parser-output h1 {
    font-size: 2rem !important;
    font-weight: 750 !important;
    line-height: 1.24 !important;
    margin-top: 1.1em !important;
    margin-bottom: 0.5em !important;
}

.mw-body h2,
.mw-parser-output h2 {
    font-size: 1.55rem !important;
    font-weight: 700 !important;
    line-height: 1.28 !important;
    margin-top: 1em !important;
    margin-bottom: 0.45em !important;
    border-bottom: 0 !important;
}

.mw-body h3,
.mw-parser-output h3 {
    font-size: 1.3rem !important;
    font-weight: 650 !important;
    line-height: 1.32 !important;
    margin-top: 0.9em !important;
    margin-bottom: 0.35em !important;
}

.mw-body h4,
.mw-parser-output h4 {
    font-size: 1.1rem !important;
    font-weight: 600 !important;
    line-height: 1.35 !important;
    margin-top: 0.8em !important;
    margin-bottom: 0.3em !important;
}

.mw-parser-output h1 .mw-headline,
.mw-parser-output h2 .mw-headline,
.mw-parser-output h3 .mw-headline,
.mw-parser-output h4 .mw-headline,
.mw-body h1 .mw-headline,
.mw-body h2 .mw-headline,
.mw-body h3 .mw-headline,
.mw-body h4 .mw-headline {
    font-size: inherit !important;
    font-weight: inherit !important;
    line-height: inherit !important;
}

@media (max-width: 768px) {
    .mw-page-title-main,
    .mw-first-heading,
    .firstHeading,
    .mw-body h1,
    .mw-parser-output h1 {
        font-size: 1.75rem !important;
    }

    .mw-body h2,
    .mw-parser-output h2 {
        font-size: 1.4rem !important;
    }

    .mw-body h3,
    .mw-parser-output h3 {
        font-size: 1.2rem !important;
    }

    .mw-body h4,
    .mw-parser-output h4 {
        font-size: 1.1rem !important;
    }
}
CSS
    );
    return true;
};

$wgGroupPermissions['*']['createaccount'] = false;
$wgGroupPermissions['*']['edit'] = false;
$wgGroupPermissions['*']['read'] = true;

wfLoadExtension( 'Cite' );
wfLoadExtension( 'ConfirmEdit' );
wfLoadExtension( 'Gadgets' );
wfLoadExtension( 'ImageMap' );
wfLoadExtension( 'Interwiki' );
wfLoadExtension( 'ParserFunctions' );
wfLoadExtension( 'PdfHandler' );
wfLoadExtension( 'Scribunto' );
wfLoadExtension( 'SyntaxHighlight_GeSHi' );
wfLoadExtension( 'TemplateData' );
if ( file_exists( "$IP/extensions/TimedMediaHandler/extension.json" ) ) {
    wfLoadExtension( 'TimedMediaHandler' );
    $wgEnableTranscode = false;
    $wgJobTypesExcludedFromDefaultQueue[] = 'webVideoTranscode';
    $wgJobTypesExcludedFromDefaultQueue[] = 'webVideoTranscodePrioritized';
    if ( file_exists( '/usr/bin/ffmpeg' ) ) {
        $wgFFmpegLocation = '/usr/bin/ffmpeg';
    }
}
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

$trigowikiRecentBreadcrumbs = "$IP/RecentBreadcrumbs.php";
if ( file_exists( $trigowikiRecentBreadcrumbs ) ) {
    require_once $trigowikiRecentBreadcrumbs;
}

$trigowikiSearchSettings = "$IP/SearchSettings.php";
if ( file_exists( $trigowikiSearchSettings ) ) {
    require_once $trigowikiSearchSettings;
}

$trigowikiEmbeddingSettings = "$IP/EmbeddingSettings.php";
if ( file_exists( $trigowikiEmbeddingSettings ) ) {
    require_once $trigowikiEmbeddingSettings;
}
