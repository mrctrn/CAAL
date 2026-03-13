export const locales = ['en', 'fr', 'it', 'pt', 'da', 'ro'] as const;
export type Locale = (typeof locales)[number];
export const defaultLocale: Locale = 'en';
