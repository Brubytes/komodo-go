/// Identity of a filterable resource list.
///
/// Used to key shared filter-state providers so each resource screen gets
/// independent search, tag, and template state.
enum ResourceKind { builds, repos, actions, procedures, syncs }
