<?php

if ( !defined( 'MEDIAWIKI' ) ) {
    exit;
}

$wgUseSiteCss = true;
$wgUseAjax = true;

$wgUrlProtocols = [
    'http://',
    'https://',
    'ftp://',
    'irc://',
    'gopher://',
    'telnet://',
    'nntp://',
    'worldwind://',
    'mailto:',
    'news:',
    'file:',
    'trigocmd:',
];

$wgGroupPermissions['sysop']['deleterevision'] = true;
$wgGroupPermissions['user']['move'] = true;
$wgGroupPermissions['user']['delete'] = true;
$wgGroupPermissions['user']['rollback'] = true;
$wgGroupPermissions['*']['edit'] = false;
$wgGroupPermissions['user']['edit'] = true;
$wgGroupPermissions['*']['createpage'] = false;
$wgGroupPermissions['user']['createpage'] = true;
$wgGroupPermissions['sysop']['editaccount'] = true;
