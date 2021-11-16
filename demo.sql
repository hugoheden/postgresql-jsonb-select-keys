-- Usage example:

select
    jsonb_select_keys(
            '{"a": "x", "b": {"c": "y", "d": "z"}}', -- document

            '{"b": {"c": 1}}' -- selection

        );
-- result: {"b": {"c": "y"}}

drop function demo;
create or replace function demo(inout doc jsonb,
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
select
    doc,
    selection,
    r.result,
    expected_result,
    coalesce(r.result = expected_result, ((r.result is null) = (expected_result is null))),
    comment
from jsonb_select_keys(doc, selection) r(result)
$$;


with
    example_doc(x) as (select
                           '
                           {
                             "a": "ax",
                             "a2": "a2x",
                             "b_obj": {
                               "ba": "bax",
                               "bb": "bbx"
                             },
                             "c_list": [
                               "cx",
                               "cy"
                             ],
                             "d_list": [
                               {"da": "da1", "db": "db1"},
                               {"da": "da2"}, {"db": "db2"}
                             ],
                             "e_obj": {
                               "ea": "eax",
                               "eb": ["ebx", "eby"],
                               "ec": [
                                 {"eca": "eca1", "ecb": "ecb1"},
                                 {"eca": "eca2"},
                                 {"ecb": "ecb2"}
                               ]
                             }
                           }
                           '::jsonb)
select (demo(example_doc.x, t.selection, t.expected_result, t.comment)).*
from example_doc
cross join (values

                (
                    '{"a": 1}'::jsonb, -- selection
                    '{"a": "ax"}'::jsonb, -- result
                    'Select a property at the root level'),

                (
                    '{"a": 1, "b_obj": {"bb": 1}}'::jsonb, -- selection
                    '{"a": "ax", "b_obj": {"bb": "bbx"}}'::jsonb, -- result
                    'Select a property at the root level, and one property in a sub-object'),

                (
                    '{"a": 1, "c_list": 1}'::jsonb, -- selection
                    '{"a": "ax", "c_list": ["cx", "cy"]}'::jsonb, -- result
                    'Select a property and a list at the root level'),

                (
                    -- selection:
                    '{"a": 1, "d_list": {"da": 1}}'::jsonb,
                    -- result:
                    '{
                      "a": "ax",
                      "d_list": [{"da": "da1"}, {"da": "da2"}, {}]
                    }'::jsonb,
                    'Select a property and parts of sub-objects within a list'),

                (
                    '{"e_obj": {"ec": {"ecb": 1}}, "b_obj": {"bb": 1}}'::jsonb, -- selection
                    '{"b_obj": {"bb": "bbx"}, "e_obj": {"ec": [{"ecb": "ecb1"}, {}, {"ecb": "ecb2"}]}}'::jsonb, --result
                    'Select a property and parts of sub-objects within a list within a sub-object, and a property in a sub-object ')
    ) t(selection, expected_result, comment);



select (demo(t.doc::jsonb, t.selection::jsonb, t.expected_result::jsonb, t.comment)).*
from (values
          ('{"a": "blabla", "b": {"c": "bleh", "d":  "bluh"}}',
           '{"a": 1}',
           '{"a": "blabla"}',
           '')
        , ('{"a": "blabla", "b": {"c": "bleh", "d":  "bluh"}}',
           '{"b": 1}',
           '{"b": {"c": "bleh", "d":  "bluh"}}',
           '')
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
           '') -- interesting
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
) t("doc", selection, expected_result, comment);
