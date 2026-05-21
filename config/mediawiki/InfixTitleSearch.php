<?php

if ( !defined( 'MEDIAWIKI' ) ) {
    exit;
}

$wgSpecialPages['InfixSearch'] = 'SpecialInfixSearch';
$wgAutoloadClasses['SpecialInfixSearch'] = __FILE__;
$wgHooks['SearchAfterNoDirectMatch'][] = 'trigowikiInfixSearchAfterNoDirectMatch';

function trigowikiInfixSearchAfterNoDirectMatch( $term, &$title ) {
    $candidate = SpecialInfixSearch::findFirstTitleForTerm( $term, 1 );
    if ( $candidate instanceof Title ) {
        $title = $candidate;
        return false;
    }
    return true;
}

class SpecialInfixSearch extends SpecialPage {
    public function __construct() {
        parent::__construct( 'InfixSearch', 'read' );
    }

    public function execute( $par ) {
        $this->setHeaders();

        $request = $this->getRequest();
        $out = $this->getOutput();
        $query = trim( $request->getText( 'q', $par ?: '' ) );
        $limit = max( 1, min( 50, $request->getInt( 'limit', 20 ) ) );

        $out->setPageTitle( 'Teilwortsuche' );
        $this->renderForm( $query, $limit );

        if ( $query === '' ) {
            return;
        }

        if ( mb_strlen( $query ) < 3 ) {
            $out->addHTML( Html::rawElement( 'p', [ 'class' => 'error' ], 'Bitte mindestens drei Zeichen eingeben.' ) );
            return;
        }

        $results = $this->findTitles( $query, $limit );
        if ( !$results ) {
            $out->addHTML( Html::rawElement( 'p', [], 'Keine Titel oder Weiterleitungen mit diesem Teilwort gefunden.' ) );
            return;
        }

        $linkRenderer = $this->getLinkRenderer();
        $items = [];
        foreach ( $results as $row ) {
            $title = Title::makeTitleSafe( (int)$row->page_namespace, $row->page_title );
            if ( !$title ) {
                continue;
            }

            $label = $linkRenderer->makeKnownLink( $title );
            $meta = [];
            if ( (int)$row->page_is_redirect === 1 ) {
                $meta[] = 'Weiterleitung';
            }
            if ( (int)$row->page_namespace !== NS_MAIN ) {
                $meta[] = $title->getNsText();
            }

            $items[] = Html::rawElement(
                'li',
                [],
                $label . ( $meta ? ' ' . Html::element( 'small', [], '(' . implode( ', ', $meta ) . ')' ) : '' )
            );
        }

        $out->addHTML( Html::rawElement( 'ul', [ 'class' => 'mw-search-results' ], implode( "\n", $items ) ) );
    }

    private function renderForm( $query, $limit ) {
        $action = $this->getPageTitle()->getLocalURL();
        $this->getOutput()->addHTML(
            Html::openElement( 'form', [ 'method' => 'get', 'action' => $action, 'class' => 'mw-search-form' ] ) .
            Html::element( 'input', [ 'type' => 'search', 'name' => 'q', 'value' => $query, 'size' => 40, 'autofocus' => 'autofocus' ] ) . ' ' .
            Html::element( 'input', [ 'type' => 'number', 'name' => 'limit', 'value' => $limit, 'min' => 1, 'max' => 50 ] ) . ' ' .
            Html::element( 'button', [ 'type' => 'submit' ], 'Suchen' ) .
            Html::closeElement( 'form' )
        );
    }

    private function findTitles( $query, $limit ) {
        $dbr = self::getReadDb();
        $normalized = self::normalizeTerm( $query );
        $like = $dbr->buildLike( $dbr->anyString(), str_replace( ' ', '_', $normalized ), $dbr->anyString() );

        $res = $dbr->select(
            'page',
            [ 'page_namespace', 'page_title', 'page_is_redirect' ],
            [
                'page_title ' . $like,
                'page_namespace' => [ NS_MAIN, NS_PROJECT, NS_HELP, NS_CATEGORY ],
            ],
            __METHOD__,
            [
                'ORDER BY' => [ 'page_is_redirect ASC', 'page_namespace ASC', 'page_title ASC' ],
                'LIMIT' => $limit,
            ]
        );

        $rows = [];
        foreach ( $res as $row ) {
            $rows[] = $row;
        }

        return $rows;
    }

    public static function findFirstTitleForTerm( $query, $limit = 1 ) {
        $query = self::normalizeTerm( $query );
        if ( $query === '' || mb_strlen( $query ) < 3 ) {
            return null;
        }

        $dbr = self::getReadDb();
        $like = $dbr->buildLike( $dbr->anyString(), str_replace( ' ', '_', $query ), $dbr->anyString() );

        $fetchLimit = max( 2, (int)$limit + 1 );
        $res = $dbr->select(
            'page',
            [ 'page_namespace', 'page_title' ],
            [
                'page_title ' . $like,
                'page_namespace' => [ NS_MAIN, NS_PROJECT, NS_HELP, NS_CATEGORY ],
            ],
            __METHOD__,
            [
                'ORDER BY' => [ 'page_is_redirect ASC', 'page_namespace ASC', 'page_title ASC' ],
                'LIMIT' => $fetchLimit,
            ]
        );

        $matches = [];
        foreach ( $res as $row ) {
            $title = Title::makeTitleSafe( (int)$row->page_namespace, $row->page_title );
            if ( $title ) {
                $matches[] = $title;
            }
        }

        return count( $matches ) === 1 ? $matches[0] : null;
    }

    private static function normalizeTerm( $term ) {
        $term = trim( preg_replace( '/\s+/', ' ', (string)$term ) );
        return trim( str_replace( [ '*', '"', "'" ], '', $term ) );
    }

    private static function getReadDb() {
        if ( class_exists( '\\MediaWiki\\MediaWikiServices' ) ) {
            $lb = \MediaWiki\MediaWikiServices::getInstance()->getDBLoadBalancer();
            if ( defined( 'DB_REPLICA' ) ) {
                return $lb->getConnection( DB_REPLICA );
            }
            return $lb->getConnection( DB_SLAVE );
        }

        if ( defined( 'DB_REPLICA' ) ) {
            return wfGetDB( DB_REPLICA );
        }

        return wfGetDB( DB_SLAVE );
    }
}
