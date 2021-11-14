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


select
    (demo('{"a": "blabla", "b": {"c": "bleh", "d":  "bluh"}}',
          '{"a": 1}',
          '{"a": "blabla"}',
          '')
        ).*
union all
select
    (demo('{"a": "blabla", "b": {"c": "bleh", "d":  "bluh"}}',
          '{"b": 1}',
          '{"b": {"c": "bleh", "d":  "bluh"}}',
          '')
        ).*
union all
select
    (demo('{"a": "blabla", "b": {"c": "bleh", "d":  "bluh"}}',
          '{"b": {"c":  1}}',
          '{"b": {"c": "bleh"}}',
          '')
        ).*
union all
select
    (demo('{"a": {"b": "blabla", "c": "bla"}}',
          '{}',
          '{}',
          '')
        ).*
union all
select
    (demo('{"a": {"b": "blabla", "c": "bla"}}',
          '{"a": {"b": 1, "c": 1}}',
          '{"a": {"b": "blabla", "c": "bla"}}',
          '')
        ).*
union all
select
    (demo('{"a": {"b": "blabla", "c": "bla"}}',
          '{"a": {"b": 1}}',
          '{"a": {"b": "blabla"}}',
          '')
        ).*
union all
select
    (demo('{"a": {"b": "blabla", "c": "bla"}}',
          '{"a": {"d": 1}}',
          '{"a": {}}',
          '')
        ).*
union all
select
    (demo('{"a": {"b": "blabla", "c": "bla"}}',
          '{"a": {"b": {"D": 1}}}',
          '{"a": {"b": "blabla"}}',
          'Mongo: {"a": {}}')
        ).*
union all
select
    (demo('{"a": {"b": "blabla", "c": "bla"}}',
          '{"a": {}}',
          '{"a": {}}',
          'Mongo: "Error An empty sub-projection is not a valid value"')
        ).*
union all
select
    (demo('{"a": {"b": {"c": "bla"}}}',
          '{"a": {"b": {"c": 1}}}',
          '{"a": {"b": {"c": "bla"}}}',
          '')
        ).*
union all
select
    (demo('{"a": {"b": {"c": "bla"}}}',
          '{"a": {"b": {"c": {"D": 1}}}}',
          '{"a": {"b": {"c": "bla"}}}',
          'Mongo: {"a": {"b": {}}}')
        ).*
union all
select
    (demo('{"a": {"b": {"c": "bla"}}}',
          '{"a": {"b": {"E": 1}}}',
          '{"a": {"b": {}}}',
          '')
        ).*
union all
select
    (demo('{"a": {"b": {"c": "bla"}}}',
          '{"a": {"E": {"F": 1}}}',
          '{"a": {}}',
          '')
        ).*
union all
select
    (demo('{"ls": ["x", "y", "z"]}',
          '{}',
          '{}',
          '')
        ).*
union all
select
    (demo('{"ls": ["x", "y", "z"]}',
          '{"ls": 1}',
          '{"ls": ["x", "y", "z"]}',
          '')
        ).*
union all
select
    (demo('{"ls": ["x", "y", "z"]}',
          '{"a": 1}',
          '{}',
          '')
        ).*
union all
select
    (demo('{"ls": ["x", "y", "z"]}',
          '{"ls": {"a": 1}}',
          '{"ls": ["x", "y", "z"]}',
          'Mongo: {"ls": []}') -- Somewhat interesting
        ).*
union all
select
    (demo('{"ls": [{"a": "x"}, {"a": "y"}, {"b": "z"}]}',
          '{}',
          '{}',
          '')
        ).*
union all
select
    (demo('{"ls": [{"a": "x"}, {"a": "y"}, {"b": "z"}]}',
          '{"ls": 1}',
          '{"ls": [{"a": "x"}, {"a": "y"}, {"b": "z"}]}',
          '')
        ).*
union all
select
    (demo('{"ls": [{"a": "x"}, {"a": "y"}, {"b": "z"}]}',
          '{"a": 1}',
          '{}',
          '')
        ).*
union all
select
    (demo('{"ls": [{"a": "x"}, {"a": "y"}, {"b": "z"}]}',
          '{"ls": {"a": 1}}',
          '{"ls": [{"a": "x"}, {"a": "y"}, {}]}',
          '')
        ).*
union all
select
    (demo('{"ls": [{"a": "x", "b": "xx"}, {"a": "y", "b": "yy"}, {"a": "z", "b": "zz"}]}',
          '{"ls": {"a": 1}}',
          '{"ls": [{"a": "x"}, {"a": "y"}, {"a": "z"}]}',
          '')
        ).*
union all
select
    (demo('{"ls": [{"a": "x", "b": "xx"}, {"a": "y", "b": "yy"}, {"a": "z", "b": "zz"}]}',
          '{"ls": {"c": 1}}',
          '{"ls": [{}, {}, {}]}',
          '') -- interesting
        ).*
union all
select
    (demo('{"ls": [["a", "b"], ["c"], [], {"a": "x", "d": "y"}, {"e": "z"}]}',
          '{"ls": {}}',
          '{"ls": [["a", "b"], ["c"], [], {}, {}]}',
          'Mongo: {"ls": [[], [], [], {}, {}]}') -- TODO - double check Mongo
        ).*
union all
select
    (demo('{"ls": [["a", "b"], ["c"], [], {"a": "x", "d": "y"}, {"e": "z"}]}',
          '{"ls": 1}',
          '{"ls": [["a", "b"], ["c"], [], {"a": "x", "d": "y"}, {"e": "z"}]}',
          '')
        ).*
union all
select
    (demo('{"ls": [["a", "b"], ["c"], [], {"a": "x", "d": "y"}, {"e": "x"}]}',
          '{"ls": {"a": 1, "d": 1}}',
          '{"ls": [["a", "b"], ["c"], [], {"a": "x", "d": "y"}, {}]}',
          'Mongo: {"ls": [[], [], [], {"a": "x", "d": "y"}, {}]}')
        ).*
union all
select
    (demo('{"ls": [["a", "b"], ["c"], [], {"a": "x", "d": "y"}, {"e": "z"}]}',
          '{"ls": {"a": 1, "d": 1, "e": 1}}',
          '{"ls": [["a", "b"], ["c"], [], {"a": "x", "d": "y"}, {"e": "z"}]}',
          'Mongo: {"ls": [[], [], [], {"a": "x", "d": "y"}, {"e": "z"}]}')
        ).*
union all
select
    (demo('{"ls": [["a", "b"], ["c"], [], {"a": "x", "d": "y"}, {"e": "z"}]}',
          '{"ls": {"a": 1, "e": 1}}',
          '{"ls": [["a", "b"], ["c"], [], {"a": "x"}, {"e": "z"}]}',
          'Mongo: {"ls": [[], [], [], {"a": "x"}, {"e": "z"}]}')
        ).*
union all
select
    (demo('{}',
          '{}',
          '{}',
          '')
        ).*
union all
select
    (demo('17',
          '{}',
          '17',
          'This is a bit weird. An object in the selection - even if empty - matches a scalar in the document')
        ).*
union all
select
    (demo('"abc"',
          '{}',
          '"abc"',
          'This is a bit weird. An object in the selection - even if empty - matches a scalar in the document')
        ).*
union all
select
    (demo('null',
          '{}',
          'null',
          'This is a bit weird. An object in the selection - even if empty - matches a scalar in the document')
        ).*

union all
select
    (demo('["x", "y", "z"]',
          '{}',
          '["x", "y", "z"]',
          'This is a bit weird...?')
        ).*
union all
select
    (demo('["x", "y", "z"]',
          '{}',
          '["x", "y", "z"]',
          'This is a bit weird...?')
        ).*
union all
select
    (demo('["x", "y", "z"]',
          '{"a": 1}',
          '["x", "y", "z"]',
          'This is a bit weird...?')
        ).*
union all
select
    (demo('[{"a": "x"}, {"a": "y"}, {"b": "z"}]',
          '{}',
          '[{}, {}, {}]',
          '')
        ).*
union all
select
    (demo('[{"a": "x"}, {"a": "y"}, {"b": "z"}]',
          '{"a": 1}',
          '[{"a": "x"}, {"a": "y"}, {}]',
          '')
        ).*
union all
select
    (demo('[{"a": "x"}, {"a": "y"}, {"b": "z"}]',
          '{"a": {"b": 1}}',
          '[{"a": "x"}, {"a": "y"}, {}]',
          '')
        ).*
;
