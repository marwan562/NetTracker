package tracker

// counterDelta returns current - previous, treating any backwards step as a
// counter reset (0) instead of an underflow. Callers must re-baseline the
// previous sample when a reset is detected.
func counterDelta(current, previous uint64) uint64 {
	if current < previous {
		return 0
	}
	return current - previous
}
