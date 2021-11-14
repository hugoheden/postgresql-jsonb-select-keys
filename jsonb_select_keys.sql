

create or replace function jsonb_select_keys(doc jsonb, selection jsonb)
    returns jsonb
    language sql
    immutable
    parallel safe
as
$$
select
    -- TODO - consider.. should we remove this? When is it needed? Do we lose performance?
    case when selection = '1'
             then doc
         else
             case jsonb_typeof(doc)
                 when 'array' then (
                     select
                         coalesce(jsonb_agg(jsonb_select_keys(doc_list_element.x, selection)), '[]')
                     from jsonb_array_elements(doc) doc_list_element(x)
                 )
                 when 'object' then
                     (
                         select
                             coalesce(jsonb_object_agg(
                                              doc_property.key,
                                              case
                                                  -- Minor note: This case statement is an optimization. We could just select
                                                  -- jsonb_select_keys(doc_property.value, projection_property.value) here. The
                                                  -- effect would be the same but that variant seems slower.
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
                 -- TODO consider ...: If the projection is an _object_ here... What should we really return here?
                 else doc
             end
    end;
$$

