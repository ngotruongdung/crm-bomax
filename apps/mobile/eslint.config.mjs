import tsParser from '@typescript-eslint/parser';

const config = [
  {
    files: ['**/*.{ts,tsx}'],
    ignores: ['node_modules/**', '.expo/**'],
    languageOptions: { parser: tsParser },
  },
];

export default config;
