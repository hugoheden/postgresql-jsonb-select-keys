#!/bin/bash

set -e

function my_psql() {
  psql postgresql://postgres:secret@localhost/json_test \
      --no-psqlrc            \
      --tuples-only            \
      --set ON_ERROR_STOP=on \
      --no-align    \
      --field-separator '|' \
      --quiet \
      "$1" "$2"
}

my_psql --file demo.sql;

function print_ascii_doc_cell() {
  echo "| $1 "
}
function print_ascii_doc_cell_json() {
  printf "|\n[source,json]\n----\n%s\n----\n" "$1"
}

(
  printf '////\nGenerated file, manual edits will be overwritten\n////\n'
  printf '[%%header,cols="a"]\n|===\n'
  printf '|Example doc\n\n'
  # Gaahh, what a mess. We add a column containing a '#' character here. This is used as a line delimiter below in read
  # -d '#' instead of newline. (The jsonb_pretty outputs newlines, so we need to use another character as line
  # delimiter)
  my_psql --command "select jsonb_pretty(ed.x), '#' from example_doc ed" |
    while IFS='|' read -r -d '#' doc; do
      print_ascii_doc_cell_json "$doc"
      echo
    done
  printf '\n|===\n'

  printf '\nGiven the above doc, consider the following example selections and results:'
  printf '[%%header,cols="a,a"]\n|===\n'
  printf '|Selection|Result\n\n'
  # Gaahh, what a mess. We add a column containing a '#' character here. This is used as a line delimiter below in read
  # -d '#' instead of newline. (The jsonb_pretty outputs newlines, so we need to use another character as line
  # delimiter)
  my_psql --command "select jsonb_pretty(edr.selection), jsonb_pretty(edr.result), '#' from example_doc_result edr" |
    while IFS='|' read -r -d '#' selection result; do
      print_ascii_doc_cell_json "$selection" ; print_ascii_doc_cell_json "$result"
      echo
    done
  printf '\n|===\n'
) >examples.adoc

(
  printf '////\nGenerated file, manual edits will be overwritten\n////\n'
  printf '[%%header,cols="a,a,a"]\n|===\n'
  printf '|Doc|Selection|Result\n\n'
  # Gaahh, what a mess. We add a column containing a '#' character here. This is used as a line delimiter below in read
  # -d '#' instead of newline. (The jsonb_pretty outputs newlines, so we need to use another character as line
  # delimiter)
  my_psql --command "select jsonb_pretty(ems.doc), jsonb_pretty(ems.selection), jsonb_pretty(ems.result), '#' from examples_many_small ems" |
    while IFS='|' read -r -d '#' doc selection result; do
      print_ascii_doc_cell_json "$doc"
      print_ascii_doc_cell_json "$selection"
      print_ascii_doc_cell_json "$result"
      echo
    done
  printf '\n|===\n'
) >examples_many_small.adoc
