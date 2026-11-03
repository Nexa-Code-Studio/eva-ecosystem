import { Check, Lightbulb, PhoneCall, Plus, Quote, Siren } from 'lucide-react'
import { cn } from '@/lib/cn'
import { FloatingNav, glassMini, ScreenHeader } from './MockupPrimitives'

export function DiaryScreen() {
  return (
    <div className="h-full">
      <ScreenHeader subtitle="Diari Otomatis" title="Selasa, 26 Okt" />
      <div className={cn(glassMini, 'mx-4 mt-3 p-3.5')}>
        <div className="flex flex-wrap gap-1.5">
          <span className="rounded-[8px] bg-secondary px-2 py-0.5 text-[9.5px] font-semibold text-secondary-dark">
            😮‍💨 Lelah
          </span>
          <span className="rounded-[8px] bg-tertiary/50 px-2 py-0.5 text-[9.5px] font-semibold text-tertiary-dark">
            Akademik
          </span>
          <span className="rounded-[8px] bg-primary-container px-2 py-0.5 text-[9.5px] font-semibold text-primary">
            Sesi suara • 12 mnt
          </span>
        </div>
        <p className="mt-2.5 text-[11.5px] leading-snug text-ink-soft">
          Hari ini kamu bercerita tentang tekanan skripsi dan rasa takut mengecewakan orang tua…
        </p>
      </div>
      <div className="mx-4 mt-2.5 rounded-[18px] bg-luna-insight p-3.5">
        <p className="flex items-center gap-1 text-[9px] font-extrabold tracking-[0.1em] text-primary uppercase">
          <Lightbulb className="size-3" /> Key insight
        </p>
        <p className="mt-1 text-[11px] leading-snug text-secondary-dark">
          Pola “all-or-nothing”: satu revisi terasa seperti kegagalan total.
        </p>
      </div>
      <div className={cn(glassMini, 'mx-4 mt-2.5 p-3.5')}>
        <Quote className="size-4 text-primary-light" />
        <p className="mt-1 text-[11px] leading-snug font-medium text-ink italic">
          Kemajuan kecil tetaplah kemajuan.
        </p>
      </div>
      <div className="mx-4 mt-2.5 flex items-center gap-2.5 rounded-[18px] border border-success/25 bg-success/10 p-3">
        <span className="flex size-7 items-center justify-center rounded-full bg-success text-white">
          <Check className="size-3.5" />
        </span>
        <p className="text-[10.5px] font-semibold text-[#0F7A57]">
          Langkah nyata: kerjakan 1 sub-bab, lalu istirahat 10 menit.
        </p>
      </div>
      <FloatingNav active={3} />
    </div>
  )
}

export function ScreeningScreen() {
  const scales = [
    { k: 'Stres', v: 38, c: 'bg-dass-mild', l: 'Ringan' },
    { k: 'Kecemasan', v: 62, c: 'bg-dass-moderate', l: 'Sedang' },
    { k: 'Depresi', v: 22, c: 'bg-dass-normal', l: 'Normal' },
  ]
  return (
    <div className="h-full">
      <ScreenHeader subtitle="Skrining DASS-21" title="Hasil Minggu Ini" />
      <div className={cn(glassMini, 'mx-4 mt-3 space-y-3.5 p-4')}>
        {scales.map((s) => (
          <div key={s.k}>
            <div className="flex items-center justify-between text-[11px]">
              <span className="font-semibold text-ink">{s.k}</span>
              <span className="font-bold text-ink-soft">{s.l}</span>
            </div>
            <div className="mt-1.5 h-2 overflow-hidden rounded-pill bg-primary-container/70">
              <span className={cn('block h-full rounded-pill', s.c)} style={{ width: `${s.v}%` }} />
            </div>
          </div>
        ))}
        <div className="flex gap-1 pt-1">
          {[
            'bg-dass-normal',
            'bg-dass-mild',
            'bg-dass-moderate',
            'bg-dass-severe',
            'bg-dass-extreme',
          ].map((c) => (
            <span key={c} className={cn('h-1 flex-1 rounded-pill', c)} />
          ))}
        </div>
      </div>
      <div className="mx-4 mt-2.5 rounded-[18px] bg-luna-insight p-3.5">
        <p className="text-[11.5px] font-bold text-ink">Jembatan ke Psikolog</p>
        <p className="mt-1 text-[10.5px] leading-snug text-secondary-dark">
          Intake Summary siap dibagikan — tanpa isi obrolan pribadimu.
        </p>
        <span className="mt-2.5 inline-flex h-8 items-center rounded-pill bg-primary px-3.5 text-[10.5px] font-semibold text-white shadow-btn">
          Hubungkan dengan psikolog HIMPSI
        </span>
      </div>
      <FloatingNav active={4} />
    </div>
  )
}

export function SafetyScreen() {
  return (
    <div className="relative h-full">
      <div className="absolute inset-0 opacity-60 blur-[2px]">
        <ScreenHeader subtitle="Sesi curhat" title="EVA" />
        <div className="mt-4 space-y-2 px-4">
          <div className="ml-auto w-3/4 rounded-[16px] rounded-br-[4px] bg-primary p-2.5 text-[10px] text-white">
            …
          </div>
          <div className="w-3/4 rounded-[16px] rounded-bl-[4px] bg-white p-2.5 text-[10px] text-ink-soft">
            …
          </div>
        </div>
      </div>
      <div className="absolute inset-0 bg-obsidian/30" />
      <div className="absolute inset-x-0 bottom-0 rounded-t-[28px] bg-white px-5 pt-3 pb-6 shadow-nav">
        <span className="mx-auto block h-1 w-10 rounded-pill bg-border-subtle" />
        <div className="mt-4 rounded-[16px] border border-crisis-border bg-crisis-bg p-3">
          <p className="flex items-center gap-1.5 text-[11px] font-bold text-crisis-text">
            <Siren className="size-3.5" /> Kamu tidak sendirian
          </p>
          <p className="mt-1 text-[10.5px] leading-snug text-crisis-text/80">
            Keselamatanmu yang utama. Bantuan profesional siap 24 jam, gratis.
          </p>
        </div>
        <span className="mt-3 flex h-11 w-full items-center justify-center gap-2 rounded-pill bg-[#DC2626] text-[11px] font-semibold text-white shadow-[0_6px_18px_rgba(220,38,38,0.35)]">
          <PhoneCall className="size-4" /> Hubungi 119 Ext 8
        </span>
        <span className="mt-2 flex h-10 w-full items-center justify-center gap-2 rounded-pill border-[1.5px] border-border-subtle text-[11px] font-semibold text-ink">
          <Plus className="size-3.5" /> Kabari kerabat terdaftar
        </span>
      </div>
    </div>
  )
}

