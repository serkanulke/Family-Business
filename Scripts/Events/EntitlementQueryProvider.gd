class_name EntitlementQueryProvider
extends RefCounted


# Phase 2 boundary only. The future Store system remains authoritative.
func owns_entitlement(_entitlement_id: String) -> bool:
	return false
