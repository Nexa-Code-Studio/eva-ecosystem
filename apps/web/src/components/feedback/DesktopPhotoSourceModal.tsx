import { useCallback, useEffect, useRef, useState } from 'react'
import { ArrowLeft, Camera, FolderOpen, RefreshCw, X } from 'lucide-react'
import { useBodyScrollLock } from '@/hooks/useBodyScrollLock'

interface DesktopPhotoSourceModalProps {
  open: boolean
  photoCount: number
  maxPhotos: number
  onCapture: (file: File) => Promise<void>
  onOpenFileManager: () => void
  onClose: () => void
}

export function DesktopPhotoSourceModal({
  open,
  photoCount,
  maxPhotos,
  onCapture,
  onOpenFileManager,
  onClose,
}: DesktopPhotoSourceModalProps) {
  const videoRef = useRef<HTMLVideoElement | null>(null)
  const streamRef = useRef<MediaStream | null>(null)

  useBodyScrollLock(open)

  const [step, setStep] = useState<'choose' | 'camera'>('choose')
  const [devices, setDevices] = useState<MediaDeviceInfo[]>([])
  const [selectedDeviceId, setSelectedDeviceId] = useState<string>('')
  const [starting, setStarting] = useState(false)
  const [capturing, setCapturing] = useState(false)
  const [errorText, setErrorText] = useState<string | null>(null)
  const [captureFlash, setCaptureFlash] = useState(false)

  const stopStream = useCallback(() => {
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((track) => track.stop())
      streamRef.current = null
    }
    if (videoRef.current) {
      videoRef.current.srcObject = null
    }
  }, [])

  const closeModalCleanly = useCallback(() => {
    stopStream()
    setStep('choose')
    setErrorText(null)
    onClose()
  }, [onClose, stopStream])

  useEffect(() => {
    if (!open || step !== 'camera') {
      stopStream()
      return
    }
    if (!navigator.mediaDevices?.getUserMedia) {
      void Promise.resolve().then(() => {
        setStarting(false)
        setErrorText('Akses kamera tidak tersedia di browser ini. Silakan buka File Manager.')
      })
      return
    }

    let active = true
    stopStream()

    const videoConstraints: MediaTrackConstraints = selectedDeviceId
      ? { deviceId: { exact: selectedDeviceId } }
      : { facingMode: { ideal: 'user' } }

    navigator.mediaDevices
      .getUserMedia({ video: videoConstraints, audio: false })
      .then(async (stream) => {
        if (!active) {
          stream.getTracks().forEach((t) => t.stop())
          return
        }
        streamRef.current = stream
        if (videoRef.current) {
          videoRef.current.srcObject = stream
          await videoRef.current.play().catch(() => undefined)
        }
        const allDevices = await navigator.mediaDevices.enumerateDevices()
        if (active) {
          setDevices(allDevices.filter((d) => d.kind === 'videoinput'))
          setErrorText(null)
        }
      })
      .catch((err) => {
        if (!active) return
        const name = err instanceof DOMException ? err.name : ''
        if (name === 'NotAllowedError' || name === 'PermissionDeniedError') {
          setErrorText(
            'Izin akses kamera ditolak browser. Anda dapat mengizinkan kamera atau memilih foto lewat File Manager.',
          )
        } else {
          setErrorText(
            'Kamera laptop tidak dapat dibuka. Silakan gunakan File Manager untuk memilih foto.',
          )
        }
      })
      .finally(() => {
        if (active) setStarting(false)
      })

    return () => {
      active = false
      stopStream()
    }
  }, [open, step, selectedDeviceId, stopStream])

  useEffect(() => {
    if (!open) return
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        closeModalCleanly()
      }
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [open, closeModalCleanly])

  if (!open) return null

  const canCaptureMore = photoCount < maxPhotos

  const handleOpenWebcam = () => {
    setErrorText(null)
    setStarting(true)
    setStep('camera')
  }

  const handleSwitchToFileManager = () => {
    closeModalCleanly()
    onOpenFileManager()
  }

  const handleSnap = async () => {
    if (!videoRef.current || !canCaptureMore || capturing || starting) return
    const video = videoRef.current
    const width = video.videoWidth || 1280
    const height = video.videoHeight || 720
    setCapturing(true)
    try {
      const canvas = document.createElement('canvas')
      canvas.width = width
      canvas.height = height
      const ctx = canvas.getContext('2d')
      if (!ctx) return
      ctx.drawImage(video, 0, 0, width, height)
      const blob = await new Promise<Blob | null>((resolve) =>
        canvas.toBlob(resolve, 'image/jpeg', 0.88),
      )
      if (!blob) return
      const file = new File([blob], `booth-webcam-${Date.now()}.jpg`, {
        type: 'image/jpeg',
      })
      await onCapture(file)
      setCaptureFlash(true)
      window.setTimeout(() => setCaptureFlash(false), 300)
    } finally {
      setCapturing(false)
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/65 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="desktop-photo-source-title"
      onClick={closeModalCleanly}
    >
      <div
        className="w-full max-w-md overflow-hidden rounded-[22px] border border-[#E2E8F0] bg-white shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-[#E2E8F0] px-5 py-3.5">
          <div className="flex items-center gap-2">
            {step === 'camera' && (
              <button
                type="button"
                onClick={() => {
                  stopStream()
                  setStep('choose')
                  setErrorText(null)
                }}
                aria-label="Kembali ke pilihan sumber foto"
                className="inline-flex size-9 cursor-pointer items-center justify-center rounded-full border border-[#E2E8F0] text-ink-soft hover:bg-canvas hover:text-ink focus-visible:outline-2 focus-visible:outline-primary"
              >
                <ArrowLeft className="size-4" aria-hidden="true" />
              </button>
            )}
            <div>
              <h3 id="desktop-photo-source-title" className="text-sm font-bold text-ink">
                {step === 'choose' ? 'Pilih Sumber Foto Booth' : 'Kamera Laptop'}
              </h3>
              <p className="text-xs text-ink-muted">
                Foto terlampir: {photoCount} / {maxPhotos}
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={closeModalCleanly}
            aria-label="Tutup dialog pilihan foto"
            className="inline-flex size-10 cursor-pointer items-center justify-center rounded-full border border-[#E2E8F0] text-ink-soft hover:bg-canvas hover:text-ink focus-visible:outline-2 focus-visible:outline-primary"
          >
            <X className="size-4" aria-hidden="true" />
          </button>
        </div>

        {step === 'choose' ? (
          <div className="space-y-3 p-5">
            <p className="text-xs leading-relaxed text-ink-soft">
              Kamera terdeteksi di laptop ini. Pilih ingin mengambil foto langsung dari kamera atau membuka File Manager:
            </p>
            <button
              type="button"
              onClick={handleOpenWebcam}
              className="flex min-h-14 w-full cursor-pointer items-center gap-3.5 rounded-[16px] border border-primary/30 bg-[#EEF0FF] px-4 py-3 text-left transition-colors hover:bg-[#E0E7FF] focus-visible:outline-2 focus-visible:outline-primary"
            >
              <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-[12px] bg-primary text-white">
                <Camera className="size-5" aria-hidden="true" />
              </span>
              <span className="min-w-0">
                <span className="block text-sm font-bold text-[#3B3E99]">Buka Akses Kamera</span>
                <span className="block text-xs text-ink-soft">
                  Ambil satu atau lebih foto langsung memakai kamera laptop
                </span>
              </span>
            </button>
            <button
              type="button"
              onClick={handleSwitchToFileManager}
              className="flex min-h-14 w-full cursor-pointer items-center gap-3.5 rounded-[16px] border border-[#CBD5E1] bg-white px-4 py-3 text-left transition-colors hover:bg-canvas focus-visible:outline-2 focus-visible:outline-primary"
            >
              <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-[12px] border border-[#E2E8F0] bg-canvas text-ink">
                <FolderOpen className="size-5" aria-hidden="true" />
              </span>
              <span className="min-w-0">
                <span className="block text-sm font-bold text-ink">Buka File Manager</span>
                <span className="block text-xs text-ink-soft">
                  Pilih file foto dari folder komputer Anda
                </span>
              </span>
            </button>
          </div>
        ) : (
          <div>
            <div className="relative aspect-[4/3] w-full bg-[#0C0A14]">
              <video
                ref={videoRef}
                playsInline
                muted
                autoPlay
                className="size-full -scale-x-100 object-cover"
              />
              {captureFlash && (
                <div aria-hidden="true" className="pointer-events-none absolute inset-0 bg-white/60" />
              )}
              {starting && (
                <div className="absolute inset-0 flex flex-col items-center justify-center gap-2 bg-black/60 text-xs font-medium text-white">
                  <RefreshCw className="size-5 animate-spin" aria-hidden="true" />
                  <span>Meminta akses kamera laptop...</span>
                </div>
              )}
              {errorText && (
                <div className="absolute inset-0 flex flex-col items-center justify-center bg-[#0C0A14]/90 p-6 text-center">
                  <p className="text-xs leading-relaxed text-white">{errorText}</p>
                  <button
                    type="button"
                    onClick={handleSwitchToFileManager}
                    className="mt-4 inline-flex min-h-11 cursor-pointer items-center gap-1.5 rounded-[12px] bg-white px-4 text-xs font-bold text-ink"
                  >
                    <FolderOpen className="size-4" aria-hidden="true" />
                    <span>Buka File Manager</span>
                  </button>
                </div>
              )}
            </div>

            <div className="space-y-3 p-4">
              {devices.length > 1 && (
                <div>
                  <label htmlFor="desktop-webcam-select" className="block text-xs font-semibold text-ink">
                    Pilih Kamera
                  </label>
                  <select
                    id="desktop-webcam-select"
                    value={selectedDeviceId}
                    onChange={(e) => {
                      setErrorText(null)
                      setStarting(true)
                      setSelectedDeviceId(e.target.value)
                    }}
                    className="mt-1 min-h-11 w-full rounded-[10px] border border-[#CBD5E1] bg-white px-3 text-xs text-ink focus:border-primary focus:outline-none"
                  >
                    <option value="">Kamera Default</option>
                    {devices.map((dev, index) => (
                      <option key={dev.deviceId} value={dev.deviceId}>
                        {dev.label || `Kamera ${index + 1}`}
                      </option>
                    ))}
                  </select>
                </div>
              )}

              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={handleSwitchToFileManager}
                  className="inline-flex min-h-11 flex-1 cursor-pointer items-center justify-center gap-1.5 rounded-[12px] border border-[#CBD5E1] bg-white px-3 text-xs font-semibold text-ink hover:bg-canvas focus-visible:outline-2 focus-visible:outline-primary"
                >
                  <FolderOpen className="size-4 shrink-0" aria-hidden="true" />
                  <span>File Manager</span>
                </button>
                <button
                  type="button"
                  onClick={() => void handleSnap()}
                  disabled={starting || capturing || !canCaptureMore || Boolean(errorText)}
                  className="inline-flex min-h-11 flex-1 cursor-pointer items-center justify-center gap-1.5 rounded-[12px] bg-primary px-4 text-xs font-bold text-white hover:bg-primary-deep focus-visible:outline-2 focus-visible:outline-primary disabled:cursor-not-allowed disabled:opacity-50"
                >
                  <Camera className="size-4 shrink-0" aria-hidden="true" />
                  <span>{canCaptureMore ? (capturing ? 'Menyimpan...' : 'Ambil Foto') : 'Batas Maksimal'}</span>
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
