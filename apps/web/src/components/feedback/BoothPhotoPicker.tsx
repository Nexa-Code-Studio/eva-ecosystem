import { useRef, useState } from 'react'
import { ImagePlus, Trash2 } from 'lucide-react'
import { compressBoothImageFile } from '@/utils/imageCompression'
import { DesktopPhotoSourceModal } from './DesktopPhotoSourceModal'

function isDesktopOrLaptopDevice(): boolean {
  if (typeof window === 'undefined') return false
  const mobileUa = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
    navigator.userAgent,
  )
  const finePointer = window.matchMedia?.('(pointer: fine)').matches ?? false
  return !mobileUa && (finePointer || window.innerWidth >= 1024)
}

export interface SelectedBoothPhoto {
  id: string
  file: File
  previewUrl: string
}

interface BoothPhotoPickerProps {
  photos: SelectedBoothPhoto[]
  maxPhotos?: number
  disabled?: boolean
  onAddPhotos: (newItems: SelectedBoothPhoto[]) => void
  onRemovePhoto: (id: string) => void
  onValidationMessage?: (message: string | null) => void
}

export function BoothPhotoPicker({
  photos,
  maxPhotos = 5,
  disabled,
  onAddPhotos,
  onRemovePhoto,
  onValidationMessage,
}: BoothPhotoPickerProps) {
  const galleryRef = useRef<HTMLInputElement | null>(null)
  const [compressing, setCompressing] = useState(false)
  const [desktopModalOpen, setDesktopModalOpen] = useState(false)
  const [checkingCamera, setCheckingCamera] = useState(false)

  const remaining = Math.max(0, maxPhotos - photos.length)

  const handleTriggerPicker = async () => {
    if (disabled || compressing || checkingCamera || remaining === 0) return

    if (!isDesktopOrLaptopDevice() || !navigator.mediaDevices?.getUserMedia || !navigator.mediaDevices?.enumerateDevices) {
      galleryRef.current?.click()
      return
    }

    setCheckingCamera(true)
    try {
      const devices = await navigator.mediaDevices.enumerateDevices()
      const hasCamera = devices.some((d) => d.kind === 'videoinput')
      if (hasCamera) {
        setDesktopModalOpen(true)
      } else {
        galleryRef.current?.click()
      }
    } catch {
      galleryRef.current?.click()
    } finally {
      setCheckingCamera(false)
    }
  }

  const handleIncomingFiles = async (fileList: FileList | File[] | null) => {
    if (!fileList) return
    const arr = Array.from(fileList)
    if (arr.length === 0) return

    if (photos.length >= maxPhotos) {
      onValidationMessage?.(`Maksimal ${maxPhotos} foto selfie dapat dilampirkan.`)
      return
    }

    const slice = arr.slice(0, maxPhotos - photos.length)
    if (arr.length > slice.length) {
      onValidationMessage?.(
        `Hanya ${slice.length} foto tambahan yang diambil agar tidak melebihi batas ${maxPhotos} foto.`,
      )
    } else {
      onValidationMessage?.(null)
    }

    setCompressing(true)
    try {
      const prepared: SelectedBoothPhoto[] = []
      for (const rawFile of slice) {
        if (!rawFile.type.startsWith('image/')) continue
        const compressed = await compressBoothImageFile(rawFile)
        if (compressed.size > 5 * 1024 * 1024) {
          onValidationMessage?.(`File "${rawFile.name}" melebihi batas 5 MB meski sudah dikompres.`)
          continue
        }
        prepared.push({
          id: `photo-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
          file: compressed,
          previewUrl: URL.createObjectURL(compressed),
        })
      }
      if (prepared.length > 0) {
        onAddPhotos(prepared)
      }
    } finally {
      setCompressing(false)
    }
  }

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="text-xs font-semibold text-ink">
          Foto Selfie / Momen Booth ({photos.length}/{maxPhotos})
        </span>
        <span className="text-xs font-medium text-ink-soft">
          Wajib minimal 1 foto (bisa lebih dari 1)
        </span>
      </div>

      {/* Single Gallery / Camera Picker Button */}
      <button
        type="button"
        disabled={disabled || compressing || checkingCamera || remaining === 0}
        onClick={() => void handleTriggerPicker()}
        className="flex min-h-12 w-full cursor-pointer items-center justify-center gap-2 rounded-[14px] border border-primary/30 bg-[#EEF0FF] px-4 py-2.5 text-sm font-bold text-[#3B3E99] transition-colors hover:bg-[#E0E7FF] active:scale-[0.98] focus-visible:outline-2 focus-visible:outline-primary disabled:cursor-not-allowed disabled:opacity-50"
      >
        <ImagePlus className="size-4 shrink-0" aria-hidden="true" />
        <span>
          {compressing
            ? 'Mengompresi foto...'
            : checkingCamera
              ? 'Memeriksa kamera...'
              : remaining === 0
                ? 'Batas 5 Foto Tercapai'
                : 'Pilih Foto dari Galeri / Kamera'}
        </span>
      </button>

      <input
        ref={galleryRef}
        type="file"
        accept="image/*"
        multiple
        className="sr-only"
        aria-label="Pilih foto dari galeri atau kamera HP"
        onChange={(e) => {
          void handleIncomingFiles(e.target.files)
          e.currentTarget.value = ''
        }}
      />

      {/* Preview Grid with aspect-square sizing (R-40) */}
      {photos.length === 0 ? (
        <div className="rounded-[14px] border border-dashed border-[#CBD5E1] bg-canvas px-4 py-6 text-center">
          <p className="text-xs font-semibold text-ink">Belum ada foto booth dipilih</p>
          <p className="mt-1 text-xs text-ink-muted">
            Ketuk tombol di atas untuk memilih foto dari galeri atau memotret dengan kamera bawaan HP.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
          {photos.map((photo, idx) => (
            <div
              key={photo.id}
              className="group relative aspect-square overflow-hidden rounded-[14px] border border-[#E2E8F0] bg-[#F1F5F9]"
            >
              <img
                src={photo.previewUrl}
                alt={`Preview foto booth ${idx + 1}`}
                width={320}
                height={320}
                className="size-full object-cover"
              />
              <button
                type="button"
                disabled={disabled}
                onClick={() => onRemovePhoto(photo.id)}
                aria-label={`Hapus foto booth ke-${idx + 1}`}
                className="absolute top-1.5 right-1.5 inline-flex size-11 cursor-pointer items-center justify-center rounded-full bg-black/70 text-white hover:bg-[#B91C1C] focus-visible:outline-2 focus-visible:outline-white disabled:opacity-50"
              >
                <Trash2 className="size-4" aria-hidden="true" />
              </button>
              <span className="pointer-events-none absolute bottom-1.5 left-1.5 rounded-[6px] bg-black/70 px-1.5 py-0.5 text-[10px] font-semibold text-white">
                #{idx + 1} ({Math.max(1, Math.round(photo.file.size / 1024))} KB)
              </span>
            </div>
          ))}
        </div>
      )}

      <DesktopPhotoSourceModal
        open={desktopModalOpen}
        photoCount={photos.length}
        maxPhotos={maxPhotos}
        onCapture={async (file) => {
          await handleIncomingFiles([file])
        }}
        onOpenFileManager={() => galleryRef.current?.click()}
        onClose={() => setDesktopModalOpen(false)}
      />
    </div>
  )
}
