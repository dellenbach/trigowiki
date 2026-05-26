<?php

// @see https://www.mediawiki.org/wiki/Manual:Configuration_settings

# Protect against web entry
if ( !defined( 'MEDIAWIKI' ) ) {
    exit;
}

if (getenv('MEDIAWIKI_SITENAME') != '') {
    $wgSitename = getenv('MEDIAWIKI_SITENAME');
}

if (getenv('MEDIAWIKI_META_NAMESPACE') != '') {
    $wgMetaNamespace = getenv('MEDIAWIKI_META_NAMESPACE');
}

# Short URLs
$wgScriptPath = "";
$wgArticlePath = "/$1";
$wgUsePathInfo = true;
$wgScriptExtension = ".php";

if (getenv('MEDIAWIKI_SERVER') == '') {
    throw new Exception('Missing environment variable MEDIAWIKI_SERVER');
} else {
    $wgServer = getenv('MEDIAWIKI_SERVER');
}

$wgResourceBasePath = $wgScriptPath;

$wgLogo = "$wgResourceBasePath/resources/trigowiki/trigonet_Logo_pos_ohneClaim_RGB.svg";
$wgHooks['BeforePageDisplay'][] = function ( OutputPage $out, Skin $skin ) use ( $wgLogo ) {
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

.mw-page-title-main,
.mw-first-heading,
.firstHeading,
.mw-body h1,
.mw-parser-output h1 {
    color: #990000;
    font-size: 2rem !important;
    font-weight: 750 !important;
    line-height: 1.24 !important;
    margin-top: 1.1em !important;
    margin-bottom: 0.5em !important;
    border-bottom: 0 !important;
}

.mw-body h2,
.mw-parser-output h2 {
    color: #990000;
    font-size: 1.55rem !important;
    font-weight: 700 !important;
    line-height: 1.28 !important;
    margin-top: 1em !important;
    margin-bottom: 0.45em !important;
    border-bottom: 0 !important;
}

.mw-body h3,
.mw-parser-output h3 {
    color: #990000;
    font-size: 1.3rem !important;
    font-weight: 650 !important;
    line-height: 1.32 !important;
    margin-top: 0.9em !important;
    margin-bottom: 0.35em !important;
    border-bottom: 0 !important;
}

.mw-body h4,
.mw-parser-output h4 {
    color: #990000;
    font-size: 1.1rem !important;
    font-weight: 600 !important;
    line-height: 1.35 !important;
    margin-top: 0.8em !important;
    margin-bottom: 0.3em !important;
    border-bottom: 0 !important;
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

.mw-heading .mw-headline,
.mw-heading {
    color: #990000;
    border-bottom: 0 !important;
}
CSS
    );
    return true;
};

if (getenv('MEDIAWIKI_EMERGENCY_CONTACT') != '') {
    $wgEmergencyContact = getenv('MEDIAWIKI_EMERGENCY_CONTACT');
}

if (getenv('MEDIAWIKI_PASSWORD_SENDER') != '') {
    $wgPasswordSender = getenv('MEDIAWIKI_PASSWORD_SENDER');
}

if (getenv('MEDIAWIKI_DB_TYPE') != '') {
    $wgDBtype = getenv('MEDIAWIKI_DB_TYPE');
}

if (getenv('MEDIAWIKI_DB_HOST') != '' || getenv('MEDIAWIKI_DB_PORT') != '') {
    $hostname = ((getenv('MEDIAWIKI_DB_HOST') != '') ? getenv('MEDIAWIKI_DB_HOST') : '127.0.0.1');
    $port = ((getenv('MEDIAWIKI_DB_PORT') != '') ? getenv('MEDIAWIKI_DB_PORT') : '3306');
    $wgDBserver = $hostname.':'.$port;
}

unset($hostname, $port);

if (getenv('MEDIAWIKI_DB_NAME') != '') {
    $wgDBname = getenv('MEDIAWIKI_DB_NAME');
}

if (getenv('MEDIAWIKI_DB_USER') != '') {
    $wgDBuser = getenv('MEDIAWIKI_DB_USER');
}

if (getenv('MEDIAWIKI_DB_PASSWORD') != '') {
    $wgDBpassword = getenv('MEDIAWIKI_DB_PASSWORD');
}

# MySQL specific settings
if (getenv('MEDIAWIKI_DB_TYPE') == 'mysql') {
    // Cache sessions in database
    $wgSessionCacheType = CACHE_DB;

    if (getenv('MEDIAWIKI_DB_PREFIX') != '') {
        $wgDBprefix = getenv('MEDIAWIKI_DB_PREFIX');
    }

    if (getenv('MEDIAWIKI_DB_TABLE_OPTIONS') != '') {
        $wgDBTableOptions = getenv('MEDIAWIKI_DB_TABLE_OPTIONS');
    }
}

$wgDBmysql5 = false;

# SQLite specific settings
$wgSQLiteDataDir = '/data';

if (getenv('MEDIAWIKI_DB_TYPE') == 'sqlite') {
    $wgObjectCaches[CACHE_DB] = [
        'class' => 'SqlBagOStuff',
        'loggroup' => 'SQLBagOStuff',
        'server' => [
            'type' => 'sqlite',
            'dbname' => 'wikicache',
            'tablePrefix' => '',
            'flags' => 0
        ]
    ];
}

$wgMainCacheType = CACHE_ACCEL;
$wgMemCachedServers = [];

$wgUploadPath = '/images';
$wgUploadDirectory = '/images';
$wgUploadSizeWarning = false;

if (getenv('MEDIAWIKI_MAX_UPLOAD_SIZE') != '') {
    // Since MediaWiki's config takes upload size in bytes and PHP in 100M format, lets use PHPs format and convert that here.
    $maxUploadSize = getenv('MEDIAWIKI_MAX_UPLOAD_SIZE');
    if (strlen($maxUploadSize) >= 2) {
        $maxUploadSizeUnit = substr($maxUploadSize, -1, 1);
        $maxUploadSizeValue = (integer)substr($maxUploadSize, 0, -1);
        switch (strtoupper($maxUploadSizeUnit)) {
            case 'G':
                $maxUploadSizeFactor = 1024 * 1024 * 1024;
                break;
            case 'M':
                $maxUploadSizeFactor = 1024 * 1024;
                break;
            case 'K':
                $maxUploadSizeFactor = 1024;
                break;
            case 'B':
            default:
                $maxUploadSizeFactor = 0;
                break;
        }
        $wgMaxUploadSize = $maxUploadSizeValue * $maxUploadSizeFactor;
        unset($maxUploadSizeUnit, $maxUploadSizeValue, $maxUploadSizeFactor);
    }
}

$wgEnableUploads = false;
if (getenv('MEDIAWIKI_ENABLE_UPLOADS') == '1') {
    $wgEnableUploads = true;
}

if (getenv('MEDIAWIKI_FILE_EXTENSIONS') != '') {
    foreach (explode(',', getenv('MEDIAWIKI_FILE_EXTENSIONS')) as $extension) {
        $wgFileExtensions[] = trim($extension);
    }
}

$wgUseImageMagick = true;
$wgImageMagickConvertCommand = "/usr/bin/convert";
$wgShellLocale = "C.UTF-8";

if (getenv('MEDIAWIKI_LANGUAGE_CODE') != '') {
    $wgLanguageCode = getenv('MEDIAWIKI_LANGUAGE_CODE');
}

if (getenv('MEDIAWIKI_SECRET_KEY') != '') {
    $wgSecretKey = getenv('MEDIAWIKI_SECRET_KEY');
}

if (getenv('MEDIAWIKI_UPGRADE_KEY') != '') {
    $wgUpgradeKey = getenv('MEDIAWIKI_UPGRADE_KEY');
}

$wgDiff3 = "/usr/bin/diff3";

$wgDefaultSkin = "vector";
if (getenv('MEDIAWIKI_DEFAULT_SKIN') != '') {
    $wgDefaultSkin = getenv('MEDIAWIKI_DEFAULT_SKIN');
}

# Enabled skins
wfLoadSkin( 'CologneBlue' );
wfLoadSkin( 'Modern' );
wfLoadSkin( 'MonoBook' );
wfLoadSkin( 'Vector' );

# Debug
if (getenv('MEDIAWIKI_DEBUG') == '1') {
    $wgShowExceptionDetails = true;
    $wgShowSQLErrors = true;
    $wgDebugDumpSql = true;
    $wgDebugLogFile = "/tmp/wiki-debug.log";
}

# SMTP E-Mail
if (getenv('MEDIAWIKI_SMTP') == '1') {
    $wgEnableEmail = true;
    $wgEnableUserEmail = true;
    $wgSMTP = array(
        'host'     => getenv('MEDIAWIKI_SMTP_HOST'), // could also be an IP address. Where the SMTP server is located
        'IDHost'   => getenv('MEDIAWIKI_SMTP_IDHOST'), // Generally this will be the domain name of your website (aka mywiki.org)
        'port'     => getenv('MEDIAWIKI_SMTP_PORT'), // Port to use when connecting to the SMTP server
        'auth'     => (getenv('MEDIAWIKI_SMTP_AUTH') == '1'), // Should we use SMTP authentication (true or false)
        'username' => getenv('MEDIAWIKI_SMTP_USERNAME'), // Username to use for SMTP authentication (if being used)
        'password' => getenv('MEDIAWIKI_SMTP_PASSWORD') // Password to use for SMTP authentication (if being used)
    );
}

# VisualEditor
if (getenv('MEDIAWIKI_EXTENSION_VISUAL_EDITOR_ENABLED') == ''
|| getenv('MEDIAWIKI_EXTENSION_VISUAL_EDITOR_ENABLED') == '1') {
    wfLoadExtension('VisualEditor');
    $wgDefaultUserOptions['visualeditor-enable'] = 1;
    $wgVirtualRestConfig['modules']['parsoid'] = array(
        'url' => 'http://localhost:8142',
        'domain' => 'localhost',
        'prefix' => ''
    );
    $wgSessionsInObjectCache = true;
    $wgVirtualRestConfig['modules']['parsoid']['forwardCookies'] = true;
}

# User Merge
if (getenv('MEDIAWIKI_EXTENSION_USER_MERGE_ENABLED') == ''
|| getenv('MEDIAWIKI_EXTENSION_USER_MERGE_ENABLED') == '1') {
    wfLoadExtension('UserMerge');
    $wgGroupPermissions['bureaucrat']['usermerge'] = true;
    $wgGroupPermissions['sysop']['usermerge'] = true;
    $wgUserMergeProtectedGroups = array();
}

# Load extra settings
require 'ExtraLocalSettings.php';

foreach ( [
    'Permissions.php',
    'Extensions.php',
    'UploadSettings.php',
    'EmbeddingSettings.php',
    'CirrusSearchTuning.php',
    'InfixTitleSearch.php',
    'RecentBreadcrumbs.php',
] as $trigowikiSettingsFile ) {
    $trigowikiSettingsPath = "$IP/$trigowikiSettingsFile";
    if ( file_exists( $trigowikiSettingsPath ) ) {
        require_once $trigowikiSettingsPath;
    }
}

$wgPasswordPolicy = [
    'policies' => [
        'default' => [],
    ],
    'checks' => $wgPasswordPolicy['checks'],
];
