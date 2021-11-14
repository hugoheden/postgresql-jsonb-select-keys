-- the selection must be a json 'object' (i.e not a scalar, list or null)
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
                                               jsonb_typeof(projection_property.value) = 'object'
                                               then
                                               jsonb_select_keys(doc_property.value, projection_property.value)
                                           else
                                               doc_property.value
                                       end
                                   ), '{}')
                  from jsonb_each(doc) doc_property(key, value)
                  inner join jsonb_each(selection) projection_property(key, value)
                             on doc_property.key = projection_property.key
        )
        -- doc is a scalar. In this case, we don't care about the projection and just return the scalar
        -- TODO consider MongoDB...: If the projection is an _object_ here, then our scalar would not be selected.
        else doc
    end;
$$

