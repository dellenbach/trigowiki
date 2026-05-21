<?php

if ( !defined( 'MEDIAWIKI' ) ) {
    exit;
}

$wgEnableUploads = true;
$wgUseImageMagick = true;
$wgImageMagickConvertCommand = '/usr/bin/convert';
$wgMaxShellMemory = 524288;

$wgFileExtensions = [
    'png',
    'gif',
    'jpg',
    'jpeg',
    'ppt',
    'pdf',
    'psd',
    'mp3',
    'xls',
    'xlsx',
    'swf',
    'doc',
    'docx',
    'odt',
    'odc',
    'odp',
    'odg',
    'mpp',
    'wmv',
    'svg',
    'mp4',
];

$wgVerifyMimeType = true;
$wgAllowedMimeTypes[] = 'video/mp4';
$wgTrustedMediaFormats[] = 'video/mp4';
$wgTrustedMediaFormats[] = 'application/pdf';

$wgPdfEmbed['width'] = 800;
$wgPdfEmbed['height'] = 1090;
