import uuid
from collections import Counter
from datetime import datetime, timezone
from typing import Any

from app.core.tz import to_wib
from app.models.conversation import Conversation, Message
from app.models.enums import MessageType
from app.models.safety import EmotionAnalysis


def format_time_local(dt: datetime | None) -> str:
    """Format datetime into 12-hour local time format (hh:mm AM/PM)."""
    if not dt:
        return "09:15 AM"
    try:
        dt_wib = to_wib(dt)
        return dt_wib.strftime("%I:%M %p") if dt_wib else "09:15 AM"
    except Exception:
        return dt.strftime("%I:%M %p")


def format_duration_str(started_at: datetime | None, last_message_at: datetime | None) -> str:
    """Calculate elapsed session duration and format as MM:SS."""
    if not started_at or not last_message_at:
        return "00:00"
    try:
        t1 = started_at if started_at.tzinfo else started_at.replace(tzinfo=timezone.utc)
        t2 = last_message_at if last_message_at.tzinfo else last_message_at.replace(tzinfo=timezone.utc)
        diff = int((t2 - t1).total_seconds())
        if diff < 0:
            diff = 0
        mins = diff // 60
        secs = diff % 60
        return f"{mins:02d}:{secs:02d}"
    except Exception:
        return "00:00"


def analyze_message_emotion_fallback(text: str) -> tuple[str, str]:
    """Determine emotion tag and emoji dynamically from message text keywords."""
    t_low = (text or "").lower()
    anx_words = ["cemas", "takut", "nervous", "panggung", "khawatir", "panik", "deg-degan", "gugup", "takutnya", "bingung", "was-was", "tegang"]
    dep_words = ["sedih", "nangis", "menangis", "hampa", "sendiri", "kehilangan", "terpuruk", "putus asa", "kecewa", "patah hati", "bunuh diri"]
    str_words = ["stres", "capek", "lelah", "beban", "berat", "penat", "pusing", "mumet", "tekanan", "tugas", "deadline", "kerjaan", "letih"]
    ang_words = ["marah", "kesal", "jengkel", "benci", "emosi", "sebal", "kesel", "geram", "murka"]
    pos_words = ["lega", "senang", "bahagia", "terima kasih", "makasih", "enakan", "tenang", "nyaman", "santai", "alhamdulillah", "syukurlah", "baik", "bersyukur"]

    if any(w in t_low for w in anx_words):
        return "fear (78%)", "😨"
    if any(w in t_low for w in dep_words):
        return "sadness (82%)", "😔"
    if any(w in t_low for w in str_words):
        return "stress (75%)", "💥"
    if any(w in t_low for w in ang_words):
        return "anger (70%)", "😡"
    if any(w in t_low for w in pos_words):
        return "calm (85%)", "😌"

    return "netral (60%)", "😐"


def get_message_emotion(
    m: Message, emotion_map: dict[uuid.UUID, EmotionAnalysis] | None = None
) -> tuple[str, str]:
    """Retrieve emotion tag and emoji for a message from ML emotion map or keyword heuristic."""
    if m.role not in ("user",):
        return "", ""

    if emotion_map and m.id in emotion_map:
        emo = emotion_map[m.id]
        if emo and emo.primary_emotion:
            pct = int((float(emo.confidence) if emo.confidence else 0.8) * 100)
            emo_lower = emo.primary_emotion.lower()
            name_map = {
                "fearful": "fear",
                "sad": "sadness",
                "angry": "anger",
                "neutral": "netral",
                "happy": "joy",
            }
            display_name = name_map.get(emo_lower, emo_lower)
            emoji_map = {
                "happy": "😃", "joy": "😃", "senang": "😃", "bahagia": "😃",
                "calm": "😌", "tenang": "😌", "lega": "😌",
                "fearful": "😨", "fear": "😨", "cemas": "😨", "takut": "😨",
                "sad": "😔", "sadness": "😔", "sedih": "😔",
                "angry": "😡", "anger": "😡", "marah": "😡",
                "stress": "💥", "stres": "💥",
                "neutral": "😐", "netral": "😐",
            }
            return f"{display_name} ({pct}%)", emoji_map.get(emo_lower, "🌱")

    return analyze_message_emotion_fallback(m.content)


def format_conversation(
    c: Conversation, emotion_map: dict[uuid.UUID, EmotionAnalysis] | None = None
) -> dict[str, Any]:
    """Format a conversation entity into a detailed API response dictionary."""
    msgs = sorted(c.messages, key=lambda m: m.sequence_number) if c.messages else []
    last_msg = msgs[-1].content if msgs else ""
    formatted_msgs = []
    user_emotions: list[tuple[str, str]] = []
    for m in msgs:
        emo_tag, emo_emoji = get_message_emotion(m, emotion_map)
        if m.role in ("user",) and emo_tag:
            user_emotions.append((emo_tag, emo_emoji))
        formatted_msgs.append({
            "id": str(m.id),
            "sender": "eva" if m.role in ("assistant", "luna", "eva") else "user",
            "text": m.content,
            "time": format_time_local(m.created_at),
            "isAudio": m.message_type in (MessageType.VOICE, "voice", "audio"),
            "emotionTag": emo_tag,
            "emotionEmoji": emo_emoji,
        })

    dominant_label = "Tenang & Nyaman"
    dominant_emoji = "😌"
    if user_emotions:
        counts: Counter[str] = Counter()
        emoji_by_name: dict[str, str] = {}
        for tag, emoji in user_emotions:
            name = tag.split()[0].lower() if tag else "netral"
            counts[name] += 1
            if emoji:
                emoji_by_name[name] = emoji

        most_common_name, _ = counts.most_common(1)[0]
        name_map = {
            "happy": "Lega & Senang",
            "joy": "Lega & Senang",
            "calm": "Tenang & Damai",
            "fear": "Cemas & Takut",
            "fearful": "Cemas & Takut",
            "anxiety": "Cemas & Gelisah",
            "sadness": "Sedih & Hampa",
            "sad": "Sedih & Hampa",
            "depression": "Sedih & Tertekan",
            "stress": "Stres & Lelah",
            "anger": "Marah & Kesal",
            "angry": "Marah & Kesal",
            "neutral": "Netral & Rileks",
            "netral": "Netral & Rileks",
        }
        dominant_label = name_map.get(most_common_name, most_common_name.capitalize())
        dominant_emoji = emoji_by_name.get(most_common_name, "😌")

    # Safety/Crisis Override: Jangan pernah kategorikan krisis atau niat menyakiti diri sebagai Netral & Rileks
    crisis_keywords = (
        "bunuh diri", "capek hidup", "mati saja", "ingin mati", "putus asa",
        "menyakiti diri", "gantung diri", "akhiri hidup", "tak sanggup lagi",
        "tidak sanggup hidup"
    )
    all_user_text = " ".join([m.content.lower() for m in msgs if m.role == "user" and m.content])
    if any(kw in all_user_text for kw in crisis_keywords):
        dominant_label = "Krisis / Sangat Tertekan"
        dominant_emoji = "🆘"

    end_time = c.last_message_at or (msgs[-1].created_at if msgs else c.started_at)
    duration_str = format_duration_str(c.started_at, end_time)

    # Return summary from DB if exists; otherwise None to trigger client-side skeleton & stream
    summary_text = None
    if hasattr(c, "summaries") and c.summaries:
        summary_text = c.summaries[-1].summary

    return {
        "id": str(c.id),
        "title": c.title or "Sesi Percakapan",
        "is_title_generating": "$skeleton" in (c.title or ""),
        "lastMessage": last_msg,
        "lastMessageTime": format_time_local(c.started_at),
        "duration": duration_str,
        "dominant_emotion": dominant_label,
        "dominant_emoji": dominant_emoji,
        "summary": summary_text,
        "messages": formatted_msgs,
    }


# Backwards-compatible aliases
_format_time_local = format_time_local
_format_duration_str = format_duration_str
_analyze_message_emotion_fallback = analyze_message_emotion_fallback
_get_message_emotion = get_message_emotion
_format_conversation = format_conversation
