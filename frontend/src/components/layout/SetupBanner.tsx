'use client'

import { useMemo, useState } from 'react'
import Link from 'next/link'
import { Alert, AlertTitle, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { ShieldAlert, AlertTriangle, ArrowRight, ExternalLink, Check, Loader2 } from 'lucide-react'
import { useTranslation } from '@/lib/hooks/use-translation'
import { useCredentialStatus, useEnvStatus } from '@/lib/hooks/use-credentials'
import { credentialsApi } from '@/lib/api/credentials'

export function SetupBanner() {
  const { t } = useTranslation()
  const { data: credentialStatus, refetch: refetchCredentialStatus } = useCredentialStatus()
  const { data: envStatus } = useEnvStatus()
  const [generatingKey, setGeneratingKey] = useState(false)
  const [keyGenerated, setKeyGenerated] = useState(false)

  const encryptionReady = credentialStatus?.encryption_configured ?? true

  const providersToMigrate = useMemo(() => {
    if (!envStatus || !credentialStatus) return []
    const providers: string[] = []
    for (const provider in envStatus) {
      if (envStatus[provider] && credentialStatus.source[provider] === 'environment') {
        providers.push(provider)
      }
    }
    return providers
  }, [envStatus, credentialStatus])

  if (encryptionReady && providersToMigrate.length === 0) {
    return null
  }

  if (!encryptionReady) {
    const handleGenerateKey = async () => {
      setGeneratingKey(true)
      try {
        const result = await credentialsApi.generateEncryptionKey()
        if (result.status === 'success' || result.status === 'already_configured') {
          setKeyGenerated(true)
          // Re-fetch credential status to update the UI
          await refetchCredentialStatus()
        }
      } catch (error) {
        console.error('Failed to generate encryption key:', error)
      } finally {
        setGeneratingKey(false)
      }
    }

    if (keyGenerated) {
      return (
        <div className="px-4 pt-3">
          <Alert className="border-green-500/50 bg-green-50 dark:bg-green-950/20">
            <Check className="h-4 w-4 text-green-600 dark:text-green-400" />
            <AlertTitle className="text-green-800 dark:text-green-200">
              {t('setupBanner.encryptionReady') || 'Encryption key configured'}
            </AlertTitle>
            <AlertDescription className="text-green-700 dark:text-green-300">
              {t('setupBanner.encryptionReadyDescription') || 'API key encryption is now active. You can store API keys safely.'}
            </AlertDescription>
          </Alert>
        </div>
      )
    }

    return (
      <div className="px-4 pt-3">
        <Alert className="border-red-500/50 bg-red-50 dark:bg-red-950/20">
          <ShieldAlert className="h-4 w-4 text-red-600 dark:text-red-400" />
          <AlertTitle className="text-red-800 dark:text-red-200">
            {t('setupBanner.encryptionRequired')}
          </AlertTitle>
          <AlertDescription className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between text-red-700 dark:text-red-300">
            <span>{t('setupBanner.encryptionRequiredDescription')}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={handleGenerateKey}
              disabled={generatingKey}
              className="shrink-0 border-red-500 text-red-700 hover:bg-red-100 dark:border-red-400 dark:text-red-300 dark:hover:bg-red-900/30"
            >
              {generatingKey ? (
                <>
                  <Loader2 className="mr-2 h-3 w-3 animate-spin" />
                  {t('setupBanner.generating') || 'Generating...'}
                </>
              ) : (
                <>
                  <ShieldAlert className="mr-2 h-3 w-3" />
                  {t('setupBanner.generateKey') || 'Generate encryption key'}
                </>
              )}
            </Button>
          </AlertDescription>
        </Alert>
      </div>
    )
  }

  return (
    <div className="px-4 pt-3">
      <Alert className="border-amber-500/50 bg-amber-50 dark:bg-amber-950/20">
        <AlertTriangle className="h-4 w-4 text-amber-600 dark:text-amber-400" />
        <AlertTitle className="text-amber-800 dark:text-amber-200">
          {t('setupBanner.migrationAvailable')}
        </AlertTitle>
        <AlertDescription className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <span className="text-amber-700 dark:text-amber-300">
            {t('setupBanner.migrationDescription', { count: providersToMigrate.length })}
          </span>
          <Button
            variant="outline"
            size="sm"
            asChild
            className="shrink-0 border-amber-500 text-amber-700 hover:bg-amber-100 dark:border-amber-400 dark:text-amber-300 dark:hover:bg-amber-900/30"
          >
            <Link href="/settings/api-keys">
              {t('setupBanner.goToSettings')}
              <ArrowRight className="ml-2 h-4 w-4" />
            </Link>
          </Button>
        </AlertDescription>
      </Alert>
    </div>
  )
}
