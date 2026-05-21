<?php

if ( !defined( 'MEDIAWIKI' ) ) {
    exit;
}

wfLoadExtension( 'Cite' );
wfLoadExtension( 'CiteThisPage' );
wfLoadExtension( 'ConfirmEdit' );
wfLoadExtension( 'Gadgets' );
wfLoadExtension( 'ImageMap' );
wfLoadExtension( 'InputBox' );
wfLoadExtension( 'Interwiki' );
wfLoadExtension( 'LocalisationUpdate' );
wfLoadExtension( 'Nuke' );
wfLoadExtension( 'ParserFunctions' );
wfLoadExtension( 'PdfHandler' );
wfLoadExtension( 'Poem' );
wfLoadExtension( 'Renameuser' );
wfLoadExtension( 'SpamBlacklist' );
wfLoadExtension( 'SyntaxHighlight_GeSHi' );
wfLoadExtension( 'TitleBlacklist' );
wfLoadExtension( 'WikiEditor' );
wfLoadExtension( 'Elastica' );
wfLoadExtension( 'TextExtracts' );
wfLoadExtension( 'TemplateData' );
wfLoadExtension( 'DeletePagesForGood' );
wfLoadExtension( 'MsUpload' );
wfLoadExtension( 'PDFEmbed' );
wfLoadExtension( 'Iframe' );

require_once "$IP/extensions/JSBreadCrumbs/JSBreadCrumbs.php";
require_once "$IP/extensions/CirrusSearch/CirrusSearch.php";
require_once "$IP/extensions/Scribunto/Scribunto.php";
require_once "$IP/extensions/DeleteBatch/DeleteBatch.php";
require_once "$IP/extensions/ClipUpload/ClipUpload.php";
require_once "$IP/extensions/DrawioEditor/DrawioEditor.php";
require_once "$IP/extensions/NativeSvgHandler/NativeSvgHandler.php";
require_once "$IP/extensions/Widgets/Widgets.php";

$wgCirrusSearchServers = [ 'elasticsearch' ];

$wgExtractsExtendOpenSearchXml = true;

$wgScribuntoDefaultEngine = 'luastandalone';
$wgScribuntoUseGeSHi = true;

$wgDeletePagesForGoodNamespaces = [
    NS_TEMPLATE => true,
    NS_TEMPLATE_TALK => true,
];

$wgGroupPermissions['sysop']['deleteperm'] = true;
$wgGroupPermissions['sysop']['nuke'] = true;
$wgGroupPermissions['sysop']['deletebatch'] = true;

$wgDefaultUserOptions['usebetatoolbar'] = 1;
