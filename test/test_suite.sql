-- create database json_test; -- this is done in docker-compose.yml

create or replace function run_test_case(inout doc jsonb,
                                         inout selection jsonb,
                                         out result jsonb,
                                         inout expected_result jsonb,
                                         out correct boolean,
                                         inout comment text)
    language sql
    immutable
    parallel safe
as
$$
select doc,
       selection,
       r.result,
       expected_result,
       coalesce(r.result = expected_result, ((r.result is null) = (expected_result is null))),
       comment
from jsonb_select_keys(doc, selection) r(result)
$$;

drop table if exists example_doc;
create table example_doc(x)
as
    (select '
            {
              "a": "ax",
              "a2": "a2x",
              "b_obj": {
                "ba": "bax",
                "bb": "bbx"
              },
              "c_obj": {
                "ca": "cax",
                "cb": [
                  "cbx",
                  "cby"
                ],
                "cc": [
                  {
                    "cca": "cca1",
                    "ccb": "ccb1"
                  },
                  {
                    "cca": "cca2"
                  },
                  {
                    "ccb": "ccb2"
                  }
                ]
              },
              "d_list": [
                "dx",
                "dy"
              ],
              "e_list": [
                {
                  "ea": "ea1",
                  "eb": "eb1"
                },
                {
                  "ea": "ea2"
                },
                {
                  "eb": "eb2"
                }
              ]
            }
            '::jsonb);

drop table if exists test_results_example_doc;
create table test_results_example_doc as
with example_selections(selection, expected_result, comment)
         as
         (values (
                     -- selection:
                     '{
                       "a": 1
                     }'::jsonb,
                     -- expected result:
                     '{
                       "a": "ax"
                     }'::jsonb,
                     'Select a property at the root level'),

                 (
                     -- selection:
                     '{
                       "a": 1,
                       "b_obj": {
                         "bb": 1
                       }
                     }'::jsonb,
                     -- expected result:
                     '{
                       "a": "ax",
                       "b_obj": {
                         "bb": "bbx"
                       }
                     }'::jsonb,
                     'Select a property at the root level, and one property in a sub-object'),

                 (
                     -- selection:
                     '{
                       "a": 1,
                       "d_list": 1
                     }'::jsonb,
                     -- expected result:
                     '{
                       "a": "ax",
                       "d_list": [
                         "dx",
                         "dy"
                       ]
                     }'::jsonb,
                     'Select a property and a list at the root level'),

                 (
                     -- selection:
                     '{
                       "a": 1,
                       "e_list": {
                         "ea": 1
                       }
                     }'::jsonb,
                     -- expected result:
                     '{
                       "a": "ax",
                       "e_list": [
                         {
                           "ea": "ea1"
                         },
                         {
                           "ea": "ea2"
                         },
                         {}
                       ]
                     }'::jsonb,
                     'Select a property and parts of sub-objects within a list'),

                 (
                     -- selection:
                     '{
                       "c_obj": {
                         "cc": {
                           "ccb": 1
                         }
                       },
                       "b_obj": {
                         "bb": 1
                       }
                     }'::jsonb,
                     -- expected result:
                     '{
                       "b_obj": {
                         "bb": "bbx"
                       },
                       "c_obj": {
                         "cc": [
                           {
                             "ccb": "ccb1"
                           },
                           {},
                           {
                             "ccb": "ccb2"
                           }
                         ]
                       }
                     }'::jsonb,
                     'Select a property and parts of sub-objects within a list within a sub-object, and a property in a sub-object '))
select (run_test_case(d.x, e.selection, e.expected_result, e.comment)).*
from example_doc d
         cross join example_selections e;



drop table if exists test_results_many_small;
create table test_results_many_small as
select (run_test_case(t.doc::jsonb, t.selection::jsonb, t.expected_result::jsonb, t.comment)).*
from (values ('{"a": "blabla", "b": {"c": "bleh", "d":  "bluh"}}', -- doc
              '{"a": 1}', -- selection
              '{"a": "blabla"}', -- expected result
              '')                  -- comment
           , ('{"a": "blabla", "b": {"c": "bleh", "d":  "bluh"}}', -- doc
              '{"b": 1}', -- selection
              '{"b": {"c": "bleh", "d":  "bluh"}}', -- expected result
              '')                  -- comment
           , ('{"a": "blabla", "b": {"c": "bleh", "d":  "bluh"}}',
              '{"b": {"c":  1}}',
              '{"b": {"c": "bleh"}}',
              '')
           , ('{"a": "blabla", "b": {"c": "bleh", "d":  "bluh"}}',
              '{"c":  1}',
              '{}',
              '')
           , ('{"a": {"b": "blabla", "c": "bla"}}',
              '{}',
              '{}',
              '')
           , ('{"a": {"b": "blabla", "c": "bla"}}',
              '{"a": {"b": 1, "c": 1}}',
              '{"a": {"b": "blabla", "c": "bla"}}',
              '')
           , ('{"a": {"b": "blabla", "c": "bla"}}',
              '{"a": {"b": 1}}',
              '{"a": {"b": "blabla"}}',
              '')
           , ('{"a": {"b": "blabla", "c": "bla"}}',
              '{"a": {"d": 1}}',
              '{"a": {}}',
              '')
           , ('{"a": {"b": "blabla", "c": "bla"}}',
              '{"a": {"b": {"D": 1}}}',
              '{"a": {"b": "blabla"}}',
              'Mongo: {"a": {}}')
           , ('{"a": {"b": "blabla", "c": "bla"}}',
              '{"a": {}}',
              '{"a": {}}',
              'Mongo: "Error An empty sub-projection is not a valid value"')
           , ('{"a": {"b": {"c": "bla"}}}',
              '{"a": {"b": {"c": 1}}}',
              '{"a": {"b": {"c": "bla"}}}',
              '')
           , ('{"a": {"b": {"c": "bla"}}}',
              '{"a": {"b": {"c": {"D": 1}}}}',
              '{"a": {"b": {"c": "bla"}}}',
              'Mongo: {"a": {"b": {}}}')
           , ('{"a": {"b": {"c": "bla"}}}',
              '{"a": {"b": {"E": 1}}}',
              '{"a": {"b": {}}}',
              '')
           , ('{"a": {"b": {"c": "bla"}}}',
              '{"a": {"E": {"F": 1}}}',
              '{"a": {}}',
              '')
           , ('{"ls": ["x", "y", "z"]}',
              '{}',
              '{}',
              '')
           , ('{"ls": ["x", "y", "z"]}',
              '{"ls": 1}',
              '{"ls": ["x", "y", "z"]}',
              '')
           , ('{"ls": []}',
              '{"ls": 1}',
              '{"ls": []}',
              '')
           , ('{"ls": ["x", "y", "z"]}',
              '{"a": 1}',
              '{}',
              '')
           , ('{"ls": ["x", "y", "z"]}',
              '{"ls": {"a": 1}}',
              '{"ls": ["x", "y", "z"]}',
              'Mongo: {"ls": []}') -- Somewhat interesting
           , ('{"ls": []}',
              '{"ls": {"a": 1}}',
              '{"ls": []}',
              '')
           , ('{"ls": [{"a": "x"}, {"a": "y"}, {"b": "z"}]}',
              '{}',
              '{}',
              '')
           , ('{"ls": [{"a": "x"}, {"a": "y"}, {"b": "z"}]}',
              '{"ls": 1}',
              '{"ls": [{"a": "x"}, {"a": "y"}, {"b": "z"}]}',
              '')
           , ('{"ls": [{"a": "x"}, {"a": "y"}, {"b": "z"}]}',
              '{"a": 1}',
              '{}',
              '')
           , ('{"ls": [{"a": "x"}, {"a": "y"}, {"b": "z"}]}',
              '{"ls": {"a": 1}}',
              '{"ls": [{"a": "x"}, {"a": "y"}, {}]}',
              '')
           , ('{"ls": [{"a": "x"}, {"a": "y"}, {"b": "z"}]}',
              '{"ls": {"c": 1}}',
              '{"ls": [{}, {}, {}]}',
              '')
           , ('{"ls": [{"a": "x", "b": "xx"}, {"a": "y", "b": "yy"}, {"a": "z", "b": "zz"}]}',
              '{"ls": {"a": 1}}',
              '{"ls": [{"a": "x"}, {"a": "y"}, {"a": "z"}]}',
              '')
           , ('{"ls": [{"a": "x", "b": "xx"}, {"a": "y", "b": "yy"}, {"a": "z", "b": "zz"}]}',
              '{"ls": {"c": 1}}',
              '{"ls": [{}, {}, {}]}',
              '')                  -- interesting
           , ('{"ls": [["a", "b"], ["c"], [], {"a": "x", "d": "y"}, {"e": "z"}]}',
              '{"ls": {}}',
              '{"ls": [["a", "b"], ["c"], [], {}, {}]}',
              'Mongo: Error An empty sub-projection is not a valid value.')
           , ('{"ls": [["a", "b"], ["c"], [], {"a": "x", "d": "y"}, {"e": "z"}]}',
              '{"ls": 1}',
              '{"ls": [["a", "b"], ["c"], [], {"a": "x", "d": "y"}, {"e": "z"}]}',
              '')
           , ('{"ls": [["a", "b"], ["c"], [], {"a": "x", "d": "y"}, {"e": "x"}]}',
              '{"ls": {"a": 1, "d": 1}}',
              '{"ls": [["a", "b"], ["c"], [], {"a": "x", "d": "y"}, {}]}',
              'Mongo: {"ls": [[], [], [], {"a": "x", "d": "y"}, {}]}')
           , ('{"ls": [["a", "b"], ["c"], [], {"a": "x", "d": "y"}, {"e": "z"}]}',
              '{"ls": {"a": 1, "d": 1, "e": 1}}',
              '{"ls": [["a", "b"], ["c"], [], {"a": "x", "d": "y"}, {"e": "z"}]}',
              'Mongo: {"ls": [[], [], [], {"a": "x", "d": "y"}, {"e": "z"}]}')
           , ('{"ls": [["a", "b"], ["c"], [], {"a": "x", "d": "y"}, {"e": "z"}]}',
              '{"ls": {"a": 1, "e": 1}}',
              '{"ls": [["a", "b"], ["c"], [], {"a": "x"}, {"e": "z"}]}',
              'Mongo: {"ls": [[], [], [], {"a": "x"}, {"e": "z"}]}')
           , ('{}',
              '{}',
              '{}',
              '')
           , ('17',
              '{}',
              '17',
              'This is a bit weird. An object in the selection - even if empty - matches a scalar in the document')
           , ('"abc"',
              '{}',
              '"abc"',
              'This is a bit weird. An object in the selection - even if empty - matches a scalar in the document')
           , ('null',
              '{}',
              'null',
              'This is a bit weird. An object in the selection - even if empty - matches a scalar in the document')
           , ('["x", "y", "z"]',
              '{}',
              '["x", "y", "z"]',
              'This is a bit weird...?')
           , ('["x", "y", "z"]',
              '{"a": 1}',
              '["x", "y", "z"]',
              'This is a bit weird...?')
           , ('[{"a": "x"}, {"a": "y"}, {"b": "z"}]',
              '{}',
              '[{}, {}, {}]',
              '')
           , ('[{"a": "x"}, {"a": "y"}, {"b": "z"}]',
              '{"a": 1}',
              '[{"a": "x"}, {"a": "y"}, {}]',
              '')
           , ('[{"a": "x"}, {"a": "y"}, {"b": "z"}]',
              '{"a": {"b": 1}}',
              '[{"a": "x"}, {"a": "y"}, {}]',
              '')
            , (
                '{
                    "a": "hello",
                    "b": {
                        "c": "there",
                        "d": "how"
                    },
                    "e" : [
                        {
                          "f": "are",
                          "g": "you"
                        },
                        {
                          "f": "this",
                          "g": "evening"
                        }
                    ]
                }'::jsonb,
               '{
                  "b": {
                      "c": 1
                  },
                  "e" : {
                      "g": 1
                  }
               }'::jsonb,
                '{
                  "b": {
                    "c": "there"
                  },
                  "e" : [
                    {
                      "g": "you"
                    },
                    {
                      "g": "evening"
                    }
                  ]
                }'::jsonb,
               'to be used in README as initial example'
        )
      ) t("doc", selection, expected_result, comment);

