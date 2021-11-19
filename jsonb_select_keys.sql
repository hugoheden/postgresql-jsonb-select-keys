
-- The "selection" must be a json 'object' (i.e not a scalar, list, null, SQL-null etc)
-- TODO - figure out and describe what happens otherwise

create or replace function jsonb_select_keys(doc jsonb, selection jsonb)
    returns jsonb
    language sql
    immutable
    parallel safe
as
$$
select
    case jsonb_typeof(doc)
        when 'array'
            then (select
                      coalesce(jsonb_agg(jsonb_select_keys(doc_list_element.x, selection)), '[]')
                  from jsonb_array_elements(doc) doc_list_element(x)
        )
        when 'object'
            then (select
                      coalesce(jsonb_object_agg(
                                       doc_property.key,
                                       case
                                           when
                                               selection_property.value = '1'
                                               then
                                               doc_property.value
                                           else
                                               jsonb_select_keys(doc_property.value, selection_property.value)
                                       end
                                   ), '{}')
                  from jsonb_each(doc) doc_property(key, value)
                  inner join jsonb_each(selection) selection_property(key, value)
                             on doc_property.key = selection_property.key
        )
        -- doc is a scalar. In this case, we don't care about the selection and just return the scalar (even if the selection is an object!)
        -- TODO consider difference from MongoDB...: If the selection is an _object_ here, then our scalar would _not_ be selected in MongoDB.
        else doc
    end;
$$

