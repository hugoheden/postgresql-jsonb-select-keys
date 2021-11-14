create or replace function demo(inout description text,
                                inout doc jsonb,
                                inout selection jsonb,
                                inout expected_result jsonb,
                                out result jsonb,
                                out correct boolean)
    language sql
    immutable
    parallel safe
as
$$
select
    description,
doc,
selection,
expected_result,
r.result,
coalesce(r.result = expected_result, ((r.result is null) = (expected_result is null)))
from jsonb_select_keys(doc, selection) r(result)
$$;

select
    (
        demo('', '{"a": {"b": "blabla", "c": "bla"}}',
             '{}', '{}')
        ).*
union all
select
    (
        demo('', '{"a": {"b": "blabla", "c": "bla"}}',
             '{"a": {"b": 1, "c": 1}}', '{"a": {"b": "blabla", "c": "bla"}}')
        ).*
union all
select
    (
        demo('', '{"a": {"b": "blabla", "c": "bla"}}',
             '{"a": {"b": 1}}', '{"a": {"b": "blabla"}}')
        ).*
union all
select
    (
        demo('', '{"a": {"b": "blabla", "c": "bla"}}',
             '{"a": {"d": 1}}', '{"a": {}}') -- INTERESTING. Empty objects returned.
        ).*
union all
select
    (
        demo('Mongo: {"a": {}}', '{"a": {"b": "blabla", "c": "bla"}}',
             '{"a": {"b": {"D": 1}}}', '{"a": {"b": "blabla"}}')
        ).*

-- INTERESTING: An object in the projection does NOT match a scalar in the doc

-- test_stuff('{"a": {"b": "blabla", "c": "bla"}}, 1); // ERROR "MongoServerError: Expected field projectionto be of type object"
-- // test_stuff('{"a": {"b": "blabla", "c": "bla"}}, null); // {"_id": {"$oid": "618d959b416c1a278f47f3eb"}, "a": {"b": "blabla", "c": "bla"}} -- just uninteresting - the selection document is ignored sort of'
-- // test_stuff('{"a": {"b": "blabla", "c": "bla"}}, {"_id": 0, "a": {}}); // Interesting ERROR: Query failed with error code 51270 and error message 'An empty sub-projection is not a valid value. Found empty object at path' on server localhost:27017'
union all
select
    (
        demo('', '{"a": {"b": {"c": "bla"}}}',
             '{"a": {"b": {"c": 1}}}', '{"a": {"b": {"c": "bla"}}}')
        ).*
union all
select
    (
        demo('Mongo: {"a": {"b": {}}}', '{"a": {"b": {"c": "bla"}}}',
             '{"a": {"b": {"c": {"D": 1}}}}', '{"a": {"b": {"c": "bla"}}}')
        ).*
union all
select
    (
        demo('', '{"a": {"b": {"c": "bla"}}}',
             '{"a": {"b": {"E": 1}}}', '{"a": {"b": {}}}')
        ).*
union all
select
    (
        demo('', '{"a": {"b": {"c": "bla"}}}',
             '{"a": {"E": {"F": 1}}}', '{"a": {}}')
        ).*
union all
select
    (
        demo('', '{"ls": ["1", "3", "5"]}',
             '{}', '{}')
        ).*
union all
select
    (
        demo('', '{"ls": ["1", "3", "5"]}',
             '{"ls": 1}', '{"ls": ["1", "3", "5"]}')
        ).*
union all
select
    (
        demo('', '{"ls": ["1", "3", "5"]}',
             '{"a": 1}', '{}')
        ).*
union all
select
    (
        demo('Monge: {"ls": []}', '{"ls": ["1", "3", "5"]}',
             '{"ls": {"a": 1}}', '{"ls": ["1", "3", "5"]}') -- Somewhat interesting
        ).*
union all
select
    (
        demo('', '{"ls": [{"a": "1"}, {"a": "3"}, {"a": "5"}, {"c": "hello"}]}',
             '{}', '{}')
        ).*
union all
select
    (
        demo('', '{"ls": [{"a": "1"}, {"a": "3"}, {"a": "5"}]}',
             '{"ls": 1}', '{"ls": [{"a": "1"}, {"a": "3"}, {"a": "5"}]}')
        ).*
union all
select
    (
        demo('', '{"ls": [{"a": "1"}, {"a": "3"}, {"a": "5"}]}',
             '{"a": 1}', '{}')
        ).*
union all
select
    (
        demo('', '{"ls": [{"a": "1"}, {"a": "3"}, {"a": "5"}]}',
             '{"ls": {"a": 1}}', '{"ls": [{"a": "1"}, {"a": "3"}, {"a": "5"}]}')
        ).*
union all
select
    (
        demo('', '{"ls": [{"a": "1", "b": "2"}, {"a": "3", "b": "4"}, {"a": "5", "b": "6"}]}',
             '{"ls": {"a": 1}}', '{"ls": [{"a": "1"}, {"a": "3"}, {"a": "5"}]}')
        ).*
union all
select
    (
        demo('', '{"ls": [{"a": "1", "b": "2"}, {"a": "3", "b": "4"}, {"a": "5", "b": "6"}]}',
             '{"ls": {"CDE": 1}}', '{"ls": [{}, {}, {}]}') -- interesting
        ).*
union all
select
    (
        demo('Mongo: {"ls": [[], [], [], {}, {}]}', '{"ls": [["a", "b"], ["c"], [], {"a": "bla", "d": "bluh"}, {"e": "bleh"}]}',
             '{"ls": {}}', '{"ls": [["a", "b"], ["c"], [], {}, {}]}') -- TODO - double check Mongo
        ).*
union all
select
    (
        demo('', '{"ls": [["a", "b"], ["c"], [], {"a": "bla", "d": "bluh"}, {"e": "bleh"}]}',
             '{"ls": 1}', '{"ls": [["a", "b"], ["c"], [], {"a": "bla", "d": "bluh"}, {"e": "bleh"}]}')
        ).*
union all
select
    (
        demo('Mongo: {"ls": [[], [], [], {"a": "bla", "d": "bluh"}, {}]}', '{"ls": [["a", "b"], ["c"], [], {"a": "bla", "d": "bluh"}, {"e": "bleh"}]}',
             '{"ls": {"a": 1, "d": 1}}', '{"ls": [["a", "b"], ["c"], [], {"a": "bla", "d": "bluh"}, {}]}')
        ).*
union all
select
    (
        demo('Mongo: {"ls": [[], [], [], {"a": "bla", "d": "bluh"}, {"e": "bleh"}]}', '{"ls": [["a", "b"], ["c"], [], {"a": "bla", "d": "bluh"}, {"e": "bleh"}]}',
             '{"ls": {"a": 1, "d": 1, "e": 1}}', '{"ls": [["a", "b"], ["c"], [], {"a": "bla", "d": "bluh"}, {"e": "bleh"}]}')
        ).*
union all
select
    (
        demo('Mongo: {"ls": [[], [], [], {"a": "bla"}, {"e": "bleh"}]}', '{"ls": [["a", "b"], ["c"], [], {"a": "bla", "d": "bluh"}, {"e": "bleh"}]}',
             '{"ls": {"a": 1, "e": 1}}', '{"ls": [["a", "b"], ["c"], [], {"a": "bla"}, {"e": "bleh"}]}')
        ).*;


-- union all select (
-- test_stuff({}, {"_id": 0}); // {}
-- test_stuff({}, {"_id": 1}); // {"_id": {"$oid": "618e8f983ab9185a982c160f"}}
-- test_stuff(17, {"_id": 0}); // {}
-- test_stuff(17, {"_id": 1}); // {"_id": {"$oid": "618e8fa13ab9185a982c1611"}}
-- test_stuff("abc", {"_id": 0}); // WEIRD? {"0": "a", "1": "b", "2": "c"}
-- test_stuff(null, {"_id": 0}); // {}
-- test_stuff(["1", "3", "5"], {"_id": 0}); // WEIRD {"0": "1", "1": "3", "2": "5"}
-- test_stuff(["1", "3", "5"], {"_id": 0, "a": 1}); // {}
-- test_stuff([{"a": "1"}, {"a": "3"}, {"a": "5"}], {"_id": 0}); // WEIRD {"0": {"a": "1"}, "1": {"a": "3"}, "2": {"a": "5"}}
-- test_stuff([{"a": "1"}, {"a": "3"}, {"a": "5"}], {"_id": 0, "a": 1}); // {}
-- test_stuff([{"a": "1"}, {"a": "3"}, {"a": "5"}], {"_id": 0, "a": {"b": 1}}); // {}
