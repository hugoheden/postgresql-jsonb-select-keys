# jsonb_select_keys - a PostgreSQL function

A postgresql function for selecting a subset of jsonb fields. "Deep selection" of json documents (well jsonb). (Is "projection" a better term?)

Tested with postgres 12

Warning: Never used or tested in production! 

TODO - describe some stuff:
* "doc" vs "selection"
* Selection must be an object.
* The selection object can only contain values that are objects or the scalar number "1". The same rule applies recursively to the sub-objects
* There is no way to say "just select the whole document". 
  * We could add that. We could allow the caller to just pass the number "1" as a selection, and let that mean "select the whole document"
* This whole concept is similar to (but simpler variant of) what  MongoDB calls a projection
* Use case: save network traffic (and application CPU?) by only pulling subsets of json that are actually needed by the application. Might be useful when having legacy DB with big legacy json-documents, and there is a slow query that really only needs
  a small sub-set, a deep sub-selection, of the stored json-documents. 
* The cost is significant CPU usage (queries get slower) on the database server
* It is somewhat quirky that the resulting document can contain lots of empty objects or lists. MongoDB behaves similarly.
  * We could fix that and make sure to filter out empty objects and lists (but I am not sure this could be done without a performance penalty)
* In MongoDB "sub-projection" (a sub-object of the selection) must not be empty, i.e no '{}'. If such an object is found, an error is emitted. We do it differently (to make the function simpler and maybe faster) - an empty object in the selection means "no fields are of interest". We thus don't have to do such a check or maintain logic for raising an error.
* In MongoDB, an object in the selection does NOT match a scalar in the document. We do it differently (but only because it is easier)
* The root level of the document in mongo is always an object (I think). But we we want to support root level lists too
* Somewhat related:
  * https://dba.stackexchange.com/questions/290005/how-to-select-sub-object-with-given-keys-from-jsonb
  * https://dba.stackexchange.com/questions/265731/how-to-select-subset-json-with-postgresql
