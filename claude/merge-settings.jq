# Deep-merge $desired into the current settings: objects merge key by key, arrays
# union (so an allow-rule added by /permissions is never dropped), scalars are
# overwritten by $desired. Unioning arrays is what makes re-running idempotent.
def merge($a; $b):
  if   ($a | type) == "object" and ($b | type) == "object"
  then reduce ($b | keys_unsorted[]) as $k ($a; .[$k] = merge($a[$k]; $b[$k]))
  elif ($a | type) == "array"  and ($b | type) == "array"
  then ($a + $b | unique)
  elif $b == null
  then $a
  else $b
  end;

merge(.[0]; .[1])
