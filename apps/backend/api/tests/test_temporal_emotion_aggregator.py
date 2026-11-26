"""Unit tests for 30–60s temporal emotion aggregation (duration-weighted mean, coverage, isolation)."""

from __future__ import annotations

from app.services.call.temporal_emotion_aggregator import SessionTemporalEmotionAggregator

from shared.domain_types import (
    EMOTION2VEC_CANONICAL_CLASSES,
    EmotionSegmentPrediction,
    EmotionSource,
    EmotionWindowStatus,
)


def _make_pred(
    segment_id: str,
    *,
    dominant: str,
    dom_score: float = 0.80,
    valid_speech_ms: int = 3000,
    sequence: int = 1,
    user_turn_id: int = 1,
    start_offset_ms: int = 0,
    model: str = "emotion2vec_plus_base",
    model_revision: str = "rev-1",
) -> EmotionSegmentPrediction:
    rem = round((1.0 - dom_score) / (len(EMOTION2VEC_CANONICAL_CLASSES) - 1), 6)
    scores = {c: (dom_score if c == dominant else rem) for c in EMOTION2VEC_CANONICAL_CLASSES}
    return EmotionSegmentPrediction(
        segment_id=segment_id,
        model=model,
        model_revision=model_revision,
        scores=scores,
        primary_emotion=dominant,
        confidence=dom_score,
        valid_speech_ms=valid_speech_ms,
        duration_ms=valid_speech_ms,
        sequence=sequence,
        user_turn_id=user_turn_id,
        capture_epoch=1,
        start_offset_ms=start_offset_ms,
        end_offset_ms=start_offset_ms + valid_speech_ms,
    )


def test_no_data_returns_unavailable_never_fabricated_neutral():
    agg = SessionTemporalEmotionAggregator("sess-empty", "gen-1", window_target_ms=30_000)
    snap = agg.build_snapshot(now_ms=1000)

    assert snap.status == EmotionWindowStatus.UNAVAILABLE
    assert snap.source == EmotionSource.UNAVAILABLE
    assert snap.scores is None
    assert snap.primary_emotion is None
    assert snap.confidence is None
    assert snap.coverage == 0.0


def test_duration_weighted_mean_and_ready_transition_over_30s():
    agg = SessionTemporalEmotionAggregator(
        "sess-weighted",
        "gen-1",
        window_target_ms=30_000,
        staleness_ms=180_000,
        min_coverage=0.60,
    )

    # 8 segments x 3s = 24s sad + 2 segments x 3s = 6s happy => 30s total
    # Weighted sad = (24*0.80 + 6*0.025) / 30 = 0.645; happy = (24*0.025 + 6*0.80) / 30 = 0.18
    for i in range(8):
        p = _make_pred(f"s-{i}", dominant="sad", dom_score=0.80, sequence=i + 1, start_offset_ms=i * 3000)
        agg.mark_pending(p.segment_id, 3000)
        assert agg.record_prediction(session_id="sess-weighted", generation_token="gen-1", prediction=p, now_ms=10_000 + i * 3000)

    mid_snap = agg.build_snapshot(now_ms=35_000)
    assert mid_snap.status == EmotionWindowStatus.PARTIAL
    assert mid_snap.speech_analyzed_ms == 24_000

    for j in range(2):
        idx = 8 + j
        p = _make_pred(f"s-{idx}", dominant="happy", dom_score=0.80, sequence=idx + 1, start_offset_ms=idx * 3000, user_turn_id=2)
        agg.mark_pending(p.segment_id, 3000)
        assert agg.record_prediction(session_id="sess-weighted", generation_token="gen-1", prediction=p, now_ms=10_000 + idx * 3000)

    ready_snap = agg.build_snapshot(current_turn_id=2, now_ms=40_000)
    assert ready_snap.status == EmotionWindowStatus.READY
    assert ready_snap.source == EmotionSource.AUDIO_TEMPORAL
    assert ready_snap.speech_analyzed_ms == 30_000
    assert ready_snap.wall_span_ms == 30_000
    assert ready_snap.coverage == 1.0
    assert ready_snap.primary_emotion == "sad"
    assert abs((ready_snap.scores or {})["sad"] - 0.645) < 0.005
    assert abs((ready_snap.scores or {})["happy"] - 0.18) < 0.005
    # Turn 2 specific scores reflect happy turn
    assert ready_snap.turn_scores is not None
    assert ready_snap.turn_scores["happy"] > 0.75

    # Staleness check
    stale_snap = agg.build_snapshot(now_ms=40_000 + 200_000)
    assert stale_snap.status == EmotionWindowStatus.STALE


def test_duplicate_out_of_order_mixed_model_and_session_isolation():
    agg = SessionTemporalEmotionAggregator("sess-iso", "gen-A", window_target_ms=30_000)

    # Wrong session or generation token rejected
    p_bad_sess = _make_pred("bad-1", dominant="angry", sequence=1)
    assert agg.record_prediction(session_id="other-sess", generation_token="gen-A", prediction=p_bad_sess) is False
    assert agg.record_prediction(session_id="sess-iso", generation_token="gen-B", prediction=p_bad_sess) is False

    # Out-of-order: seq 2 arrives before seq 1
    p2 = _make_pred("seg-2", dominant="happy", sequence=2, start_offset_ms=3000)
    p1 = _make_pred("seg-1", dominant="sad", sequence=1, start_offset_ms=0)
    assert agg.record_prediction(session_id="sess-iso", generation_token="gen-A", prediction=p2, now_ms=5000) is True
    assert agg.record_prediction(session_id="sess-iso", generation_token="gen-A", prediction=p1, now_ms=5100) is True

    # Duplicate segment_id ignored
    assert agg.record_prediction(session_id="sess-iso", generation_token="gen-A", prediction=p1, now_ms=5200) is False

    # Mixed model revision rejected
    p_mixed = _make_pred("seg-3", dominant="angry", sequence=3, start_offset_ms=6000, model_revision="rev-2")
    assert agg.record_prediction(session_id="sess-iso", generation_token="gen-A", prediction=p_mixed, now_ms=5300) is False

    snap = agg.build_snapshot(now_ms=5500)
    assert snap.segment_count == 2
    assert snap.wall_span_ms == 6000
    assert snap.failed_count == 1
    assert "mixed_model_version_rejected" in snap.degradation_reasons

    artifact = agg.build_session_artifact(now_ms=5500)
    assert artifact["schema_version"] == 1
    assert artifact["segment_count"] == 2
    assert "bukan diagnosis klinis" in artifact["disclaimer"].lower()
