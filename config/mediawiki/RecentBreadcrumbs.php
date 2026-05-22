<?php

if ( !defined( 'MEDIAWIKI' ) ) {
    exit;
}

const TRIGOWIKI_RECENT_BREADCRUMBS_LIMIT = 5;

if ( !class_exists( 'Html' ) && class_exists( '\MediaWiki\Html\Html' ) ) {
    class_alias( '\MediaWiki\Html\Html', 'Html' );
}

$wgHooks['BeforePageDisplay'][] = static function ( OutputPage $out, Skin $skin ) {
    $title = $out->getTitle();
    if ( !is_object( $title ) || !method_exists( $title, 'getPrefixedDBkey' ) ) {
        return true;
    }
    if ( $title->isSpecial( 'Badtitle' ) ) {
        return true;
    }

    $out->addInlineStyle( <<<CSS
.trigowiki-recent-breadcrumbs {
    background: #f8f9fa;
    border: 1px solid #c8ccd1;
    color: #202122;
    font-size: 0.875rem;
    line-height: 1.45;
    margin: 0 0 0.8em;
    padding: 0.45em 0.7em;
}
.trigowiki-recent-breadcrumbs a {
    color: #0645ad;
}
.trigowiki-recent-breadcrumbs-label {
    font-weight: 600;
}
.trigowiki-recent-breadcrumbs:empty {
    display: none;
}
CSS
    );

    $out->prependHTML(
        Html::element( 'div', [
            'class' => 'trigowiki-recent-breadcrumbs',
            'data-current-key' => $title->getPrefixedDBkey(),
            'data-current-text' => $title->getPrefixedText(),
            'data-current-url' => $title->getLocalURL(),
            'data-limit' => TRIGOWIKI_RECENT_BREADCRUMBS_LIMIT,
        ] )
        . Html::rawElement( 'script', [], <<<'JS'
( function () {
    var key = 'trigowiki-recent-breadcrumbs';
    var node = document.querySelector( '.trigowiki-recent-breadcrumbs' );
    if ( !node || !window.localStorage ) {
        return;
    }

    var current = {
        key: node.getAttribute( 'data-current-key' ),
        text: node.getAttribute( 'data-current-text' ),
        url: node.getAttribute( 'data-current-url' )
    };
    var limit = parseInt( node.getAttribute( 'data-limit' ), 10 ) || 5;
    var items = [];

    try {
        items = JSON.parse( window.localStorage.getItem( key ) || '[]' );
    } catch ( e ) {
        items = [];
    }
    if ( !Array.isArray( items ) ) {
        items = [];
    }

    items = items.filter( function ( item ) {
        return item && item.key && item.key !== current.key;
    } );
    items.push( current );
    items = items.slice( -limit );

    try {
        window.localStorage.setItem( key, JSON.stringify( items ) );
    } catch ( e ) {}

    if ( items.length < 2 ) {
        return;
    }

    var label = document.createElement( 'span' );
    label.className = 'trigowiki-recent-breadcrumbs-label';
    label.textContent = 'Zuletzt besucht:';
    node.appendChild( label );
    node.appendChild( document.createTextNode( ' ' ) );

    items.forEach( function ( item, index ) {
        if ( index > 0 ) {
            node.appendChild( document.createTextNode( ' » ' ) );
        }
        var link = document.createElement( 'a' );
        link.href = item.url;
        link.textContent = item.text;
        node.appendChild( link );
    } );
}() );
JS
        )
    );

    return true;
};