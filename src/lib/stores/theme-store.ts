import { create } from 'zustand'
import { persist } from 'zustand/middleware'

export type Theme = 'light' | 'dark' | 'system'
export type Skin = 'quiet-green' | 'classic'

interface ThemeState {
  theme: Theme
  skin: Skin
  setTheme: (theme: Theme) => void
  setSkin: (skin: Skin) => void
  getSystemTheme: () => 'light' | 'dark'
  getEffectiveTheme: () => 'light' | 'dark'
}

const applySkinToDocument = (skin: Skin) => {
  if (typeof window !== 'undefined') {
    const root = window.document.documentElement
    root.setAttribute('data-skin', skin)
  }
}

export const useThemeStore = create<ThemeState>()(
  persist(
    (set, get) => ({
      theme: 'system',
      skin: 'quiet-green',
      
      setTheme: (theme: Theme) => {
        set({ theme })
        
        // Apply theme to document immediately
        if (typeof window !== 'undefined') {
          const root = window.document.documentElement
          const effectiveTheme = theme === 'system' ? get().getSystemTheme() : theme
          
          root.classList.remove('light', 'dark')
          root.classList.add(effectiveTheme)
          root.setAttribute('data-theme', effectiveTheme)
        }
      },

      setSkin: (skin: Skin) => {
        set({ skin })
        applySkinToDocument(skin)
      },
      
      getSystemTheme: () => {
        if (typeof window !== 'undefined') {
          return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
        }
        return 'light'
      },
      
      getEffectiveTheme: () => {
        const { theme } = get()
        return theme === 'system' ? get().getSystemTheme() : theme
      }
    }),
    {
      name: 'theme-storage',
      partialize: (state) => ({ theme: state.theme, skin: state.skin })
    }
  )
)

// Hook for components to use theme
export function useTheme() {
  const { theme, skin, setTheme, setSkin, getEffectiveTheme } = useThemeStore()
  
  return {
    theme,
    skin,
    setTheme,
    setSkin,
    effectiveTheme: getEffectiveTheme(),
    isDark: getEffectiveTheme() === 'dark'
  }
}