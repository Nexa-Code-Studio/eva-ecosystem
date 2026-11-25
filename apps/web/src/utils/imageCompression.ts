/**
 * Client-side image resizer and JPEG compressor so high-resolution mobile camera selfies
 * upload reliably over event Wi-Fi or mobile networks without exceeding backend limits.
 */
export async function compressBoothImageFile(
  file: File,
  options?: { maxDimension?: number; quality?: number },
): Promise<File> {
  const maxDimension = options?.maxDimension ?? 1440
  const quality = options?.quality ?? 0.82

  if (typeof window === 'undefined' || !file.type.startsWith('image/')) {
    return file
  }

  try {
    const objectUrl = URL.createObjectURL(file)
    try {
      const img = await new Promise<HTMLImageElement>((resolve, reject) => {
        const el = new Image()
        el.onload = () => resolve(el)
        el.onerror = () => reject(new Error('Gagal membaca file gambar.'))
        el.src = objectUrl
      })

      const srcW = img.naturalWidth || img.width
      const srcH = img.naturalHeight || img.height
      if (!srcW || !srcH) return file

      const scale = Math.min(1, maxDimension / Math.max(srcW, srcH))
      const targetW = Math.max(1, Math.round(srcW * scale))
      const targetH = Math.max(1, Math.round(srcH * scale))

      // Preserve already small JPEG/PNG/WebP under 450 KB when dimensions fit
      if (scale === 1 && file.size <= 450 * 1024 && ['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
        return file
      }

      const canvas = document.createElement('canvas')
      canvas.width = targetW
      canvas.height = targetH
      const ctx = canvas.getContext('2d')
      if (!ctx) return file

      ctx.drawImage(img, 0, 0, targetW, targetH)
      const blob = await new Promise<Blob | null>((resolve) => {
        canvas.toBlob(resolve, 'image/jpeg', quality)
      })
      if (!blob) return file

      const cleanStem = file.name.replace(/\.[^.]+$/, '') || 'booth-selfie'
      return new File([blob], `${cleanStem}.jpg`, {
        type: 'image/jpeg',
        lastModified: Date.now(),
      })
    } finally {
      URL.revokeObjectURL(objectUrl)
    }
  } catch {
    return file
  }
}
