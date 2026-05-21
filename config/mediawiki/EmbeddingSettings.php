<?php

if ( !defined( 'MEDIAWIKI' ) ) {
    exit;
}

$wgDrawioEditorImageInteractive = true;
$wgReferrerPolicy = 'origin';
$wgExternalLinkTarget = '_blank';

$wgIframe['category'] = 'Iframe';
$wgIframe['width'] = 1028;
$wgIframe['height'] = 768;
$wgIframe['delay'] = -1;
$wgIframe['allowfullscreen'] = true;
$wgIframe['server']['drawio'] = [ 'scheme' => 'https', 'domain' => 'www.draw.io' ];
$wgIframe['server']['svg'] = [ 'scheme' => 'http', 'domain' => 'www.w3.org' ];
$wgIframe['server']['intranet'] = [ 'scheme' => 'https', 'domain' => 'sharepoint.com' ];
$wgIframe['server']['drawioext'] = [ 'scheme' => 'https', 'domain' => 'diagrams.net' ];

$wgAllowExternalImagesFrom = [
    'http://127.0.0.1/',
    'https://trigonet.sharepoint.com/',
    'https://trigonet.ch/',
];

$wgEditPageFrameOptions = false;
$wgRawHtml = true;
