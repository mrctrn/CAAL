'use client';

import { useState } from 'react';
import { createPortal } from 'react-dom';
import { Globe } from '@phosphor-icons/react/dist/ssr';

const LANGUAGES = [
  { code: 'en', label: 'English' },
  { code: 'fr', label: 'Français' },
  { code: 'it', label: 'Italiano' },
  { code: 'pt', label: 'Português' },
  { code: 'da', label: 'Dansk' },
  { code: 'ro', label: 'Română' },
] as const;

const PIPER_MODELS: Record<string, string> = {
  fr: 'speaches-ai/piper-fr_FR-siwis-medium',
  it: 'speaches-ai/piper-it_IT-paola-medium',
  pt: 'speaches-ai/piper-pt_BR-faber-medium',
  da: 'speaches-ai/piper-da_DK-talesyntese-medium',
  ro: 'speaches-ai/piper-ro_RO-mihai-medium',
};

interface LanguageSelectorProps {
  onSelect: () => void;
}

export function LanguageSelector({ onSelect }: LanguageSelectorProps) {
  const [selected, setSelected] = useState('en');
  const [saving, setSaving] = useState(false);

  const handleContinue = async () => {
    setSaving(true);

    // Set locale cookie (1 year)
    document.cookie = `CAAL_LOCALE=${selected};path=/;max-age=31536000;SameSite=Lax`;

    // Save language to backend so agent knows before setup completes
    try {
      await fetch('/api/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ settings: { language: selected } }),
      });
    } catch {
      // Best-effort — cookie is the critical part
    }

    // Pre-download Piper TTS model for non-English languages
    const modelId = PIPER_MODELS[selected];
    if (modelId) {
      fetch('/api/download-piper-model', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ model_id: modelId }),
      }).catch(() => {});
    }

    onSelect();
    window.location.reload();
  };

  return createPortal(
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="bg-background border-input dark:border-muted flex w-full max-w-sm flex-col items-center gap-6 rounded-lg border p-8 shadow-xl">
        <Globe className="text-muted-foreground h-10 w-10" weight="duotone" />

        <div className="text-center">
          <h2 className="text-lg font-semibold">Choose your language</h2>
          <p className="text-muted-foreground text-sm">
            Choisissez votre langue / Scegli la tua lingua
            <br />
            Escolha o idioma / Vælg dit sprog / Alegeți limba
          </p>
        </div>

        <select
          value={selected}
          onChange={(e) => setSelected(e.target.value)}
          className="select-field text-foreground w-full px-4 py-3 text-sm"
        >
          {LANGUAGES.map((lang) => (
            <option key={lang.code} value={lang.code}>
              {lang.label}
            </option>
          ))}
        </select>

        <button
          onClick={handleContinue}
          disabled={saving}
          className="bg-primary text-primary-foreground hover:bg-primary/90 w-full rounded-md px-4 py-2.5 text-sm font-medium transition-colors disabled:opacity-50"
        >
          {saving ? '...' : 'Continue →'}
        </button>
      </div>
    </div>,
    document.body
  );
}
