import { clsx, type ClassValue } from 'clsx'
import { extendTailwindMerge } from 'tailwind-merge'

const customTwMerge = extendTailwindMerge({
  extend: {
    classGroups: {
      'font-size': [
        'text-hero',
        'text-section',
        'text-display',
        'text-headline',
        'text-title-lg',
        'text-title-md',
        'text-title-sm',
        'text-body-lg',
        'text-body-md',
        'text-body-sm',
        'text-caption',
        'text-overline',
      ],
      'text-color': [
        'text-primary',
        'text-primary-light',
        'text-primary-container',
        'text-primary-vivid',
        'text-primary-deep',
        'text-secondary',
        'text-secondary-dark',
        'text-tertiary',
        'text-tertiary-dark',
        'text-blush',
        'text-canvas',
        'text-surface',
        'text-obsidian',
        'text-ink',
        'text-ink-soft',
        'text-ink-muted',
        'text-crisis-text',
        'text-dass-normal',
        'text-dass-mild',
        'text-dass-moderate',
        'text-dass-severe',
        'text-dass-extreme',
      ],
    },
  },
})

/** Merge conditional class names and resolve Tailwind conflicts. */
export function cn(...inputs: ClassValue[]) {
  return customTwMerge(clsx(inputs))
}

