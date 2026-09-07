# P0 tuning note

`p0_constants.gd` is the intended source of truth for P0 tuning values. Until `combat_test.gd` is refactored to consume those constants directly, the prototype keeps matching values in its local constants for maximum standalone reliability. During the first cleanup after runtime validation, replace duplicated literals with `P0Constants` references.
