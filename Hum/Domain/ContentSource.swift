/// Where a piece of content comes from, which is the only thing the
/// subscription gate needs to know about it.
///
/// The distinction is load-bearing: Apple Music **catalog** content requires an
/// active subscription, while **library** content (purchased, matched, or
/// uploaded) plays without one. Collapsing the two would either block a
/// subscriber-less user from music they own, or send a user toward the
/// subscription offer for content the offer is irrelevant to.
enum ContentSource: Sendable, Hashable, CaseIterable {
    case catalog
    case library
}
