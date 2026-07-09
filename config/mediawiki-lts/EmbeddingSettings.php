<?php

if ( !defined( 'MEDIAWIKI' ) ) {
    exit;
}

// Keep legacy behavior: interactive draw.io image previews when extension is present.
$wgDrawioEditorImageInteractive = true;

$drawioExtensionJson = "$IP/extensions/DrawioEditor/extension.json";
$drawioLegacyEntry = "$IP/extensions/DrawioEditor/DrawioEditor.php";
if ( file_exists( $drawioExtensionJson ) ) {
    wfLoadExtension( 'DrawioEditor' );
} elseif ( file_exists( $drawioLegacyEntry ) ) {
    require_once $drawioLegacyEntry;
}

$pdfEmbedExtensionJson = "$IP/extensions/PDFEmbed/extension.json";
$pdfEmbedLegacyEntry = "$IP/extensions/PDFEmbed/PDFEmbed.php";
if ( file_exists( $pdfEmbedExtensionJson ) ) {
    wfLoadExtension( 'PDFEmbed' );
} elseif ( file_exists( $pdfEmbedLegacyEntry ) ) {
    require_once $pdfEmbedLegacyEntry;
}

$iframeExtensionJson = "$IP/extensions/Iframe/extension.json";
$iframeLegacyEntry = "$IP/extensions/Iframe/Iframe.php";
if ( file_exists( $iframeExtensionJson ) ) {
    wfLoadExtension( 'Iframe' );
} elseif ( file_exists( $iframeLegacyEntry ) ) {
    require_once $iframeLegacyEntry;
}

$wgIframe['category'] = 'Iframe';
$wgIframe['width'] = 1028;
$wgIframe['height'] = 768;
$wgIframe['delay'] = -1;
$wgIframe['allowfullscreen'] = true;
$wgIframe['server']['drawio'] = [
    'scheme' => 'https',
    'domain' => 'www.draw.io',
];
$wgIframe['server']['drawioext'] = [
    'scheme' => 'https',
    'domain' => 'diagrams.net',
];
