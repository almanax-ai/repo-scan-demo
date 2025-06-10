<?php

libxml_disable_entity_loader(false);

function respond($msg) {
    header('Content-Type: text/plain');
    echo $msg;
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond("Usage: POST XML data to me.\n");
}

$raw = file_get_contents('php://input');
$doc = new DOMDocument();

$doc->loadXML($raw, LIBXML_NOENT | LIBXML_DTDLOAD);

$root = $doc->documentElement;
$action = $root->getAttribute('action');

if ($action === 'get_info') {
    $urlNodes = $root->getElementsByTagName('url');
    if ($urlNodes->length === 0) respond("Missing <url>.\n");
    $url = $urlNodes->item(0)->nodeValue;

    $response = @file_get_contents($url);
    if ($response === false) respond("Failed to fetch $url\n");

    respond($response);
}

respond("Unknown action: $action\n");
