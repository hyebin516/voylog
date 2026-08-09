// Single source of truth for behavior action weights (phase 5) -- never
// hardcode these anywhere else. Weight sign determines whether an action
// nudges the user's preference vector/tag_scores toward or away from the
// place; magnitude reflects how strong a signal of intent the action is.
const BEHAVIOR_WEIGHTS = {
  view_detail: 1,
  map_view: 2,
  share: 3,
  bookmark: 4,
  add_to_itinerary: 5,
  like: 5,
  hide: -4,
  not_interested: -5,
};

// hide/not_interested additionally trigger a hard exclusion filter in
// findNearby (recommendation.repository.js), not just a scoring penalty.
const HIDDEN_ACTIONS = new Set(['hide', 'not_interested']);

const LEARNING_RATE = 0.15;
const MIN_TAG_SCORE = -2;
const MAX_TAG_SCORE = 2;

function isValidAction(action) {
  return Object.prototype.hasOwnProperty.call(BEHAVIOR_WEIGHTS, action);
}

function weightFor(action) {
  return BEHAVIOR_WEIGHTS[action];
}

// Prevents a single place's repeated clicks from runaway-reinforcing a
// preference: the 2nd, 3rd, ... same action on the same place counts for
// progressively less.
function dampingFor(pastOccurrenceCount) {
  return 1 / Math.sqrt(pastOccurrenceCount + 1);
}

function clampTagScore(score) {
  return Math.max(MIN_TAG_SCORE, Math.min(MAX_TAG_SCORE, score));
}

module.exports = {
  BEHAVIOR_WEIGHTS,
  HIDDEN_ACTIONS,
  LEARNING_RATE,
  isValidAction,
  weightFor,
  dampingFor,
  clampTagScore,
};
