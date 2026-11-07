import {
  BookOpen,
  Check,
  Flame,
  Lightbulb,
  MessageCircle,
  MicOff,
  PhoneOff,
  Play,
  Wind,
} from 'lucide-react'
import { LunaOrb } from '@/components/ui'
import { cn } from '@/lib/cn'
import { FloatingNav, glassMini, ScreenHeader, Waveform } from './MockupPrimitives'

export function HomeScreen() {
  const moods = ['😌 Tenang', '😮‍💨 Lelah', '😟 Cemas', '🙂 Baik']
  return (
    <div className="h-full">
      <div className="flex items-center justify-between px-5 pt-3">
        <div>
          <p className="text-[11px] font-semibold text-ink-muted">Selamat malam,</p>
          <p className="text-[17px] font-bold text-ink">Raka 🌙</p>
        </div>
        <span className="flex items-center gap-1 rounded-pill bg-white/80 px-2.5 py-1 text-[10px] font-bold text-[#E2683C] shadow-subtle">
          <Flame className="size-3" /> 7 hari
        </span>
      </div>

      <div className="mt-4 flex flex-col items-center">
        <LunaOrb className="size-[104px]" />
        <p className="mt-5 text-[13px] font-semibold text-ink">Bagaimana perasaanmu hari ini?</p>
        <div className="mt-3 flex flex-wrap justify-center gap-1.5 px-4">
          {moods.map((m, i) => (
            <span
              key={m}
              className={cn(
                'rounded-pill px-2.5 py-1 text-[10px] font-semibold',
                i === 0
                  ? 'bg-primary text-white shadow-btn'
                  : 'border border-border-subtle bg-white text-ink-soft',
              )}
            >
              {m}
            </span>
          ))}
        </div>
      </div>

      <div className="mt-5 grid grid-cols-2 gap-2.5 px-4">
        <div className={cn(glassMini, 'p-3')}>
          <span className="flex size-7 items-center justify-center rounded-[10px] bg-tertiary/50 text-tertiary-dark">
            <Wind className="size-3.5" />
          </span>
          <p className="mt-2 text-[11px] font-semibold text-ink">Napas 4-7-8</p>
          <p className="text-[9px] text-ink-muted">3 menit</p>
        </div>
        <div className={cn(glassMini, 'p-3')}>
          <span className="flex size-7 items-center justify-center rounded-[10px] bg-secondary text-secondary-dark">
            <BookOpen className="size-3.5" />
          </span>
          <p className="mt-2 text-[11px] font-semibold text-ink">Diari Hari Ini</p>
          <p className="text-[9px] text-ink-muted">Siap dibaca</p>
        </div>
      </div>

      <div className="mx-4 mt-2.5 rounded-[18px] bg-luna-insight p-3">
        <p className="flex items-center gap-1 text-[9px] font-extrabold tracking-[0.1em] text-primary uppercase">
          <Lightbulb className="size-3" /> Catatan EVA
        </p>
        <p className="mt-1 text-[10.5px] leading-snug text-secondary-dark">
          Kamu sudah jujur pada perasaanmu minggu ini. Itu langkah yang berani. 💜
        </p>
      </div>

      <FloatingNav active={0} />
    </div>
  )
}

export function VoiceScreen() {
  return (
    <div className="flex h-full flex-col items-center bg-[linear-gradient(180deg,#EEF0FF_0%,#E3E6FF_60%,#F3F5FF_100%)] px-5 pt-6">
      <p className="text-[10px] font-extrabold tracking-[0.14em] text-primary uppercase">
        Sedang mendengarkan
      </p>
      <p className="mt-1 text-[12px] font-semibold text-ink-soft">04:12</p>
      <div className="relative mt-10 flex items-center justify-center">
        <span className="absolute size-[190px] animate-ping rounded-full border border-primary-light/30 [animation-duration:3.2s]" />
        <span className="absolute size-[160px] rounded-full border border-primary-light/40" />
        <LunaOrb className="size-[130px]" />
      </div>
      <Waveform className="mt-12" />
      <div
        className={cn(
          glassMini,
          'mt-4 w-full p-3 text-center text-[11px] leading-snug text-ink-soft',
        )}
      >
        “Aku dengar napasmu agak berat. Mau kita pelan-pelan dulu, tarik napas bareng?”
      </div>
      <div className="mt-auto mb-8 flex items-center gap-6">
        <span className="flex size-12 items-center justify-center rounded-full bg-white text-ink-soft shadow-subtle">
          <MicOff className="size-5" />
        </span>
        <span className="flex size-14 items-center justify-center rounded-full bg-error text-white shadow-[0_6px_20px_rgba(186,26,26,0.4)]">
          <PhoneOff className="size-6" />
        </span>
        <span className="flex size-12 items-center justify-center rounded-full bg-white text-primary shadow-subtle">
          <MessageCircle className="size-5" />
        </span>
      </div>
    </div>
  )
}

export function QuestScreen() {
  const quests = [
    {
      t: '3 Menit Grounding',
      d: 'Teknik 5-4-3-2-1',
      c: 'bg-tertiary/50 text-tertiary-dark',
      done: true,
    },
    {
      t: 'Napas Diafragma',
      d: '2 menit • Relaksasi',
      c: 'bg-primary-container text-primary',
      done: false,
    },
    {
      t: 'Lepaskan Pikiran Kalut',
      d: '5 menit • Refleksi',
      c: 'bg-secondary text-secondary-dark',
      done: false,
    },
  ]
  return (
    <div className="h-full">
      <ScreenHeader subtitle="Misi Hari Ini" title="Resilience Quests" />
      <div className="mx-4 mt-3 flex items-center gap-3 rounded-[18px] bg-luna-fab p-3.5 text-white shadow-btn">
        <span className="flex size-10 items-center justify-center rounded-[12px] bg-white/20">
          <Flame className="size-5" />
        </span>
        <div className="flex-1">
          <p className="text-[12px] font-bold">Streak welas asih: 7 hari</p>
          <div className="mt-1.5 h-1.5 overflow-hidden rounded-pill bg-white/25">
            <span className="block h-full w-2/3 rounded-pill bg-white" />
          </div>
        </div>
      </div>
      <div className="mt-3 space-y-2.5 px-4">
        {quests.map((q) => (
          <div key={q.t} className={cn(glassMini, 'flex items-center gap-3 p-3')}>
            <span className={cn('flex size-9 items-center justify-center rounded-[12px]', q.c)}>
              <Wind className="size-4" />
            </span>
            <div className="min-w-0 flex-1">
              <p className="text-[12px] font-semibold text-ink">{q.t}</p>
              <p className="text-[10px] text-ink-muted">{q.d}</p>
            </div>
            <span
              className={cn(
                'flex size-8 items-center justify-center rounded-full',
                q.done ? 'bg-success/15 text-success' : 'bg-primary text-white shadow-btn',
              )}
            >
              {q.done ? (
                <Check className="size-4" />
              ) : (
                <Play className="size-3.5 translate-x-px fill-current" />
              )}
            </span>
          </div>
        ))}
      </div>
      <FloatingNav active={1} />
    </div>
  )
}

export function AvatarScreen() {
  const poses = [
    {
      label: 'Cemas',
      face: '😮‍💨',
      bg: 'from-tertiary to-primary-light',
      hint: 'Ayo bernapas bareng',
    },
    {
      label: 'Mendengar',
      face: '🥹',
      bg: 'from-secondary to-primary-light',
      hint: 'Aku di sini',
    },
    {
      label: 'Cerah',
      face: '😊',
      bg: 'from-blush to-[#FFD8A8]',
      hint: 'Kamu hebat hari ini!',
    },
  ]
  return (
    <div className="h-full">
      <ScreenHeader subtitle="Mood Avatar" title="Perjalanan Emosimu" />
      <div className="mt-6 flex flex-col items-center">
        <div className="relative flex size-[130px] items-center justify-center rounded-full bg-linear-to-br from-blush via-secondary to-tertiary shadow-halo">
          <span className="animate-breath text-[56px]">😊</span>
        </div>
        <p className="mt-3 rounded-pill bg-white/85 px-3 py-1 text-[11px] font-semibold text-primary shadow-subtle">
          “Kamu hebat hari ini!” ✨
        </p>
      </div>
      <div className="mt-6 grid grid-cols-3 gap-2 px-4">
        {poses.map((p) => (
          <div key={p.label} className={cn(glassMini, 'flex flex-col items-center p-2.5')}>
            <span
              className={cn(
                'flex size-10 items-center justify-center rounded-full bg-linear-to-br text-[20px]',
                p.bg,
              )}
            >
              {p.face}
            </span>
            <p className="mt-1.5 text-[10px] font-semibold text-ink">{p.label}</p>
            <p className="text-center text-[8.5px] leading-tight text-ink-muted">{p.hint}</p>
          </div>
        ))}
      </div>
      <div className="mx-4 mt-3 flex h-14 items-end gap-1.5 rounded-[18px] bg-white/70 p-2.5">
        {[40, 55, 35, 60, 72, 66, 85].map((h, i) => (
          <span
            key={i}
            className="flex-1 rounded-t-[4px] bg-linear-to-t from-primary-light/60 to-blush/70"
            style={{ height: `${h}%` }}
          />
        ))}
      </div>
      <FloatingNav active={4} />
    </div>
  )
}

