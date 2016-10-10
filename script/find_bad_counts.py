#!/usr/bin/env python

# script to find inconsistent occurrences_count on elasticsearch backing exceptionist
# occurrences_count can then be corrected by hand.

import requests
import json
import os

target = os.environ.get("ELASTIC_HOST", "http://127.0.0.1:9200")

def url(path):
    return target + path

def all_docs(index, es_type, size=100):
    base = url("/{}/{}/_search".format(index, es_type))
    scroll = requests.get(base, params={"scroll": "1m", "search_type": "scan", "size": size}).json()
    scroll_id = scroll["_scroll_id"]
    print scroll_id
    try:
        rounds = 0
        while True:
            resp = requests.get(url("/_search/scroll"), params={ "scroll": "1m", "scroll_id": scroll_id})
            docs = resp.json()['hits']
            rounds += 1

            if len(docs['hits']) == 0:
                break

            for doc in docs['hits']:
                yield doc
    except Exception as e:
        print resp.content

def count(index, filtr):
    query = {
        "query": {
            "term": filtr
        }
    }

    return requests.get(url("/_count"), data=json.dumps(query)).json()

def find_inconsistent_uber_ids():
    for uber in all_docs("exceptionist", "exceptions"):
        expect = uber['_source'].get('occurrences_count', 0)
        actual = count("exceptionist", {"uber_key":  uber["_id"]}).get('count', 0)
        if expect != actual:
            print uber["_id"], ":", expect, "!=", actual

if __name__ == "__main__":
    find_inconsistent_uber_ids()
