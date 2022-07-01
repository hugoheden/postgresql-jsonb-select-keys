#!/bin/bash

set -e
set -o pipefail

function my_psql() {
  docker-compose exec -T postgres psql postgresql://postgres:secret@localhost/json_test \
      --no-psqlrc            \
      --tuples-only            \
      --set ON_ERROR_STOP=on \
      --no-align    \
      --field-separator '|' \
      --quiet \
      "$1" "$2"
}

my_psql --file json_test/jsonb_select_keys.sql

my_psql --file json_test/test/test_suite.sql;

ERRORS_TEST_RESULTS_EXAMPLE_DOC=$(my_psql --command 'select * from test_results_example_doc e where not e.correct')
if [ "xx" != "x${ERRORS_TEST_RESULTS_EXAMPLE_DOC}x" ]; then
  echo "test failed, please check table test_results_example_doc" 1>&2
  exit 1
fi

ERRORS_TEST_RESULTS_MANY_SMALL=$(my_psql --command 'select * from test_results_many_small e where not e.correct')
if [ "xx" != "x${ERRORS_TEST_RESULTS_MANY_SMALL}x" ]; then
  echo "test failed, please check table test_results_many_small" 1>&2
  exit 1
fi

echo "tests ok"

function print_ascii_doc_cell() {
  echo "| $1 "
}
function print_ascii_doc_cell_json() {
  printf "|\n[source,json]\n----\n%s\n----\n" "$1"
}

# Generate examples.adoc:
(
  printf '////\nGenerated file (by test.bash), manual edits will be overwritten\n////\n'
  doc="$(my_psql --command 'select jsonb_pretty(ed.x) from example_doc ed')"
  # shellcheck disable=SC2016
  printf '\nConsider this example doc and selections. `jsonb_select_keys()` yields the following results:\n\n'
  printf '[%%header,cols="a,a,a"]\n|===\n'
  printf '|A sample doc|Selection|Result\n\n'
  printf '.100+' ; print_ascii_doc_cell_json "$doc";
  # Gaahh, what a mess. We add a column containing a '#' character here. This is used as a line delimiter below in read
  # -d '#' instead of newline. (The jsonb_pretty outputs newlines, so we need to use another character as line
  # delimiter)
  my_psql --command "select jsonb_pretty(edr.selection), jsonb_pretty(edr.result), '#' from test_results_example_doc edr" |
    while IFS='|' read -r -d '#' selection result; do
      print_ascii_doc_cell_json "$selection" ; print_ascii_doc_cell_json "$result"
      echo
    done
  printf '\n|===\n'
) > examples.adoc

# Generate examples_many_small.adoc:
(
  printf '////\nGenerated file (by test.bash), manual edits will be overwritten\n////\n'
  printf '[%%header,cols="a,a,a"]\n|===\n'
  printf '|Doc|Selection|Result\n\n'
  # Gaahh, what a mess. We add a column containing a '#' character here. This is used as a line delimiter below in read
  # -d '#' instead of newline. (The jsonb_pretty outputs newlines, so we need to use another character as line
  # delimiter)
  my_psql --command "select jsonb_pretty(ems.doc), jsonb_pretty(ems.selection), jsonb_pretty(ems.result), '#' from test_results_many_small ems" |
    while IFS='|' read -r -d '#' doc selection result; do
      print_ascii_doc_cell_json "$doc"
      print_ascii_doc_cell_json "$selection"
      print_ascii_doc_cell_json "$result"
      echo
    done
  printf '\n|===\n'
) > examples_many_small.adoc

echo "files generated ok (check with git status, should be no differences)"
